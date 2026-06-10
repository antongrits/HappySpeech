import Foundation

// MARK: - CulturalContentModels (Clean Swift: Models)
//
// Block R.5 v18 — Cultural Content Screen.
//
// Сущности фичи:
//   • CulturalItem — сказка / песня / стихотворение / скороговорка
//   • CulturalCategory — четыре категории контента
//   • CulturalLine — строка караоке-транскрипта (start/end + text)
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: bookmarks/favorites через UserDefaults (per-child).
// COPPA: контент on-device (bundled), audio через AVFoundation.
// Локализация: ru-only, источник — методолог-логопед.

// MARK: - CulturalCategory

/// Категория русского культурного контента.
public enum CulturalCategory: String, Sendable, CaseIterable, Identifiable {
    case fairyTale     // Народные сказки
    case song          // Детские песни
    case poem          // Стихи (Барто, Чуковский, Маршак)
    case tongueTwister // Скороговорки

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .fairyTale:     return "books.vertical.fill"
        case .song:          return "music.note"
        case .poem:          return "quote.opening"
        case .tongueTwister: return "tongue"
        }
    }

    public var titleKey: String {
        switch self {
        case .fairyTale:     return "cultural.category.fairyTale.title"
        case .song:          return "cultural.category.song.title"
        case .poem:          return "cultural.category.poem.title"
        case .tongueTwister: return "cultural.category.tongueTwister.title"
        }
    }
}

// MARK: - CulturalLine

/// Строка караоке-транскрипта.
public struct CulturalLine: Identifiable, Sendable, Hashable {
    public let id: Int
    public let startSeconds: Double
    public let endSeconds: Double
    public let text: String
}

// MARK: - CulturalItem

/// Один элемент культурного контента (сказка, песня и т.д.).
public struct CulturalItem: Identifiable, Sendable, Hashable {

    public let id: String
    public let category: CulturalCategory
    public let titleKey: String
    public let authorKey: String?
    public let durationSeconds: Double
    public let targetSounds: [String]      // звуки для тренировки (С, З...)
    public let lines: [CulturalLine]
    public let symbolName: String

    // Каталог данных определён в CulturalContentData.swift (extension CulturalItem).

    public static func find(id: String) -> CulturalItem? {
        catalog.first { $0.id == id }
    }

    public static func items(for category: CulturalCategory) -> [CulturalItem] {
        catalog.filter { $0.category == category }
    }
}

// MARK: - CulturalContentModels namespace

enum CulturalContentModels {

    // MARK: Load

    enum Load {

        struct Request: Sendable {
            let childId: String
            let category: CulturalCategory?
        }

        struct Response: Sendable {
            let activeCategory: CulturalCategory?
            let items: [CulturalItem]
            let bookmarkedItemIDs: Set<String>
        }

        struct ViewModel: Sendable {
            let categories: [CategoryRow]
            let activeCategoryId: String?
            let items: [ItemRow]
            let totalLabel: String
            let emptyHint: String?
        }

        struct CategoryRow: Identifiable, Sendable {
            let id: String
            let title: String
            let symbolName: String
            let isActive: Bool
            let count: Int
            let accessibilityLabel: String
        }

        struct ItemRow: Identifiable, Sendable {
            let id: String
            let title: String
            let author: String?
            let categoryTitle: String
            let symbolName: String
            let durationLabel: String
            let targetSoundsText: String
            let isBookmarked: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: Open

    enum Open {

        struct Request: Sendable {
            let itemId: String
        }

        struct Response: Sendable {
            let item: CulturalItem
            let isBookmarked: Bool
        }

        struct ViewModel: Sendable, Identifiable {
            var id: String { title }
            let title: String
            let author: String?
            let lines: [LineViewModel]
            let durationLabel: String
            let targetSoundsText: String
            let isBookmarked: Bool
        }

        struct LineViewModel: Identifiable, Sendable {
            let id: Int
            let text: String
            let startSeconds: Double
            let endSeconds: Double
        }
    }

    // MARK: ToggleBookmark

    enum ToggleBookmark {

        struct Request: Sendable {
            let childId: String
            let itemId: String
        }

        struct Response: Sendable {
            let itemId: String
            let isBookmarked: Bool
        }

        struct ViewModel: Sendable {
            let toastMessage: String
            let bookmarkedItemIDs: Set<String>
        }
    }
}
