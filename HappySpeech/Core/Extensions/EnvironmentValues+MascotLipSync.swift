import SwiftUI

// MARK: - MascotLipSyncStateKey
//
// Swift 6 concurrency: MascotLipSyncState изолирован на @MainActor, а
// EnvironmentKey.defaultValue должен быть nonisolated static. SwiftUI строит
// View-дерево (и читает EnvironmentValues) на MainActor, поэтому defaultValue
// безопасно создаётся через `MainActor.assumeIsolated`. Реальный shared-экземпляр
// инжектится из MainActor-isolated AppContainer (`mascotLipSyncState`).

private struct MascotLipSyncStateKey: EnvironmentKey {
    // EnvironmentKey требует nonisolated static. defaultValue инициализируется
    // лениво при первом обращении из MainActor-контекста (SwiftUI View body
    // всегда на MainActor), поэтому `assumeIsolated` здесь безопасен.
    static let defaultValue: MascotLipSyncState = {
        MainActor.assumeIsolated {
            MascotLipSyncState()
        }
    }()
}

// MARK: - EnvironmentValues extension

public extension EnvironmentValues {

    /// Shared real-time lip-sync state маскота Ляли.
    /// Устанавливается в HappySpeechApp через AppContainer.mascotLipSyncState.
    /// Читается в LyalyaMascotView для отображения MouthBubbleOverlay.
    var mascotLipSyncState: MascotLipSyncState {
        get { self[MascotLipSyncStateKey.self] }
        set { self[MascotLipSyncStateKey.self] = newValue }
    }
}
