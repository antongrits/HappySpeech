import Foundation
import OSLog

// MARK: - MusicalSoundDrumsInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class MusicalSoundDrumsInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MusicalSoundDrums"
    )

    let childId: String
    var state: MusicalSoundDrumsModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func tap(_ drumId: MusicalSoundDrumsModels.DrumId) {
        state.beatsCount += 1
        state.lastDrumId = drumId
        Self.logger.info("tap \(drumId.rawValue, privacy: .public) total=\(self.state.beatsCount)")
    }

    func reset() {
        state.beatsCount = 0
        state.lastDrumId = nil
    }
}
