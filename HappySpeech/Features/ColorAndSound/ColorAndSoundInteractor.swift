import Foundation
import OSLog

// MARK: - ColorAndSoundInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class ColorAndSoundInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ColorAndSound"
    )

    let childId: String
    var state: ColorAndSoundModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func toggle(_ id: String) {
        guard let idx = state.pairs.firstIndex(where: { $0.id == id }) else { return }
        state.pairs[idx].isMatched.toggle()
        state.selectedId = id
        Self.logger.info("toggle \(id, privacy: .public) → \(self.state.pairs[idx].isMatched)")
    }
}
