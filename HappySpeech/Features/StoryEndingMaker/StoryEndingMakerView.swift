import SwiftUI

// MARK: - StoryEndingMakerView

struct StoryEndingMakerView: View {

    let childId: String

    @State private var interactor: StoryEndingMakerInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp3), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                // Step 10 Batch E — Pattern 1: mesh .kidWarm палитра «придумай
                // концовку» — тёплый креативный режим.
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "storyEnding.nav.title")))
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
                    let maker = StoryEndingMakerInteractor(
                        childId: childId,
                        worker: StoryEndingMakerWorker(childRepository: container.childRepository),
                        audioService: container.audioService,
                        adaptivePlanner: container.adaptivePlannerService
                    )
                    interactor = maker
                    await maker.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if !interactor.state.isLoaded {
                ProgressView().controlSize(.large)
            } else if interactor.state.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        hero(state: interactor.state)
                        cards(interactor: interactor)
                        if interactor.state.phase == .saved {
                            savedBanner
                        }
                        cta(interactor: interactor)
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

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .idle, size: 80)
                .accessibilityHidden(true)
            Text(String(localized: "storyEnding.empty.title"))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.screenEdge)
    }

    private func hero(state: StoryEndingMakerModels.ViewState) -> some View {
        // Step 10 Batch E — Pattern 2: hero на HSLiquidGlassCard(.elevated).
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .thinking, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "storyEnding.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "storyEnding.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    phaseLabel(state.phase)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func phaseLabel(_ phase: StoryEndingMakerModels.Phase) -> some View {
        let text: String = {
            switch phase {
            case .choosing:  return String(localized: "storyEnding.step.choose")
            case .recording: return String(localized: "storyEnding.step.record")
            case .saving:    return String(localized: "storyEnding.step.saving")
            case .saved:     return String(localized: "storyEnding.step.done")
            }
        }()
        Text(text)
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.top, 2)
    }

    private func cards(interactor: StoryEndingMakerInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
            ForEach(interactor.state.cards) { card in
                cardTile(card, selected: interactor.state.selectedId == card.id) {
                    hapticService.impact(.light)
                    interactor.select(card.id)
                }
                // Step 10 Batch E — Pattern 3: scrollTransition stagger fade+scale.
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                }
                // Step 10 Batch E — Pattern 4: parallax drift на picture tiles.
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func cardTile(
        _ card: StoryEndingMakerModels.PictureCard,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                HSContentSymbol(card.asset ?? "sparkles", size: 56)
                Text(card.label)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    // Тёплая коралловая подсветка выбранной карточки (эталон
                    // .choice.sel = primary-lo). Раньше был Brand.sky (синий).
                    .fill(selected ? ColorTokens.Brand.primaryLo.opacity(0.40) : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(card.label))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var savedBanner: some View {
        // Тёплая «butter» подложка баннера «сохранено» вместо зелёного
        // Semantic.successBg на крупной карточке (стандинг-ордер: тёплая палитра
        // на больших заливках; зелёный success — только мелкие иконки/галочки).
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.30))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 48)
                    .accessibilityHidden(true)
                Text(String(localized: "storyEnding.saved.banner"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
            }
        }
    }

    private func cta(interactor: StoryEndingMakerInteractor) -> some View {
        let label: String = {
            switch interactor.state.phase {
            case .choosing:  return String(localized: "storyEnding.cta.action")
            case .recording: return String(localized: "storyEnding.cta.save")
            case .saving:    return String(localized: "storyEnding.step.saving")
            case .saved:     return String(localized: "storyEnding.cta.restart")
            }
        }()
        let icon: String = {
            switch interactor.state.phase {
            case .choosing:  return "hand.point.up.left.fill"
            case .recording: return "checkmark.circle.fill"
            case .saving:    return "hourglass"
            case .saved:     return "arrow.counterclockwise"
            }
        }()
        return HSButton(
            label,
            style: .primary,
            size: .large,
            icon: icon
        ) {
            hapticService.notification(.success)
            switch interactor.state.phase {
            case .choosing, .saving:  break
            case .recording: interactor.save()
            case .saved:     interactor.reset()
            }
        }
        .disabled(
            (interactor.state.phase == .choosing && interactor.state.selectedId == nil)
                || interactor.state.phase == .saving
        )
        .opacity(
            interactor.state.phase == .choosing && interactor.state.selectedId == nil ? 0.5 : 1.0
        )
    }
}

// MARK: - Preview

#Preview("StoryEndingMaker — Light") {
    StoryEndingMakerView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("StoryEndingMaker — Dark") {
    StoryEndingMakerView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
