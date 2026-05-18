import Charts
import OSLog
import SwiftUI

// MARK: - AchievementsView (Clean Swift: View)
//
// Экран достижений + offline leaderboard (M13 Extension L6).
// Состав:
//   1. Tab picker: «Достижения» / «Прогресс»
//   2. Tab достижений: прогресс-заголовок + секции по rarity
//   3. Tab прогресса: bar chart дней / семейный leaderboard

struct AchievementsView: View {

    let childId: String

    @State private var viewModel: AchievementsModels.Load.ViewModel?
    @State private var interactor: AchievementsInteractor?
    @State private var presenter: AchievementsPresenter?
    @State private var router: AchievementsRouter?
    // Сильная ссылка на presenter-proxy: `presenter.view` — weak. Без strong-владельца
    // proxy освобождается сразу после setupScene() и displayAchievements никогда
    // не вызывается — экран навсегда зависает на ProgressView.
    @State private var displayProxy: AchievementsDisplayProxy?
    @State private var selectedTab: AchievementsTab = .list
    @State private var toastViewModel: AchievementsModels.ToastUnlocked.ViewModel?
    @State private var showToast: Bool = false
    @State private var showUnlockConfetti: Bool = false

    // MARK: S12 Hero Transitions (Block S)
    // Namespace для matchedGeometryEffect: badge icon → expanded detail overlay.
    @Namespace private var achievementNamespace
    @State private var expandedAchievementId: String?

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "ru.happyspeech", category: "AchievementsView")

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ColorTokens.Kid.bg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)

                if let vm = viewModel {
                    TabView(selection: $selectedTab) {
                        achievementsTab(vm: vm)
                            .tag(AchievementsTab.list)

                        leaderboardTab(vm: vm)
                            .tag(AchievementsTab.leaderboard)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: selectedTab)
                } else {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                    Spacer()
                }
            }

            if showToast, let toast = toastViewModel {
                toastBanner(toast)
                    .padding(.bottom, SpacingTokens.sp6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Конфетти при разблокировке ачивки (medal preset)
            HSConfettiView(preset: .medal, isActive: $showUnlockConfetti)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // S12 Hero Overlay: expanded achievement badge detail.
            if let expandedId = expandedAchievementId,
               let vm = viewModel,
               let section = vm.sections.first(where: { $0.items.contains(where: { $0.id == expandedId }) }),
               let item = section.items.first(where: { $0.id == expandedId }) {
                achievementHeroOverlay(item: item)
                    .transition(.opacity)
                    .zIndex(30)
            }
        }
        .navigationTitle(String(localized: "achievements.tab.list"))
        .navigationBarTitleDisplayMode(.large)
        .task { await setupScene() }
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(.list, title: String(localized: "achievements.tab.list"))
            tabButton(.leaderboard, title: String(localized: "achievements.tab.leaderboard"))
        }
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.button)
                .fill(Color(.secondarySystemFill))
        )
    }

    private func tabButton(_ tab: AchievementsTab, title: String) -> some View {
        Button {
            withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(TypographyTokens.caption(14))
                .foregroundStyle(selectedTab == tab ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.inkMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    selectedTab == tab
                    ? RoundedRectangle(cornerRadius: RadiusTokens.button - 2)
                        .fill(ColorTokens.Brand.primary)
                    : nil
                )
                .padding(3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    // MARK: - Achievements tab

    private func achievementsTab(vm: AchievementsModels.Load.ViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                progressHeader(vm: vm)

                if vm.sections.isEmpty {
                    emptyState
                } else {
                    ForEach(vm.sections) { section in
                        achievementSection(section)
                    }
                }

                Spacer(minLength: SpacingTokens.sp8)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp4)
        }
    }

    private func progressHeader(vm: AchievementsModels.Load.ViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(String(localized: "achievements.tab.list"))
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(vm.progressText)
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .font(TypographyTokens.headline(28))
                .foregroundStyle(ColorTokens.Brand.butter)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "achievements.tab.list")). \(vm.progressText)")
    }

    private func achievementSection(_ section: AchievementSection) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(section.rarity.localizedTitle)
            ForEach(section.items) { item in
                // S12: matchedGeometryEffect — card is source while not expanded.
                // Tap на unlocked ачивку — hero expand (если ReduceMotion off).
                AchievementCardView(item: item)
                    .matchedGeometryEffect(
                        id: "achievement_\(item.id)",
                        in: achievementNamespace,
                        isSource: expandedAchievementId != item.id
                    )
                    .onTapGesture {
                        guard item.isUnlocked else { return }
                        if reduceMotion {
                            // Без hero анимации — просто ничего не делаем (нет отдельного detail screen).
                            return
                        }
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            expandedAchievementId = item.id
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(item.isUnlocked
                                       ? String(localized: "achievements.card.expand.hint")
                                       : "")
            }
        }
    }

    // MARK: - Achievement Hero Overlay (S12 Block S)

    @ViewBuilder
    private func achievementHeroOverlay(item: AchievementCellViewModel) -> some View {
        ZStack {
            ColorTokens.Overlay.dimmerHeavy
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        expandedAchievementId = nil
                    }
                }
                .accessibilityLabel(String(localized: "child.home.hero.dismiss.a11y"))
                .accessibilityAddTraits(.isButton)

            VStack(spacing: SpacingTokens.sp5) {
                // Hero badge icon — большой круг с иконкой.
                ZStack {
                    Circle()
                        .fill(heroRarityColor(item.rarity).opacity(0.20))
                        .frame(width: 120, height: 120)
                    Image(systemName: item.iconName)
                        .font(TypographyTokens.kidDisplay(52))
                        .foregroundStyle(heroRarityColor(item.rarity))
                }
                .matchedGeometryEffect(
                    id: "achievement_\(item.id)",
                    in: achievementNamespace,
                    isSource: expandedAchievementId == item.id
                )
                .accessibilityHidden(true)

                VStack(spacing: SpacingTokens.sp2) {
                    Text(item.title)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    if let dateText = item.unlockedDateFormatted {
                        Text(dateText)
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(heroRarityColor(item.rarity))
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        expandedAchievementId = nil
                    }
                } label: {
                    Text(String(localized: "rewards.detail.close"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .padding(.horizontal, SpacingTokens.sp6)
                        .padding(.vertical, SpacingTokens.sp3)
                        .background(
                            Capsule().fill(heroRarityColor(item.rarity))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "rewards.detail.close"))
            }
            .padding(SpacingTokens.screenEdge)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card * 2, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 24, x: 0, y: 8)
            )
            .padding(.horizontal, SpacingTokens.sp4)
        }
        .accessibilityElement(children: .contain)
    }

    private func heroRarityColor(_ rarity: AchievementRarity) -> Color {
        switch rarity {
        case .legendary: return ColorTokens.Brand.butter
        case .rare:      return ColorTokens.Brand.lilac
        case .common:    return ColorTokens.Brand.mint
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(TypographyTokens.caption(11))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .tracking(1.2)
            .accessibilityAddTraits(.isHeader)
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp4) {
            LyalyaMascotView(state: .encouraging, size: 140)
                .accessibilityHidden(true)
            Text(String(localized: "achievements.empty"))
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, SpacingTokens.sp8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Leaderboard tab

    private func leaderboardTab(vm: AchievementsModels.Load.ViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp6) {
                if !vm.leaderboardDays.isEmpty {
                    activityChartSection(days: vm.leaderboardDays)
                }

                if vm.showFamilyLeaderboard && !vm.siblingLeaderboard.isEmpty {
                    familyLeaderboardSection(entries: vm.siblingLeaderboard)
                }

                Spacer(minLength: SpacingTokens.sp8)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp4)
        }
    }

    private func activityChartSection(days: [LeaderboardDayEntry]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(String(localized: "achievements.tab.leaderboard"))

            Chart(days) { entry in
                BarMark(
                    x: .value("День", entry.label),
                    y: .value("Раунды", entry.roundsCompleted)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [ColorTokens.Brand.primary, ColorTokens.Brand.sky],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .accessibilityLabel(String(localized: "achievements.tab.leaderboard"))
        }
    }

    private func familyLeaderboardSection(entries: [SiblingLeaderboardEntry]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(String(localized: "achievements.family.leaderboard.title"))

            ForEach(entries) { entry in
                HStack(spacing: SpacingTokens.sp3) {
                    Text("\(entry.rank)")
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(rankColor(entry.rank))
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    Text(entry.childName)
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Kid.ink)

                    Spacer()

                    Text(
                        String(
                            format: String(localized: "achievements.progress.format"),
                            entry.totalAchievements,
                            Achievement.allCases.count
                        )
                    )
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .padding(.horizontal, SpacingTokens.sp4)
                .padding(.vertical, SpacingTokens.sp3)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(entry.rank) место. \(entry.childName). \(entry.totalAchievements) достижений"
                )
            }
        }
    }

    // MARK: - Toast

    private func toastBanner(_ toast: AchievementsModels.ToastUnlocked.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: toast.iconName)
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Brand.butter)
                .accessibilityHidden(true)
            Text(toast.message)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.sp5)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            Capsule()
                .fill(ColorTokens.Kid.surface)
                .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 12, x: 0, y: 4)
        )
        .accessibilityAnnouncement(toast.message)
    }

    // MARK: - Helpers

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return ColorTokens.Brand.butter
        case 2: return Color(.systemGray)
        case 3: return Color(.brown)
        default: return ColorTokens.Kid.inkMuted
        }
    }

    // MARK: - Scene setup

    private func setupScene() async {
        guard interactor == nil else { return }

        let achievementsPresenter = AchievementsPresenter()
        let achievementsInteractor = AchievementsInteractor(
            realmActor: container.realmActor,
            childRepository: container.childRepository,
            sessionRepository: container.sessionRepository
        )
        let achievementsRouter = AchievementsRouter()

        let proxy = makeDisplayProxy()
        achievementsInteractor.presenter = achievementsPresenter
        achievementsPresenter.view = proxy
        achievementsRouter.coordinator = coordinator

        interactor = achievementsInteractor
        presenter = achievementsPresenter
        router = achievementsRouter
        displayProxy = proxy

        await interactor?.loadAchievements(.init(childId: childId))
    }

    /// Creates a lightweight proxy that routes presenter callbacks to this @State view.
    private func makeDisplayProxy() -> AchievementsDisplayProxy {
        AchievementsDisplayProxy(
            onDisplay: { [self] vm in
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                    viewModel = vm
                }
            },
            onToast: { [self] toast in
                toastViewModel = toast
                withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.75)) {
                    showToast = true
                }
                showUnlockConfetti = true
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { showToast = false }
                }
            }
        )
    }
}

