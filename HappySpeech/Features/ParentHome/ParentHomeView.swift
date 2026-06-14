import SwiftUI

// MARK: - ParentHomeView

struct ParentHomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var scene: ParentHomeScene?
    @State private var selectedTab: ParentTab = .dashboard
    @State private var sidebarSelection: ParentTab? = .dashboard

    enum ParentTab: String, CaseIterable {
        case dashboard  = "Обзор"
        case sessions   = "Занятия"
        case analytics  = "Аналитика"
        case settings   = "Настройки"

        var icon: String {
            switch self {
            case .dashboard:  return "house.fill"
            case .sessions:   return "list.bullet.rectangle"
            case .analytics:  return "chart.xyaxis.line"
            case .settings:   return "gearshape.fill"
            }
        }

        /// Локализованная подпись таб-бара (ru + en, App Store secondary).
        var localizedTitle: String {
            switch self {
            case .dashboard:  return String(localized: "parentHome.tab.dashboard")
            case .sessions:   return String(localized: "parentHome.tab.sessions")
            case .analytics:  return String(localized: "parentHome.tab.analytics")
            case .settings:   return String(localized: "parentHome.tab.settings")
            }
        }
    }

    var body: some View {
        Group {
            // P0.2 fix v19: always use tabLayout on iPhone (iOS 26 on SE3 simulator
            // may return .regular hSizeClass or .pad idiom via new adaptive APIs).
            // sidebarLayout is intentionally disabled for this build (iPhone-only) (iPhone-only).
            tabLayout
        }
        .tint(ColorTokens.Parent.accent)
        .environment(\.circuitContext, .parent)
        // P0.2 fix v19: create scene synchronously in onAppear so tabContent
        // renders immediately (scene != nil) before async fetch completes.
        .onAppear { bootstrapScene() }
        .task {
            // E.2 — Performance trace: parent dashboard load time (opt-in, COPPA-safe).
            let trace = container.performanceMonitorService.trace(name: "parent_dashboard_load")
            trace.start()
            await scene?.interactor.fetchData(.init(preferredChildId: nil))
            trace.stop()
        }
    }

    // MARK: - Bootstrap

    /// P0.2 fix v19: creates the scene synchronously on first appear so that
    /// tabContent renders immediately with an empty state instead of ProgressView.
    private func bootstrapScene() {
        guard scene == nil else { return }
        scene = ParentHomeScene(
            childRepository: container.childRepository,
            sessionRepository: container.sessionRepository,
            screeningOutcomeRepository: container.screeningOutcomeRepository,
            llmDecisionService: container.llmDecisionService,
            adaptivePlannerService: container.adaptivePlannerService,
            notificationService: container.notificationService
        )
    }

    // MARK: - Tablet sidebar layout
    //
    // NavigationSplitView требует `Binding<Optional<Tag>>` для single-selection.
    // Синхронизируем sidebarSelection с selectedTab через onChange.

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                ForEach(ParentTab.allCases, id: \.self) { tab in
                    Label(tab.localizedTitle, systemImage: tab.icon)
                        .tag(tab)
                        .accessibilityLabel(tab.localizedTitle)
                }
            }
            .navigationTitle(String(localized: "Родитель"))
            .listStyle(.sidebar)
        } detail: {
            if let vm = scene?.viewModel {
                switch selectedTab {
                case .dashboard:  ParentDashboardTab(viewModel: vm, coordinator: coordinator)
                case .sessions:   ParentSessionsTab(
                    sessions: vm.recentSessions,
                    childId: vm.childId,
                    coordinator: coordinator
                )
                case .analytics:  ParentAnalyticsTab(progress: vm.soundProgress)
                case .settings:   SettingsView()
                }
            } else {
                loadingSection
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: sidebarSelection) { _, newVal in
            if let tab = newVal {
                selectedTab = tab
            }
        }
    }

    // MARK: - Phone tab layout
    //
    // P0.2 fix v19: replaced ZStack+HSAnimatedTabBar with system TabView to prevent
    // iOS 26 adaptive column navigation (split sidebar) from appearing on iPhone.
    // HSAnimatedTabBar caused a matchedGeometryEffect bug on iOS 26 SE3 simulator.

    private var tabLayout: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
                .tabItem {
                    Label(ParentTab.dashboard.localizedTitle, systemImage: ParentTab.dashboard.icon)
                }
                .tag(ParentTab.dashboard)
                .accessibilityIdentifier("parentDashboardTab")

            sessionsTab
                .tabItem {
                    Label(ParentTab.sessions.localizedTitle, systemImage: ParentTab.sessions.icon)
                }
                .tag(ParentTab.sessions)
                .accessibilityIdentifier("parentSessionsTab")

            analyticsTab
                .tabItem {
                    Label(ParentTab.analytics.localizedTitle, systemImage: ParentTab.analytics.icon)
                }
                .tag(ParentTab.analytics)
                .accessibilityIdentifier("parentAnalyticsTab")

            settingsTab
                .tabItem {
                    Label(ParentTab.settings.localizedTitle, systemImage: ParentTab.settings.icon)
                }
                .tag(ParentTab.settings)
                .accessibilityIdentifier("parentSettingsTab")
        }
        .tint(ColorTokens.Parent.accent)
        .accessibilityIdentifier("ParentHomeRoot")
    }

    @ViewBuilder private var dashboardTab: some View {
        if let vm = scene?.viewModel {
            ParentDashboardTab(viewModel: vm, coordinator: coordinator)
        } else {
            loadingSection
        }
    }

    @ViewBuilder private var sessionsTab: some View {
        if let vm = scene?.viewModel {
            ParentSessionsTab(
                sessions: vm.recentSessions,
                childId: vm.childId,
                coordinator: coordinator
            )
        } else {
            loadingSection
        }
    }

    @ViewBuilder private var analyticsTab: some View {
        if let vm = scene?.viewModel {
            ParentAnalyticsTab(progress: vm.soundProgress)
        } else {
            loadingSection
        }
    }

    @ViewBuilder private var settingsTab: some View {
        SettingsView()
    }

    // MARK: - Loading placeholder
    //
    // Plan v21 Block A.fix — пока `scene?.viewModel == nil` (cold start
    // ~5-6s на real device: Realm + Firebase + WhisperKit init), показываем
    // дружелюбный placeholder с маскотом + индикатором вместо `ProgressView()`
    // на пустом cream фоне. Это убирает «empty cream bg» восприятие при
    // первом запуске. На последующих запусках scene создаётся синхронно
    // в `bootstrapScene()` (P0.2 fix v19) — placeholder фактически не виден.
    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            Spacer()
            // E v21: 3D Ляля на loading state ParentHome (требование пользователя).
            LyalyaHeroView(state: .thinking, size: 120)
                // F.tier1 v21: mascot чуть мягче в dark, чтобы не светил.
                .opacity(colorScheme == .dark ? 0.9 : 1.0)
                .accessibilityHidden(true)
            ProgressView()
                .tint(ColorTokens.Parent.accent)
            Text(String(localized: "general.loading"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "general.loading"))
    }
}

