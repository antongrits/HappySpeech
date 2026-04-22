import SwiftUI

// MARK: - ParentHomeView

struct ParentHomeView: View {
    @State private var interactor = ParentHomeInteractor()
    @Environment(AppCoordinator.self) private var coordinator
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
        .onAppear {
            Task { await interactor.fetchData() }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: ParentTab) -> some View {
        switch tab {
        case .dashboard:  ParentDashboardTab(viewModel: interactor.viewModel, coordinator: coordinator)
        case .sessions:   ParentSessionsTab(sessions: interactor.viewModel.recentSessions)
        case .analytics:  ParentAnalyticsTab(progress: interactor.viewModel.soundProgress)
        case .settings:   SettingsView()
        }
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
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Parent.surface)
                .parentCardShadow()
        )
    }

    private func lastSessionCard(_ session: ParentHomeViewModel.SessionSummary) -> some View {
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
                    .foregroundStyle(Color(hex: "#E5A000"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Домашнее задание"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(Color(hex: "#E5A000"))
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
    let sessions: [ParentHomeViewModel.SessionSummary]

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
    let session: ParentHomeViewModel.SessionSummary

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
    let progress: [ParentHomeViewModel.SoundProgress]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.sp5) {
                    ForEach(progress, id: \.sound) { item in
                        SoundProgressCard(item: item)
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

private struct SoundProgressCard: View {
    let item: ParentHomeViewModel.SoundProgress

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
        .padding(.vertical, SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Parent.surface)
                .parentCardShadow()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - ViewModel & Interactor

struct ParentHomeViewModel {
    var childId: String = "preview-child-1"
    var childName: String = "Миша"
    var childAge: Int = 6
    var targetSoundsText: String = "Р, Ш"
    var greeting: String = "Добрый день"
    var currentStreak: Int = 5
    var totalSessionMinutes: Int = 112
    var overallRate: Double = 0.68
    var lastSession: SessionSummary? = nil
    var homeTask: String? = nil
    var recommendations: [String] = []
    var recentSessions: [SessionSummary] = []
    var soundProgress: [SoundProgress] = []

    struct SessionSummary: Identifiable {
        let id: String
        let targetSound: String
        let templateName: String
        let dateText: String
        let durationText: String
        let totalAttempts: Int
        let correctAttempts: Int
        let successRate: Double
        var resultText: String { "\(correctAttempts)/\(totalAttempts)" }
    }

    struct SoundProgress: Identifiable {
        var id: String { sound }
        let sound: String
        let familyName: String
        let currentStage: String
        let overallRate: Double
    }
}

@Observable
@MainActor
final class ParentHomeInteractor {
    var viewModel = ParentHomeViewModel()

    func fetchData() async {
        viewModel.childName = "Миша"
        viewModel.childAge = 6
        viewModel.targetSoundsText = "Р, Ш"
        viewModel.greeting = "Добрый день"
        viewModel.currentStreak = 5
        viewModel.totalSessionMinutes = 112
        viewModel.overallRate = 0.68
        viewModel.lastSession = .init(
            id: "s1",
            targetSound: "Р",
            templateName: "Слушай и выбирай",
            dateText: "Сегодня",
            durationText: "8 мин",
            totalAttempts: 12,
            correctAttempts: 9,
            successRate: 0.75
        )
        viewModel.homeTask = "Повторите дома: ворона, гараж, огород."
        viewModel.recommendations = [
            "Уделите 10 минут звуку Р каждый день.",
            "Слова с Р в середине пока даются трудно — используйте упражнение «Повторяй за мной».",
        ]
        viewModel.soundProgress = [
            .init(sound: "Р", familyName: "Сонорные", currentStage: "Слова", overallRate: 0.45),
            .init(sound: "Ш", familyName: "Шипящие", currentStage: "Слоги", overallRate: 0.72),
        ]
        viewModel.recentSessions = [viewModel.lastSession!]
    }
}

// MARK: - Preview

#Preview("Parent Home") {
    ParentHomeView()
        .environment(AppCoordinator())
        
}
