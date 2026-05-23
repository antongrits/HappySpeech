import Foundation
import OSLog

// MARK: - TongueTwisterArenaInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class TongueTwisterArenaInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "TongueTwisterArena"
    )

    let childId: String
    var state: TongueTwisterArenaModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func select(_ twister: TongueTwisterArenaModels.Twister) {
        state.selected = twister
        state.isRecording = false
        Self.logger.info("select twister \(twister.id, privacy: .public)")
    }

    func back() {
        state.selected = nil
        state.isRecording = false
    }

    func toggleRecord() {
        state.isRecording.toggle()
        Self.logger.info("toggleRecord → \(self.state.isRecording)")
    }
}
