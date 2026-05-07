import CoreSpotlight
import FirebaseAppCheck
import FirebaseCore
import GoogleSignIn
import os.signpost
import OSLog
import SwiftUI

// MARK: - HappySpeechApp

@main
struct HappySpeechApp: App {

    // MARK: - Performance instrumentation

    /// Log-объект для os_signpost замеров.
    /// Subsystem = Bundle ID, category "Performance" — стандарт для Instruments Points of Interest.
    private static let perfLog = OSLog(subsystem: "ru.happyspeech.app", category: "Performance")

    // MARK: - Init

    init() {
        // Отмечаем начало cold start сразу при входе в App.init().
        // OSSignpostID создаётся локально — нет проблем с actor isolation в Swift 6.
        // В Instruments: Time Profiler → Points of Interest → интервал "ColdStart".
        let signID = OSSignpostID(log: Self.perfLog)
        os_signpost(.begin,
                    log: Self.perfLog,
                    name: "ColdStart",
                    signpostID: signID,
                    "init pid=%d uptime=%.3f",
                    ProcessInfo.processInfo.processIdentifier,
                    ProcessInfo.processInfo.systemUptime)

        // Пропускаем Firebase bootstrap в XCTest-окружении: хост-процесс XCTest загружает
        // бинарь приложения, и отсутствующий GoogleService-Info.plist вызывает NSException SIGABRT
        // до запуска тестов.
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isTesting, FirebaseApp.app() == nil {
            // Защита от placeholder-значений в GoogleService-Info.plist (CI / Debug без Firebase).
            if let plistURL = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
               let plist = NSDictionary(contentsOf: plistURL),
               let apiKey = plist["API_KEY"] as? String,
               !apiKey.hasPrefix("REPLACE_") {

                // D.4 — App Check: DeviceCheck в production, Debug provider в Debug/Simulator builds.
                // Конфигурация App Check ДОЛЖНА быть установлена до FirebaseApp.configure().
#if DEBUG
                let appCheckFactory = AppCheckDebugProviderFactory()
#else
                let appCheckFactory = DeviceCheckProviderFactory()
#endif
                AppCheck.setAppCheckProviderFactory(appCheckFactory)

                FirebaseApp.configure()
                HSLogger.app.info("FirebaseApp.configure() вызван с App Check (\(String(describing: type(of: appCheckFactory)), privacy: .public))")
            } else {
                HSLogger.app.warning("GoogleService-Info.plist содержит placeholder — Firebase пропущен (Debug/CI режим)")
            }
        }

        // Конец App.init(): все синхронные инициализации завершены.
        // bootstrapApp() закроет интервал после Realm.open() — это и есть cold start.
        os_signpost(.event,
                    log: Self.perfLog,
                    name: "ColdStart",
                    "app_init_done uptime=%.3f",
                    ProcessInfo.processInfo.systemUptime)
    }

    @State private var container: AppContainer = HappySpeechApp.makeContainer()
    @State private var coordinator: AppCoordinator = AppCoordinator()
    @State private var spotlightCoordinator: SpotlightIndexCoordinator?

