import Foundation

// MARK: - SpeechNormsEncyclopediaRoutingLogic

@MainActor
protocol SpeechNormsEncyclopediaRoutingLogic: AnyObject {
    func dismiss()
}

// MARK: - SpeechNormsEncyclopediaRouter (Clean Swift: Router)
//
// v31 Волна A, Функция Ф10 «Что должно быть в возрасте».
//
// Внешней навигации не требуется — карточки разворачиваются inline в списке.

@MainActor
final class SpeechNormsEncyclopediaRouter: SpeechNormsEncyclopediaRoutingLogic {

    var dismissAction: (() -> Void)?

    init(dismissAction: (() -> Void)? = nil) {
        self.dismissAction = dismissAction
    }

    func dismiss() {
        dismissAction?()
    }
}
