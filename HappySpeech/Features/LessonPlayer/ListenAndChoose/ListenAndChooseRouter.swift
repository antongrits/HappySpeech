import SwiftUI

// MARK: - ListenAndChooseRoutingLogic

@MainActor
protocol ListenAndChooseRoutingLogic: AnyObject {
    func finishRound(score: Float)
}

// MARK: - ListenAndChooseRouter

/// The Listen-and-Choose screen does not own navigation — it reports completion
/// via a closure owned by the parent `SessionShell`. Router is kept for VIP parity
/// and future extensibility.
@MainActor
final class ListenAndChooseRouter: ListenAndChooseRoutingLogic {

    var onFinish: ((Float) -> Void)?

    func finishRound(score: Float) {
        onFinish?(score)
    }
}
