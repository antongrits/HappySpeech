import SwiftUI

// MARK: - GoalTrackerKidView

struct GoalTrackerKidView: View {

    let childId: String

    @State private var interactor: GoalTrackerKidInteractor?
    @Environment(AppContainer.self) private var container
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
            .navigationTitle(Text(String(localized: "goalTracker.kid.nav.title")))
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
                    let new = GoalTrackerKidInteractor(
                        childId: childId,
                        sessionRepository: container.sessionRepository,
                        childRepository: container.childRepository
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
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    goalsList(interactor: interactor)
                    cta
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

    private func hero(state: GoalTrackerKidModels.ViewState) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .pointing, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "goalTracker.kid.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "goalTracker.kid.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    HSProgressBar(value: state.overallProgress, style: .kid)
                        .frame(height: 8)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func goalsList(interactor: GoalTrackerKidInteractor) -> some View {
        if interactor.state.goals.isEmpty {
            HSEmptyStateView(
                warmPanel: .thinking,
                title: String(
                    localized: "goalTracker.kid.empty.title",
                    defaultValue: "Целей пока нет"
                ),
                subtitle: String(
                    localized: "goalTracker.kid.empty.subtitle",
                    defaultValue: "Сыграй немного — и здесь появятся твои цели на сегодня."
                )
            )
            .padding(.top, SpacingTokens.sp4)
        } else {
            goalsGrid(interactor: interactor)
        }
    }

    private func goalsGrid(interactor: GoalTrackerKidInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.state.goals.enumerated()), id: \.element.id) { index, goal in
                goalCard(goal) {
                    hapticService.impact(.light)
                }
                .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.94)
                }
                .hsParallaxTile(factor: 0.22)
                .zIndex(Double(interactor.state.goals.count - index))
            }
        }
    }

    private func goalCard(
        _ goal: GoalTrackerKidModels.Goal,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            // Достигнутая цель — тёплый золотой тинт (достижение), без крупной
            // зелёной заливки. Признак «готово» дублируется bounce-иконкой.
            HSCard(style: goal.isReached
                ? .tinted(ColorTokens.Brand.gold.opacity(0.10))
                : .elevated) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                    HStack(spacing: SpacingTokens.sp2) {
                        Image(systemName: goal.id.iconSystemName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(width: 28, height: 28)
                            .hsSymbolEffect(.bounce, value: goal.isReached)
                        Text(goal.id.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        Text("\(goal.current)/\(goal.target) \(goal.id.unit)")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    HSProgressBar(value: goal.progress, style: .kid)
                        .frame(height: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(goal.id.title))
        .accessibilityValue(Text("\(goal.current) из \(goal.target) \(goal.id.unit)"))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "goalTracker.kid.cta.action"),
            style: .primary,
            size: .large,
            icon: "play.fill"
        ) {
            hapticService.notification(.success)
            coordinator.navigate(to: .childHome(childId: childId))
        }
    }
}

// MARK: - Preview

#Preview("GoalTrackerKid — Light") {
    GoalTrackerKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("GoalTrackerKid — Dark") {
    GoalTrackerKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
