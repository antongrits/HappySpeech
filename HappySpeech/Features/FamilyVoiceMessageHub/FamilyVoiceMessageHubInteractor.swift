import Foundation
import OSLog

// MARK: - FamilyVoiceMessageHubInteractor

/// VIP-модуль хаба семейных голосовых сообщений (@Observable Interactor + View).
///
/// Источник данных — реальные записи «Голоса семьи» из `FamilyRecordingStoreWorker`
/// (Realm за DTO-границей). Хаб отображает их как входящие и помечает прочитанными;
/// состояние прочтения персистится в `FamilyVoiceMessageReadStore` (UserDefaults).
/// Без записей — честный пустой стейт, никакой фабрикации сообщений.
@MainActor
@Observable
final class FamilyVoiceMessageHubInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyVoiceMessageHub"
    )

    var state: FamilyVoiceMessageHubModels.ViewState

    private let parentId: String
    private let recordingStore: (any FamilyRecordingStoring)?
    private let readStore: FamilyVoiceMessageReadStore

    init(
        parentId: String = "local-parent",
        recordingStore: (any FamilyRecordingStoring)? = nil,
        readStore: FamilyVoiceMessageReadStore? = nil
    ) {
        self.parentId = parentId
        self.recordingStore = recordingStore
        self.readStore = readStore ?? FamilyVoiceMessageReadStore(parentId: parentId)
        self.state = .initial
    }

    /// Загружает реальные семейные записи и наполняет ViewState.
    /// Без стора (Preview/тесты) — остаётся честный пустой стейт.
    func load() async {
        guard let recordingStore else { return }
        let recordings = await recordingStore.fetchAll(parentId: parentId)
        let messages = FamilyVoiceMessageHubModels.messages(
            from: recordings,
            readIds: readStore.readIds()
        )
        state.messages = messages
        Self.logger.info("loaded \(messages.count) family voice messages")
    }

    func markRead(_ id: String) {
        guard let idx = state.messages.firstIndex(where: { $0.id == id }) else { return }
        guard state.messages[idx].isUnread else { return }
        state.messages[idx].isUnread = false
        readStore.markRead(id)
        Self.logger.info("markRead \(id, privacy: .public)")
    }

    func markAllRead() {
        let unreadIds = state.messages.filter(\.isUnread).map(\.id)
        guard !unreadIds.isEmpty else { return }
        for idx in state.messages.indices {
            state.messages[idx].isUnread = false
        }
        readStore.markRead(unreadIds)
        Self.logger.info("markAllRead count=\(unreadIds.count)")
    }
}
