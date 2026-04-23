import SwiftUI

// MARK: - ChildHomeView (Clean Swift: View)

struct ChildHomeView: View {
    let childId: String

    @State private var viewModel = ChildHomeViewModel()
    @State private var interactor: ChildHomeInteractor?
    @State private var router: ChildHomeRouter?

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(childId: String) {
        self.childId = childId
    }

    var body: some View {
        ZStack {
            kidBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    greetingSection
                    mascotSection
                        .spotlightAnchor(key: "mascot_header")
                    dailyMissionSection
                        .spotlightAnchor(key: "daily_mission_card")
                    quickActionsSection
                        .spotlightAnchor(key: "start_lesson_button")
                    progressSection
                        .spotlightAnchor(key: "streak_banner")

                    Spacer(minLength: SpacingTokens.sp16)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            parentButton
                .spotlightAnchor(key: "parent_dashboard")
        }
        .onAppear { bootstrap() }
        .task {
            await interactor?.fetchChildData(.init(childId: childId))
        }
        .environment(\.circuitContext, .kid)
        .loadingOverlay(viewModel.isLoading)
    }

    // MARK: - Wiring

    private func bootstrap() {
        guard interactor == nil else { return }
        let presenter = ChildHomePresenter()
        let interactor = ChildHomeInteractor(
            childRepository: container.childRepository,
            sessionRepository: container.sessionRepository
        )
        interactor.presenter = presenter
        presenter.viewModel = viewModel
        let router = ChildHomeRouter()
        router.coordinator = coordinator
        self.interactor = interactor
        self.router = router
        ActiveChildStore.shared.set(childId)
    }

    // MARK: - Sections

    private var kidBackground: some View {
        ZStack {
            LinearGradient(
                colors: [ColorTokens.Kid.bgSoft, ColorTokens.Kid.bgSofter],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            CloudDecoration()
        }
    }

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "child.home.greeting"))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                Text(viewModel.childName.isEmpty
                     ? String(localized: "child.default.name")
                     : viewModel.childName)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
            }

            Spacer()

            if viewModel.currentStreak > 0 {
                StreakBadge(streak: viewModel.currentStreak)
            }
        }
        .padding(.top, SpacingTokens.pageTop)
        .padding(.bottom, SpacingTokens.sp3)
    }

    private var mascotSection: some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSMascotView(mood: viewModel.mascotMood, size: 140)

            if let phrase = viewModel.mascotPhrase {
                Text(phrase)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.sp8)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, SpacingTokens.sp4)
    }

    private var dailyMissionSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "child.home.daily.section"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .tracking(1)

            DailyMissionCard(mission: viewModel.dailyMission) {
                router?.routeToLesson(childId: childId, template: "listenAndChoose")
            }
        }
        .padding(.top, SpacingTokens.sp2)
    }

    private var quickActionsSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: SpacingTokens.sp3
        ) {
            QuickActionTile(
                title: String(localized: "child.home.action.worldmap"),
                icon: "map.fill",
                color: ColorTokens.Brand.sky
            ) {
                router?.routeToWorldMap(childId: childId, sound: viewModel.dailyMission.targetSound)
            }

            QuickActionTile(
                title: String(localized: "child.home.action.ar"),
                icon: "camera.fill",
                color: ColorTokens.Brand.lilac
            ) {
                router?.routeToARZone()
            }

            QuickActionTile(
                title: String(localized: "child.home.action.rewards"),
                icon: "star.fill",
                color: ColorTokens.Brand.butter
            ) {
                router?.routeToRewards(childId: childId)
            }

            QuickActionTile(
                title: String(localized: "child.home.action.achievements"),
                icon: "trophy.fill",
                color: ColorTokens.Brand.mint
            ) {
                router?.routeToRewards(childId: childId)
            }
        }
        .padding(.top, SpacingTokens.sp5)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "child.home.progress.section"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.top, SpacingTokens.sp5)

            ForEach(viewModel.soundProgress) { item in
                SoundProgressRow(item: item)
            }
        }
    }

    private var parentButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    router?.routeToParentHome()
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .padding(SpacingTokens.sp3)
                        .background(
                            Circle().fill(ColorTokens.Kid.surface)
                                .kidTileShadow()
                        )
                }
                .accessibilityLabel(String(localized: "child.home.a11y.parent.button"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp2)
            Spacer()
        }
    }
}

// MARK: - Supporting Views

private struct CloudDecoration: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.6))
                .frame(width: 120, height: 60)
                .blur(radius: 20)
                .offset(x: -80, y: 60)

            Ellipse()
                .fill(Color.white.opacity(0.5))
                .frame(width: 90, height: 45)
                .blur(radius: 16)
                .offset(x: 100, y: 90)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct DailyMissionCard: View {
    let mission: ChildHomeModels.DailyMission
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.sp4) {
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Brand.primary.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Text(mission.targetSound)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)

                    Text(mission.subtitle)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)

                    HSProgressBar(value: mission.progress, style: .kid, tint: ColorTokens.Brand.primary)
                        .frame(height: 10)
                        .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            .padding(SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidCardShadow()
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel(Text("\(mission.title). \(mission.subtitle)"))
        .accessibilityHint(Text(String(localized: "child.home.daily.a11y.hint")))
    }
}

private struct QuickActionTile: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(color.opacity(0.12)))

                Text(title)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .ctaTextStyle()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .kidCardShadow()
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel(title)
    }
}

private struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.Semantic.warning)
            Text("\(streak)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.Semantic.warning)
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp2)
        .background(Capsule().fill(ColorTokens.Semantic.warning.opacity(0.12)))
        .accessibilityLabel(Text(String.localizedStringWithFormat(
            String(localized: "child.home.streak.a11y"),
            streak
        )))
    }
}

private struct SoundProgressRow: View {
    let item: ChildHomeModels.SoundProgressItem

    var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Text(item.sound)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(ColorTokens.SoundFamilyColors.hue(for: item.accent))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.stageName)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Spacer()
                    Text(formatPercent(item.rate))
                        .font(TypographyTokens.mono(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                HSProgressBar(
                    value: item.rate,
                    style: .kid,
                    tint: ColorTokens.SoundFamilyColors.hue(for: item.accent)
                )
                .frame(height: 8)
            }
        }
        .padding(.vertical, SpacingTokens.sp2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String.localizedStringWithFormat(
            String(localized: "child.home.sound.row.a11y"),
            item.sound, item.stageName, Int(item.rate * 100)
        )))
    }

    private func formatPercent(_ rate: Double) -> String {
        "\(Int(rate * 100))%"
    }
}

// MARK: - Preview

#Preview("Child Home") {
    ChildHomeView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
