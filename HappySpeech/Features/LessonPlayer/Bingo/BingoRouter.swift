import Foundation

// MARK: - BingoRoutingLogic
//
// Bingo живёт внутри `SessionShellView`, поэтому собственный AppCoordinator
// ему не нужен. Маршрутизация ограничивается одним сценарием — выходом
// из игры с прокидыванием финального score родителю через `onDismiss`.

@MainActor
protocol BingoRoutingLogic: AnyObject {
    func routeBack()
}

// MARK: - BingoRouter

@MainActor
final class BingoRouter: BingoRoutingLogic {

    /// Замыкание, которое вызывается, когда игра завершена и пользователь
    /// нажал «Завершить». `BingoView` подключает к нему вызов `onComplete`
    /// (контракт с родительским `SessionShellView`).
    var onDismiss: (() -> Void)?

    func routeBack() {
        onDismiss?()
    }
}
