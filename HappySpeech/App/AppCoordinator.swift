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
    // v25 6.2: new features (F-301 / F-302 / F-303)
    case weeklyReport(childId: String, weekOffset: Int)
    case articulationGym(soundGroup: ArticulationSoundGroup)
    case wordBank(childId: String)
    // v26 2.1: ранее не подключённые экраны (полный VIP, недостижимы из навигации)
    case grammarGame(childId: String)
    case guidedTour
    case speechVisualization(word: String, targetSound: String)
    case arFaceFilter
    case dialectAdaptation(childId: String)
    case logopedistChat(parentId: String, specialistId: String)
    case culturalContent(childId: String)
    case weeklyChallenge(childId: String)
    // v29 Фаза 8: новые функции (Волна 1)
    case plainProgress(childId: String)
    case parentGuide(childId: String)
    case soundTrafficLight(childId: String)
    // v29 Фаза 8: новые функции (Волна 2)
    case phonemicListening(childId: String)
    case speechTempo(childId: String)
    case breatheAndSpeak(childId: String)
    // v29 Фаза 8: новые функции (Волна 3)
    case prosody(childId: String)
    case retelling(childId: String)
    case lexicalThemes(childId: String)
    case storytelling(childId: String)
    case coPlay(childId: String)
    case assignedHomework(specialistId: String)
    // v31 Волна A: новые методически-ценные функции
    case speechNormsEncyclopedia
    case dailyRitualsLyalya(kind: RitualKind)
    // v31 Волна B Ф.1: новый методически-ценный экран.
    case syllableConstructor(childId: String)
    // v31 Волна B Ф.2: импрессивная речь, понимание инструкции по Левиной.
    case comprehensionDetective(childId: String)
    // v31 Волна B Ф.3: спокойный вечерний поток — дыхание + история.
    case bedtimeMode(childId: String)
    // v31 Волна B Ф.4: родительские голосовые записки «Мамин голос».
    case parentVoiceNote(childId: String)

    // MARK: - v31 Волна C
    case rewardShop(childId: String)
    case letterTrace(childId: String)
    case customWordList(specialistId: String)

    // MARK: - v31 Волна D
    /// Ф.1 (kid): Read-aloud + comprehension quiz («Слушай и понимай»).
    case readAloudStory(childId: String)
    /// Ф.3 (specialist): 10-Q анкета первичной оценки ребёнка.
    case specialistAssessment(childId: String, specialistId: String)

    // MARK: - v31 Wave E (research F-02 / G-06, methodology Ф6 / Ф9)
    /// Wave E Ф.1 (kid): Karaoke pitch-контур — real-time pitch vs модель.
    case karaokePitch(childId: String)
    /// Wave E Ф.2 (kid): Пальчики-говоруны — Vision Hand Pose.
    case fingerPlay(childId: String)
    /// Wave E Ф.3 (kid): Oral story creator — 3 картинки → запись → ASR/TTR.
    case oralStoryCreator(childId: String)
    /// Wave E Ф.4 (parent): Speech growth diary — шифрованные видеоклипы.
    case speechGrowthDiary(childId: String)

    // MARK: - v31 Wave F (Object Description Map, методология Ткаченко)
    /// Wave F Ф.2 (kid): План-схема описания объекта (Ткаченко) —
    /// ребёнок описывает объект по 6–8 пиктограммам, ASR + анализ
    /// покрытия пунктов плана → 0…3 ★.
    case objectDescriptionMap(childId: String)
    /// Wave F Ф.7 (kid): Логоритмика (Картушина / Волкова) —
    /// chant-метроном, CMMotionManager детектит тапы по вертикальному
    /// ускорению, BeatScorer считает F1 совпадения с expected beats.
    case logorhythmics(childId: String)

    // MARK: - v31 Wave F F-05 (Daily Time Cap, NO Family Controls)
    /// Wave F F-05 (parent): дневной лимит времени в HappySpeech.
    /// Per-device cap + UserDefaults accounting; нет ScreenTime entitlement.
    case dailyTimeCap

    // MARK: - v31 Wave F Ф.11 (Bilingual Mode, методология Глухов/Цейтлин)
    /// Wave F Ф.11 (kid): двуязычный режим — словарик из 30+ слов с
    /// переводами на белорусский / английский, + tap-практика 10 раундов.
    /// Persistence выбора языка — UserDefaults("bilingualMode.secondLanguage").
    case bilingualMode(childId: String)
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

    // MARK: - v31 Wave F F-05 — Daily time cap gate

    /// Helper для child-экранов: проверяет, превышен ли дневной лимит,
    /// и если да — показывает `.capReached` sheet.
    /// Tracker — `DailyUsageTracking` из `AppContainer`. Безопасно вызывать
    /// многократно (sheet будет показан только если не показан ранее).
    func checkDailyCap(using tracker: any DailyUsageTracking) {
        guard tracker.isOverCap() else { return }
        if case .capReached = presentedSheet { return }
        HSLogger.navigation.info("Daily cap reached → presenting CapReached sheet")
        present(sheet: .capReached)
    }
}

