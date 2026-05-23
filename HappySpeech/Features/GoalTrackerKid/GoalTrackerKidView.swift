import SwiftUI

// MARK: - GoalTrackerKidView

struct GoalTrackerKidView: View {

    let childId: String

    @State private var interactor: GoalTrackerKidInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "goalTracker.kid.nav.title")))
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
                    interactor = GoalTrackerKidInteractor(childId: childId)
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
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: GoalTrackerKidModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.18))) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .pointing, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "goalTracker.kid.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
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

    private func goalsList(interactor: GoalTrackerKidInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.goals) { goal in
                goalCard(goal) {
                    hapticService.impact(.light)
                    interactor.bump(goal.id)
                }
            }
        }
    }

    private func goalCard(
        _ goal: GoalTrackerKidModels.Goal,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HSCard(style: goal.isReached ? .tinted(ColorTokens.Semantic.successBg) : .elevated) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                    HStack(spacing: SpacingTokens.sp2) {
                        Image(systemName: goal.id.iconSystemName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(width: 28, height: 28)
                        Text(goal.id.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
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
