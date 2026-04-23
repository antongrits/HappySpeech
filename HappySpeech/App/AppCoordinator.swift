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
    case signUp
    case forgotPassword
    case verifyEmail
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

    /// Latest auth snapshot. Updated by `bindAuthState(_:)`.
    private(set) var authUser: AuthUser?
    private var authHandle: Any?
    private weak var boundAuthService: (any AuthService)?

    // MARK: - Auth wiring

    /// Attaches an auth-state listener. Call once at app bootstrap.
    /// When the user signs in/out, root route is switched between `.auth` and role-select / home.
    func bindAuthState(_ service: any AuthService) {
        // Remove previous binding if any.
        if let previousHandle = authHandle, let previousService = boundAuthService {
            previousService.removeAuthStateListener(previousHandle)
        }
        boundAuthService = service
        authHandle = service.addAuthStateListener { [weak self] user in
            Task { @MainActor [weak self] in
                self?.handleAuthChange(user)
            }
        }
    }

    private func handleAuthChange(_ user: AuthUser?) {
        authUser = user
        let uidLabel = user.map { "uid=\($0.uid)" } ?? "nil"
        HSLogger.auth.info("authState changed: \(uidLabel, privacy: .private)")

        // Don't interrupt splash transition or in-progress onboarding.
        switch currentRoute {
        case .splash, .onboarding, .permissionFlow:
            return
        default:
            break
        }

        if user == nil {
            // Signed out — go back to auth screen.
            navigate(to: .auth)
        }
        // Note: successful sign-in transitions are driven explicitly by Auth feature
        // (coordinator.navigate(to: .roleSelect)) so that verify-email flow can intervene.
    }

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
    @Environment(AppContainer.self) private var container

    var body: some View {
        // Wrap the entire navigation stack in the guided-tour container so the
        // spotlight + coach-mark overlay renders on top of whichever screen is
        // currently active. Individual screens register spotlight anchors via
        // `.spotlightAnchor(key:)` at strategic points (mascot, daily mission,
        // quick actions, etc).
        GuidedTourContainer(coordinator: container.guidedTourCoordinator) {
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

        case .signUp:
            AuthSignUpView()

        case .forgotPassword:
            AuthForgotPasswordView()

        case .verifyEmail:
            AuthVerifyEmailView()

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
