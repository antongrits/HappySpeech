import Foundation
import OSLog

// MARK: - ParentInspirationBoardInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class ParentInspirationBoardInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentInspirationBoard"
    )

    var state: ParentInspirationBoardModels.ViewState

    init() {
        self.state = .initial
    }

    func next() {
        state.currentIndex = (state.currentIndex + 1) % state.quotes.count
        Self.logger.info("next → index=\(self.state.currentIndex)")
    }

    func previous() {
        state.currentIndex = (state.currentIndex - 1 + state.quotes.count) % state.quotes.count
        Self.logger.info("previous → index=\(self.state.currentIndex)")
    }

    func toggleFavorite() {
        guard let current = state.current,
              let idx = state.quotes.firstIndex(where: { $0.id == current.id })
        else { return }
        state.quotes[idx].isFavorite.toggle()
        Self.logger.info("toggleFavorite → \(self.state.quotes[idx].isFavorite)")
    }
}
