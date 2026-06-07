import Foundation
import OSLog

// MARK: - FamilyVoiceMessageHubInteractor

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
@MainActor
@Observable
final class FamilyVoiceMessageHubInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyVoiceMessageHub"
    )

    var state: FamilyVoiceMessageHubModels.ViewState

    init() {
        self.state = .initial
    }

    func markRead(_ id: String) {
        guard let idx = state.messages.firstIndex(where: { $0.id == id }) else { return }
        state.messages[idx].isUnread = false
        Self.logger.info("markRead \(id, privacy: .public)")
    }

    func markAllRead() {
        for idx in state.messages.indices {
            state.messages[idx].isUnread = false
        }
        Self.logger.info("markAllRead")
    }
}
