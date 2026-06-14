import Foundation
import OSLog

// MARK: - ChildAchievementShareInteractor

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
@MainActor
@Observable
final class ChildAchievementShareInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ChildAchievementShare"
    )

    var items: [ChildAchievementShareModels.Item] = ChildAchievementShareModels.seed
    var selectedId: String?
    /// Имя ребёнка для текста шаринга. Заполняется из реального профиля
    /// (`ChildRepository`) в `loadChildName()`; до загрузки и при отсутствии
    /// активного профиля — нейтральный дефолт (не персональные данные).
    var childName: String = ChildAchievementShareModels.defaultChildName

    /// Источник id активного ребёнка (по умолчанию — единый `ActiveChildStore`).
    private let childId: String?
    private let childRepository: (any ChildRepository)?

    init(
        childId: String? = ActiveChildStore.shared.id,
        childRepository: (any ChildRepository)? = nil
    ) {
        self.childId = childId
        self.childRepository = childRepository
    }

    var selected: ChildAchievementShareModels.Item? {
        guard let selectedId else { return nil }
        return items.first { $0.id == selectedId }
    }

    /// Подтягивает реальное имя активного ребёнка. Без репозитория/childId —
    /// остаётся нейтральный дефолт (Preview/тесты). Никакой фабрикации.
    func loadChildName() async {
        guard let childRepository, let childId, !childId.isEmpty else { return }
        guard let profile = try? await childRepository.fetch(id: childId),
              !profile.name.isEmpty else { return }
        childName = profile.name
        Self.logger.info("Loaded child name for achievement share")
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
