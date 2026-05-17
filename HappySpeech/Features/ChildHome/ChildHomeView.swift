import os.signpost
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

    // MARK: - S.1 v16 — Daily Streak Rewards
    // Tap на flame badge → sheet с DailyStreakView (milestones + saver).
    @State private var showDailyStreakSheet: Bool = false

    // MARK: - R.3 v18 — Weekly Challenge
    // Tap на quick action card → sheet с WeeklyChallengeView.
    @State private var showWeeklyChallengeSheet: Bool = false

    // MARK: - R.5 v18 — Cultural Content (русские сказки/песни)
    // Tap на quick action card → sheet с CulturalContentView.
    @State private var showCulturalContentSheet: Bool = false

    // MARK: - Plan v22 Block 0.5 — Cold start instrumentation
    /// Флаг для одноразового signpost `ChildHomeFirstFrame` — фиксирует первый рендер
    /// главного детского экрана после splash/auth, используется в Instruments POI.
    @State private var firstFrameLogged: Bool = false

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.colorScheme) private var colorScheme

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
            // Block J v18 — kavsoft-style pull-to-refresh с маскотом Лялей
            // (kid-контур). Внутри hsMascotRefresh уже вызывается .refreshable.
            .hsMascotRefresh {
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
        .onAppear {
            // Plan v22 Block 0.5 — фиксируем первый рендер главного детского экрана.
            // Срабатывает один раз — повторные .onAppear (push/pop) не логируются.
            if !firstFrameLogged {
                firstFrameLogged = true
                os_signpost(.event,
                            log: HSSignpost.pointsOfInterest,
                            name: "ChildHomeFirstFrame")
            }
            bootstrap()
        }
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
        .sheet(isPresented: $showDailyStreakSheet) {
            DailyStreakView(
                childId: childId,
                childName: viewModel.displayedName
            )
            .environment(container)
        }
        // Block R.3 v18 — WeeklyChallenge sheet.
        .sheet(isPresented: $showWeeklyChallengeSheet) {
            WeeklyChallengeView(childId: childId)
                .environment(container)
                .presentationDetents([.large])
        }
        // Block R.5 v18 — CulturalContent sheet.
        .sheet(isPresented: $showCulturalContentSheet) {
            CulturalContentView(childId: childId)
                .environment(container)
                .presentationDetents([.large])
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

    /// G.3 v17 — три слоя: бренд-фон → mesh gradient (низкая opacity) → облака.
    /// Mesh gradient НЕ заменяет KidBackgroundView, а добавляет «дыхание»
    /// цвета сверху. На iOS 17 fallback на radial gradient (см. компонент).
    /// Reduce Motion компонент учитывает сам.
    private var kidBackground: some View {
        ZStack {
            KidBackgroundView()
                .ignoresSafeArea()

            HSMeshGradientBackground(palette: .kidWarm, animated: true)
                .ignoresSafeArea()
                // F.tier1 v21: чуть притушеваем mesh в dark, чтобы не «выгорало» поверх тёмного фона.
                .opacity(colorScheme == .dark ? 0.22 : 0.35)
                .blendMode(.softLight)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            ChildHomeCloudDecoration()
                // F.tier1 v21: облака мягче в dark, чтобы не перетягивали внимание.
                .opacity(colorScheme == .dark ? 0.85 : 1.0)
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

                // Block J v18 — HSProgressRing для дневной миссии (Activity Ring style).
                // Showing 1.0 if mission completed, 0.0 если нет.
                // Hidden если streak > 0 (показывается streak badge).
                if viewModel.currentStreak > 0 {
                    Button {
                        showDailyStreakSheet = true
                    } label: {
                        ChildHomeStreakBadge(
                            streak: viewModel.currentStreak,
                            isHot: viewModel.isStreakHot
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("child.home.streak.tap.hint"))
                } else {
                    HSProgressRing(
                        value: viewModel.dailyMissionDetail.isCompleted ? 1.0 : 0.0,
                        size: 56,
                        lineWidth: 6,
                        color: viewModel.dailyMissionDetail.isCompleted
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Brand.primary,
                        label: viewModel.dailyMissionDetail.isCompleted ? "✓" : ""
                    )
                    .accessibilityLabel(
                        viewModel.dailyMissionDetail.isCompleted
                            ? String(localized: "child.home.mission.completed.a11y")
                            : String(localized: "child.home.mission.pending.a11y")
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
                sectionHeader(
                    String(localized: "child.home.mission.section"),
                    systemImage: "target",
                    tint: ColorTokens.Brand.primary
                )
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
            ColorTokens.Overlay.dimmer
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
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
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
            sectionHeader(
                String(localized: "child.home.quick.section"),
                systemImage: "gamecontroller.fill",
                tint: ColorTokens.Brand.primary
            )

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
                .padding(.horizontal, SpacingTokens.micro)
                .padding(.vertical, SpacingTokens.micro)
            }
        }
    }

    // MARK: - Quick Actions (adaptive grid + Sibling Multiplayer card)
    //
    // Regular width (iPad full/split 1/2 landscape): 4-column grid.
    // Compact width (iPhone, iPad Slide Over, iPad split portrait/1/3): 2-column grid.

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(
                String(localized: "child.home.actions.section"),
                systemImage: "sparkles",
                tint: ColorTokens.Brand.primary
            )

            // Sibling Multiplayer card (full-width, above grid)
            Button {
                router?.routeToSiblingMultiplayer(childId: childId)
            } label: {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: "person.2.fill")
                        .font(TypographyTokens.headline(22))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
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

            // Block T v17 — Voice Cloning «Голосовой архив».
            Button {
                router?.routeToVoiceCloning(childId: childId)
            } label: {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: "mic.badge.plus")
                        .font(TypographyTokens.headline(22))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(ColorTokens.Brand.lilac.opacity(0.9)))
                        .accessibilityHidden(true)

                    Text(String(localized: "voice_cloning.entry.title"))
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
                        .fill(ColorTokens.Brand.lilac.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .strokeBorder(ColorTokens.Brand.lilac.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "voice_cloning.entry.title"))
            .accessibilityHint(String(localized: "voice_cloning.entry.hint"))

            // F-302 v25 — Articulation Gym «Зарядка для язычка».
            ChildHomeV25EntryCard(
                titleKey: "articulationGym.entry.title",
                hintKey: "articulationGym.entry.hint",
                iconName: "mouth.fill",
                accent: ColorTokens.Brand.mint
            ) {
                router?.routeToArticulationGym()
            }

            // F-303 v25 — Word Bank «Копилка слов».
            ChildHomeV25EntryCard(
                titleKey: "wordBank.entry.title",
                hintKey: "wordBank.entry.hint",
                iconName: "star.square.on.square.fill",
                accent: ColorTokens.Brand.gold
            ) {
                router?.routeToWordBank(childId: childId)
            }

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
                // Block R.3 v18 — Weekly Challenge entry.
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.weekly"),
                    icon: "calendar.badge.clock",
                    color: ColorTokens.Brand.rose,
                    heroId: "quickaction_weekly",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion
                ) {
                    showWeeklyChallengeSheet = true
                }
                // Block R.5 v18 — Cultural Content entry.
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.cultural"),
                    icon: "books.vertical.fill",
                    color: ColorTokens.Brand.butter,
                    heroId: "quickaction_cultural",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion
                ) {
                    showCulturalContentSheet = true
                }
            }
        }
    }

    // MARK: - World Map mini preview

    private var worldMapPreviewSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                sectionHeader(
                    String(localized: "child.home.world.section"),
                    systemImage: "map.fill",
                    tint: ColorTokens.Brand.primary
                )
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
            sectionHeader(
                String(localized: "child.home.progress.section"),
                systemImage: "chart.line.uptrend.xyaxis",
                tint: ColorTokens.Brand.primary
            )

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
                sectionHeader(
                    String(localized: "child.home.rewards.title"),
                    systemImage: "medal.fill",
                    tint: ColorTokens.Brand.primary
                )
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
                sectionHeader(
                    String(localized: "child.home.recent.section"),
                    systemImage: "books.vertical.fill",
                    tint: ColorTokens.Brand.primary
                )
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
            sectionHeader(
                String(localized: "child.home.today.words.section"),
                systemImage: "square.and.pencil",
                tint: ColorTokens.Brand.primary
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.sp3) {
                    ForEach(viewModel.todayWords) { word in
                        ChildHomeTodayWordCard(word: word)
                    }
                }
                .padding(.horizontal, SpacingTokens.micro)
                .padding(.vertical, SpacingTokens.micro)
            }
        }
    }

    // MARK: - HomeTasks Preview (M8.7 v6)

    private var homeTasksSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                sectionHeader(
                    String(localized: "child.home.hometasks.section"),
                    systemImage: "list.bullet.clipboard.fill",
                    tint: ColorTokens.Brand.primary
                )
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

    private func sectionHeader(
        _ title: String,
        systemImage: String,
        tint: Color = ColorTokens.Brand.primary
    ) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: systemImage)
                .font(TypographyTokens.caption(14).weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
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
