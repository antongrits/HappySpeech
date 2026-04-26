import OSLog
import SwiftUI

// MARK: - ChildHomeView (Clean Swift: View)
//
// Главный экран ребёнка (kid contour). Состав секций:
//   1. Hero (приветствие, дата, streak badge)
//   2. Маскот Ляля (ReactiveMascot, реагирует на streak)
//   3. AchievementBanner (если есть новая ачивка)
//   4. Daily Mission Detail (с reps counter)
//   5. Quick Play — горизонтальная карусель из 5 игр
//   6. Quick Actions — 2×2 grid с навигацией
//   7. World Map mini preview (5 цветных кружков)
//   8. Sound Progress (по звукам ребёнка)
//   9. Recent Sessions (последние 3 урока)
//
// Все View-компоненты (Mascot, Bubble, StreakBadge, MissionCard, QuickPlayCard,
// WorldMapMiniPreview, ProgressRow, RecentSessionRow, AchievementBanner, Empty
// states, helpers) вынесены в ChildHomeViewComponents.swift, чтобы файл не
// превышал лимит SwiftLint file_length=900.

struct ChildHomeView: View {

    let childId: String

    @State private var viewModel = ChildHomeViewModel()
    @State private var interactor: ChildHomeInteractor?
    @State private var router: ChildHomeRouter?

