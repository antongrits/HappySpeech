import Foundation
import SwiftUI

// MARK: - SoundDictionaryRoutingLogic

@MainActor
protocol SoundDictionaryRoutingLogic: AnyObject {
    func dismiss()
    func routeToPractice(phonemeId: String)
}

// MARK: - SoundDictionaryRouter (Clean Swift: Router)
//
// Block AE v21 — навигация. Phoneme detail отображается как `sheet` внутри
// текущего экрана; уход на тренировку — через external callback (как правило
// в parent home / settings показывается информационно, без запуска тренажёра).

@MainActor
final class SoundDictionaryRouter: SoundDictionaryRoutingLogic {

    var dismissAction: (() -> Void)?
    var practiceAction: ((String) -> Void)?

    init(
        dismissAction: (() -> Void)? = nil,
        practiceAction: ((String) -> Void)? = nil
    ) {
        self.dismissAction = dismissAction
        self.practiceAction = practiceAction
    }

    func dismiss() {
        dismissAction?()
    }

    func routeToPractice(phonemeId: String) {
        practiceAction?(phonemeId)
    }
}
