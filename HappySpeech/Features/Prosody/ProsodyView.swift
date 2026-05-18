import OSLog
import SwiftUI

// MARK: - ProsodyViewModelHolder

@MainActor
@Observable
final class ProsodyViewModelHolder: ProsodyDisplayLogic {

    var startVM: ProsodyModels.Start.ViewModel?
    var currentRound: ProsodyModels.Start.RoundViewModel?
    var lastFeedback: String?
    var lastWasCorrect: Bool?
    var summary: ProsodyModels.Answer.SummaryViewModel?
    var isFinished: Bool = false

    func displayStart(viewModel: ProsodyModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        self.isFinished = false
        self.summary = nil
        self.lastFeedback = nil
        self.lastWasCorrect = nil
    }

    func displayAnswer(viewModel: ProsodyModels.Answer.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextRound {
            // Новый раунд — стираем обратную связь предыдущего, чтобы
            // баннер не оставался висеть на следующей фразе.
            self.currentRound = next
            self.lastFeedback = nil
            self.lastWasCorrect = nil
        } else {
            self.lastFeedback = viewModel.feedbackText
            self.lastWasCorrect = viewModel.wasCorrect
        }
    }
}

// MARK: - ProsodyView (Clean Swift: View)
//
// v29 Фаза 8, Функция 1 «Голосовые краски».
//
// Детская игра просодии: ребёнок различает интонацию на слух, повторяет
// фразу с заданной мелодикой, произносит фразу самостоятельно.
//
// Accessibility:
//   • Kid circuit: кнопки ≥ 56pt высотой
//   • VoiceOver: вопрос и варианты — описательные labels
//   • Dynamic Type: VStack + minimumScaleFactor
//   • Reduced Motion: смена раунда гейтится reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct ProsodyView: View {

    let childId: String

    @State private var holder = ProsodyViewModelHolder()
    @State private var interactor: ProsodyInteractor?
    @State private var presenter: ProsodyPresenter?
    @State private var router: ProsodyRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Prosody.View"
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
            .navigationTitle(Text("prosody.title"))
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
                    .accessibilityLabel(Text("prosody.close.a11y"))
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
        round: ProsodyModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            progressBar(round)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Text(round.prompt)
                    .font(TypographyTokens.headline(19))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp4)

                phraseCard(round)
            }
            .id(round.id)
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            if let feedback = holder.lastFeedback,
               let wasCorrect = holder.lastWasCorrect {
                feedbackBanner(text: feedback, isCorrect: wasCorrect)
            }

            Spacer()

            if round.stage == .discriminate {
                discriminateOptions(round)
            } else {
                voiceControl(round)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private func progressBar(
        _ round: ProsodyModels.Start.RoundViewModel
    ) -> some View {
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
    }

    private func phraseCard(
        _ round: ProsodyModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            if round.stage != .discriminate {
                Image(systemName: round.intonationSymbol)
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .accessibilityHidden(true)
            }
            Text(round.phraseText)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
        }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(round.accessibilityLabel))
    }

    private func discriminateOptions(
        _ round: ProsodyModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            ForEach(round.options) { option in
                Button {
                    Task { await answer(optionIndex: option.id, voice: false) }
                } label: {
                    HStack(spacing: SpacingTokens.sp3) {
                        Image(systemName: option.symbol)
                            .font(.title3)
                        Text(option.label)
                            .font(TypographyTokens.headline(19))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Spacer()
                    }
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(.horizontal, SpacingTokens.sp4)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.sky)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(option.label))
                .accessibilityHint(Text("prosody.option.hint"))
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.sp6)
    }

    private func voiceControl(
        _ round: ProsodyModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            Button {
                Task { await answer(optionIndex: 0, voice: true) }
            } label: {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                    Text("prosody.voice.say")
                        .font(TypographyTokens.headline(18))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("prosody.voice.hint"))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.sp6)
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
        _ summary: ProsodyModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "music.note.list"
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
                    Text("prosody.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("prosody.summary.again.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("prosody.summary.done")
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
            Text("prosody.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = ProsodyPresenter(displayLogic: holder)
            let worker = ProsodyWorker(childRepository: container.childRepository)
            let interactor = ProsodyInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = ProsodyRouter(dismissAction: { dismiss() })
        }
        _ = forceRestart
        await interactor?.start(request: .init(childId: childId))
    }

    private func answer(optionIndex: Int, voice: Bool) async {
        await interactor?.answer(
            request: .init(optionIndex: optionIndex, voiceAttempted: voice)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Prosody / game") {
    ProsodyView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
