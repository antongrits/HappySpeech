import SwiftUI

// MARK: - StoryRetellingProView (Clean Swift: View)
//
// Реальная активность пересказа: выбор сказки → запись пересказа (микрофон) →
// ASR-распознавание → скоринг покрытия ключевых фактов → результат. Бейджи
// «выполнено» отражают РЕАЛЬНУЮ завершённость из Realm (через Interactor.load).

struct StoryRetellingProView: View {

    let childId: String

    @State private var interactor: StoryRetellingProInteractor?
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "storyRetelling.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let worker = StoryRetellingProWorker(
                        audioService: container.audioService,
                        asrService: container.asrService,
                        realmActor: container.realmActor
                    )
                    let new = StoryRetellingProInteractor(childId: childId, worker: worker)
                    interactor = new
                    await new.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if interactor.state.isLoading {
                ProgressView().controlSize(.large)
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        hero
                        list(interactor: interactor)
                        activityPanel(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "storyRetelling.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "storyRetelling.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func list(interactor: StoryRetellingProInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.stories) { story in
                row(story: story, isSelected: story.id == interactor.state.selectedStoryId) {
                    hapticService.impact(.light)
                    interactor.select(story.id)
                }
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                }
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func row(
        story: StoryRetellingProModels.Story,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            // Выбранная сказка — тёплая коралловая подсветка (эталон .choice.sel),
            // а не мятно-зелёная: mint резервируем под success-галочки.
            HSCard(style: isSelected ? .tinted(ColorTokens.Brand.primaryLo.opacity(0.34)) : .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: story.isCompleted ? "checkmark.seal.fill" : "book.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            story.isCompleted ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft
                        )
                        .hsSymbolEffect(.bounce, value: story.isCompleted)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(story.title)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(story.summary)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(story.keyFactsCount) фактов")
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                        if story.bestCoverage > 0 {
                            Text("\(Int((story.bestCoverage * 100).rounded()))%")
                                .font(TypographyTokens.caption(11))
                                .foregroundStyle(ColorTokens.Brand.primary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(rowAccessibilityLabel(story)))
        .accessibilityAddTraits(.isButton)
    }

    private func rowAccessibilityLabel(_ story: StoryRetellingProModels.Story) -> String {
        let status = story.isCompleted
            ? String(localized: "storyRetelling.status.done")
            : String(localized: "storyRetelling.status.todo")
        return "\(story.title), \(story.keyFactsCount) ключевых фактов, \(status)"
    }

    // MARK: - Activity panel (record / scoring / result)

    @ViewBuilder
    private func activityPanel(interactor: StoryRetellingProInteractor) -> some View {
        if let storyId = interactor.state.selectedStoryId,
           let story = interactor.state.stories.first(where: { $0.id == storyId }) {
            HSCard(style: .elevated) {
                VStack(spacing: SpacingTokens.sp3) {
                    switch interactor.state.phase {
                    case .browsing:
                        recordPrompt(story: story, interactor: interactor)
                    case .recording:
                        recordingPanel(interactor: interactor)
                    case .scoring:
                        ProgressView()
                            .controlSize(.large)
                            .padding(.vertical, SpacingTokens.sp3)
                    case let .result(coverage, matched, missed):
                        resultPanel(
                            story: story,
                            coverage: coverage,
                            matched: matched,
                            missed: missed,
                            interactor: interactor
                        )
                    }
                }
            }
        }
    }

    private func recordPrompt(
        story: StoryRetellingProModels.Story,
        interactor: StoryRetellingProInteractor
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            Text(String(localized: "storyRetelling.record.prompt"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            HSButton(
                String(localized: "storyRetelling.record.start"),
                style: .primary,
                size: .large,
                icon: "mic.fill"
            ) {
                hapticService.impact(.medium)
                Task { await interactor.startRecording() }
            }
        }
    }

    private func recordingPanel(interactor: StoryRetellingProInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "waveform")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.Brand.primary)
                .hsSymbolEffect(.pulse, value: true)
            Text(String(localized: "storyRetelling.record.listening"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.ink)
            HSButton(
                String(localized: "storyRetelling.record.stop"),
                style: .primary,
                size: .large,
                icon: "stop.fill"
            ) {
                hapticService.impact(.medium)
                Task { await interactor.stopAndScore() }
            }
        }
    }

    private func resultPanel(
        story: StoryRetellingProModels.Story,
        coverage: Double,
        matched: [String],
        missed: [String],
        interactor: StoryRetellingProInteractor
    ) -> some View {
        let passed = coverage >= StoryRetellingProModels.ViewState.passThreshold
        return VStack(spacing: SpacingTokens.sp3) {
            Image(systemName: passed ? "checkmark.seal.fill" : "arrow.clockwise.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.Brand.primary)
                .hsSymbolEffect(.bounce, value: passed)
            Text(passed
                 ? String(localized: "storyRetelling.result.passed")
                 : String(localized: "storyRetelling.result.tryAgain"))
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Text("\(String(localized: "storyRetelling.result.coverage")): \(Int((coverage * 100).rounded()))%")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Brand.primary)
            if !missed.isEmpty {
                Text("\(String(localized: "storyRetelling.result.missed")): \(missed.joined(separator: ", "))")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            HSButton(
                String(localized: "storyRetelling.result.retry"),
                style: .secondary,
                size: .large,
                icon: "arrow.clockwise"
            ) {
                hapticService.impact(.light)
                interactor.backToBrowsing()
            }
        }
    }
}

// MARK: - Preview

#Preview("StoryRetellingPro — Light") {
    StoryRetellingProView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("StoryRetellingPro — Dark") {
    StoryRetellingProView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
