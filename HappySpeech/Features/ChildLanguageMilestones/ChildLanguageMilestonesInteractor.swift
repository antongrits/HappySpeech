import Foundation
import OSLog

// MARK: - ChildLanguageMilestonesInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class ChildLanguageMilestonesInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ChildLanguageMilestones"
    )

    var state: ChildLanguageMilestonesModels.ViewState

    init() {
        self.state = .initial
    }

    func toggle(_ id: String) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[idx].isAchieved.toggle()
        Self.logger.info("toggle \(id, privacy: .public) → \(self.state.items[idx].isAchieved)")
    }
}