    /// Выбирает production или preview-контейнер в зависимости от launch arguments.
    /// При запуске UI-тестов с флагами -UITestMockServices или -UITestOffline
    /// используется AppContainer.preview() с MockNetworkMonitor.
    private static func makeContainer() -> AppContainer {
        let args = ProcessInfo.processInfo.arguments
        let hasStartRoute = args.contains("-HSStartRoute")
        let useMock = args.contains("-UITestMockServices") || args.contains("-UITestOffline") || hasStartRoute
        // UI-тест: при -UITestResetState сбрасываем флаг онбординга,
        // чтобы при следующем запуске splash гарантированно роутил в .onboarding.
        if args.contains("-UITestResetState") {
            OnboardingState.reset()
        }
        if useMock {
            let container = AppContainer.preview()
            // При -UITestOffline принудительно отключаем сеть в MockNetworkMonitor
            if args.contains("-UITestOffline"),
               let mock = container.networkMonitor as? MockNetworkMonitor {
                mock.isConnected = false
                mock.connectionType = .none
            }
            return container
        }
        return AppContainer.live()
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: coordinator)
                .environment(container.themeManager)
                .environment(coordinator)
                .environment(container)
                .environment(\.mascotLipSyncState, container.mascotLipSyncState)
                .environment(\.mascotEyeContactState, container.mascotEyeContactState)
                .preferredColorScheme(container.themeManager.preferredColorScheme)
                .onAppear {
                    Task { await bootstrapApp() }
                }
                .onOpenURL { url in
                    // Callback Google Sign-In redirect.
                    _ = GIDSignIn.sharedInstance.handle(url)
                    // Deep link из виджета «Задание дня»
                    if url.absoluteString == "happyspeech://daily-mission" {
                        if #available(iOS 17.0, *) {
                            DeepLinkRouter.shared.handleShowTodaysMission()
                        }
                    }
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handleSpotlightActivity(activity)
                }
        }
    }

    // MARK: - Bootstrap

    private func bootstrapApp() async {
        do {
            try await container.realmActor.open()
            // Wire LessonVoiceWorker с семейными записями (Priority 1 в цепочке озвучки).
            LessonVoiceWorker.shared.realmActor = container.realmActor

            // Block I v16: GuidedTour VIP — Router получает weak ref на AppCoordinator
            // после того как корневая навигация полностью инициализирована.
            container.attachGuidedTourCoordinator(coordinator)
            // Cold start завершён: Realm открыт, первый экран рендерится.
            // Логируем uptime для расчёта интервала вручную из log stream:
            // cold_start_ms = (end_uptime - begin_uptime) * 1000
            HSLogger.app.info("ColdStart end uptime=\(ProcessInfo.processInfo.systemUptime, format: .fixed(precision: 3)) — Realm открыт")

            // D.2 — FCM: wire notification handler for foreground/background + deep link.
            // Вызываем только если Firebase активен (не testing, не placeholder plist).
            let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            let isFirebaseActive = !isTesting && FirebaseApp.app() != nil
            if isFirebaseActive {
                FCMNotificationHandler.shared.attach(
                    coordinator: coordinator,
                    fcmService: container.fcmService
                )
                HSLogger.app.info("FCMNotificationHandler attached")
            }

            // D.1 — Remote Config: fetch + activate + realtime updates.
            // Выполняется асинхронно после Realm open, не блокирует UI.
            // Ошибки fetch — graceful degradation на bundled defaults.
            if isFirebaseActive {
                Task {
                    do {
                        try await container.remoteConfigService.fetch()
                        _ = try await container.remoteConfigService.activate()
                        container.remoteConfigService.startRealtimeUpdates()
                        HSLogger.app.info("RemoteConfig fetch + activate + realtime OK")
                    } catch {
                        HSLogger.app.warning("RemoteConfig bootstrap failed (using bundled defaults): \(error.localizedDescription)")
                    }
                }
            }

            // K.4 — Запуск Spotlight-индексации после успешного открытия Realm.
            let spotlightCoord = SpotlightIndexCoordinator(
                indexer: container.spotlightIndexer,
                contentService: container.contentService,
                sessionRepository: container.sessionRepository
            )
            spotlightCoordinator = spotlightCoord
            spotlightCoord.start()

            // L.4 — Регистрируем AppCoordinator в DeepLinkRouter для Siri App Intents.
            // Выполняется после Realm.open() — coordinator уже инициализирован и готов.
            if #available(iOS 17.0, *) {
                DeepLinkRouter.shared.register(coordinator: coordinator)
                HSLogger.app.info("DeepLinkRouter: AppCoordinator зарегистрирован для Siri Shortcuts")
            }
        } catch {
            HSLogger.app.critical("ColdStart error — Realm open failed: \(error)")
        }
    }

    // MARK: - K.5 — Deep Link Handling

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }
        HSLogger.app.info("Spotlight deep link: \(identifier, privacy: .public)")

        if identifier.hasPrefix("lesson_") {
            let lessonId = String(identifier.dropFirst("lesson_".count))
            coordinator.navigateToLesson(id: lessonId)
        } else if identifier.hasPrefix("achievement_") {
            let achId = String(identifier.dropFirst("achievement_".count))
            coordinator.navigateToAchievement(id: achId)
        } else if identifier.hasPrefix("session_") {
            let sessionId = String(identifier.dropFirst("session_".count))
            coordinator.navigateToSession(id: sessionId)
        }
    }
}
