import Foundation
import OSLog

// MARK: - GoalTrackerKidInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class GoalTrackerKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "GoalTrackerKid"
    )

    let childId: String
    var state: GoalTrackerKidModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func bump(_ kind: GoalTrackerKidModels.GoalKind) {
        guard let index = state.goals.firstIndex(where: { $0.id == kind }) else { return }
        let goal = state.goals[index]
        guard goal.current < goal.target else { return }
        state.goals[index].current += 1
        Self.logger.info("bump \(kind.rawValue, privacy: .public) → \(self.state.goals[index].current)")
    }

    func reset() {
        state = .initial
    }
}
