import UIKit

// MARK: - FamilyChallengeRouter

/// Минимальный router: dismiss + presenter-агностичное открытие share-sheet.
/// View сама держит `@State` для share-sheet — router'у достаточно вернуться.
@MainActor
final class FamilyChallengeRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }

    /// Открывает системный share-sheet с переданным текстом.
    /// Использует ``UIApplication/topViewController(base:)`` — единый для приложения
    /// helper, безопасно работающий с multi-scene и presented-controllers.
    func presentShareSheet(text: String) {
        guard let top = UIApplication.topViewController() else { return }
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        // iPad popover anchor.
        controller.popoverPresentationController?.sourceView = top.view
        controller.popoverPresentationController?.sourceRect = CGRect(
            x: top.view.bounds.midX,
            y: top.view.bounds.midY,
            width: 0,
            height: 0
        )
        controller.popoverPresentationController?.permittedArrowDirections = []
        top.present(controller, animated: true)
    }
}
