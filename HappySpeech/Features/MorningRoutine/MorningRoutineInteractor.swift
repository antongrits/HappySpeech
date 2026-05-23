import Foundation
import OSLog

// MARK: - MorningRoutineInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class MorningRoutineInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MorningRoutine"
    )

    let childId: String
    var state: MorningRoutineModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func toggle(_ step: MorningRoutineModels.StepKind) {
        guard let index = state.steps.firstIndex(where: { $0.id == step }) else { return }
        state.steps[index].isDone.toggle()
        Self.logger.info("toggle \(step.rawValue, privacy: .public) → \(self.state.steps[index].isDone)")
    }

    func reset() {
        state = .initial
    }
}
