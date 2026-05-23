import SwiftUI

// MARK: - DailyMissionsHubView

struct DailyMissionsHubView: View {

    let childId: String

    @State private var interactor: DailyMissionsHubInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "missions.nav.title")))
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
                    interactor = DailyMissionsHubInteractor(childId: childId)
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
                    hero(interactor: interactor)
                    missionsList(interactor: interactor)
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

    private func hero(interactor: DailyMissionsHubInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.sky.opacity(0.18))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .pointing, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "missions.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "missions.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    HSProgressBar(value: interactor.state.progress, style: .kid)
                        .frame(height: 8)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func missionsList(interactor: DailyMissionsHubInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(DailyMissionsHubModels.Mission.allCases) { mission in
                missionRow(mission, interactor: interactor)
            }
        }
    }

    private func missionRow(
        _ mission: DailyMissionsHubModels.Mission,
        interactor: DailyMissionsHubInteractor
    ) -> some View {
        let done = interactor.state.completed.contains(mission)
        return Button {
            hapticService.impact(.light)
            interactor.markCompleted(mission)
            route(for: mission)
        } label: {
            HSCard(style: done ? .tinted(ColorTokens.Semantic.successBg) : .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: mission.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        Text(mission.subtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    Image(systemName: done ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(done
                                         ? ColorTokens.Semantic.success
                                         : ColorTokens.Kid.inkSoft)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(mission.title))
        .accessibilityHint(Text(mission.subtitle))
    }

    private func cta(interactor: DailyMissionsHubInteractor) -> some View {
        HSButton(
            String(localized: "missions.cta.start"),
            style: .primary,
            size: .large,
            icon: "play.fill"
        ) {
            hapticService.notification(.success)
            coordinator.navigate(
                to: .lessonPlayer(templateType: "bingo", childId: childId)
            )
        }
    }

    private func route(for mission: DailyMissionsHubModels.Mission) {
        switch mission {
        case .warmup:
            coordinator.navigate(to: .articulationGym(soundGroup: .sibilant))
        case .soundOfDay:
            coordinator.navigate(to: .soundOfTheDay(childId: childId))
        case .bingo:
            coordinator.navigate(to: .lessonPlayer(templateType: "bingo", childId: childId))
        case .breathing:
            coordinator.navigate(to: .breatheAndSpeak(childId: childId))
        case .story:
            coordinator.navigate(to: .readAloudStory(childId: childId))
        }
    }
}

// MARK: - Preview

#Preview("DailyMissionsHub — Light") {
    DailyMissionsHubView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("DailyMissionsHub — Dark") {
    DailyMissionsHubView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
