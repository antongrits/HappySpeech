import OSLog
import SwiftUI

// MARK: - ReadAloudStoryViewModelHolder

@MainActor
@Observable
final class ReadAloudStoryViewModelHolder: ReadAloudStoryDisplayLogic {

    var startVM: ReadAloudStoryModels.Start.ViewModel?
    var stage: ReadAloudStage = .reading(currentSentenceIndex: 0)
    var highlightedSentenceIndex: Int?
    var progressLabel: String = ""
    var progressFraction: Double = 0
    var currentQuestionVM: ReadAloudStoryModels.StartQuiz.ViewModel?
    var lastFeedback: String?
    var lastWasCorrect: Bool?
    var summary: ReadAloudStoryModels.Answer.SummaryViewModel?
    var isFinished: Bool = false

    func displayStart(viewModel: ReadAloudStoryModels.Start.ViewModel) async {
        startVM = viewModel
        stage = .reading(currentSentenceIndex: 0)
        highlightedSentenceIndex = nil
        progressLabel = viewModel.firstSentenceLabel
        progressFraction = viewModel.sentences.isEmpty ? 0 : (1.0 / Double(viewModel.sentences.count))
        currentQuestionVM = nil
        summary = nil
        isFinished = false
        lastFeedback = nil
        lastWasCorrect = nil
    }

    func displayNextSentence(viewModel: ReadAloudStoryModels.NextSentence.ViewModel) async {
        stage = viewModel.stage
        highlightedSentenceIndex = viewModel.highlightedSentenceIndex
        progressLabel = viewModel.progressLabel
        progressFraction = viewModel.progressFraction
    }

    func displayStartQuiz(viewModel: ReadAloudStoryModels.StartQuiz.ViewModel) async {
        stage = .quiz(questionIndex: 0)
        currentQuestionVM = viewModel
        progressLabel = viewModel.progressLabel
        progressFraction = viewModel.progressFraction
        lastFeedback = nil
        lastWasCorrect = nil
    }

    func displayAnswer(viewModel: ReadAloudStoryModels.Answer.ViewModel) async {
        isFinished = viewModel.isFinished
        summary = viewModel.summary
        if let next = viewModel.nextQuestion {
            currentQuestionVM = next
            progressLabel = next.progressLabel
            progressFraction = next.progressFraction
            lastFeedback = nil
            lastWasCorrect = nil
        } else {
            lastFeedback = viewModel.feedbackText
            lastWasCorrect = viewModel.wasCorrect
            if viewModel.isFinished {
                stage = .summary
            }
        }
    }
}

// MARK: - ReadAloudStoryView
//
// v31 Волна D Ф.1 «Слушай и понимай».
// Карточка истории с озвучкой → 3-вопросный квиз на понимание.
//
// Accessibility:
//   • Kid circuit: тач-цели ≥ 56pt, шрифт ≥ 17pt.
//   • Dynamic Type: minimumScaleFactor 0.7–0.85.
//   • Reduced Motion: переходы гейтятся `reduceMotion`.
//   • VoiceOver: вопросы и варианты — accessibilityLabel.
//   • Light + Dark: ColorTokens.Kid.

struct ReadAloudStoryView: View {

    let childId: String

