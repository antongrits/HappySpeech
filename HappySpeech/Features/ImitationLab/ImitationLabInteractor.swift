import Foundation
import OSLog

// MARK: - ImitationLabInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class ImitationLabInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ImitationLab"
    )

    let childId: String
    var state: ImitationLabModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func playSample(_ id: String) {
        guard let idx = state.samples.firstIndex(where: { $0.id == id }) else { return }
        state.samples[idx].isPlayed = true
        state.currentSampleId = id
        Self.logger.info("play sample \(id, privacy: .public)")
    }
}
