import SwiftUI
import Charts

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
                    sessionRepository: container.sessionRepository
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
        sessionRepository: any SessionRepository
    ) {
        let viewModel = ParentHomeViewModel()
        let presenter = ParentHomePresenter()
        let interactor = ParentHomeInteractor(
            childRepository: childRepository,
            sessionRepository: sessionRepository
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
        HSCard(style: .elevated) {
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

                HSProgressBar(value: session.successRate, style: .parent, tint: session.successRate >= 0.7 ? ColorTokens.Semantic.success : ColorTokens.Semantic.warning)
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

    private var recommendationsSection: some View {
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
        .padding(SpacingTokens.sp5)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Parent.surface)
                .parentCardShadow()
        )
    }
}

// MARK: - Sessions Tab

private struct ParentSessionsTab: View {
    let sessions: [ParentHomeModels.SessionSummary]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    HSEmptyState(
                        icon: "list.bullet.rectangle",
                        title: String(localized: "Занятий ещё не было"),
                        message: String(localized: "История занятий появится здесь после первого сеанса")
                    )
                } else {
                    List(sessions, id: \.id) { session in
                        SessionRow(session: session)
                            .listRowBackground(ColorTokens.Parent.surface)
                            .listRowSeparatorTint(ColorTokens.Parent.line)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(ColorTokens.Parent.bg)
                }
            }
            .navigationTitle(String(localized: "История занятий"))
        }
    }
}

private struct SessionRow: View {
    let session: ParentHomeModels.SessionSummary

    var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            // Sound badge
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(session.targetSound)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.templateName)
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Parent.ink)
                HStack(spacing: SpacingTokens.sp2) {
                    Text(session.dateText)
                    Text("·")
                    Text(session.durationText)
                }
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Parent.inkMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.resultText)
                    .font(TypographyTokens.mono(14))
                    .foregroundStyle(session.successRate >= 0.7 ? ColorTokens.Semantic.success : ColorTokens.Semantic.warning)
            }
        }
        .padding(.vertical, SpacingTokens.sp2)
    }
}

// MARK: - Analytics Tab

private struct ParentAnalyticsTab: View {
    let progress: [ParentHomeModels.SoundProgress]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.sp5) {
                    if progress.isEmpty {
                        HSEmptyState(
                            icon: "chart.bar.xaxis",
                            title: String(localized: "Данных пока нет"),
                            message: String(localized: "Аналитика появится после первых занятий")
                        )
                        .frame(minHeight: 360)
                    } else {
                        SoundAccuracyChartCard(progress: progress)

                        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                            Text(String(localized: "По звукам"))
                                .font(TypographyTokens.headline(17))
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .padding(.horizontal, SpacingTokens.sp1)

                            ForEach(progress, id: \.sound) { item in
                                SoundProgressCard(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp5)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "Аналитика"))
        }
    }
}

// MARK: - Sound accuracy chart (Swift Charts)

/// Bar chart of average accuracy per target sound.
/// Uses Swift Charts (`Chart` / `BarMark`) — iOS 16+. Tinted to the parent
/// circuit accent. Bars are sorted in the same order as the cards below for
/// visual continuity.
private struct SoundAccuracyChartCard: View {
    let progress: [ParentHomeModels.SoundProgress]

    private var chartData: [ChartPoint] {
        progress.map { item in
            ChartPoint(
                sound: item.sound,
                accuracy: item.overallRate,
                tint: Self.tint(for: item.overallRate)
            )
        }
    }

    private var averageAccuracy: Double {
        guard !progress.isEmpty else { return 0 }
        let sum = progress.map(\.overallRate).reduce(0, +)
        return sum / Double(progress.count)
    }

    var body: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                header

                Chart(chartData) { point in
                    BarMark(
                        x: .value(String(localized: "Звук"), point.sound),
                        y: .value(String(localized: "Точность"), point.accuracy * 100)
                    )
                    .foregroundStyle(point.tint)
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center, spacing: 4) {
                        Text("\(Int(point.accuracy * 100))%")
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 0...110)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine().foregroundStyle(ColorTokens.Parent.line.opacity(0.4))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(TypographyTokens.caption(10))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(TypographyTokens.caption(11).bold())
                            .foregroundStyle(ColorTokens.Parent.ink)
                    }
                }
                .accessibilityLabel(String(localized: "Диаграмма точности по звукам"))
                .accessibilityValue(
                    chartData
                        .map { "\($0.sound): \(Int($0.accuracy * 100))%" }
                        .joined(separator: ", ")
                )

                averageRow
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Точность по звукам"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(String(localized: "За последние 30 дней"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            Spacer()
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(ColorTokens.Parent.accent)
        }
    }

    private var averageRow: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.Semantic.success)
            Text(String(localized: "Средняя точность: \(Int(averageAccuracy * 100))%"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
            Spacer()
        }
        .padding(.top, SpacingTokens.sp1)
    }

    /// Bar tint by accuracy band — green ≥ 80 %, gold 60–79 %, warning < 60 %.
    private static func tint(for rate: Double) -> Color {
        switch rate {
        case 0.80...:
            return ColorTokens.Semantic.success
        case 0.60..<0.80:
            return ColorTokens.Brand.gold
        default:
            return ColorTokens.Semantic.warning
        }
    }

    private struct ChartPoint: Identifiable, Sendable {
        let id = UUID()
        let sound: String
        let accuracy: Double
        let tint: Color
    }
}

private struct SoundProgressCard: View {
    let item: ParentHomeModels.SoundProgress

    var body: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack {
                    Text(item.sound)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.Brand.primary)

                    VStack(alignment: .leading) {
                        Text(item.familyName)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                        Text(item.currentStage)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                    }

                    Spacer()

                    Text("\(Int(item.overallRate * 100))%")
                        .font(TypographyTokens.headline(22))
                        .foregroundStyle(ColorTokens.Parent.accent)
                }

                HSProgressBar(value: item.overallRate, style: .parent, tint: ColorTokens.Parent.accent)
            }
        }
        .environment(\.circuitContext, .parent)
    }
}

// MARK: - Stat Card

private struct ParentStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HSLiquidGlassCard(style: .tinted(color), padding: SpacingTokens.sp4) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.Parent.ink)

                Text(label)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .ctaTextStyle()
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview("Parent Home") {
    ParentHomeView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