// MARK: - Scene (VIP container)

@MainActor
final class ParentHomeScene {
    let interactor: ParentHomeInteractor
    let presenter: ParentHomePresenter
    let viewModel: ParentHomeViewModel

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        screeningOutcomeRepository: (any ScreeningOutcomeRepository)? = nil,
        llmDecisionService: (any LLMDecisionServiceProtocol)? = nil,
        adaptivePlannerService: (any AdaptivePlannerService)? = nil,
        notificationService: (any NotificationService)? = nil
    ) {
        let viewModel = ParentHomeViewModel()
        let presenter = ParentHomePresenter()
        let interactor = ParentHomeInteractor(
            childRepository: childRepository,
            sessionRepository: sessionRepository,
            screeningOutcomeRepository: screeningOutcomeRepository,
            llmDecisionService: llmDecisionService,
            adaptivePlannerService: adaptivePlannerService,
            notificationService: notificationService
        )
        presenter.viewModel = viewModel
        interactor.presenter = presenter
        self.viewModel = viewModel
        self.presenter = presenter
        self.interactor = interactor
    }
}

// MARK: - Dashboard Tab

private struct ParentDashboardTab: View {
    let viewModel: ParentHomeViewModel
    let coordinator: AppCoordinator

    @Environment(AppContainer.self) private var container

