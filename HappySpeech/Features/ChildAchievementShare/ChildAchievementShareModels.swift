import Foundation

// MARK: - ChildAchievementShareModels

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
enum ChildAchievementShareModels {

    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        let emoji: String
    }

    static let seed: [Item] = [
        .init(id: "first-session", title: "Первый шаг",
              subtitle: "Завершил первую сессию", emoji: "🌱"),
        .init(id: "week-streak", title: "Неделя подряд",
              subtitle: "Серия 7 дней", emoji: "🔥"),
        .init(id: "sound-s-master", title: "Мастер «С»",
              subtitle: "Точность 90% на «С»", emoji: "🌟"),
        .init(id: "sound-r-progress", title: "Подружились с «Р»",
              subtitle: "20 повторений", emoji: "🎯"),
        .init(id: "ar-explorer", title: "AR-исследователь",
              subtitle: "Прошёл 5 AR-упражнений", emoji: "🛰️"),
        .init(id: "story-creator", title: "Маленький рассказчик",
              subtitle: "Записал 3 истории", emoji: "📖")
    ]

    static func shareText(item: Item, childName: String) -> String {
        "\(childName) получил(а) достижение «\(item.title)» в HappySpeech — \(item.subtitle)! \(item.emoji)"
    }
}
