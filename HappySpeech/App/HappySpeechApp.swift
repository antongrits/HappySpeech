import SwiftUI
import OSLog

// MARK: - HappySpeechApp

@main
struct HappySpeechApp: App {
    @State private var container: AppContainer = AppContainer.live()
    @State private var coordinator: AppCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: coordinator)
                .environment(container.themeManager)
                .environment(coordinator)
                .preferredColorScheme(container.themeManager.preferredColorScheme)
                .onAppear {
                    Task { await bootstrapApp() }
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
