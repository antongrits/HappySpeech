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
            FirebaseApp.configure()
            HSLogger.app.info("FirebaseApp.configure() called")
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
