import SwiftUI
import OSLog
import FirebaseCore
import GoogleSignIn

// MARK: - HappySpeechApp

@main
struct HappySpeechApp: App {

    // MARK: - Init
    init() {
        // Skip Firebase bootstrap in unit-test runs: XCTest hosts the app binary
        // into the xctest bundle and any missing GoogleService-Info.plist triggers
        // NSException SIGABRT before tests can start.
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isTesting, FirebaseApp.app() == nil {
            // Guard against placeholder GoogleService-Info.plist (CI / local Debug without real Firebase config).
            // If API_KEY is a template value Firebase throws NSException before any UI is shown.
            if let plistURL = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
               let plist = NSDictionary(contentsOf: plistURL),
               let apiKey = plist["API_KEY"] as? String,
               !apiKey.hasPrefix("REPLACE_") {
                FirebaseApp.configure()
                HSLogger.app.info("FirebaseApp.configure() called")
            } else {
                HSLogger.app.warning("GoogleService-Info.plist contains placeholder values — Firebase skipped (Debug/CI mode)")
            }
        }
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
                    // Google Sign-In redirect callback.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    private func bootstrapApp() async {
        do {
            try await container.realmActor.open()
            HSLogger.app.info("HappySpeech started — Realm open")
        } catch {
            HSLogger.app.critical("Realm open failed: \(error)")
        }
    }
}
