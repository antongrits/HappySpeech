import Foundation

// MARK: - SoundHunterRoutingLogic

@MainActor
protocol SoundHunterRoutingLogic: AnyObject {
    func routeBack()
}

// MARK: - SoundHunterRouter
//
// SoundHunter встраивается внутрь `SessionShell` и не имеет собственной навигации —
// по завершении игры View вызывает `onComplete(score:)`, родитель сам решает,
// куда идти дальше. Роутер используется лишь для сценария «закрыть досрочно».

@MainActor
final class SoundHunterRouter: SoundHunterRoutingLogic {

    var onDismiss: (() -> Void)?

    func routeBack() {
        onDismiss?()
    }
}
