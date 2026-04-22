import SwiftUI
import OSLog

// MARK: - AppRoute

/// Top-level navigation routes.
enum AppRoute: Hashable {
    case splash
    case onboarding
    case roleSelect
    case childHome(childId: String)
    case parentHome
    case specialistHome
    case auth
    case settings
    case offlineState
    case permissionFlow(PermissionType)
    case demoMode
    case sessionComplete
    case lessonPlayer(templateType: String, childId: String)
    case worldMap(childId: String, targetSound: String)
    case arZone
    case rewards(childId: String)
    case progressDashboard(childId: String)
    case sessionHistory(childId: String)
    case homeTasks
}

enum PermissionType: Hashable {
    case microphone
    case camera
    case notifications
}

// MARK: - AppCoordinator

/// Root coordinator — manages top-level navigation stack.
/// Features navigate by calling coordinator methods, not by direct routing.
@Observable
@MainActor
final class AppCoordinator {

    // MARK: - State

    var currentRoute: AppRoute = .splash
    var navigationPath = NavigationPath()
    var presentedSheet: AppSheet?
    var isShowingOfflineBanner: Bool = false
    var offlinePendingCount: Int = 0

    // MARK: - Navigation

    func navigate(to route: AppRoute) {
        HSLogger.navigation.info("Navigate → \(String(describing: route))")
        withAnimation(MotionTokens.page) {
            currentRoute = route
        }
    }

    func push(_ route: AppRoute) {
        navigationPath.append(route)
    }

    func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }

    func present(sheet: AppSheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func showOfflineBanner(pendingCount: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingOfflineBanner = true
            offlinePendingCount = pendingCount
        }
    }

    func hideOfflineBanner() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingOfflineBanner = false
        }
    }
}

// MARK: - AppSheet

enum AppSheet: Identifiable, Hashable {
    case settings
    case childProfile(childId: String)
    case downloadPacks
    case exportReport(childId: String)
    case parentGuide

    var id: String {
        switch self {
        case .settings:             return "settings"
        case .childProfile(let id): return "childProfile_\(id)"
        case .downloadPacks:        return "downloadPacks"
        case .exportReport(let id): return "exportReport_\(id)"
        case .parentGuide:          return "parentGuide"
        }
    }
}

// MARK: - AppCoordinatorView

/// Root view wired to AppCoordinator — switches between top-level screens.
struct AppCoordinatorView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            mainContent
                .animation(MotionTokens.page, value: coordinator.currentRoute)

            // Offline banner (global)
            if coordinator.isShowingOfflineBanner {
                HSOfflineBanner(
                    pendingCount: coordinator.offlinePendingCount,
                    onRetry: { Task { /* trigger sync */ } }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch coordinator.currentRoute {
        case .splash:
            SplashView()
                .onAppear { launchSplash() }

        case .onboarding:
            OnboardingFlowView()
                .environment(\.circuitContext, .parent)

        case .roleSelect:
            RoleSelectView()

        case .childHome(let childId):
            ChildHomeView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .parentHome:
            ParentHomeView()
                .environment(\.circuitContext, .parent)

        case .specialistHome:
            SpecialistHomeView()
                .environment(\.circuitContext, .specialist)

        case .auth:
            AuthSignInView()

        case .settings:
            SettingsView()

        case .offlineState:
            OfflineStateView()

        case .permissionFlow(let type):
            PermissionFlowView(type: type)

        case .demoMode:
            DemoModeView()

        case .sessionComplete:
            SessionCompleteView(
                result: .sample,
                onContinue: { coordinator.navigate(to: .childHome(childId: "")) },
                onReplay: { coordinator.pop() }
            )

        case .lessonPlayer(let templateType, _):
            Text("LessonPlayer: \(templateType)")
                .font(TypographyTokens.title())

        case .worldMap(let childId, let targetSound):
            WorldMapView(childId: childId, targetSound: targetSound)
                .environment(\.circuitContext, .kid)

        case .arZone:
            ARZoneView()
                .environment(\.circuitContext, .kid)

        case .rewards(let childId):
            RewardsView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .progressDashboard(let childId):
            ProgressDashboardView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .sessionHistory(let childId):
            SessionHistoryView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .homeTasks:
            HomeTasksView()
                .environment(\.circuitContext, .parent)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsView()
        case .childProfile(let id):
            Text("Профиль ребёнка \(id)")
        case .downloadPacks:
            Text("Загрузка контента")
        case .exportReport(let id):
            Text("Экспорт отчёта \(id)")
        case .parentGuide:
            Text("Руководство для родителей")
        }
    }

    private func launchSplash() {
        // Auto-transition from splash after delay
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                coordinator.navigate(to: .auth)
            }
        }
    }
}
