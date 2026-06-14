import SwiftUI

// MARK: - MorningRoutineView

struct MorningRoutineView: View {

    let childId: String

    @State private var interactor: MorningRoutineInteractor?
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "morning.nav.title")))
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
                    let new = MorningRoutineInteractor(childId: childId)
                    new.load()
                    interactor = new
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor, interactor.state.isLoaded {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    stepsList(interactor: interactor)
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: MorningRoutineModels.ViewState) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .waving, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "morning.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "morning.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    HSProgressBar(value: state.progress, style: .kid)
                        .frame(height: 8)
                        .padding(.top, SpacingTokens.micro)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func stepsList(interactor: MorningRoutineInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.state.steps.enumerated()), id: \.element.id) { index, step in
                stepCard(step) {
                    hapticService.impact(.light)
                    interactor.toggle(step.id)
                }
                .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                }
                .hsParallaxTile(factor: 0.22)
                .zIndex(Double(interactor.state.steps.count - index))
            }
        }
    }

    private func stepCard(
        _ step: MorningRoutineModels.Step,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            // Выполненный шаг — тёплый золотой тинт (достижение), без крупной
            // зелёной заливки. Признак «готово» — мятная галочка-акцент справа.
            HSCard(style: step.isDone
                ? .tinted(ColorTokens.Brand.gold.opacity(0.10))
                : .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: step.id.iconSystemName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.id.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(step.id.subtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(step.isDone ? ColorTokens.Semantic.success : ColorTokens.Kid.inkSoft)
                        .hsSymbolEffect(.bounce, value: step.isDone)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(step.id.title))
        .accessibilityValue(Text(step.isDone
            ? String(localized: "morning.a11y.done")
            : String(localized: "morning.a11y.todo")))
        .accessibilityAddTraits(.isButton)
    }

    private func cta(interactor: MorningRoutineInteractor) -> some View {
        HSButton(
            interactor.state.isCompleted
                ? String(localized: "morning.cta.finish")
                : String(localized: "morning.cta.start"),
            style: .primary,
            size: .large,
            icon: interactor.state.isCompleted ? "checkmark" : "sun.max.fill"
        ) {
            hapticService.notification(.success)
            if interactor.state.isCompleted {
                exitGame()
            } else {
                coordinator.navigate(to: .articulationGym(soundGroup: .sibilant))
            }
        }
    }
}

// MARK: - Preview

#Preview("MorningRoutine — Light") {
    MorningRoutineView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("MorningRoutine — Dark") {
    MorningRoutineView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
