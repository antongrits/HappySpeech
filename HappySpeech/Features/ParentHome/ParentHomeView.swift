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
    }

    var body: some View {
        Group {
            // P0.2 fix v19: always use tabLayout on iPhone (iOS 26 on SE3 simulator
            // may return .regular hSizeClass or .pad idiom via new adaptive APIs).
            // sidebarLayout is intentionally disabled for diploma build (iPhone-only).
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
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                        .accessibilityLabel(tab.rawValue)
                }
            }
            .navigationTitle(String(localized: "Родитель"))
            .listStyle(.sidebar)
        } detail: {
            if let vm = scene?.viewModel {
                switch selectedTab {
                case .dashboard:  ParentDashboardTab(viewModel: vm, coordinator: coordinator)
                case .sessions:   ParentSessionsTab(sessions: vm.recentSessions)
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
                    Label(ParentTab.dashboard.rawValue, systemImage: ParentTab.dashboard.icon)
                }
                .tag(ParentTab.dashboard)

            sessionsTab
                .tabItem {
                    Label(ParentTab.sessions.rawValue, systemImage: ParentTab.sessions.icon)
                }
                .tag(ParentTab.sessions)

            analyticsTab
                .tabItem {
                    Label(ParentTab.analytics.rawValue, systemImage: ParentTab.analytics.icon)
                }
                .tag(ParentTab.analytics)

            settingsTab
                .tabItem {
                    Label(ParentTab.settings.rawValue, systemImage: ParentTab.settings.icon)
                }
                .tag(ParentTab.settings)
        }
        .tint(ColorTokens.Parent.accent)
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
            ParentSessionsTab(sessions: vm.recentSessions)
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
            LyalyaMascotView(state: .thinking, size: 80)
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

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(AppContainer.self) private var container

    /// Block R.2 v18 — sheet с LogopedistChatView (parent ↔ specialist).
    @State private var showLogopedistChatSheet: Bool = false
    /// Block R.4 v18 — sheet с FamilyAchievementsView (общие достижения).
    @State private var showFamilyAchievementsSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sectionGap) {
                    // Header
                    headerSection

                    // Child selector (if multiple children)
                    childSection

                    // Last session card
                    if let lastSession = viewModel.lastSession {
                        lastSessionCard(lastSession)
                    } else {
                        noSessionCard
                    }

                    // Streak & stats
                    statsRow

                    // M6.16: Screening card (если скрининг пройден)
                    if let screening = viewModel.screeningCard {
                        screeningCard(screening)
                    }

                    // Home task from LLM
                    if let homeTask = viewModel.homeTask {
                        homeTaskCard(homeTask)
                    }

                    // Family Voice card
                    familyVoiceCard

                    // Block T v17 — Pronunciation Leaderboard (parent-only, COPPA-safe).
                    pronunciationLeaderboardCard

                    // Block T v17 — Neurolinguist Insights (rule-based summary).
                    neurolinguistInsightsCard

                    // Family Calendar card
                    familyCalendarCard

                    // Block R.2 v18 — Logopedist chat card.
                    logopedistChatCard

                    // Block R.4 v18 — Family achievements card.
                    familyAchievementsCard

                    // Stuttering / Fluency module (if hasFluencyGoal enabled)
                    stutteringCard

                    // Recommendations
                    recommendationsSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp16)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
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

    private var headerSection: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text(viewModel.greeting)
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: SpacingTokens.sp2)
            LyalyaMascotView(state: .waving, size: 64)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.sp3)
    }

    private var childSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp3) {
                // Avatar
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(String(viewModel.childName.prefix(1)))
                            .font(TypographyTokens.titleSmall(22))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(ColorTokens.Brand.primary.opacity(0.35), lineWidth: 1.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.childName)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "\(viewModel.childAge) лет · \(viewModel.targetSoundsText)"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: SpacingTokens.sp2)

                Button {
                    // Switch child
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                }
            }
        }
    }

    private func lastSessionCard(_ session: ParentHomeModels.SessionSummary) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack {
                    HSBadge(session.targetSound, style: .filled(ColorTokens.Brand.primary))
                    HSBadge(session.templateName, style: .neutral)
                    Spacer()
                    Text(session.dateText)
                        .font(TypographyTokens.mono(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Результат занятия"))
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(session.resultText)
                            .font(TypographyTokens.headline(20))
                            .foregroundStyle(session.successRate >= 0.7 ? ColorTokens.Semantic.success : ColorTokens.Semantic.warning)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: SpacingTokens.sp2)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(localized: "Попыток"))
                            .font(TypographyTokens.body(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text("\(session.totalAttempts)")
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                let tint = session.successRate >= 0.7
                    ? ColorTokens.Semantic.success
                    : ColorTokens.Semantic.warning
                HSProgressBar(value: session.successRate, style: .parent, tint: tint)
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private var noSessionCard: some View {
        HSEmptyState(
            icon: "play.circle",
            title: String(localized: "Занятий пока нет"),
            message: String(localized: "Начните первое занятие вместе с ребёнком"),
            actionTitle: String(localized: "Начать занятие")
        ) {}
    }

    private var statsRow: some View {
        // Regular (iPad): горизонтальный ряд из 3 карточек.
        // Compact (iPhone / Slide Over): вертикальный стек 3 карточек.
        Group {
            if hSizeClass == .regular {
                HStack(spacing: SpacingTokens.sp3) {
                    statCards
                }
            } else {
                VStack(spacing: SpacingTokens.sp3) {
                    statCards
                }
            }
        }
    }

    @ViewBuilder
    private var statCards: some View {
        ParentStatCard(
            value: "\(viewModel.currentStreak)",
            label: String(localized: "Дней подряд"),
            icon: "flame.fill",
            color: .orange
        )
        ParentStatCard(
            value: "\(viewModel.totalSessionMinutes)",
            label: String(localized: "Минут всего"),
            icon: "clock.fill",
            color: ColorTokens.Brand.sky
        )
        ParentStatCard(
            value: "\(Int((viewModel.overallRate) * 100))%",
            label: String(localized: "Средний результат"),
            icon: "checkmark.seal.fill",
            color: ColorTokens.Semantic.success
        )
    }

    private func homeTaskCard(_ task: String) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.15))) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Image(systemName: "house.circle.fill")
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Brand.gold)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Домашнее задание"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(task)
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(4)
                        .ctaTextStyle()
                }
            }
        }
        .environment(\.circuitContext, .parent)
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
                        .padding(.horizontal, 8)
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
                        coordinator.navigate(to: .screening(childId: viewModel.childId))
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
        switch token {
        case "severe":   return ColorTokens.Semantic.error
        case "moderate": return ColorTokens.Brand.gold
        default:          return ColorTokens.Semantic.success
        }
    }

    // MARK: - Family Voice Card

    private var familyVoiceCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "mic.badge.plus")
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
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
                Image(systemName: "trophy.fill")
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
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

    // MARK: - Block T v17: Neurolinguist Insights card

    private var neurolinguistInsightsCard: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "sparkles")
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
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
                Image(systemName: "calendar.badge.checkmark")
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
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
                Image(systemName: "message.badge.filled.fill")
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
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
                Image(systemName: "trophy.circle.fill")
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
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

    private var recommendationsSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.sp5) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(String(localized: "Рекомендации"))
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Parent.ink)

                ForEach(viewModel.recommendations, id: \.self) { rec in
                    HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                        Image(systemName: "lightbulb.fill")
                            .font(TypographyTokens.caption(14))
                            .foregroundStyle(ColorTokens.Brand.butter)
                            .padding(.top, 2)

                        Text(rec)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .ctaTextStyle()
                    }
                }
            }
        }
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
