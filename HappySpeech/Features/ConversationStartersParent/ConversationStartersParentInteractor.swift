import Foundation
import OSLog

// MARK: - ConversationStartersParentInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class ConversationStartersParentInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ConversationStartersParent"
    )

    var state: ConversationStartersParentModels.ViewState

    init() {
        self.state = .initial
    }

    func toggleFavorite(_ id: String) {
        guard let idx = state.questions.firstIndex(where: { $0.id == id }) else { return }
        state.questions[idx].isFavorite.toggle()
        Self.logger.info("toggleFavorite \(id, privacy: .public) → \(self.state.questions[idx].isFavorite)")
    }
}
