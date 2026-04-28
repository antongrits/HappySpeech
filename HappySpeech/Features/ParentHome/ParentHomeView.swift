import SwiftUI

// MARK: - ParentHomeView

struct ParentHomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @State private var scene: ParentHomeScene?
    @State private var selectedTab: ParentTab = .dashboard

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
        TabView(selection: $selectedTab) {
            ForEach(ParentTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(ColorTokens.Parent.accent)
        .environment(\.circuitContext, .parent)
        .task {
            if scene == nil {
                scene = ParentHomeScene(
                    childRepository: container.childRepository,
                    sessionRepository: container.sessionRepository,
                    screeningOutcomeRepository: container.screeningOutcomeRepository
                )
            }
            await scene?.interactor.fetchData(.init(preferredChildId: nil))
        }
    }

    @ViewBuilder
    private func tabContent(for tab: ParentTab) -> some View {
        if let viewModel = scene?.viewModel {
            switch tab {
            case .dashboard:  ParentDashboardTab(viewModel: viewModel, coordinator: coordinator)
            case .sessions:   ParentSessionsTab(sessions: viewModel.recentSessions)
            case .analytics:  ParentAnalyticsTab(progress: viewModel.soundProgress)
            case .settings:   SettingsView()
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Parent.bg)
        }
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
        screeningOutcomeRepository: (any ScreeningOutcomeRepository)? = nil
    ) {
        let viewModel = ParentHomeViewModel()
        let presenter = ParentHomePresenter()
        let interactor = ParentHomeInteractor(
            childRepository: childRepository,
            sessionRepository: sessionRepository,
            screeningOutcomeRepository: screeningOutcomeRepository
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

                    // Recommendations
                    recommendationsSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp16)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "Прогресс"))
            .navigationBarTitleDisplayMode(.large)
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
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(viewModel.greeting)
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .padding(.top, SpacingTokens.sp3)
        }
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
                            .font(.system(size: 22, weight: .bold, design: .rounded))
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
                    Text(String(localized: "\(viewModel.childAge) лет · \(viewModel.targetSoundsText)"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }

                Spacer()

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
                        Text(session.resultText)
                            .font(TypographyTokens.headline(20))
                            .foregroundStyle(session.successRate >= 0.7 ? ColorTokens.Semantic.success : ColorTokens.Semantic.warning)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(localized: "Попыток"))
                            .font(TypographyTokens.body(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                        Text("\(session.totalAttempts)")
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Parent.ink)
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
        HStack(spacing: SpacingTokens.sp3) {
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
    }

    private func homeTaskCard(_ task: String) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.15))) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Image(systemName: "house.circle.fill")
                    .font(.system(size: 28))
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
                        .font(.system(size: 18, weight: .semibold))
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
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
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

    private var recommendationsSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.sp5) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(String(localized: "Рекомендации"))
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Parent.ink)

                ForEach(viewModel.recommendations, id: \.self) { rec in
                    HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14))
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
