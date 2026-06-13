import OSLog
import SwiftUI

// MARK: - PhonemicListeningViewModelHolder

@MainActor
@Observable
final class PhonemicListeningViewModelHolder: PhonemicListeningDisplayLogic {

    var startVM: PhonemicListeningModels.Start.ViewModel?
    var currentRound: PhonemicListeningModels.Start.RoundViewModel?
    var lastFeedback: String?
    var lastWasCorrect: Bool?
    var summary: PhonemicListeningModels.Answer.SummaryViewModel?
    var isFinished: Bool = false

    func displayStart(viewModel: PhonemicListeningModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        self.isFinished = false
        self.summary = nil
        self.lastFeedback = nil
        self.lastWasCorrect = nil
    }

    func displayAnswer(viewModel: PhonemicListeningModels.Answer.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextRound {
            // Новый раунд — стираем обратную связь предыдущего, чтобы
            // баннер не оставался висеть на следующем вопросе.
            self.currentRound = next
            self.lastFeedback = nil
            self.lastWasCorrect = nil
        } else {
            self.lastFeedback = viewModel.feedbackText
            self.lastWasCorrect = viewModel.wasCorrect
        }
    }
}

// MARK: - PhonemicListeningView (Clean Swift: View)
//
// v29 Фаза 8, Функция 12 «Слушай внимательно».
//
// Детская игра фонематического анализа: ребёнок отвечает на вопрос о
// позиции звука / количестве звуков / синтезе слова, выбирая один из
// вариантов. По завершении — сводка.
//
// Accessibility:
//   • Kid circuit: кнопки-варианты ≥ 56pt высотой
//   • VoiceOver: вопрос и варианты — описательные labels
//   • Dynamic Type: VStack + minimumScaleFactor
//   • Reduced Motion: смена раунда гейтится reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct PhonemicListeningView: View {

    let childId: String

    @State private var holder = PhonemicListeningViewModelHolder()
    @State private var interactor: PhonemicListeningInteractor?
    @State private var presenter: PhonemicListeningPresenter?
    @State private var router: PhonemicListeningRouter?
    /// Порядок отображения вариантов текущего раунда: `id` остаётся
    /// оригинальным индексом (для проверки в Interactor), но позиция на
    /// экране перемешана, чтобы правильный вариант не был всегда первым.
    @State private var optionOrder: [Int] = []

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemicListening.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if holder.isFinished, let summary = holder.summary {
                    summarySection(summary)
                } else if let round = holder.currentRound {
                    gameSection(round: round)
                } else {
                    loadingSection
                }
            }
            .navigationBarHidden(true)
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Game

    private func gameSection(
        round: PhonemicListeningModels.Start.RoundViewModel
    ) -> some View {
        KidGameTapScaffold(
            stepLabel: round.progressLabel,
            progress: round.progressFraction,
            promptText: round.prompt,
            mascotState: .thinking,
            feedback: currentFeedback,
            onClose: { exitGame() }
        ) {
            wordCard(round.word)
            optionsList(round)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private var currentFeedback: KidGameFeedback? {
        guard let feedback = holder.lastFeedback,
              let wasCorrect = holder.lastWasCorrect else { return nil }
        return KidGameFeedback(wasCorrect ? .correct : .incorrect, feedback)
    }

    private func optionsList(
        _ round: PhonemicListeningModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.small) {
            ForEach(displayedOptions(round)) { option in
                optionButton(option) {
                    Task { await answer(optionIndex: option.id) }
                }
            }
        }
        .id(round.id)
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
    }

    private func wordCard(_ word: String) -> some View {
        Text(word)
            .font(TypographyTokens.title(40))
            .foregroundStyle(ColorTokens.Kid.ink)
            .lineLimit(nil)
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.large)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .kidTileShadow()
            .accessibilityLabel(Text(verbatim: word))
            .accessibilityAddTraits(.isStaticText)
    }

    private func optionButton(
        _ option: PhonemicListeningModels.Start.OptionViewModel,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(option.label)
                .font(TypographyTokens.kidCardTitle(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(SpacingTokens.small)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                                .strokeBorder(ColorTokens.Brand.primary.opacity(0.4), lineWidth: 1.5)
                        )
                )
                .kidTileShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.label))
        .accessibilityHint(Text("phonemicListening.option.hint"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: PhonemicListeningModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "ear.badge.checkmark"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.butter)
                // Step 10 Batch C — Pattern 5: bounce on summary reveal
                // (kid celebration feedback).
                .hsSymbolEffect(.bounce, value: summary.scoreText)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("phonemicListening.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("phonemicListening.summary.again.hint"))

                Button {
                    exitGame()
                } label: {
                    Text("phonemicListening.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("phonemicListening.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Option ordering

    /// Варианты в перемешанном порядке отображения; `id` остаётся
    /// оригинальным индексом (для проверки в Interactor).
    private func displayedOptions(
        _ round: PhonemicListeningModels.Start.RoundViewModel
    ) -> [PhonemicListeningModels.Start.OptionViewModel] {
        guard optionOrder.count == round.options.count else {
            return round.options
        }
        return optionOrder.compactMap { idx in
            round.options.first { $0.id == idx }
        }
    }

    private func refreshOptionOrder(
        for round: PhonemicListeningModels.Start.RoundViewModel?
    ) {
        guard let round else { return }
        optionOrder = round.options.map(\.id).shuffled()
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = PhonemicListeningPresenter(displayLogic: holder)
            let worker = PhonemicListeningWorker(childRepository: container.childRepository)
            let interactor = PhonemicListeningInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = PhonemicListeningRouter(dismissAction: { exitGame() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId))
        refreshOptionOrder(for: holder.currentRound)
    }

    private func answer(optionIndex: Int) async {
        await interactor?.answer(request: .init(optionIndex: optionIndex))
        refreshOptionOrder(for: holder.currentRound)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PhonemicListening / game") {
    PhonemicListeningView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
