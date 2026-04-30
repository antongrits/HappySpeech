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

    // MARK: - S12 Hero Transitions (Block S)
    // Namespace для matchedGeometryEffect: mission card → expanded hero overlay.
    @Namespace private var heroNamespace
    // Флаг: показывать развёрнутую mission-карточку поверх контента.
    @State private var missionHeroExpanded: Bool = false

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass

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


                    SeasonalBannerView(manager: .shared) {
                        guard let event = SeasonalEventsManager.shared.activeEvent else { return }
                        router?.routeToSeasonalLesson(event: event, childId: childId)
                    }
                    .animation(.easeInOut(duration: 0.3), value: SeasonalEventsManager.shared.activeEvent?.rawValue)

                    mascotInteractionZone
                        .spotlightAnchor(key: "mascot_header")

                    if viewModel.hasAchievement, let ach = viewModel.achievement {
                        ChildHomeAchievementBanner(achievement: ach) {
                            Task { await interactor?.dismissAchievement(id: ach.id) }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    if viewModel.currentStreak > 0 {
                        ChildHomeStreakBanner(
                            streak: viewModel.currentStreak,
                            isHot: viewModel.isStreakHot
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    homeScreenCardSection

                    dailyMissionSection
                        .spotlightAnchor(key: "daily_mission_card")

                    // M8.7 v6: Слова дня
                    if !viewModel.todayWords.isEmpty {
                        todayWordsSection
                    }

                    quickPlaySection
                        .spotlightAnchor(key: "quick_play_strip")

                    quickActionsSection
                        .spotlightAnchor(key: "start_lesson_button")

                    // M8.7 v6: Задания логопеда
                    if !viewModel.homeTasks.isEmpty {
                        homeTasksSection
                    }

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
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: SpacingTokens.sp8) }
            .refreshable {
                await interactor?.refreshData(childId: childId)
            }

            parentButton
                .spotlightAnchor(key: "parent_dashboard")

            // MARK: — S12 Hero Overlay: expanded mission card
            // Появляется поверх контента при tап на mission card (reduceMotion off).
            if missionHeroExpanded {
                missionHeroOverlay
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .accessibilityIdentifier("ChildHomeRoot")
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
            sessionRepository: container.sessionRepository,
            missionSyncService: container.dailyMissionSyncService
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

    // MARK: - Mascot Interaction Zone (M8.7 v6)
    //
    // Tap по Ляле → Interactor → Presenter → случайная поощрительная фраза.
    // Bubble появляется на 3 секунды, потом пропадает.
    // Reduced Motion: убираем scale-анимацию, bubble всё равно появляется.

    private var mascotInteractionZone: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Button {
                Task { @MainActor in
                    await interactor?.tapMascot()
                    // Автоскрытие через 3 сек.
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation(reduceMotion ? nil : MotionTokens.spring) {
                        viewModel.mascotTapPhrase = nil
                    }
                }
            } label: {
                ChildHomeReactiveMascot(mood: viewModel.mascotMood, reduceMotion: reduceMotion)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "child.home.mascot.tap.a11y"))
            .accessibilityHint(String(localized: "child.home.mascot.tap.a11y.hint"))

            // MascotTap phrase — показывается поверх обычной фразы.
            if let tapPhrase = viewModel.mascotTapPhrase {
                ChildHomeMascotBubble(text: tapPhrase)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if let phrase = viewModel.mascotPhrase {
                ChildHomeMascotBubble(text: phrase)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, SpacingTokens.sp3)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : MotionTokens.spring, value: viewModel.mascotTapPhrase)
    }

    // MARK: - HomeScreen Widget card preview (L9)

    private var homeScreenCardSection: some View {
        HStack(spacing: SpacingTokens.sp3) {
            HomeScreenCard(
                dailyMission: viewModel.dailyMissionDetail.title.isEmpty
                    ? viewModel.dailyMission.targetSound
                    : viewModel.dailyMissionDetail.title,
                streakDays: viewModel.currentStreak,
                lyalyaIcon: "bird.fill"
            )
            Spacer(minLength: 0)
        }
        .padding(.vertical, SpacingTokens.sp1)
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

            // S12: matchedGeometryEffect — card является source в свёрнутом состоянии.
            // isSource=false когда hero overlay открыт (overlayCard сам становится source).
            ChildHomeDailyMissionDetailCard(
                mission: viewModel.dailyMissionDetail
            ) {
                if reduceMotion {
                    // Reduced Motion: без hero, сразу в урок.
                    guard let interactor, let router else { return }
                    Task { await interactor.recordMissionTap() }
                    router.routeToLesson(
                        childId: childId,
                        template: viewModel.dailyMissionDetail.templateType
                    )
                } else {
                    // Hero expand: показываем overlay с matchedGeometryEffect.
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                        missionHeroExpanded = true
                    }
                }
            }
            .matchedGeometryEffect(
                id: "mission_card",
                in: heroNamespace,
                isSource: !missionHeroExpanded
            )
        }
    }

    // MARK: - Mission Hero Overlay (S12 Block S)
    //
    // Развёрнутая карточка миссии с matchedGeometryEffect, занимает большую
    // часть экрана. Tap «Начать» → маршрутизация через router, overlay закрывается.
    // Tap по фону → collapse обратно.

    @ViewBuilder
    private var missionHeroOverlay: some View {
        ZStack(alignment: .center) {
            // Dim background
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        missionHeroExpanded = false
                    }
                }
                .accessibilityLabel(String(localized: "child.home.hero.dismiss.a11y"))
                .accessibilityAddTraits(.isButton)

            // Expanded mission card (matchedGeometryEffect destination)
            VStack(spacing: SpacingTokens.sp4) {
                ChildHomeDailyMissionDetailCard(
                    mission: viewModel.dailyMissionDetail
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        missionHeroExpanded = false
                    }
                    guard let interactor, let router else { return }
                    Task { await interactor.recordMissionTap() }
                    router.routeToLesson(
                        childId: childId,
                        template: viewModel.dailyMissionDetail.templateType
                    )
                }
                .matchedGeometryEffect(
                    id: "mission_card",
                    in: heroNamespace,
                    isSource: missionHeroExpanded
                )

                // CTA «Начать» появляется только в развёрнутом состоянии
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        missionHeroExpanded = false
                    }
                    guard let interactor, let router else { return }
                    Task { await interactor.recordMissionTap() }
                    router.routeToLesson(
                        childId: childId,
                        template: viewModel.dailyMissionDetail.templateType
                    )
                } label: {
                    HStack(spacing: SpacingTokens.sp2) {
                        Image(systemName: "play.fill")
                            .font(TypographyTokens.body(16))
                            .accessibilityHidden(true)
                        Text(String(localized: "child.home.mission.start"))
                            .font(TypographyTokens.headline(17))
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpacingTokens.sp6)
                    .padding(.vertical, SpacingTokens.sp3)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                            .fill(ColorTokens.Brand.primary)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "child.home.mission.start"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
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

    // MARK: - Quick Actions (adaptive grid + Sibling Multiplayer card)
    //
    // Regular width (iPad full/split 1/2 landscape): 4-column grid.
    // Compact width (iPhone, iPad Slide Over, iPad split portrait/1/3): 2-column grid.

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(String(localized: "child.home.actions.section"), emoji: "✨")

            // Sibling Multiplayer card (full-width, above grid)
            Button {
                router?.routeToSiblingMultiplayer(childId: childId)
            } label: {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: "person.2.fill")
                        .font(TypographyTokens.headline(22))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(ColorTokens.Brand.sky.opacity(0.9)))
                        .accessibilityHidden(true)

                    Text(String(localized: "sibling.entry.title"))
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.caption(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, SpacingTokens.sp4)
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.sky.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .strokeBorder(ColorTokens.Brand.sky.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "sibling.entry.title"))
            .accessibilityHint(String(localized: "sibling.discovery.nav_title"))

            let columns: [GridItem] = hSizeClass == .regular
                ? [GridItem(.flexible()), GridItem(.flexible()),
                   GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())]

            LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
                // S12: matchedGeometryEffect на icon-круглые элементы QuickAction-тайлов.
                // Namespace heroNamespace; каждый тайл несёт уникальный id иконки.
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.worldmap"),
                    icon: "map.fill",
                    color: ColorTokens.Brand.sky,
                    heroId: "quickaction_worldmap",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion
                ) {
                    router?.routeToWorldMap(
                        childId: childId,
                        sound: viewModel.dailyMission.targetSound
                    )
                }
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.ar"),
                    icon: "camera.fill",
                    color: ColorTokens.Brand.lilac,
                    heroId: "quickaction_ar",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion
                ) {
                    router?.routeToARZone()
                }
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.rewards"),
                    icon: "star.fill",
                    color: ColorTokens.Brand.butter,
                    heroId: "quickaction_rewards",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion
                ) {
                    router?.routeToRewards(childId: childId)
                }
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.achievements"),
                    icon: "trophy.fill",
                    color: ColorTokens.Brand.mint,
                    heroId: "quickaction_achievements",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion
                ) {
                    router?.routeToAchievements(childId: childId)
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "child.home.world.open"))
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "child.home.rewards.show_all"))
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "child.home.recent.all"))
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

    // MARK: - Today Words (M8.7 v6)

    private var todayWordsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(String(localized: "child.home.today.words.section"), emoji: "📝")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.sp3) {
                    ForEach(viewModel.todayWords) { word in
                        ChildHomeTodayWordCard(word: word)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - HomeTasks Preview (M8.7 v6)

    private var homeTasksSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                sectionHeader(String(localized: "child.home.hometasks.section"), emoji: "📋")
                Spacer()
                Button {
                    router?.routeToHomeTasks()
                } label: {
                    Text(String(localized: "child.home.hometasks.see_all"))
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(String(localized: "child.home.hometasks.see_all"))
            }

            VStack(spacing: SpacingTokens.sp2) {
                ForEach(viewModel.homeTasks.prefix(2)) { task in
                    ChildHomeTaskPreviewRow(task: task) {
                        router?.routeToHomeTasks()
                    }
                }
            }
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
