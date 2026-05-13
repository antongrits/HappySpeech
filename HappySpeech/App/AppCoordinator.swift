import os.signpost
import OSLog
import SwiftUI

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
    /// M6.16: Повторный скрининг из ParentHome.
    case screening(childId: String)
    case familyCalendar
    case familyVoice
    case familyVoiceSplit
    case familyVoiceLibrary
    case stutteringHome
    case fluencyDiaryParent
    case siblingMultiplayer(childId: String)
    case achievements(childId: String)
    // Block N: Family features
    case familyHome
    case comparisonDashboard
    case profileEditor(childId: String)
    // Block P: SharePlay — родитель запускает, COPPA-safe
    case sharePlay
    // Block T v17: новые экраны (T.1, T.3, T.4)
    case voiceCloning(childId: String)
    case pronunciationLeaderboard(parentId: String)
    case neurolinguistInsights(childId: String)
    // Block AE v21: extension screens (110+ target)
    case soundDictionary
    case helpCenter
    // Block AE batch 2 v21: gamification + parent insights + 3D cabinet
    case dailyChallenge(childId: String)
    case parentInsightsTimeline(childId: String)
    case familyAwardsCabinet(parentId: String)
}

enum PermissionType: Hashable {
    case microphone
    case camera
    case notifications
    /// ARKit Face Tracking — требует camera + ARKit, запрашивается через AVCaptureDevice.
    /// На устройствах без TrueDepth считается недоступным (ограничен до .camera).
    case faceTracking
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
        // Plan v22 Block 0.5 — AuthInit interval (Instruments Points of Interest).
        // Замеряет время на удаление прошлой подписки + установку нового listener'а.
        os_signpost(.begin,
                    log: HSSignpost.pointsOfInterest,
                    name: "AuthInit")
        defer {
            os_signpost(.end,
                        log: HSSignpost.pointsOfInterest,
                        name: "AuthInit")
        }

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

        case .lessonPlayer(let templateType, let childId):
            SessionShellView(
                childId: childId,
                targetSoundId: "Р",
                sessionType: templateType.isEmpty ? .adaptive : .quickPractice,
                forcedGameType: GameType.fromTemplateRoute(templateType),
                container: container,
                coordinator: coordinator
            )
            .environment(\.circuitContext, .kid)

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

        case .screening(let childId):
            ScreeningView(
                childId: childId,
                childAge: 6,
                onFinish: { _ in coordinator.navigate(to: .parentHome) },
                onCancel: { coordinator.navigate(to: .parentHome) }
            )
            .environment(\.circuitContext, .parent)

        case .familyCalendar:
            NavigationStack {
                FamilyCalendarView()
            }
            .environment(\.circuitContext, .parent)

        case .familyVoice:
            NavigationStack {
                FamilyVoiceView(parentId: "local-parent")
            }
            .environment(\.circuitContext, .parent)

        case .familyVoiceSplit:
            NavigationStack {
                FamilyVoiceSplitView(
                    recordings: [],
                    parentId: "local-parent",
                    realmActor: container.realmActor
                )
            }
            .environment(\.circuitContext, .parent)

        case .familyVoiceLibrary:
            NavigationStack {
                FamilyVoiceLibraryView(parentId: "local-parent")
            }
            .environment(\.circuitContext, .parent)

        case .stutteringHome:
            NavigationStack {
                StutteringView()
            }
            .environment(\.circuitContext, .kid)

        case .fluencyDiaryParent:
            NavigationStack {
                FluencyDiaryParentView()
            }
            .environment(\.circuitContext, .parent)

        case .siblingMultiplayer(let childId):
            SiblingMultiplayerView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .achievements(let childId):
            NavigationStack {
                AchievementsView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        case .familyHome:
            FamilyHomeView()
                .environment(\.circuitContext, .parent)

        case .comparisonDashboard:
            ComparisonDashboardView()
                .environment(\.circuitContext, .parent)

        case .profileEditor(let childId):
            ProfileEditorView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .sharePlay:
            SharePlayView()
                .environment(\.circuitContext, .parent)

        // MARK: - Block T v17

        case .voiceCloning(let childId):
            NavigationStack {
                VoiceCloningView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        case .pronunciationLeaderboard(let parentId):
            NavigationStack {
                PronunciationLeaderboardView(parentId: parentId)
            }
            .environment(\.circuitContext, .parent)

        case .neurolinguistInsights(let childId):
            NavigationStack {
                NeurolinguistInsightsView(childId: childId)
            }
            .environment(\.circuitContext, .parent)

        // MARK: - Block AE v21

        case .soundDictionary:
            SoundDictionaryView()
                .environment(\.circuitContext, .parent)

        case .helpCenter:
            HelpCenterView()
                .environment(\.circuitContext, .parent)

        // MARK: - Block AE batch 2 v21

        case .dailyChallenge(let childId):
            DailyChallengeView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .parentInsightsTimeline(let childId):
            ParentInsightsTimelineView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .familyAwardsCabinet(let parentId):
            FamilyAwardsCabinetView(parentId: parentId)
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

    // swiftlint:disable:next cyclomatic_complexity
    private func launchSplash() {
        // Debug screenshot-tour shortcut: launch with -HSStartRoute <route> to skip splash.
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-HSStartRoute"), idx + 1 < args.count {
            let route = args[idx + 1]
            let target: AppRoute
            switch route {
            case "demoMode":         target = .demoMode
            case "parentHome":       target = .parentHome
            case "roleSelect":       target = .roleSelect
            case "onboarding":       target = .onboarding
            case "settings":         target = .settings
            case "offlineState":     target = .offlineState
            case "childHome":        target = .childHome(childId: "preview-child-1")
            case "progressDashboard": target = .progressDashboard(childId: "preview-child-1")
            case "rewards":          target = .rewards(childId: "preview-child-1")
            case "worldMap":         target = .worldMap(childId: "preview-child-1", targetSound: "Р")
            case "sessionHistory":   target = .sessionHistory(childId: "preview-child-1")
            case "sessionComplete":  target = .sessionComplete
            case "arZone":           target = .arZone
            case "lessonPlayer":     target = .lessonPlayer(templateType: "bingo", childId: "preview-child-1")
            case "familyVoice":      target = .familyVoice
            case "stuttering":          target = .stutteringHome
            case "fluencyDiary":        target = .fluencyDiaryParent
            case "siblingMultiplayer":  target = .siblingMultiplayer(childId: "preview-child-1")
            case "soundDictionary":     target = .soundDictionary
            case "helpCenter":          target = .helpCenter
            case "dailyChallenge":      target = .dailyChallenge(childId: "preview-child-1")
            case "parentInsightsTimeline":
                target = .parentInsightsTimeline(childId: "preview-child-1")
            case "familyAwardsCabinet":
                target = .familyAwardsCabinet(parentId: "local-parent")
            default:                    target = .auth
            }
            coordinator.navigate(to: target)
            return
        }
        // UI-test: при -UITestOffline сразу открываем OfflineStateView — NetworkMonitor
        // уже выставлен в isConnected=false в AppContainer.makeContainer().
        if ProcessInfo.processInfo.arguments.contains("-UITestOffline") {
            coordinator.navigate(to: .offlineState)
            return
        }

        // Auto-transition from splash after delay.
        // First launch (онбординг не пройден) → показываем 10-шаговый онбординг.
        // В противном случае идём в auth — пользователь либо войдёт, либо
        // зарегистрируется и попадёт в roleSelect.
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                let target: AppRoute = OnboardingState.isCompleted ? .auth : .onboarding
                coordinator.navigate(to: target)
            }
        }
    }
}
