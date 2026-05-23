import SwiftUI

// MARK: - VoiceJournalRouter

/// VIP-Router. Дневник голоса — листовый экран, основное действие — закрыть.
@MainActor
final class VoiceJournalRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }
}