// MARK: - AchievementsTab

enum AchievementsTab: Hashable {
    case list
    case leaderboard
}

// MARK: - AchievementsDisplayProxy

/// Bridges AchievementsDisplayLogic (class protocol) into SwiftUI closures.
@MainActor
final class AchievementsDisplayProxy: AchievementsDisplayLogic {

    private let onDisplay: (AchievementsModels.Load.ViewModel) -> Void
    private let onToast: (AchievementsModels.ToastUnlocked.ViewModel) -> Void
    private let onNextProgress: ((AchievementsModels.NextAchievementProgress.ViewModel) -> Void)?
    private let onMotivationalMessage: ((String) -> Void)?
    private let onShareSheet: ((String, Achievement) -> Void)?

    init(
        onDisplay: @escaping (AchievementsModels.Load.ViewModel) -> Void,
        onToast: @escaping (AchievementsModels.ToastUnlocked.ViewModel) -> Void,
        onNextProgress: ((AchievementsModels.NextAchievementProgress.ViewModel) -> Void)? = nil,
        onMotivationalMessage: ((String) -> Void)? = nil,
        onShareSheet: ((String, Achievement) -> Void)? = nil
    ) {
        self.onDisplay = onDisplay
        self.onToast = onToast
        self.onNextProgress = onNextProgress
        self.onMotivationalMessage = onMotivationalMessage
        self.onShareSheet = onShareSheet
    }

    func displayAchievements(_ viewModel: AchievementsModels.Load.ViewModel) {
        onDisplay(viewModel)
    }

    func displayUnlockedToast(_ viewModel: AchievementsModels.ToastUnlocked.ViewModel) {
        onToast(viewModel)
    }

    func displayNextAchievementProgress(
        _ viewModel: AchievementsModels.NextAchievementProgress.ViewModel
    ) {
        onNextProgress?(viewModel)
    }

    func displayMotivationalMessage(_ message: String) {
        onMotivationalMessage?(message)
    }

    func displayShareSheet(shareText: String, achievement: Achievement) {
        onShareSheet?(shareText, achievement)
    }
}

// MARK: - View+accessibilityAnnouncement helper

private extension View {
    @ViewBuilder
    func accessibilityAnnouncement(_ message: String) -> some View {
        self.accessibilityLabel(message)
    }
}

// MARK: - Preview

#Preview("Achievements — Light") {
    NavigationStack {
        AchievementsView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
    }
}
