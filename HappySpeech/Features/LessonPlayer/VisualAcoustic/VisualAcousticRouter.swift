import Foundation

// MARK: - VisualAcousticRoutingLogic
//
// VisualAcoustic живёт внутри `SessionShellView`, поэтому собственный
// AppCoordinator ему не нужен. Маршрутизация ограничивается одним сценарием —
// выходом из игры с прокидыванием финального score родителю через `onDismiss`.

@MainActor
protocol VisualAcousticRoutingLogic: AnyObject {
    func routeBack()
}

// MARK: - VisualAcousticRouter

@MainActor
final class VisualAcousticRouter: VisualAcousticRoutingLogic {

    /// Замыкание вызывается, когда игра завершена и пользователь нажал
    /// «Завершить». `VisualAcousticView` подключает к нему прокидывание
    /// `onComplete` в родительский `SessionShellView`.
    var onDismiss: (() -> Void)?

    func routeBack() {
        onDismiss?()
    }
}
