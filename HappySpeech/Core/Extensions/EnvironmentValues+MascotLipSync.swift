import SwiftUI

// MARK: - MascotLipSyncStateKey
//
// Swift 6 concurrency challenge: MascotLipSyncState изолирован на @MainActor,
// но EnvironmentKey.defaultValue должен быть nonisolated static.
//
// Решение: используем lazy var внутри MainActor-isolated AppContainer как
// единственный путь создания реального экземпляра. Для defaultValue
// применяем специальный sentinel-класс-обёртку, инициализированный с
// помощью withoutActuallyEscaping обхода через @_marker protocol.
//
// Самый чистый Swift 6 паттерн: вынести хранение в отдельный reference type
// который сам является @unchecked Sendable, используя MainActor.assumeIsolated.

private final class LipSyncStateBox: @unchecked Sendable {
    // Хранит MascotLipSyncState. Инициализация происходит один раз на MainActor
    // (через AppContainer), либо лениво через assumeIsolated для default.
    var state: MascotLipSyncState?

    static let fallback: LipSyncStateBox = {
        let box = LipSyncStateBox()
        // MainActor.assumeIsolated безопасен здесь:
        // SwiftUI вызывает EnvironmentValues на MainActor при построении View-дерева.
        MainActor.assumeIsolated {
            box.state = MascotLipSyncState()
        }
        return box
    }()
}

private struct MascotLipSyncStateKey: EnvironmentKey {
    // EnvironmentKey требует nonisolated static.
    // LipSyncStateBox.fallback инициализируется лениво при первом обращении
    // из MainActor контекста (SwiftUI View body всегда на MainActor).
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
