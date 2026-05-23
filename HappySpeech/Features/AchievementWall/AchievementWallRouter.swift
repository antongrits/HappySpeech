import UIKit

// MARK: - AchievementWallRouter

/// Router отвечает за share-sheet с UIImage стены + текст.
/// Snapshot стены делает сама View через ImageRenderer и передаёт сюда.
@MainActor
final class AchievementWallRouter {

    weak var coordinator: AppCoordinator?

    func dismiss() {
        coordinator?.pop()
    }

    /// Share-sheet с массивом activity items: текст + опционально UIImage снимка стены.
    func presentShareSheet(text: String, snapshot: UIImage?) {
        guard let top = UIApplication.topViewController() else { return }
        var items: [Any] = [text]
        if let snapshot {
            items.append(snapshot)
        }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
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
