import Foundation
import OSLog

// MARK: - PhonemeJourneyMapInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class PhonemeJourneyMapInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemeJourneyMap"
    )

    let childId: String
    var state: PhonemeJourneyMapModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func toggle(_ stage: PhonemeJourneyMapModels.Stage) {
        guard let idx = state.stages.firstIndex(where: { $0.id == stage }) else { return }
        state.stages[idx].isComplete.toggle()
        Self.logger.info("toggle \(stage.title, privacy: .public) → \(self.state.stages[idx].isComplete)")
    }
}
