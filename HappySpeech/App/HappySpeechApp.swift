import SwiftUI
import OSLog
import FirebaseCore
import GoogleSignIn

// MARK: - HappySpeechApp

@main
struct HappySpeechApp: App {

    // MARK: - Init
    init() {
        // Firebase must be configured before any Firebase-dependent service is constructed.
        if FirebaseApp.app() == nil {
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
