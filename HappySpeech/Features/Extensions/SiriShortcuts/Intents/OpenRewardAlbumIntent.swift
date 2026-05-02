import AppIntents
import Foundation
import OSLog

// MARK: - RewardCategory (AppEnum)

/// Категории наград в альбоме Ляли.
@available(iOS 17.0, *)
public enum RewardCategory: String, AppEnum {
    case all
    case stickers
    case badges
    case streaks
    case soundPacks

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Категория")
    )

    public static let caseDisplayRepresentations: [RewardCategory: DisplayRepresentation] = [
        .all:        DisplayRepresentation(title: "Все"),
        .stickers:   DisplayRepresentation(title: "Наклейки"),
        .badges:     DisplayRepresentation(title: "Значки"),
        .streaks:    DisplayRepresentation(title: "Серии"),
        .soundPacks: DisplayRepresentation(title: "Звуковые паки")
    ]
}

// MARK: - OpenRewardAlbumIntent

/// "Сири, открой альбом наград в ХэппиСпич"
/// Открывает Rewards экран с опциональной фильтрацией по категории.
@available(iOS 17.0, *)
public struct OpenRewardAlbumIntent: AppIntent {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "OpenRewardAlbumIntent")

    public static let title: LocalizedStringResource = "Открыть альбом наград"
    public static let description = IntentDescription(
        LocalizedStringResource("Альбом наклеек, значков и достижений Ляли"),
        categoryName: "Награды"
    )
    public static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: LocalizedStringResource("Категория"),
        description: LocalizedStringResource("Фильтр по категории наград"),
        default: .all
    )
    public var category: RewardCategory

    public init() {}

    public init(category: RewardCategory = .all) {
        self.category = category
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let stats = await loadRewardStats()

        await MainActor.run {
            DeepLinkRouter.shared.handleOpenRewardAlbum()
        }

        logger.info("OpenRewardAlbumIntent: category=\(category.rawValue)")

        let categoryLabel = categoryDisplayName(category)
        let cheer = cheerMessage(unlocked: stats.unlocked, total: stats.total)
        let text = "Открываю \(categoryLabel). У тебя \(stats.unlocked) из \(stats.total) наград. \(cheer)"
        let dialog = IntentDialog(stringLiteral: text)
        return .result(dialog: dialog)
    }

    // MARK: - Private

    private struct RewardStats {
        let unlocked: Int
        let total: Int
    }

    private func loadRewardStats() async -> RewardStats {
        let defaults = UserDefaults(suiteName: "group.com.mmf.bsu.shared")
        let unlocked = defaults?.integer(forKey: "rewards.unlocked_count") ?? 0
        let total    = defaults?.integer(forKey: "rewards.total_count") ?? 32
        return RewardStats(unlocked: max(unlocked, 0), total: max(total, 1))
    }

    private func categoryDisplayName(_ c: RewardCategory) -> String {
        switch c {
        case .all:        return "весь альбом"
        case .stickers:   return "наклейки"
        case .badges:     return "значки"
        case .streaks:    return "серии"
        case .soundPacks: return "звуковые паки"
        }
    }

    private func cheerMessage(unlocked: Int, total: Int) -> String {
        let percent = total > 0 ? (unlocked * 100) / total : 0
        switch percent {
        case 100:   return "Ты собрал всё! Невероятно!"
        case 75...: return "Совсем немного осталось!"
        case 50...: return "Больше половины! Молодец!"
        case 25...: return "Хорошее начало!"
        default:    return "Впереди много интересного!"
        }
    }
}
