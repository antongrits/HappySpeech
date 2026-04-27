import FirebaseCore
import GoogleSignIn
import OSLog
import SwiftUI
import os.signpost

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
                FirebaseApp.configure()
                HSLogger.app.info("FirebaseApp.configure() вызван")
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

    @State private var container: AppContainer = AppContainer.live()
    @State private var coordinator: AppCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: coordinator)
                .environment(container.themeManager)
                .environment(coordinator)
                .environment(container)
                .preferredColorScheme(container.themeManager.preferredColorScheme)
                .onAppear {
                    Task { await bootstrapApp() }
                }
                .onOpenURL { url in
                    // Callback Google Sign-In redirect.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    // MARK: - Bootstrap

    private func bootstrapApp() async {
        do {
            try await container.realmActor.open()
            // Cold start завершён: Realm открыт, первый экран рендерится.
            // Логируем uptime для расчёта интервала вручную из log stream:
            // cold_start_ms = (end_uptime - begin_uptime) * 1000
            HSLogger.app.info("ColdStart end uptime=\(ProcessInfo.processInfo.systemUptime, format: .fixed(precision: 3)) — Realm открыт")
        } catch {
            HSLogger.app.critical("ColdStart error — Realm open failed: \(error)")
        }
    }
}