// MARK: - AppSheet

enum AppSheet: Identifiable, Hashable {
    case settings
    case childProfile(childId: String)
    case exportReport(childId: String)
    case parentGuide
    /// v31 Wave F F-05 — превышен дневной лимит, ребёнок видит «время вышло».
    case capReached

    var id: String {
        switch self {
        case .settings:             return "settings"
        case .childProfile(let id): return "childProfile_\(id)"
        case .exportReport(let id): return "exportReport_\(id)"
        case .parentGuide:          return "parentGuide"
        case .capReached:           return "capReached"
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

        // MARK: - v25 6.2: F-301 / F-302 / F-303

        case .weeklyReport(let childId, let weekOffset):
            WeeklySoundReportView(childId: childId, weekOffset: weekOffset)
                .environment(\.circuitContext, .parent)

        case .articulationGym(let soundGroup):
            ArticulationGymView(
                childId: container.currentChildId,
                soundGroup: soundGroup
            )
            .environment(\.circuitContext, .kid)

        case .wordBank(let childId):
            WordBankView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v26 2.1: ранее не подключённые экраны

        case .grammarGame(let childId):
            GrammarGameScene(childId: childId)
                .environment(\.circuitContext, .kid)

        case .guidedTour:
            GuidedTourLaunchView()
                .environment(\.circuitContext, .kid)

        case .speechVisualization(let word, let targetSound):
            NavigationStack {
                SpeechVisualizationView(word: word, targetSound: targetSound)
            }
            .environment(\.circuitContext, .parent)

        case .arFaceFilter:
            ARFaceFilterView()
                .environment(\.circuitContext, .kid)

        case .dialectAdaptation(let childId):
            NavigationStack {
                DialectAdaptationView(childId: childId)
            }
            .environment(\.circuitContext, .parent)

        case .logopedistChat(let parentId, let specialistId):
            NavigationStack {
                LogopedistChatView(parentId: parentId, specialistId: specialistId)
            }
            .environment(\.circuitContext, .parent)

        case .culturalContent(let childId):
            NavigationStack {
                CulturalContentView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        case .weeklyChallenge(let childId):
            NavigationStack {
                WeeklyChallengeView(childId: childId)
            }
            .environment(\.circuitContext, .kid)

        // MARK: - v29 Фаза 8: Волна 1

        case .plainProgress(let childId):
            PlainProgressView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .parentGuide(let childId):
            ParentGuideView(childId: childId)
                .environment(\.circuitContext, .parent)

        case .soundTrafficLight(let childId):
            SoundTrafficLightView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v29 Фаза 8: Волна 2

        case .phonemicListening(let childId):
            PhonemicListeningView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .speechTempo(let childId):
            SpeechTempoView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .breatheAndSpeak(let childId):
            BreatheAndSpeakView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v29 Фаза 8: Волна 3

        case .prosody(let childId):
            ProsodyView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .retelling(let childId):
            RetellingView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .lexicalThemes(let childId):
            LexicalThemesView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .storytelling(let childId):
            StorytellingView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .coPlay(let childId):
            CoPlayView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .assignedHomework(let specialistId):
            AssignedHomeworkView(specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        // MARK: - v31 Волна A

        case .speechNormsEncyclopedia:
            SpeechNormsEncyclopediaView()
                .environment(\.circuitContext, .parent)

        case .dailyRitualsLyalya(let kind):
            DailyRitualsLyalyaView(kind: kind)
                .environment(\.circuitContext, .parent)

        // MARK: - v31 Волна B Ф.1

        case .syllableConstructor(let childId):
            SyllableConstructorView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Волна B Ф.2

        case .comprehensionDetective(let childId):
            ComprehensionDetectiveView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Волна B Ф.3

        case .bedtimeMode(let childId):
            BedtimeModeView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Волна B Ф.4

        case .parentVoiceNote(let childId):
            ParentVoiceNoteView(childId: childId)
                .environment(\.circuitContext, .parent)

        // MARK: - v31 Волна C

        case .rewardShop(let childId):
            RewardShopView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .letterTrace(let childId):
            LetterTraceView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .customWordList(let specialistId):
            CustomWordListView(specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        // MARK: - v31 Волна D

        case .readAloudStory(let childId):
            ReadAloudStoryView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .specialistAssessment(let childId, let specialistId):
            SpecialistAssessmentView(childId: childId, specialistId: specialistId)
                .environment(\.circuitContext, .specialist)

        // MARK: - v31 Wave E

        case .karaokePitch(let childId):
            KaraokePitchView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .fingerPlay(let childId):
            FingerPlayView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .oralStoryCreator(let childId):
            OralStoryCreatorView(childId: childId)
                .environment(\.circuitContext, .kid)

        case .speechGrowthDiary(let childId):
            SpeechGrowthDiaryView(childId: childId)
                .environment(\.circuitContext, .parent)

        // MARK: - v31 Wave F Ф.2

        case .objectDescriptionMap(let childId):
            ObjectDescriptionMapView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Wave F Ф.7

        case .logorhythmics(let childId):
            LogorhythmicsView(childId: childId)
                .environment(\.circuitContext, .kid)

        // MARK: - v31 Wave F F-05

        case .dailyTimeCap:
            DailyTimeCapView()
                .environment(\.circuitContext, .parent)

        // MARK: - v31 Wave F Ф.11

        case .bilingualMode(let childId):
            BilingualModeView(childId: childId)
                .environment(\.circuitContext, .kid)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsView()
        case .childProfile(let id):
            Text("Профиль ребёнка \(id)")
        case .exportReport(let id):
            Text("Экспорт отчёта \(id)")
        case .parentGuide:
            Text("Руководство для родителей")
        case .capReached:
            CapReachedView()
                .interactiveDismissDisabled(true)
        }
    }

    private func launchSplash() {
        // Debug screenshot-tour shortcut: launch with -HSStartRoute <route> to skip splash.
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-HSStartRoute"), idx + 1 < args.count {
            let route = args[idx + 1]
            let target = Self.resolveStartRoute(route)
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

// MARK: - HSStartRoute mapping (v22 Block 0.2)

extension AppCoordinatorView {

    /// Maps a `-HSStartRoute <name>` debug argument to an `AppRoute`.
    ///
    /// Block 0.2 v22 expansion (104 entries): existing 19 base routes + 85 new
    /// routes spanning auth, onboarding (10), lesson templates (16), AR (9),
    /// session (8), settings sub (10), demo (4), family (6), specialist (5),
    /// stuttering (5), misc (11), R+AE (11).
    ///
    /// Strategy:
    /// - Lesson templates → `.lessonPlayer(templateType:)` with kebab-case
    ///   slug matching `GameType.fromTemplateRoute` (16 distinct screenshots).
    /// - Sub-screens of single-root features (onboarding, AR, settings, demo)
    ///   fall back to root `AppRoute` — capture serves as baseline.
    /// - Aliases for already-supported routes (anonymousAuth → .auth,
    ///   authSignUp → .signUp, etc.).
    /// - Unknown / unimplemented routes return `.auth` (default fallback).
    ///
    /// This helper is intentionally side-effect-free and pure to keep the
    /// `launchSplash` flow simple and unit-testable.
    static func resolveStartRoute(_ route: String) -> AppRoute {
        // swiftlint:disable:previous cyclomatic_complexity function_body_length

        let previewChild = "preview-child-1"
        let previewChild2 = "preview-child-2"
        let previewParent = "local-parent"

        switch route {
        // MARK: Base 19 routes (unchanged from pre-v22 behaviour)
        case "demoMode":            return .demoMode
        case "parentHome":          return .parentHome
        case "roleSelect":          return .roleSelect
        case "onboarding":          return .onboarding
        case "settings":            return .settings
        case "offlineState":        return .offlineState
        case "childHome":           return .childHome(childId: previewChild)
        case "progressDashboard":   return .progressDashboard(childId: previewChild)
        case "rewards":             return .rewards(childId: previewChild)
        case "worldMap":            return .worldMap(childId: previewChild, targetSound: "Р")
        case "sessionHistory":      return .sessionHistory(childId: previewChild)
        case "sessionComplete":     return .sessionComplete
        case "arZone":              return .arZone
        case "lessonPlayer":        return .lessonPlayer(templateType: "bingo", childId: previewChild)
        case "familyVoice":         return .familyVoice
        case "stuttering":          return .stutteringHome
        case "fluencyDiary":        return .fluencyDiaryParent
        case "siblingMultiplayer":  return .siblingMultiplayer(childId: previewChild)
        case "auth":                return .auth

        // MARK: Tier 1 — Auth + Onboarding 10 + role/home (20)
        case "authSignUp":          return .signUp
        case "authForgotPassword":  return .forgotPassword
        case "authVerifyEmail":     return .verifyEmail
        case "anonymousAuth":       return .auth
        case "splash":              return .splash
        case "specialistHome":      return .specialistHome
        case "childHome2":          return .childHome(childId: previewChild2)
        case "onboarding1",
             "onboarding2",
             "onboarding3",
             "onboarding4",
             "onboarding5",
             "onboarding6",
             "onboarding7",
             "onboarding8",
             "onboarding9",
             "onboarding10":
            return .onboarding

        // MARK: Tier 2 — LessonPlayer 16 templates
        case "lessonListenAndChoose":
            return .lessonPlayer(templateType: "listen-and-choose", childId: previewChild)
        case "lessonRepeatAfterModel":
            return .lessonPlayer(templateType: "repeat-after-model", childId: previewChild)
        case "lessonDragAndMatch":
            return .lessonPlayer(templateType: "drag-and-match", childId: previewChild)
        case "lessonStoryCompletion":
            return .lessonPlayer(templateType: "story-completion", childId: previewChild)
        case "lessonPuzzleReveal":
            return .lessonPlayer(templateType: "puzzle-reveal", childId: previewChild)
        case "lessonSorting":
            return .lessonPlayer(templateType: "sorting", childId: previewChild)
        case "lessonMemory":
            return .lessonPlayer(templateType: "memory", childId: previewChild)
        case "lessonBingo":
            return .lessonPlayer(templateType: "bingo", childId: previewChild)
        case "lessonSoundHunter":
            return .lessonPlayer(templateType: "sound-hunter", childId: previewChild)
        case "lessonArticulationImitation":
            return .lessonPlayer(templateType: "articulation-imitation", childId: previewChild)
        case "lessonARActivity":
            return .lessonPlayer(templateType: "ar-activity", childId: previewChild)
        case "lessonVisualAcoustic":
            return .lessonPlayer(templateType: "visual-acoustic", childId: previewChild)
        case "lessonBreathingExercise":
            return .lessonPlayer(templateType: "breathing", childId: previewChild)
        case "lessonRhythm":
            return .lessonPlayer(templateType: "rhythm", childId: previewChild)
        case "lessonNarrativeQuest":
            return .lessonPlayer(templateType: "narrative-quest", childId: previewChild)
        case "lessonMinimalPairs":
            return .lessonPlayer(templateType: "minimal-pairs", childId: previewChild)

        // MARK: Tier 3 — AR sub-screens 9 (fallback to .arZone)
        case "arMirror",
             "arStoryQuest",
             "breathingAR",
             "butterflyCatch",
             "holdThePose",
             "mascot3D",
             "mimicLyalya",
             "poseSequence",
             "soundAndFace":
            return .arZone

        // MARK: Tier 4 — Session 5 (fallback to .sessionComplete / .rewards)
        case "sessionShell":
            return .lessonPlayer(templateType: "bingo", childId: previewChild)
        case "sessionDetail":
            return .sessionHistory(childId: previewChild)
        case "celebrationOverlay":
            return .sessionComplete
        case "rewardDetail",
             "rewardAlbum":
            return .rewards(childId: previewChild)

        // MARK: Tier 5 — Settings sub-screens 9 (fallback to .settings)
        case "settingsTheme",
             "settingsNotifications",
             "settingsModelPacks",
             "settingsPrivacy",
             "settingsGDPR",
             "settingsAbout",
             "settingsVoice",
             "settingsLanguage",
             "settingsAccessibility":
            return .settings

        // MARK: Tier 6 — Demo/Misc 7
        case "demoStep1",
             "demoStep5",
             "demoStep10",
             "demoStep15":
            return .demoMode
        case "homeTasks":
            return .homeTasks
        case "rewardCollection",
             "dailyStreak":
            return .rewards(childId: previewChild)

        // MARK: Tier 7 — Family 6
        case "familyHome":
            return .familyHome
        case "profileEditor":
            return .profileEditor(childId: previewChild)
        case "comparisonDashboard":
            return .comparisonDashboard
        case "familyCalendar":
            return .familyCalendar
        case "familyLeaderboard":
            return .pronunciationLeaderboard(parentId: previewParent)
        case "familyAchievements",
             "achievements":
            return .achievements(childId: previewChild)
        case "screening":
            return .screening(childId: previewChild)

        // MARK: Tier 8 — Specialist 5 (fallback to .specialistHome / .auth)
        case "specialistLogin":
            return .auth
        case "studentsList",
             "programEditor",
             "sessionReview",
             "reports":
            return .specialistHome

        // MARK: Tier 9 — Stuttering 5
        case "stutteringHome":
            return .stutteringHome
        case "breathingTree",
             "metronome",
             "softOnset":
            return .stutteringHome
        case "fluencyDiaryHome":
            return .fluencyDiaryParent

        // MARK: Tier 10 — Misc 9 (most fall back to .auth — no view yet)
        case "neurolinguistInsights":
            return .neurolinguistInsights(childId: previewChild)
        case "speechVisualization":
            return .speechVisualization(word: "сова", targetSound: "С")
        case "arFaceFilter":
            return .arFaceFilter
        case "guidedTour":
            return .guidedTour
        case "grammarGame":
            return .grammarGame(childId: previewChild)
        case "offlineMiniGame":
            return .auth
        case "siblingMultiplayerDiscovery",
             "siblingMultiplayerLobby",
             "siblingMultiplayerGame":
            return .siblingMultiplayer(childId: previewChild)

        // MARK: Tier 11 — R-screens + AE 11
        case "dialectAdaptation":
            return .dialectAdaptation(childId: previewChild)
        case "logopedistChat":
            return .logopedistChat(parentId: previewParent, specialistId: "specialist-default")
        case "weeklyChallenge":
            return .weeklyChallenge(childId: previewChild)
        case "plainProgress":
            return .plainProgress(childId: previewChild)
        case "parentGuide":
            return .parentGuide(childId: previewChild)
        case "soundTrafficLight":
            return .soundTrafficLight(childId: previewChild)
        case "phonemicListening":
            return .phonemicListening(childId: previewChild)
        case "speechTempo":
            return .speechTempo(childId: previewChild)
        case "breatheAndSpeak":
            return .breatheAndSpeak(childId: previewChild)
        case "prosody":
            return .prosody(childId: previewChild)
        case "retelling":
            return .retelling(childId: previewChild)
        case "lexicalThemes":
            return .lexicalThemes(childId: previewChild)
        case "storytelling":
            return .storytelling(childId: previewChild)
        case "coPlay":
            return .coPlay(childId: previewChild)
        case "assignedHomework":
            return .assignedHomework(specialistId: "specialist-default")
        case "culturalContent":
            return .culturalContent(childId: previewChild)
        case "pronunciationLeaderboard":
            return .pronunciationLeaderboard(parentId: previewParent)
        case "soundDictionary":
            return .soundDictionary
        case "helpCenter":
            return .helpCenter
        case "dailyChallenge":
            return .dailyChallenge(childId: previewChild)
        case "parentInsightsTimeline":
            return .parentInsightsTimeline(childId: previewChild)
        case "familyAwardsCabinet":
            return .familyAwardsCabinet(parentId: previewParent)
        case "voiceCloning":
            return .voiceCloning(childId: previewChild)

        // MARK: v25 6.2 — F-301 / F-302 / F-303
        case "weeklyReport":
            return .weeklyReport(childId: previewChild, weekOffset: 0)
        case "articulationGym":
            return .articulationGym(soundGroup: .hissing)
        case "wordBank":
            return .wordBank(childId: previewChild)

        // MARK: v28 Фаза 2 — ранее недостижимые маршруты (4)
        case "permissionFlow":
            return .permissionFlow(.microphone)
        case "sharePlay":
            return .sharePlay
        case "familyVoiceSplit":
            return .familyVoiceSplit
        case "familyVoiceLibrary":
            return .familyVoiceLibrary

        // MARK: v31 Волна A — методически-ценные функции
        case "speechNormsEncyclopedia",
             "speechNorms":
            return .speechNormsEncyclopedia
        case "dailyRitualsMorning",
             "dailyRituals":
            return .dailyRitualsLyalya(kind: .morning)
        case "dailyRitualsEvening":
            return .dailyRitualsLyalya(kind: .evening)

        // MARK: v31 Волна B Ф.1
        case "syllableConstructor",
             "syllable":
            return .syllableConstructor(childId: previewChild)

        // MARK: v31 Волна B Ф.2
        case "comprehensionDetective",
             "detective":
            return .comprehensionDetective(childId: previewChild)

        // MARK: v31 Волна B Ф.3
        case "bedtimeMode",
             "bedtime":
            return .bedtimeMode(childId: previewChild)

        // MARK: v31 Волна B Ф.4
        case "parentVoiceNote",
             "voiceNote":
            return .parentVoiceNote(childId: previewChild)

        // MARK: v31 Волна C Ф.1
        case "rewardShop",
             "stickerShop":
            return .rewardShop(childId: previewChild)

        // MARK: v31 Волна C Ф.2
        case "letterTrace",
             "trace":
            return .letterTrace(childId: previewChild)

        // MARK: v31 Волна C Ф.4
        case "customWordList",
             "wordList":
            return .customWordList(specialistId: previewParent)

        // MARK: v31 Волна D Ф.1
        case "readAloudStory",
             "readAloud":
            return .readAloudStory(childId: previewChild)

        // MARK: v31 Волна D Ф.3
        case "specialistAssessment",
             "assessment":
            return .specialistAssessment(
                childId: previewChild,
                specialistId: previewParent
            )

        // MARK: v31 Wave E
        case "karaokePitch",
             "karaoke":
            return .karaokePitch(childId: previewChild)
        case "fingerPlay",
             "fingers":
            return .fingerPlay(childId: previewChild)
        case "oralStoryCreator",
             "storyCreator":
            return .oralStoryCreator(childId: previewChild)
        case "speechGrowthDiary",
             "growthDiary",
             "diary":
            return .speechGrowthDiary(childId: previewChild)

        // MARK: v31 Wave F Ф.2
        case "objectDescriptionMap",
             "descriptionMap",
             "tkachenkoMap":
            return .objectDescriptionMap(childId: previewChild)

        // MARK: v31 Wave F Ф.7
        case "logorhythmics",
             "rhythm",
             "kartushina":
            return .logorhythmics(childId: previewChild)

        // MARK: v31 Wave F F-05
        case "dailyTimeCap",
             "timeCap",
             "screenTime":
            return .dailyTimeCap

        // MARK: v31 Wave F Ф.11
        case "bilingualMode",
             "bilingual",
             "twoLanguages":
            return .bilingualMode(childId: previewChild)

        default:
            return .auth
        }
    }
}
