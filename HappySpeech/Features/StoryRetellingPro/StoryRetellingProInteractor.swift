import Foundation
import OSLog

// MARK: - StoryRetellingProInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class StoryRetellingProInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "StoryRetellingPro"
    )

    let childId: String
    var state: StoryRetellingProModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func select(_ id: String) {
        state.selectedStoryId = id
        Self.logger.info("select story \(id, privacy: .public)")
    }
}
