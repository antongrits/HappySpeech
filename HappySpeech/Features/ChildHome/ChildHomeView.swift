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
    // Доступен из ChildHomeView+EntryCards.swift (routeTo* в карточках-входах),
    // поэтому не private — остальное состояние экрана остаётся приватным.
    @State var router: ChildHomeRouter?

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
    // A-08 «Спокойный режим» — снижает плотность декора и стимуляции на главном
    // детском экране. Всё под `if calmMode`; при выключенном (default) — без изменений.
    @Environment(\.calmMode) private var calmMode
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

            if viewModel.isLoading {
                childHomeSkeletonView
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp5) {
                    heroSection

                    SeasonalBannerView(manager: .shared) {
                        guard let event = SeasonalEventsManager.shared.activeEvent else { return }
                        router?.routeToSeasonalLesson(event: event, childId: childId)
                    }
                    .animation(
                        (reduceMotion || calmMode) ? nil : .easeInOut(duration: 0.3),
                        value: SeasonalEventsManager.shared.activeEvent?.rawValue
                    )

                    mascotInteractionZone
                        .spotlightAnchor(key: "mascot_header")

                    // «Новое достижение» и streak-баннер (или start-streak для
                    // новичка) — одна группа с единым ритмом отступов sp3.
                    // Боковые поля наследуются от родительского screenEdge —
                    // та же ширина, что и все прочие секции (defect #2).
                    VStack(spacing: SpacingTokens.sp3) {
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
                        } else {
                            // Defect #4 — первый запуск (серия 0): вместо пустоты
                            // показываем дружелюбное приглашение начать серию.
                            // Tap → DailyStreakView (milestones / saver).
                            Button {
                                showDailyStreakSheet = true
                            } label: {
                                ChildHomeStartStreakBanner()
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(Text("child.home.streak.tap.hint"))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    // Defect #2 (единые отступы) — баннеры выравниваются по тому
                    // же screenEdge, что и все остальные карточки/секции.
                    // Прежний дополнительный sp3 делал группу на 12pt уже прочих
                    // секций (асимметрия между секциями на SE).

                    dailyMissionSection
                        .spotlightAnchor(key: "daily_mission_card")
                        .hsScrollEffect(.scaleFade)

                    // M8.7 v6: Слова дня
                    if !viewModel.todayWords.isEmpty {
                        todayWordsSection
                            .hsScrollEffect(.scaleFade)
                    }

                    quickPlaySection
                        .spotlightAnchor(key: "quick_play_strip")
                        .hsScrollEffect(.scaleFade)

                    quickActionsSection
                        .spotlightAnchor(key: "start_lesson_button")
                        .hsScrollEffect(.scaleFade)

                    // M8.7 v6: Задания логопеда
                    if !viewModel.homeTasks.isEmpty {
                        homeTasksSection
                            .hsScrollEffect(.scaleFade)
                    }

                    worldMapPreviewSection
                        .hsScrollEffect(.scaleFade)

                    progressSection
                        .spotlightAnchor(key: "streak_banner")
                        .hsScrollEffect(.scaleFade)

                    recentRewardsSection
                        .hsScrollEffect(.scaleFade)

                    recentSessionsSection
                        .hsScrollEffect(.scaleFade)

                    sosSection

                    Spacer(minLength: SpacingTokens.sp16)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                // Fix (SE 3 asymmetric margins) — пиним ширину контентного VStack
                // ровно по ширине ScrollView. Без этого full-bleed горизонтальные
                // ряды (EdgeToEdgeScrollRow с отрицательным padding) раздували
                // VStack шире вьюпорта: левое поле screenEdge рендерилось, а правое
                // уезжало за правый край экрана → весь контент прижимался вправо
                // (на узком iPhone SE слева 24pt, справа 0pt). Фикс. ширина
                // гарантирует симметричные поля: левое == правое.
                .containerRelativeFrame(.horizontal)
                .animation((reduceMotion || calmMode) ? nil : .easeInOut(duration: 0.25),
                           value: viewModel.hasAchievement)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: SpacingTokens.sp8) }
            // Block J v18 — kavsoft-style pull-to-refresh с маскотом Лялей
            // (kid-контур). Внутри hsMascotRefresh уже вызывается .refreshable.
            .hsMascotRefresh {
                await interactor?.refreshData(childId: childId)
            }
            // Скрываем пустой контент во время cold-start загрузки:
            // скелетон (childHomeSkeletonView) накладывается поверх, пока
            // isLoading == true, и реальный контент не мелькает через него.
            .opacity(viewModel.isLoading ? 0 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3),
                       value: viewModel.isLoading)

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
            // v31 Wave F F-05 — daily time cap gate: если родитель включил cap
            // и сегодня превышено, показываем CapReachedView (полноэкранный sheet).
            coordinator.checkDailyCap(using: container.dailyUsageTracker)
        }
        .task {
            await interactor?.fetchChildData(.init(childId: childId))
        }
        .environment(\.circuitContext, .kid)
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

    // MARK: - Skeleton (cold-launch placeholder)
    //
    // Показывается вместо пустого экрана в первые 3-4 секунды холодного запуска
    // (пока Realm + Firebase инициализируются). Заменяет блокирующий dimmed
    // ProgressView из `.loadingOverlay(viewModel.isLoading)`.
    // HSSkeletonCard + shimmer — стандарт DesignSystem (Block O).

    private var childHomeSkeletonView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.sp4) {
                // Hero placeholder
                HSSkeletonCard()
                    .frame(height: 80)

                // Mission card placeholder
                HSSkeletonCard()
                    .frame(height: 100)

                // Quick play strip placeholder
                HSSkeletonCard()
                    .frame(height: 80)

                // Три строки контента
                HSSkeletonCard()
                HSSkeletonCard()
                HSSkeletonCard()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp5)
        }
        .hsShimmer(active: true)
        .accessibilityLabel(String(localized: "general.loading", defaultValue: "Загрузка…"))
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .transition(.opacity)
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
        // P1-8: пишем через единый источник истины (`container.currentChildId`
        // → `ActiveChildStore` + Sendable-снимок для не-isolated ML-слоёв).
        // Пустой childId НЕ сохраняем: навигационные выходы из мини-игр идут
        // через `childHome("")`, и запись "" стёрла бы выбранного ребёнка
        // (`ActiveChildStore` трактует "" как «очистить»).
        if !childId.isEmpty {
            container.currentChildId = childId
        }
        Self.logger.debug("ChildHome bootstrapped for child=\(childId, privacy: .public)")
    }

    // MARK: - Background

    /// Фон детского экрана — два СТАТИЧНЫХ тёплых слоя: бренд-mesh
    /// (KidBackgroundView) → тёплый mesh-gradient (низкая opacity, softLight).
    ///
    /// Defect #3 / стандинг-ордер владельца: фон статичный и тёплый — никакой
    /// движущейся «волновой»/«дышащей» анимации и плавающих облаков (убраны).
    /// Только ColorTokens, без растровых подложек. `animated: false` всегда.
    private var kidBackground: some View {
        ZStack {
            KidBackgroundView()
                .ignoresSafeArea()

            HSMeshGradientBackground(palette: .kidWarm, animated: false)
                .ignoresSafeArea()
                // F.tier1 v21: чуть притушеваем mesh в dark, чтобы не «выгорало» поверх тёмного фона.
                .opacity(calmMode ? 0.14 : (colorScheme == .dark ? 0.22 : 0.35))
                .blendMode(.softLight)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Hero / greeting

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: 3) {
                    // Эталон childhome.html — приветствие одной строкой:
                    // «Привет, <Имя>!» с именем в коралловом акценте, затем
                    // дружелюбный подзаголовок. Без обрезки: имя переносится,
                    // подзаголовок раскрывается полностью (.fixedSize vertical).
                    (
                        Text(String(localized: "child.home.greeting") + " ")
                            .foregroundStyle(ColorTokens.Kid.ink)
                        + Text("\(viewModel.displayedName)!")
                            .foregroundStyle(ColorTokens.Brand.primary)
                    )
                    .font(TypographyTokens.kidHero(28))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(String(localized: "child.home.greeting.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    if !viewModel.formattedDate.isEmpty {
                        Text(viewModel.formattedDate.capitalizedFirstLetter)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                            .padding(.top, 1)
                    }
                }

                Spacer()

                // Block J v18 — справа от приветствия: streak badge (если серия
                // идёт) или дневное кольцо миссии. Первый запуск (streak == 0,
                // миссия не закрыта) → дружелюбный «Начни серию!» бейдж вместо
                // пустого кольца, чтобы экран новичка не выглядел уныло (defect #4).
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
                } else if viewModel.dailyMissionDetail.isCompleted {
                    // Part 2: completed mission ring → Brand.gold вместо Semantic.success
                    HSProgressRing(
                        value: 1.0,
                        size: 56,
                        lineWidth: 6,
                        color: ColorTokens.Brand.gold,
                        label: "✓"
                    )
                    .accessibilityLabel(String(localized: "child.home.mission.completed.a11y"))
                } else {
                    // Первый запуск / нет серии: приглашение начать серию.
                    Button {
                        showDailyStreakSheet = true
                    } label: {
                        ChildHomeStartStreakBadge()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "child.home.streak.start"))
                    .accessibilityHint(Text("child.home.streak.tap.hint"))
                }
            }
        }
        // Fix v32-postreaudit — round FAB (56pt + screenEdge 24pt)
        // занимает справа порядка 80pt. Раньше trailing был sp10=40pt и
        // FAB накладывался на streakBadge / mission ring («лишняя кнопка»
        // визуально). Увеличиваем до sp16=64pt + дополнительный sp4=16pt,
        // итого 80pt — streakBadge гарантированно слева от FAB-кнопки.
        .padding(.trailing, SpacingTokens.sp16 + SpacingTokens.sp4)
        .padding(.top, SpacingTokens.pageTop)
        // v32 P1 — ShadowTokens.kidDepth: two-layer depth under greeting card.
        .depthShadow(ShadowTokens.kidDepth)
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
                // A-08: спокойный режим останавливает покачивание маскота (как reduceMotion).
                ChildHomeReactiveMascot(mood: viewModel.mascotMood, reduceMotion: reduceMotion || calmMode)
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
        .animation((reduceMotion || calmMode) ? nil : MotionTokens.spring, value: viewModel.mascotTapPhrase)
    }

    // MARK: - HomeScreen Widget card preview (L9)

    // MARK: - Daily Mission

    private var dailyMissionSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            // Эталон childhome.png — отдельный заголовок «Миссия дня» убран:
            // тег-пилюля «Задание дня» внутри карточки сама служит меткой секции.
            // Таймер до конца дня показываем компактно над карточкой справа.
            if !viewModel.dailyMissionDetail.isCompleted {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ChildHomeMissionTimerLabel()
                }
            }

            // S12: matchedGeometryEffect — card является source в свёрнутом состоянии.
            // isSource=false когда hero overlay открыт (overlayCard сам становится source).
            ChildHomeDailyMissionDetailCard(
                mission: viewModel.dailyMissionDetail
            ) {
                if reduceMotion || calmMode {
                    // Reduced Motion / A-08 Спокойный режим: без hero-overlay, сразу в урок.
                    guard let interactor, let router else { return }
                    Task { await interactor.recordMissionTap() }
                    router.routeToLesson(
                        childId: childId,
                        template: viewModel.dailyMissionDetail.templateType,
                        targetSound: viewModel.dailyMissionDetail.targetSound
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
                        template: viewModel.dailyMissionDetail.templateType,
                        targetSound: viewModel.dailyMissionDetail.targetSound
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
                        template: viewModel.dailyMissionDetail.templateType,
                        targetSound: viewModel.dailyMissionDetail.targetSound
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
                .padding(.vertical, SpacingTokens.micro)
            }
            // Fix v35 (SE 3 asymmetric margins) — горизонтальный ряд
            // делаем full-bleed (counteract родительский screenEdge), затем
            // через .contentMargins даём симметричный screenEdge-инсет слева
            // и справа: первая карточка начинается ровно на уровне заголовка,
            // последняя «выглядывает» на тот же отступ. Прежний внутренний
            // `.padding(.horizontal, micro)` давал асимметрию (28pt слева /
            // bleed справа) на узких устройствах.
            .modifier(EdgeToEdgeScrollRow())
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

            v25EntryCards

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
                    reduceMotion: reduceMotion || calmMode
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
                    reduceMotion: reduceMotion || calmMode
                ) {
                    router?.routeToARZone()
                }
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.rewards"),
                    icon: "star.fill",
                    color: ColorTokens.Brand.butter,
                    heroId: "quickaction_rewards",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion || calmMode
                ) {
                    router?.routeToRewards(childId: childId)
                }
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.achievements"),
                    icon: "trophy.fill",
                    color: ColorTokens.Brand.mint,
                    heroId: "quickaction_achievements",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion || calmMode
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
                    reduceMotion: reduceMotion || calmMode
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
                    reduceMotion: reduceMotion || calmMode
                ) {
                    showCulturalContentSheet = true
                }
                // v26 2.1 — Grammar Game entry «Грамматика-игра».
                ChildHomeQuickActionTile(
                    title: String(localized: "child.home.action.grammar"),
                    icon: "textformat.abc",
                    color: ColorTokens.Brand.lilac,
                    heroId: "quickaction_grammar",
                    namespace: heroNamespace,
                    reduceMotion: reduceMotion || calmMode
                ) {
                    router?.routeToGrammarGame(childId: childId)
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
}

