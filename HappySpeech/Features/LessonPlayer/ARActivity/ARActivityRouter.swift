import SwiftUI
import UIKit

// MARK: - ARActivityRoutingLogic

@MainActor
protocol ARActivityRoutingLogic: AnyObject {
    func routeToARMirror()
    func routeToARStoryQuest()
    func routeToButterflyCatch()
    func routeToBreathingAR()
    func routeToMimicLyalya()
    func routeToHoldThePose()
    func routeToPoseSequence()
    func routeToSoundAndFace()
    func routeToSystemSettings()
    func dismiss()
}

// MARK: - ARActivityRouter
//
// AR-игры открываются как `fullScreenCover` поверх SessionShell.
// Router хранит коллбеки для каждой из 7 игр; View-слой привязывает их к
// собственным `@State` флагам `show<Game>`. Игры без отдельного VIP-модуля
// направляются к ближайшему существующему экрану (ARMirror/ARStoryQuest).
@MainActor
final class ARActivityRouter: ARActivityRoutingLogic {

    // MARK: - Callbacks

    var onRouteToMirror:         (() -> Void)?
    var onRouteToStoryQuest:     (() -> Void)?
    var onRouteToButterflyCatch: (() -> Void)?
    var onRouteToBreathingAR:    (() -> Void)?
    var onRouteToMimicLyalya:    (() -> Void)?
    var onRouteToHoldThePose:    (() -> Void)?
    var onRouteToPoseSequence:   (() -> Void)?
    var onRouteToSoundAndFace:   (() -> Void)?
    var onDismiss:               (() -> Void)?
    var onCompleted:             ((Float, Int) -> Void)?

    // MARK: - ARActivityRoutingLogic

    func routeToARMirror() { onRouteToMirror?() }

    func routeToARStoryQuest() { onRouteToStoryQuest?() }

    func routeToButterflyCatch() {
        // Пока отдельный VIP не реализован — fallback к ARStoryQuest
        onRouteToButterflyCatch?() ?? onRouteToStoryQuest?()
    }

    func routeToBreathingAR() {
        onRouteToBreathingAR?() ?? onRouteToStoryQuest?()
    }

    func routeToMimicLyalya() {
        onRouteToMimicLyalya?() ?? onRouteToMirror?()
    }

    func routeToHoldThePose() {
        onRouteToHoldThePose?() ?? onRouteToMirror?()
    }

    func routeToPoseSequence() {
        onRouteToPoseSequence?() ?? onRouteToMirror?()
    }

    func routeToSoundAndFace() {
        onRouteToSoundAndFace?() ?? onRouteToMirror?()
    }

    func routeToSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }

    func dismiss() { onDismiss?() }
}
