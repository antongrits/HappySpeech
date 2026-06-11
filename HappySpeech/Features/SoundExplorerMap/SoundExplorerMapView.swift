import SwiftUI

// MARK: - SoundExplorerMapView

struct SoundExplorerMapView: View {

    let childId: String

    @State private var interactor: SoundExplorerMapInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 5)

    var body: some View {
        NavigationStack {
            ZStack {
                // Step 10 Batch E — Pattern 1: mesh .kidCool палитра для
                // «карты звуков» (прохладный exploration feel).
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidCool, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "soundMap.nav.title")))
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
                    let new = SoundExplorerMapInteractor(
                        childId: childId,
                        childRepository: container.childRepository,
                        sessionRepository: container.sessionRepository
                    )
                    interactor = new
                    new.refresh()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    hero
                    filterBar(interactor: interactor)
                    grid(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                // P6 v32: отступ снизу для glass-футера CTA.
                .padding(.bottom, SpacingTokens.sp16)
            }
            // P6 v32: стеклянный футер CTA, плавающий над контентом.
            .safeAreaInset(edge: .bottom) {
                HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.tiny)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
        // Step 10 Batch E — Pattern 2: hero на HSLiquidGlassCard(.elevated).
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .explaining, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "soundMap.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "soundMap.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func filterBar(interactor: SoundExplorerMapInteractor) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(SoundExplorerMapModels.MasteryFilter.allCases) { f in
                    chip(f, interactor: interactor)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(
        _ f: SoundExplorerMapModels.MasteryFilter,
        interactor: SoundExplorerMapInteractor
    ) -> some View {
        let selected = interactor.filter == f
        return Button {
            hapticService.impact(.light)
            interactor.setFilter(f)
        } label: {
            Text(f.title)
                .font(TypographyTokens.body(13))
                .foregroundStyle(selected
                                 ? ColorTokens.Overlay.onAccent
                                 : ColorTokens.Kid.ink)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected
                                   ? ColorTokens.Brand.primary
                                   : ColorTokens.Kid.bgSoft)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(f.title))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func grid(interactor: SoundExplorerMapInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.visible) { cell in
                soundCell(cell)
                    // Step 10 Batch E — Pattern 3: scrollTransition stagger
                    // fade+scale на sound-map cells.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                    }
                    // Step 10 Batch E — Pattern 4: parallax drift на map cells.
                    .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func soundCell(_ cell: SoundExplorerMapModels.SoundCell) -> some View {
        // P0.2 v32: каждый чип — 72pt квадрат с gradient fill, radius md=18,
        // badge состояния цветной (gold/primary/soft). ShadowTokens.Kid.tile.
        let (bgFrom, bgTo, textColor): (Color, Color, Color) = {
            switch cell.mastery {
            case .known:
                return (
                    ColorTokens.Brand.primaryLo.opacity(0.30),
                    ColorTokens.Brand.primary.opacity(0.10),
                    ColorTokens.Brand.primary
                )
            case .learning:
                return (
                    ColorTokens.Brand.butter.opacity(0.35),
                    ColorTokens.Brand.gold.opacity(0.12),
                    ColorTokens.Brand.gold
                )
            case .untried:
                return (
                    ColorTokens.Kid.bgSoft.opacity(0.90),
                    ColorTokens.Kid.surface.opacity(0.60),
                    ColorTokens.Kid.ink
                )
            }
        }()

        return Button {
            hapticService.impact(.light)
            coordinator.navigate(to: .articulationGym(soundGroup: .sibilant))
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    Text(cell.id)
                        .font(TypographyTokens.title(22).weight(.black))
                        .foregroundStyle(textColor)
                    Text(cell.group)
                        .font(TypographyTokens.caption(8))
                        .foregroundStyle(textColor.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 72)
                .padding(.vertical, SpacingTokens.sp2)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [bgFrom, bgTo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.50),
                            lineWidth: 0.5
                        )
                )

                // Значок состояния (P0.2: цветные badge вместо серого замка)
                masteryBadge(for: cell.mastery)
                    .padding(SpacingTokens.micro)
            }
            .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(cell.id), группа \(cell.group), \(masteryAccessibilityLabel(cell.mastery))"))
    }

    @ViewBuilder
    private func masteryBadge(for mastery: SoundExplorerMapModels.Mastery) -> some View {
        switch mastery {
        case .known:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.Brand.primary)
        case .learning:
            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.Brand.gold)
        case .untried:
            EmptyView()
        }
    }

    private func masteryAccessibilityLabel(_ mastery: SoundExplorerMapModels.Mastery) -> String {
        switch mastery {
        case .known:    return String(localized: "soundMap.mastery.known", defaultValue: "освоен")
        case .learning: return String(localized: "soundMap.mastery.learning", defaultValue: "учу")
        case .untried:  return String(localized: "soundMap.mastery.untried", defaultValue: "ещё не пробовал")
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "soundMap.cta.start"),
            style: .primary,
            size: .large,
            icon: "play.circle.fill"
        ) {
            hapticService.notification(.success)
            coordinator.navigate(to: .articulationGym(soundGroup: .sibilant))
        }
    }
}

// MARK: - Preview

#Preview("SoundExplorerMap — Light") {
    SoundExplorerMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SoundExplorerMap — Dark") {
    SoundExplorerMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
