import Foundation
import OSLog

// MARK: - SoundDoctorKidInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SoundDoctorKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDoctorKid"
    )

    let childId: String
    var state: SoundDoctorKidModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    @discardableResult
    func choose(_ optionId: String) -> Bool {
        guard let kase = state.currentCase,
              let option = kase.options.first(where: { $0.id == optionId })
        else { return false }
        if option.isCorrect {
            state.cured += 1
        }
        state.currentCaseIndex = min(state.currentCaseIndex + 1, state.cases.count)
        Self.logger.info("choose \(optionId, privacy: .public) correct=\(option.isCorrect)")
        return option.isCorrect
    }

    func reset() {
        state = .initial
    }
}
