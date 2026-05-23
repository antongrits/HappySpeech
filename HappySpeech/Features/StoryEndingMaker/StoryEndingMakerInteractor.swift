import Foundation
import OSLog

// MARK: - StoryEndingMakerInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class StoryEndingMakerInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "StoryEndingMaker"
    )

    let childId: String
    var state: StoryEndingMakerModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func select(_ id: String) {
        state.selectedId = id
        state.phase = .recording
        Self.logger.info("select card \(id, privacy: .public)")
    }

    func save() {
        state.phase = .saved
        Self.logger.info("save story ending")
    }

    func reset() {
        state = .initial
    }
}
