import Foundation
import OSLog

// MARK: - PhonemeFamilyMatcherInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class PhonemeFamilyMatcherInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemeFamilyMatcher"
    )

    let childId: String
    var state: PhonemeFamilyMatcherModels.ViewState

    init(childId: String) {
        self.childId = childId
        self.state = .initial
    }

    func assign(_ wordId: String, to family: PhonemeFamilyMatcherModels.Family) {
        guard let idx = state.words.firstIndex(where: { $0.id == wordId }) else { return }
        state.words[idx].assignedFamily = family
        Self.logger.info("assign \(wordId, privacy: .public) → \(family.rawValue, privacy: .public)")
    }

    func reset() {
        state = .initial
    }
}
