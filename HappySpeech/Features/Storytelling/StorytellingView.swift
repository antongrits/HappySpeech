import OSLog
import SwiftUI

// MARK: - StorytellingViewModelHolder

@MainActor
@Observable
final class StorytellingViewModelHolder: StorytellingDisplayLogic {

    var topicsVM: StorytellingModels.LoadTopics.ViewModel?
    var topicStartVM: StorytellingModels.StartTopic.ViewModel?
    var completedStepIds: Set<String> = []
    var progressLabel: String = ""
    var progressFraction: Double = 0
    var finishVM: StorytellingModels.Finish.ViewModel?
    var phase: Phase = .loading

    enum Phase: Equatable {
        case loading
        case topics
        case telling
        case finished
    }

    func displayTopics(viewModel: StorytellingModels.LoadTopics.ViewModel) async {
        self.topicsVM = viewModel
        self.phase = .topics
        self.finishVM = nil
    }

    func displayTopicStart(viewModel: StorytellingModels.StartTopic.ViewModel) async {
        self.topicStartVM = viewModel
        self.completedStepIds = []
        self.progressLabel = ""
        self.progressFraction = 0
        self.phase = .telling
    }

    func displayToggle(viewModel: StorytellingModels.ToggleStep.ViewModel) async {
        self.completedStepIds = viewModel.completedStepIds
        self.progressLabel = viewModel.progressLabel
        self.progressFraction = viewModel.progressFraction
    }

    func displayFinish(viewModel: StorytellingModels.Finish.ViewModel) async {
        self.finishVM = viewModel
        self.phase = .finished
    }
}

// MARK: - StorytellingView (Clean Swift: View)
//
// v29 Фаза 8, Функция 11 «Я расскажу историю».
//
// Детская игра творческого нарратива: ребёнок выбирает тему и составляет
// рассказ по плану-схеме, отмечая озвученные шаги; рассказ сохраняется
// в «Книжку историй».
//
// Accessibility:
//   • Kid circuit: карточки и кнопки ≥ 56pt
//   • VoiceOver: темы и шаги — описательные labels
//   • Dynamic Type: minimumScaleFactor
//   • Reduced Motion: переходы фаз гейтятся reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct StorytellingView: View {

    let childId: String

    @State private var holder = StorytellingViewModelHolder()
    @State private var interactor: StorytellingInteractor?
    @State private var presenter: StorytellingPresenter?
    @State private var router: StorytellingRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Storytelling.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                switch holder.phase {
                case .loading:
                    loadingSection
                case .topics:
                    if let topics = holder.topicsVM { topicsSection(topics) }
                case .telling:
                    if let start = holder.topicStartVM { tellingSection(start) }
                case .finished:
                    if let finish = holder.finishVM { summarySection(finish) }
                }
            }
            .navigationTitle(Text("storytelling.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if holder.phase == .telling {
                            Task { await backToTopics() }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("storytelling.close.a11y"))
                }
            }
            .task {
                await setup()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Topics

    private func topicsSection(
        _ topics: StorytellingModels.LoadTopics.ViewModel
    ) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                Text("storytelling.topics.prompt")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp4)
                    .padding(.top, SpacingTokens.sp4)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: SpacingTokens.sp3
                ) {
                    ForEach(topics.topics) { topic in
                        topicCard(topic)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp6)
            }
        }
    }

    private func topicCard(
        _ topic: StorytellingModels.LoadTopics.TopicCardViewModel
    ) -> some View {
        Button {
            Task { await startTopic(topicId: topic.id) }
        } label: {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: topic.symbolName)
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                Text(topic.title)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
            )
            .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(topic.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Telling

    private func tellingSection(
        _ start: StorytellingModels.StartTopic.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: start.symbolName)
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .accessibilityHidden(true)
                Text(start.topicTitle)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text("storytelling.telling.prompt")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp4)
                if !holder.progressLabel.isEmpty {
                    Text(holder.progressLabel)
                        .font(TypographyTokens.caption(13).monospacedDigit())
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
            }
            .padding(.top, SpacingTokens.sp4)

            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    ForEach(start.steps) { step in
                        stepCard(
                            step,
                            isDone: holder.completedStepIds.contains(step.id)
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Button {
                Task { await finish() }
            } label: {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "book.fill")
                    Text("storytelling.finishButton")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("storytelling.finishButton.hint"))
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp5)
        }
    }

    private func stepCard(
        _ step: StorytellingModels.StartTopic.StepViewModel,
        isDone: Bool
    ) -> some View {
        Button {
            Task { await toggle(stepId: step.id) }
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: step.symbolName)
                    .font(.system(size: 32))
                    .foregroundStyle(isDone ? ColorTokens.Brand.mint : ColorTokens.Brand.sky)
                    .frame(width: 44)
                Text(step.question)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? ColorTokens.Brand.mint : ColorTokens.Kid.inkSoft)
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(
                        isDone ? ColorTokens.Brand.mint : ColorTokens.Kid.line,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(step.accessibilityLabel))
        .accessibilityHint(Text("storytelling.step.hint"))
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isDone)
    }

    // MARK: - Summary

    private func summarySection(
        _ finish: StorytellingModels.Finish.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: finish.savedToBook
                ? "books.vertical.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)

            Text(finish.title)
                .font(TypographyTokens.title(25))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(finish.scoreText)
                .font(TypographyTokens.headline(19).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(finish.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await backToTopics() }
                } label: {
                    Text("storytelling.summary.another")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("storytelling.summary.another.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("storytelling.summary.done")
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
            Text("storytelling.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    private func setup() async {
        if interactor == nil {
            let presenter = StorytellingPresenter(displayLogic: holder)
            let worker = StorytellingWorker(childRepository: container.childRepository)
            let interactor = StorytellingInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = StorytellingRouter(dismissAction: { dismiss() })
        }
        await interactor?.loadTopics(request: .init(childId: childId))
    }

    private func startTopic(topicId: String) async {
        await interactor?.startTopic(request: .init(topicId: topicId))
    }

    private func toggle(stepId: String) async {
        await interactor?.toggleStep(request: .init(stepId: stepId))
    }

    private func finish() async {
        await interactor?.finish(request: .init(voiceRecorded: true))
    }

    private func backToTopics() async {
        await interactor?.loadTopics(request: .init(childId: childId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Storytelling / topics") {
    StorytellingView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
