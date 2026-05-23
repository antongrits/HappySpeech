import Foundation
import OSLog

// MARK: - ChildAchievementShareInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class ChildAchievementShareInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ChildAchievementShare"
    )

    var items: [ChildAchievementShareModels.Item] = ChildAchievementShareModels.seed
    var selectedId: String?
    var childName: String = "Малыш"

    var selected: ChildAchievementShareModels.Item? {
        guard let selectedId else { return nil }
        return items.first { $0.id == selectedId }
    }

    func select(_ id: String) {
        selectedId = id
        Self.logger.info("Selected achievement: \(id, privacy: .public)")
    }

    func makeShareText() -> String? {
        guard let s = selected else { return nil }
        return ChildAchievementShareModels.shareText(item: s, childName: childName)
    }
}