    /// B13 — SOS-flow: alert «Позвать родителя?» перед фактическим переходом.
    @State private var showSOSAlert: Bool = false

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "ChildHome")

    init(childId: String) {
        self.childId = childId
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            kidBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp5) {
                    heroSection

                    mascotSection
                        .spotlightAnchor(key: "mascot_header")

                    if viewModel.hasAchievement, let ach = viewModel.achievement {
                        ChildHomeAchievementBanner(achievement: ach) {
                            Task { await interactor?.dismissAchievement(id: ach.id) }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    // B13: полноразмерный Streak Banner с pulse-анимацией.
                    // Показываем только при streak ≥ 1 — нечего поощрять при нуле.
                    if viewModel.currentStreak > 0 {
                        ChildHomeStreakBanner(
                            streak: viewModel.currentStreak,
                            isHot: viewModel.isStreakHot
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    dailyMissionSection
                        .spotlightAnchor(key: "daily_mission_card")

                    quickPlaySection
                        .spotlightAnchor(key: "quick_play_strip")

                    quickActionsSection
                        .spotlightAnchor(key: "start_lesson_button")

                    worldMapPreviewSection

                    progressSection
                        .spotlightAnchor(key: "streak_banner")

                    recentRewardsSection

                    recentSessionsSection

                    sosSection

                    Spacer(minLength: SpacingTokens.sp16)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25),
                           value: viewModel.hasAchievement)
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
        .alert(
            String(localized: "child.home.sos.alert_title"),
            isPresented: $showSOSAlert
        ) {
            Button(String(localized: "child.home.sos.confirm")) {
                Self.logger.info("SOS confirmed → routing to ParentHome")
                router?.routeToParentHome()
            }
            Button(String(localized: "child.home.sos.cancel"), role: .cancel) {
                Self.logger.debug("SOS cancelled by child")
            }
        } message: {
            Text(String(localized: "child.home.sos.alert_message"))
        }
    }

    // MARK: - Wiring (Clean Swift bootstrap)

    private func bootstrap() {
        guard interactor == nil else { return }
        let presenter = ChildHomePresenter()
        let createdInteractor = ChildHomeInteractor(
            childRepository: container.childRepository,
            sessionRepository: container.sessionRepository
        )
        createdInteractor.presenter = presenter
        presenter.viewModel = viewModel

        let createdRouter = ChildHomeRouter()
        createdRouter.coordinator = coordinator

        self.interactor = createdInteractor
        self.router = createdRouter
        ActiveChildStore.shared.set(childId)
        Self.logger.debug("ChildHome bootstrapped for child=\(childId, privacy: .public)")
    }

    // MARK: - Background

    private var kidBackground: some View {
        ZStack {
            LinearGradient(
                colors: [ColorTokens.Kid.bgSoft, ColorTokens.Kid.bgSofter],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ChildHomeCloudDecoration()
        }
    }

    // MARK: - Hero / greeting

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "child.home.greeting"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)

                    Text("\(viewModel.displayedName)!")
                        .font(TypographyTokens.title(28))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if !viewModel.formattedDate.isEmpty {
                        Text(viewModel.formattedDate.capitalizedFirstLetter)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                if viewModel.currentStreak > 0 {
                    ChildHomeStreakBadge(
                        streak: viewModel.currentStreak,
                        isHot: viewModel.isStreakHot
                    )
                }
            }
        }
        .padding(.top, SpacingTokens.pageTop)
    }

    // MARK: - Mascot Lyalya

    private var mascotSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ChildHomeReactiveMascot(mood: viewModel.mascotMood, reduceMotion: reduceMotion)

            if let phrase = viewModel.mascotPhrase {
                ChildHomeMascotBubble(text: phrase)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, SpacingTokens.sp3)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Daily Mission

    private var dailyMissionSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp2) {
                sectionHeader(String(localized: "child.home.mission.section"), emoji: "🎯")
                Spacer(minLength: 0)
                // B13: компактный таймер до конца дня (TimelineView, обновление 60с).
                // Не показываем, если миссия уже завершена.
                if !viewModel.dailyMissionDetail.isCompleted {
                    ChildHomeMissionTimerLabel()
                }
            }

            ChildHomeDailyMissionDetailCard(
                mission: viewModel.dailyMissionDetail
            ) {
                guard let interactor, let router else { return }
                Task { await interactor.recordMissionTap() }
                router.routeToLesson(
                    childId: childId,
                    template: viewModel.dailyMissionDetail.templateType
                )
            }
        }
    }

    // MARK: - Quick Play (M8.7 — horizontal carousel)

    private var quickPlaySection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(String(localized: "child.home.quick.section"), emoji: "🎮")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.sp3) {
                    ForEach(viewModel.quickPlayItems) { item in
                        ChildHomeQuickPlayCard(item: item) {
                            router?.routeToLesson(
                                childId: childId,
                                template: item.templateType
                            )
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Quick Actions (legacy 2x2 grid)

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(String(localized: "child.home.actions.section"), emoji: "✨")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: SpacingTokens.sp3
            ) {
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.worldmap"),
                    icon: "map.fill",
                    color: ColorTokens.Brand.sky
                ) {
                    router?.routeToWorldMap(
                        childId: childId,
                        sound: viewModel.dailyMission.targetSound
                    )
                }
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.ar"),
                    icon: "camera.fill",
                    color: ColorTokens.Brand.lilac
                ) {
                    router?.routeToARZone()
                }
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.rewards"),
                    icon: "star.fill",
                    color: ColorTokens.Brand.butter
                ) {
                    router?.routeToRewards(childId: childId)
                }
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.achievements"),
                    icon: "trophy.fill",
                    color: ColorTokens.Brand.mint
                ) {
                    router?.routeToRewards(childId: childId)
                }
            }
        }
    }

    // MARK: - World Map mini preview

    private var worldMapPreviewSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                sectionHeader(String(localized: "child.home.world.section"), emoji: "🗺")
                Spacer()
                Button {
                    router?.routeToWorldMap(
                        childId: childId,
                        sound: viewModel.dailyMission.targetSound
                    )
                } label: {
                    Text(String(localized: "child.home.world.open"))
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                .accessibilityHint(String(localized: "child.home.world.open.hint"))
            }

            ChildHomeWorldMapMiniPreview(
                zones: viewModel.worldZones,
                onZoneTap: { zone in
                    router?.routeToWorldMap(childId: childId, sound: zone.sound)
                }
            )
        }
    }

    // MARK: - Sound Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(String(localized: "child.home.progress.section"), emoji: "📈")

            if viewModel.soundProgress.isEmpty {
                ChildHomeEmptyProgressView()
            } else {
                ForEach(viewModel.soundProgress) { item in
                    ChildHomeSoundProgressRow(item: item)
                }
            }
        }
    }

    // MARK: - Recent Rewards (B13 — отдельная секция, не путать с RecentSessions)

    private var recentRewardsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                sectionHeader(String(localized: "child.home.rewards.title"), emoji: "🏅")
                Spacer()
                Button {
                    router?.routeToRewards(childId: childId)
                } label: {
                    Text(String(localized: "child.home.rewards.show_all"))
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                .accessibilityHint(String(localized: "child.home.rewards.show_all.hint"))
            }

            if viewModel.recentRewards.isEmpty {
                ChildHomeEmptyRewardsView()
            } else {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(viewModel.recentRewards.prefix(3)) { reward in
                        ChildHomeRecentRewardRow(reward: reward)
                    }
                }
            }
        }
    }

    // MARK: - SOS (B13 — «Позвать родителя» с alert-подтверждением)

    private var sosSection: some View {
        Button {
            Self.logger.debug("SOS button tapped — presenting alert")
            showSOSAlert = true
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(TypographyTokens.body(16).weight(.semibold))
                    .accessibilityHidden(true)
                Text(String(localized: "child.home.sos.button"))
                    .font(TypographyTokens.body(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp3)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(ColorTokens.Brand.primary.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .strokeBorder(ColorTokens.Brand.primary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel(String(localized: "child.home.sos.button"))
        .accessibilityHint(String(localized: "child.home.sos.alert_message"))
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                sectionHeader(String(localized: "child.home.recent.section"), emoji: "📚")
                Spacer()
                Button {
                    router?.routeToSessionHistory(childId: childId)
                } label: {
                    Text(String(localized: "child.home.recent.all"))
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                .accessibilityHint(String(localized: "child.home.recent.all.hint"))
            }

            if viewModel.recentSessions.isEmpty {
                ChildHomeEmptyRecentView()
            } else {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(viewModel.recentSessions) { session in
                        ChildHomeRecentSessionRow(session: session)
                    }
                }
            }
        }
    }

    // MARK: - Parent button

    private var parentButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    // B13: вместо немедленного перехода — показываем SOS alert
                    // (consistency с нижней кнопкой «Позвать родителя»).
                    Self.logger.debug("Top-right parent button tapped — presenting SOS alert")
                    showSOSAlert = true
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle().fill(ColorTokens.Kid.surface).kidTileShadow()
                        )
                        .contentShape(Circle())
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(String(localized: "child.home.a11y.parent.button"))
                .accessibilityHint(String(localized: "child.home.a11y.parent.button.hint"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp2)
            Spacer()
        }
    }

    // MARK: - Section header helper

    private func sectionHeader(_ title: String, emoji: String) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Text(emoji)
                .font(TypographyTokens.caption(14))
                .accessibilityHidden(true)
            Text(title)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .tracking(1)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview("Child Home — Light") {
    ChildHomeView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("Child Home — Dark") {
    ChildHomeView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