// MARK: - ChildHomeView + Sections (SOS / Recent / Parent / Today / HomeTasks)
//
// Секции-подвиды вынесены в same-file extension, чтобы тело `ChildHomeView`
// не превышало SwiftLint type_body_length. Доступ private сохраняется
// (same-file scope). Чистый view-рендер, без бизнес-логики.

extension ChildHomeView {

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
                    .lineLimit(nil)
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
                .padding(.vertical, SpacingTokens.micro)
            }
            // Fix v35 — симметричный screenEdge-инсет (см. quickPlaySection).
            .modifier(EdgeToEdgeScrollRow())
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

// MARK: - EdgeToEdgeScrollRow (Fix v35)
//
// Делает горизонтальный ScrollView, лежащий внутри VStack с
// `.padding(.horizontal, screenEdge)`, full-bleed — и возвращает контенту
// симметричный screenEdge-инсет через `.contentMargins`. В результате первая
// карточка ряда выровнена с заголовком секции (screenEdge слева), а последняя
// «выглядывает» из правого края ровно на тот же отступ — левое поле == правое.
// `scrollClipDisabled` отключён намеренно: контент-маргины сами обрезают
// видимую область, тени карточек не клипуются жёстко по краю экрана.
private struct EdgeToEdgeScrollRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, -SpacingTokens.screenEdge)
            .contentMargins(.horizontal, SpacingTokens.screenEdge, for: .scrollContent)
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
