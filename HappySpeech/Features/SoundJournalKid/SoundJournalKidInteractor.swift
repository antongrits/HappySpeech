import Foundation
import OSLog

// MARK: - SoundJournalKidInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SoundJournalKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundJournalKid"
    )

    let childId: String
    var state: SoundJournalKidModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func select(_ id: String) {
        state.selectedEntryId = (state.selectedEntryId == id) ? nil : id
        Self.logger.info("select entry \(id, privacy: .public)")
    }
}