    @State private var holder = ReadAloudStoryViewModelHolder()
    @State private var interactor: ReadAloudStoryInteractor?
    @State private var presenter: ReadAloudStoryPresenter?
    @State private var router: ReadAloudStoryRouter?
    @State private var optionOrder: [Int] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ReadAloudStory.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text("readAloud.title"))
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
                    .accessibilityLabel(Text("readAloud.close.a11y"))
                }
            }
            .task {
                await setup()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if holder.isFinished, let summary = holder.summary {
            summarySection(summary)
        } else if case .quiz = holder.stage, let quiz = holder.currentQuestionVM {
            quizSection(quiz)
        } else if let start = holder.startVM {
            readingSection(start)
        } else {
            loadingSection
        }
    }

    // MARK: - Reading

    private func readingSection(_ start: ReadAloudStoryModels.Start.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                    Text(start.title)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.bottom, SpacingTokens.sp2)

                    ForEach(Array(start.sentences.enumerated()), id: \.offset) { idx, sentence in
                        sentenceLine(sentence, index: idx)
                    }
                }
                .padding(SpacingTokens.sp4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Kid.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
                )
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            VStack(spacing: SpacingTokens.sp2) {
                Button {
                    Task { await interactor?.playNextSentence() }
                } label: {
                    Label {
                        Text(playButtonLabel(for: start))
                            .font(TypographyTokens.headline(17))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    } icon: {
                        Image(systemName: holder.highlightedSentenceIndex == nil
                              ? "play.circle.fill" : "speaker.wave.2.fill")
                    }
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("readAloud.playButton")
                .accessibilityHint(Text("readAloud.play.hint"))

                Button {
                    Task { await interactor?.skipToQuiz() }
                } label: {
                    Text("readAloud.skipToQuiz")
                        .font(TypographyTokens.body(15).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("readAloud.skipButton")
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp5)
        }
    }

    private func sentenceLine(_ sentence: String, index: Int) -> some View {
        let isActive = holder.highlightedSentenceIndex == index
        return Text(sentence)
            .font(TypographyTokens.body(17))
            .foregroundStyle(isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.ink)
            .fontWeight(isActive ? .semibold : .regular)
            .lineLimit(nil)
            .padding(.vertical, SpacingTokens.sp1)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(isActive
                          ? ColorTokens.Brand.primary.opacity(0.08)
                          : Color.clear)
                    .padding(.horizontal, -SpacingTokens.sp2)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isActive)
            .accessibilityLabel(Text(sentence))
    }

    private func playButtonLabel(
        for start: ReadAloudStoryModels.Start.ViewModel
    ) -> String {
        if holder.highlightedSentenceIndex == nil {
            return String(localized: "readAloud.playFromStart")
        }
        return String(localized: "readAloud.playNext")
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: SpacingTokens.sp1) {
            Text(holder.progressLabel)
                .font(TypographyTokens.caption(12).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.surfaceAlt)
                    Capsule()
                        .fill(ColorTokens.Brand.primary)
                        .frame(width: max(0, geo.size.width * holder.progressFraction))
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp3)
    }

    // MARK: - Quiz

    private func quizSection(
        _ quiz: ReadAloudStoryModels.StartQuiz.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            progressBar
            Spacer()
            Text(quiz.prompt)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp4)
                .accessibilityLabel(Text(quiz.accessibilityLabel))

            if let feedback = holder.lastFeedback,
               let wasCorrect = holder.lastWasCorrect {
                feedbackBanner(text: feedback, isCorrect: wasCorrect)
            }

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                ForEach(displayedOptions(quiz)) { option in
                    optionButton(option)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp5)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: quiz.prompt)
    }

    private func optionButton(
        _ option: ReadAloudStoryModels.StartQuiz.OptionViewModel
    ) -> some View {
        Button {
            Task { await answer(optionIndex: option.id) }
        } label: {
            Text(option.label)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 60)
                .padding(SpacingTokens.sp3)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.sky)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.label))
        .accessibilityIdentifier("readAloud.option.\(option.id)")
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
                .minimumScaleFactor(0.85)
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
        _ summary: ReadAloudStoryModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            Spacer()
            Image(systemName: summary.accuracyFraction >= 0.8
                  ? "star.circle.fill"
                  : "hand.thumbsup.circle.fill")
                .font(.system(size: 84))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(19).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.sp5)
            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await restart() }
                } label: {
                    Text("readAloud.summary.newStory")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("readAloud.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp5)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView().controlSize(.large)
            Text("readAloud.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Option ordering (shuffle for fairness)

    private func displayedOptions(
        _ quiz: ReadAloudStoryModels.StartQuiz.ViewModel
    ) -> [ReadAloudStoryModels.StartQuiz.OptionViewModel] {
        guard optionOrder.count == quiz.options.count else {
            return quiz.options
        }
        return optionOrder.compactMap { idx in
            quiz.options.first { $0.id == idx }
        }
    }

    private func refreshOptionOrder(for quiz: ReadAloudStoryModels.StartQuiz.ViewModel?) {
        guard let quiz else { return }
        optionOrder = quiz.options.map(\.id).shuffled()
    }

    // MARK: - Wiring

    private func setup() async {
        if interactor == nil {
            let presenter = ReadAloudStoryPresenter(displayLogic: holder)
            let worker = ReadAloudStoryWorker()
            let interactor = ReadAloudStoryInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = ReadAloudStoryRouter(dismissAction: { dismiss() })
        }
        await interactor?.start(request: .init(childId: childId, excludeStoryId: nil))
    }

    private func answer(optionIndex: Int) async {
        await interactor?.answer(request: .init(optionIndex: optionIndex))
        refreshOptionOrder(for: holder.currentQuestionVM)
    }

    private func restart() async {
        let previousId = holder.startVM?.storyId
        await interactor?.start(request: .init(childId: childId, excludeStoryId: previousId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ReadAloudStory") {
    ReadAloudStoryView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
