import SwiftUI

// MARK: - PuzzleRevealRoutingLogic

@MainActor
protocol PuzzleRevealRoutingLogic: AnyObject {
    func routeBack()
}

// MARK: - PuzzleRevealRouter
//
// Минимальный router — View сам решает, когда вызвать `onComplete(score)`;
// router нужен как запасной канал dismiss, совместимый с остальной VIP-машинерией.

@MainActor
final class PuzzleRevealRouter: PuzzleRevealRoutingLogic {

    var onDismiss: (() -> Void)?

    func routeBack() {
        onDismiss?()
    }
}
