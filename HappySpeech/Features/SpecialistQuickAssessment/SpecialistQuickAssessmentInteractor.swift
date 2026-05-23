import Foundation
import OSLog

// MARK: - SpecialistQuickAssessmentInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SpecialistQuickAssessmentInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistQuickAssessment"
    )

    let childId: String
    let specialistId: String
    var state: SpecialistQuickAssessmentModels.ViewState

    init(childId: String, specialistId: String) {
        self.childId = childId
        self.specialistId = specialistId
        self.state = .initial
    }

    func set(_ category: SpecialistQuickAssessmentModels.Category, stars: Int) {
        guard let idx = state.ratings.firstIndex(where: { $0.id == category }) else { return }
        state.ratings[idx].stars = max(0, min(5, stars))
        state.isSaved = false
    }

    func save() {
        state.isSaved = true
        Self.logger.info("save assessment avg=\(self.state.averageStars)")
    }

    func reset() {
        state = .initial
    }
}