    /// Block R.2 v18 — sheet с LogopedistChatView (parent ↔ specialist).
    @State private var showLogopedistChatSheet: Bool = false
    /// Block R.4 v18 — sheet с FamilyAchievementsView (общие достижения).
    @State private var showFamilyAchievementsSheet: Bool = false

    // v27 visual modernization (#5) — фон parent-контура перестаёт выглядеть
    // как системный Settings.app: поверх Parent.bg ложится очень мягкий
    // mesh-слой палитры .calm (тот же, что в ProgressDashboard) — узнаваемый
    // характер контура без потери спокойствия. Static, чтобы не отвлекать.
    @ViewBuilder
    private var dashboardBackground: some View {
        // Чистый тёплый статичный фон (без декоративной mesh-подложки).
        ColorTokens.Parent.bg
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    /// Эталон — «Имя, N лет» в одну строку (без возраста, если он неизвестен).
    /// Никогда не показывает «0 лет»: при невалидном возрасте остаётся только имя.
    private var childNameAgeText: String {
        ChildAgeFormatter.nameWithAge(name: viewModel.childName, age: viewModel.childAge)
    }

    /// Целевые звуки чипами (из `targetSoundsText` "Р, Ш"); пустые отброшены.
    private var targetSoundChips: [String] {
        viewModel.targetSoundsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// D-29 v27 — единый icon-badge для navigation-карточек: SF Symbol
    /// в тонированном круге (задаёт ритм и глубину списку карточек).
    private func parentNavIcon(_ systemName: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 44, height: 44)
            Image(systemName: systemName)
                .font(TypographyTokens.subtitle(20))
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                // Fix #8 — sectionGap (32) выглядел разреженно; `large` (24)
                // сводит карточки в читаемую структуру без лишнего скролла.
                VStack(spacing: SpacingTokens.large) {
                    // ── Секция 1: Обзор (эталон parenthome.html) ──────────────

                    // Header (greeting + 3D Ляля)
                    ParentHeaderSection(greeting: viewModel.greeting)
                        .modifier(ParentDashboardTipModifier())

                    // Карточка ребёнка (аватар + имя/возраст + чипы + streak)
                    ParentChildCard(
                        name: viewModel.childName,
                        nameWithAge: childNameAgeText,
                        soundChips: targetSoundChips,
                        streak: viewModel.currentStreak
                    )

                    // Stat-strip (3-grid: серия / минуты / успех)
                    ParentStatStrip(
                        streak: viewModel.currentStreak,
                        totalMinutes: viewModel.totalSessionMinutes,
                        overallRate: viewModel.overallRate
                    )
                    .hsScrollEffect(.scaleFade)

                    // Недельная диаграмма + «Инсайт недели» (реальные данные;
                    // дружелюбный empty-state при отсутствии активности).
                    ParentWeeklyActivityCard(
                        weekStats: viewModel.weekStats,
                        insight: viewModel.weeklyInsight
                    )
                    .hsScrollEffect(.scaleFade)

                    // Прогресс по звукам (реальный soundProgress; эталонная
                    // карточка с пер-звуковыми барами; empty-state при пустоте).
                    ParentSoundProgressCard(progress: viewModel.soundProgress)
                        .hsScrollEffect(.scaleFade)

                    // Последнее занятие (3-cell grid + дисклеймер) либо
                    // дружелюбное пустое состояние с маскотом и CTA.
                    Group {
                        if let lastSession = viewModel.lastSession {
                            ParentLastSessionCard(session: lastSession)
                        } else {
                            ParentNoSessionCard {
                                coordinator.navigate(to: .childHome(childId: viewModel.childId))
                            }
                        }
                    }
                    .hsScrollEffect(.scaleFade)

                    // M6.16: Карточка скрининга (если скрининг пройден).
                    if let screening = viewModel.screeningCard {
                        screeningCard(screening)
                            .hsScrollEffect(.scaleFade)
                    }

                    // Задание на дом (нумерованные шаги + CTA), если есть.
                    if let homeTask = viewModel.homeTask {
                        ParentHomeTaskCard(task: homeTask) {
                            coordinator.navigate(to: .childHome(childId: viewModel.childId))
                        }
                        .hsScrollEffect(.scaleFade)
                    }

                    // Рекомендации обычным языком (реальные из Presenter).
                    ParentRecommendationsCard(recommendations: viewModel.recommendations)
                        .hsScrollEffect(.scaleFade)

                    // ── Секция 2: Инструменты и материалы ─────────────────────
                    // Все навигационные точки входа сгруппированы под единым
                    // заголовком секции — даёт иерархию и заполняет высоту, не
                    // создавая «стену» одинаковых карточек без структуры.

                    ParentToolsSectionHeader()

                    weeklyReportCard.hsScrollEffect(.scaleFade)
                    weeklyVideoReportCard.hsScrollEffect(.scaleFade)
                    plainProgressCard.hsScrollEffect(.scaleFade)
                    neurolinguistInsightsCard.hsScrollEffect(.scaleFade)
                    pronunciationLeaderboardCard.hsScrollEffect(.scaleFade)
                    familyVoiceCard.hsScrollEffect(.scaleFade)
                    parentVoiceNoteCard.hsScrollEffect(.scaleFade)
                    dailyRitualsLyalyaCard.hsScrollEffect(.scaleFade)
                    speechGrowthDiaryCard.hsScrollEffect(.scaleFade)
                    parentGuideCard.hsScrollEffect(.scaleFade)
                    soundDictionaryCard.hsScrollEffect(.scaleFade)
                    speechNormsEncyclopediaCard.hsScrollEffect(.scaleFade)
                    methodologyAssistantCard.hsScrollEffect(.scaleFade)
                    logopedistChatCard.hsScrollEffect(.scaleFade)
                    familyAchievementsCard.hsScrollEffect(.scaleFade)
                    familyCalendarCard.hsScrollEffect(.scaleFade)
                    dailyTimeCapCard.hsScrollEffect(.scaleFade)
                    stutteringCard.hsScrollEffect(.scaleFade)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp16 + SpacingTokens.sp10)
            }
            .background(dashboardBackground)
            .navigationTitle(String(localized: "Прогресс"))
            .navigationBarTitleDisplayMode(.large)
            // Block R.2 v18 — LogopedistChat sheet.
            .sheet(isPresented: $showLogopedistChatSheet) {
                let parentId = coordinator.authUser?.uid ?? "parent-default"
                LogopedistChatView(
                    parentId: parentId,
                    specialistId: "specialist-default"
                )
                .environment(container)
                .presentationDetents([.large])
            }
            // Block R.4 v18 — FamilyAchievements sheet.
            .sheet(isPresented: $showFamilyAchievementsSheet) {
                let familyId = coordinator.authUser?.uid ?? "family-default"
                FamilyAchievementsView(familyId: familyId)
                    .environment(container)
                    .presentationDetents([.large])
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        coordinator.navigate(to: .sessionHistory(childId: viewModel.childId))
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(ColorTokens.Parent.accent)
                    }
                    .accessibilityLabel(String(localized: "История занятий"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        coordinator.navigate(to: .childHome(childId: viewModel.childId))
                    } label: {
                        Image(systemName: "person.fill")
                            .foregroundStyle(ColorTokens.Parent.accent)
                    }
                    .accessibilityLabel(String(localized: "Переключиться на детский режим"))
                }
            }
        }
    }

    // MARK: - M6.16: Screening card

    private func screeningCard(_ card: ParentHomeModels.ScreeningCardViewModel) -> some View {
        let accentColor = severityColor(for: card.severityColorToken)
        return HSCard(style: .tinted(accentColor.opacity(0.10))) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                // Header
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "ear.and.waveform")
                        .font(TypographyTokens.subtitle(18))
                        .foregroundStyle(accentColor)
                        .hsSymbolEffect(.pulse, value: card.severityText)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(localized: "screening.card.title"))
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(card.completedAtText)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }

                    Spacer()

                    // Severity badge
                    Text(card.severityText)
                        .font(TypographyTokens.labelRounded(11, weight: .bold))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .padding(.horizontal, SpacingTokens.tiny)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor))
                }

                // Problematic sounds
                if !card.problematicSoundsText.isEmpty {
                    HStack(spacing: SpacingTokens.sp2) {
                        Text(String(localized: "screening.card.sounds_label"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                        Text(card.problematicSoundsText)
                            .font(TypographyTokens.body(13).weight(.semibold))
                            .foregroundStyle(ColorTokens.Parent.ink)
                    }
                }

                // Recommendation
                Text(card.recommendationText)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .ctaTextStyle()
                    .fixedSize(horizontal: false, vertical: true)

                // Retake button (если актуально)
                if card.canRetake {
                    Button {
                        coordinator.navigate(to: .screening(childId: viewModel.childId,
                                                            age: viewModel.childAge))
                    } label: {
                        Label(String(localized: "screening.card.retake"),
                              systemImage: "arrow.clockwise")
                            .font(TypographyTokens.body(13).weight(.medium))
                            .foregroundStyle(accentColor)
                    }
                    .accessibilityHint(String(localized: "screening.card.retake.hint"))
                }
            }
        }
        .environment(\.circuitContext, .parent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "screening.card.a11y"),
                   card.severityText,
                   card.problematicSoundsText,
                   card.completedAtText)
        )
    }

    private func severityColor(for token: String) -> Color {
        // Part 2: default/mild screening → Brand.gold вместо зелёного success
        switch token {
        case "severe":   return ColorTokens.Semantic.error
        case "moderate": return ColorTokens.Brand.gold
        default:          return ColorTokens.Brand.butter
        }
    }

    // MARK: - Family Voice Card

    private var familyVoiceCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("mic.badge.plus", tint: ColorTokens.Brand.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "family.voice.library.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "family.voice.library.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .ctaTextStyle()
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .familyVoiceLibrary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "family.voice.library.title") + ". " +
            String(localized: "family.voice.library.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Block T v17: Pronunciation Leaderboard card

    private var pronunciationLeaderboardCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("trophy.fill", tint: ColorTokens.Brand.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "leaderboard.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "leaderboard.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            // Read parent uid from coordinator authUser; fallback empty.
            let parentId = coordinator.authUser?.uid ?? ""
            coordinator.navigate(to: .pronunciationLeaderboard(parentId: parentId))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "leaderboard.entry.title") + ". " +
            String(localized: "leaderboard.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: - F-301 v25: Weekly Sound Report card

    private var weeklyReportCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("calendar.badge.clock", tint: ColorTokens.Brand.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "weeklyReport.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "weeklyReport.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(
                to: .weeklyReport(childId: viewModel.childId, weekOffset: 0)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "weeklyReport.entry.title") + ". " +
            String(localized: "weeklyReport.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: - п.26: Weekly Video Report card (Remotion)

    private var weeklyVideoReportCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("play.rectangle.on.rectangle.fill", tint: ColorTokens.Brand.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "weeklyVideoReport.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "weeklyVideoReport.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .weeklyVideoReport(childId: viewModel.childId))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "weeklyVideoReport.entry.title") + ". " +
            String(localized: "weeklyVideoReport.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Block T v17: Neurolinguist Insights card

    private var neurolinguistInsightsCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("sparkles", tint: ColorTokens.Brand.lilac)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "insights.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "insights.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .neurolinguistInsights(childId: viewModel.childId))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "insights.entry.title") + ". " +
            String(localized: "insights.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Family Calendar Card

    private var familyCalendarCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("calendar.badge.checkmark", tint: ColorTokens.Brand.sky)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "family_calendar.card.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "family_calendar.card.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .familyCalendar)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "family_calendar.card.title") + ". " +
            String(localized: "family_calendar.card.subtitle")
        )
        .accessibilityHint(String(localized: "family_calendar.a11y.open_hint"))
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Stuttering / Fluency card
    //
    // Visible only when `childProfile.hasFluencyGoal == true`.
    // MVP: always shown (flag storage via UserDefaults key "hasFluencyGoal").

    @ViewBuilder
    private var stutteringCard: some View {
        let hasFluencyGoal = UserDefaults.standard.bool(forKey: "hasFluencyGoal")
        if hasFluencyGoal {
            HSCard(style: .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: "waveform.path")
                        .font(TypographyTokens.titleMedium(24))
                        .foregroundStyle(ColorTokens.Brand.sky)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "stuttering.entry.title"))
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        Text(String(localized: "stuttering.entry.subtitle"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                }
            }
            .onTapGesture {
                coordinator.navigate(to: .stutteringHome)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "stuttering.entry.title") + ". " +
                String(localized: "stuttering.entry.subtitle")
            )
            .environment(\.circuitContext, .parent)
        }
    }

    // MARK: - Block R.2 v18: Logopedist Chat Card

    private var logopedistChatCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("message.badge.filled.fill", tint: ColorTokens.Brand.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "chat.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "chat.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            showLogopedistChatSheet = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "chat.entry.title") + ". " +
            String(localized: "chat.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Block R.4 v18: Family Achievements Card

    private var familyAchievementsCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("trophy.circle.fill", tint: ColorTokens.Brand.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "family.achievements.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "family.achievements.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            showFamilyAchievementsSheet = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "family.achievements.entry.title") + ". " +
            String(localized: "family.achievements.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: - v29 Фаза 8: Ф.9 «Понятный прогресс»

    private var plainProgressCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("text.book.closed.fill", tint: ColorTokens.Brand.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "plainProgress.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "plainProgress.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .plainProgress(childId: viewModel.childId))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "plainProgress.entry.title") + ". " +
            String(localized: "plainProgress.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: - v29 Фаза 8: Ф.3 «Логопед для родителей»

    // MARK: - v31 Волна A: Ф.8 «Утро и вечер с Лялей»

    private var dailyRitualsLyalyaCard: some View {
        DailyRitualsLyalyaEntryCard { kind in
            coordinator.navigate(to: .dailyRitualsLyalya(kind: kind))
        }
    }

    // MARK: - v31 Волна B: Ф.4 «Мамин голос»

    private var parentVoiceNoteCard: some View {
        ParentVoiceNoteEntryCard {
            coordinator.navigate(to: .parentVoiceNote(childId: viewModel.childId))
        }
    }
}

// MARK: - ParentDashboardTab Entry Cards (extension to keep struct body length manageable)

private extension ParentDashboardTab {

    // MARK: v31 Wave E Ф.4 — Дневник речевого роста

    var speechGrowthDiaryCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("video.fill.badge.checkmark", tint: ColorTokens.Brand.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "speechGrowthDiary.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "speechGrowthDiary.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .speechGrowthDiary(childId: viewModel.childId))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: v31 Wave F F-05 — «Лимит времени в день»

    var dailyTimeCapCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("clock.badge.checkmark.fill", tint: ColorTokens.Brand.sky)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "dailyTimeCap.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "dailyTimeCap.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .dailyTimeCap)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "dailyTimeCap.entry.title") + ". " +
            String(localized: "dailyTimeCap.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: v31 Волна A — Ф.10 «Что должно быть в возрасте»

    var speechNormsEncyclopediaCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("book.closed.fill", tint: ColorTokens.Brand.sky)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "speechNorms.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "speechNorms.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .speechNormsEncyclopedia)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "speechNorms.entry.title") + ". " +
            String(localized: "speechNorms.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    var parentGuideCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("graduationcap.fill", tint: ColorTokens.Brand.lilac)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "parentGuide.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "parentGuide.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .parentGuide(childId: viewModel.childId))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "parentGuide.entry.title") + ". " +
            String(localized: "parentGuide.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // MARK: — «Словарь звуков» (точка входа на SoundDictionaryView)

    var soundDictionaryCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("character.book.closed.fill", tint: ColorTokens.Brand.rose)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "soundDictionary.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "soundDictionary.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .soundDictionary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "soundDictionary.entry.title") + ". " +
            String(localized: "soundDictionary.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    // Cad-task-1 — «Помощник по методике» (Vertex AI Search). За parental gate
    // (открывается внутри самого экрана), доступен только взрослому.
    var methodologyAssistantCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                parentNavIcon("graduationcap.circle.fill", tint: ColorTokens.Brand.sky)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "methodologyAssistant.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "methodologyAssistant.entry.hint"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture {
            coordinator.navigate(to: .methodologyAssistant)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "methodologyAssistant.entry.title") + ". " +
            String(localized: "methodologyAssistant.entry.hint")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }
}

// MARK: - Preview

#Preview("Parent Home") {
    ParentHomeView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("Parent Home — Mock Data") {
    let container = AppContainer.preview()
    container.currentChildId = "preview-child-1"
    return ParentHomeView()
        .environment(AppCoordinator())
        .environment(container)
}
