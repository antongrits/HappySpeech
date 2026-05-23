import Foundation
import OSLog

// MARK: - SentenceBuilderKidInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class SentenceBuilderKidInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SentenceBuilderKid"
    )

    let childId: String
    var state: SentenceBuilderKidModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func pickFromAvailable(_ chipId: UUID) {
        guard let idx = state.available.firstIndex(where: { $0.id == chipId }) else { return }
        let chip = state.available.remove(at: idx)
        state.assembled.append(chip)
        Self.logger.info("pick \(chip.text, privacy: .public)")
    }

    func removeFromAssembled(_ chipId: UUID) {
        guard let idx = state.assembled.firstIndex(where: { $0.id == chipId }) else { return }
        let chip = state.assembled.remove(at: idx)
        state.available.append(chip)
        Self.logger.info("remove \(chip.text, privacy: .public)")
    }

    func reset() {
        state = .initial
    }
}
