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

    /// Bundled-каталог. Не использует сетевые ресурсы — всё on-device.
    public static let catalog: [CulturalItem] = [
        // Сказки
        .init(
            id: "tale.repka",
            category: .fairyTale,
            titleKey: "cultural.tale.repka.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 180,
            targetSounds: ["Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 5,
                             text: "Посадил дед репку."),
                CulturalLine(id: 1, startSeconds: 5, endSeconds: 12,
                             text: "Выросла репка большая-пребольшая."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Стал дед репку из земли тащить."),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Тянет-потянет, вытянуть не может.")
            ],
            symbolName: "leaf.fill"
        ),
        .init(
            id: "tale.kolobok",
            category: .fairyTale,
            titleKey: "cultural.tale.kolobok.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 240,
            targetSounds: ["К", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 6,
                             text: "Жили-были старик со старухой."),
                CulturalLine(id: 1, startSeconds: 6, endSeconds: 12,
                             text: "Испекла старуха колобок."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Покатился колобок по дорожке."),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Я колобок, колобок, я от бабушки ушёл!")
            ],
            symbolName: "circle.fill"
        ),
        // Песни
        .init(
            id: "song.elka",
            category: .song,
            titleKey: "cultural.song.elka.title",
            authorKey: "cultural.song.elka.author",
            durationSeconds: 90,
            targetSounds: ["Л", "С"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 6,
                             text: "В лесу родилась ёлочка,"),
                CulturalLine(id: 1, startSeconds: 6, endSeconds: 12,
                             text: "В лесу она росла."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Зимой и летом стройная,"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Зелёная была.")
            ],
            symbolName: "tree.fill"
        ),
        // Стихи
        .init(
            id: "poem.barto.bear",
            category: .poem,
            titleKey: "cultural.poem.barto.bear.title",
            authorKey: "cultural.poem.barto.author",
            durationSeconds: 30,
            targetSounds: ["Ш", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 4,
                             text: "Уронили мишку на пол,"),
                CulturalLine(id: 1, startSeconds: 4, endSeconds: 8,
                             text: "Оторвали мишке лапу."),
                CulturalLine(id: 2, startSeconds: 8, endSeconds: 12,
                             text: "Всё равно его не брошу,"),
                CulturalLine(id: 3, startSeconds: 12, endSeconds: 16,
                             text: "Потому что он хороший.")
            ],
            symbolName: "quote.opening"
        ),
        .init(
            id: "poem.chuk.muha",
            category: .poem,
            titleKey: "cultural.poem.chuk.muha.title",
            authorKey: "cultural.poem.chuk.author",
            durationSeconds: 60,
            targetSounds: ["Х", "Ц"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 4,
                             text: "Муха, муха, цокотуха,"),
                CulturalLine(id: 1, startSeconds: 4, endSeconds: 8,
                             text: "Позолоченное брюхо."),
                CulturalLine(id: 2, startSeconds: 8, endSeconds: 12,
                             text: "Муха по полю пошла,"),
                CulturalLine(id: 3, startSeconds: 12, endSeconds: 16,
                             text: "Муха денежку нашла.")
            ],
            symbolName: "ant.fill"
        ),
        // Скороговорки
        .init(
            id: "twist.shasha",
            category: .tongueTwister,
            titleKey: "cultural.twist.shasha.title",
            authorKey: nil,
            durationSeconds: 12,
            targetSounds: ["Ш", "С"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 6,
                             text: "Шла Саша по шоссе и сосала сушку.")
            ],
            symbolName: "tongue"
        ),
        .init(
            id: "twist.bobry",
            category: .tongueTwister,
            titleKey: "cultural.twist.bobry.title",
            authorKey: nil,
            durationSeconds: 10,
            targetSounds: ["Б", "Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 6,
                             text: "Бобры идут в боры, бобры добры.")
            ],
            symbolName: "leaf.fill"
        )
    ]

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

        struct ViewModel: Sendable {
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
