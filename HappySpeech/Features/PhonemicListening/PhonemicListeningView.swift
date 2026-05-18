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

    @Environment(\.dismiss) private var dismiss
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
            .navigationTitle(Text("phonemicListening.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("phonemicListening.close.a11y"))
                }
            }
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
        VStack(spacing: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(round.progressLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ColorTokens.Kid.surfaceAlt)
                        Capsule()
                            .fill(ColorTokens.Brand.primary)
                            .frame(width: max(0, geo.size.width * round.progressFraction))
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp4)

            Spacer()

            // Question + word
            VStack(spacing: SpacingTokens.sp3) {
                Text(round.prompt)
                    .font(TypographyTokens.headline(19))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp4)

                wordCard(round.word)
            }
            .id(round.id)
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            if let feedback = holder.lastFeedback,
               let wasCorrect = holder.lastWasCorrect {
                feedbackBanner(text: feedback, isCorrect: wasCorrect)
            }

            Spacer()

            // Answer options
            VStack(spacing: SpacingTokens.sp3) {
                ForEach(displayedOptions(round)) { option in
                    optionButton(option) {
                        Task { await answer(optionIndex: option.id) }
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private func wordCard(_ word: String) -> some View {
        Text(word)
            .font(TypographyTokens.title(40))
            .foregroundStyle(ColorTokens.Kid.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, SpacingTokens.sp6)
            .padding(.vertical, SpacingTokens.sp6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(Text(verbatim: word))
            .accessibilityAddTraits(.isStaticText)
    }

    private func optionButton(
        _ option: PhonemicListeningModels.Start.OptionViewModel,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(option.label)
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(SpacingTokens.sp3)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.sky)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.label))
        .accessibilityHint(Text("phonemicListening.option.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private func feedbackBanner(text: String, isCorrect: Bool) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: isCorrect
                ? "checkmark.circle.fill"
                : "arrow.counterclockwise.circle.fill")
                .font(.title3)
            Text(text)
                .font(TypographyTokens.body(15).weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(ColorTokens.Overlay.onAccent)
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp2)
        .background(
            Capsule().fill(isCorrect ? ColorTokens.Brand.mint : ColorTokens.Brand.butter)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(text))
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
                    dismiss()
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
            self.router = PhonemicListeningRouter(dismissAction: { dismiss() })
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
