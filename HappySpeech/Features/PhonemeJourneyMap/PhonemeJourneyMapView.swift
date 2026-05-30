import SwiftUI

// MARK: - PhonemeJourneyMapView

struct PhonemeJourneyMapView: View {

    let childId: String

    @State private var interactor: PhonemeJourneyMapInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch C — Pattern 1: kidCool mesh палитра (прохладный
                // roadmap-вайб). softLight overlay для глубины фона.
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.28)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "phonemeJourney.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = PhonemeJourneyMapInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    roadmap(interactor: interactor)
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: PhonemeJourneyMapModels.ViewState) -> some View {
        // Step 10 Batch C — Pattern 2: HSLiquidGlassCard(.elevated) — kavsoft
        // hero card поверх kidCool mesh.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp3) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .explaining, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "phonemeJourney.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "phonemeJourney.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: 6) {
                        Text(state.targetSound)
                            .font(TypographyTokens.titleLarge(28).weight(.bold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                        Text("· шаг \(state.currentIndex + 1) из \(state.stages.count)")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    HSProgressBar(value: state.progress, style: .kid)
                        .frame(height: 8)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func roadmap(interactor: PhonemeJourneyMapInteractor) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(interactor.state.stages.enumerated()), id: \.element.id) { idx, item in
                stageRow(
                    item: item,
                    index: idx,
                    isLast: idx == interactor.state.stages.count - 1
                ) {
                    hapticService.impact(.light)
                    interactor.toggle(item.id)
                }
                // Step 10 Batch C — Pattern 3 + 4: scrollTransition stagger
                // fade+scale + parallax drift на roadmap stages.
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                }
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func stageRow(
        item: PhonemeJourneyMapModels.StageItem,
        index: Int,
        isLast: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(item.isComplete ? ColorTokens.Semantic.success : ColorTokens.Kid.surfaceAlt)
                        .frame(width: 36, height: 36)
                    Image(systemName: item.isComplete ? "checkmark" : item.id.iconSystemName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(item.isComplete ? Color.white : ColorTokens.Brand.primary)
                        // Step 10 Batch C — Pattern 5: bounce on stage symbol
                        // when item flips to complete (state-reactive feedback).
                        .hsSymbolEffect(.bounce, value: item.isComplete)
                }
                if !isLast {
                    Rectangle()
                        .fill(item.isComplete ? ColorTokens.Semantic.success.opacity(0.5) : ColorTokens.Kid.line)
                        .frame(width: 3, height: 44)
                }
            }
            Button(action: action) {
                HSCard(style: item.isComplete ? .tinted(ColorTokens.Semantic.successBg) : .elevated) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.id.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(item.id.caption)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(item.id.title))
            .accessibilityValue(Text(item.isComplete ? "Готово" : "В работе"))
            .accessibilityAddTraits(.isButton)
        }
        .padding(.bottom, isLast ? 0 : SpacingTokens.sp2)
    }

    private func cta(interactor: PhonemeJourneyMapInteractor) -> some View {
        HSButton(
            String(localized: "phonemeJourney.cta.action"),
            style: .primary,
            size: .large,
            icon: "arrow.right"
        ) {
            hapticService.notification(.success)
            coordinator.navigate(to: .worldMap(
                childId: childId,
                targetSound: interactor.state.targetSound
            ))
        }
    }
}

// MARK: - Preview

#Preview("PhonemeJourneyMap — Light") {
    PhonemeJourneyMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("PhonemeJourneyMap — Dark") {
    PhonemeJourneyMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
