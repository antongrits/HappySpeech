import Foundation

// MARK: - DialectAdaptationModels (Clean Swift: Models)
//
// Block R.1 v18 — Dialect Adaptation Screen.
//
// Сущности фичи:
//   • RegionalDialect — пять русских диалектов с фонетическими маркерами
//   • DialectProfile — выбранный диалект + дата применения
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: UserDefaults (под префиксом "happyspeech.dialect.").
// COPPA: всё on-device, никакой сетевой синхронизации.

// MARK: - RegionalDialect

/// Русский диалект — region + key phonetic markers.
/// Используется PronunciationScorer для адаптации acoustic model
/// под региональные особенности произношения.
public struct RegionalDialect: Identifiable, Hashable, Sendable {

    public let id: String
    public let titleKey: String
    public let descriptionKey: String
    public let symbolName: String
    public let phoneticMarkers: [String]   // короткие подсказки

    /// Все доступные диалекты — фиксированный набор для v1.0.
    public static let all: [RegionalDialect] = [
        .init(
            id: "moscow",
            titleKey: "dialect.moscow.title",
            descriptionKey: "dialect.moscow.description",
            symbolName: "building.columns",
            phoneticMarkers: ["aканье", "редукция безударных", "мягкое «г»"]
        ),
        .init(
            id: "petersburg",
            titleKey: "dialect.petersburg.title",
            descriptionKey: "dialect.petersburg.description",
            symbolName: "ferry",
            phoneticMarkers: ["чёткие гласные", "«что» а не «што»", "твёрдое «ж»"]
        ),
        .init(
            id: "south",
            titleKey: "dialect.south.title",
            descriptionKey: "dialect.south.description",
            symbolName: "sun.max",
            phoneticMarkers: ["фрикативное «г»", "оканье", "мягкое «т»"]
        ),
        .init(
            id: "ural",
            titleKey: "dialect.ural.title",
            descriptionKey: "dialect.ural.description",
            symbolName: "mountain.2",
            phoneticMarkers: ["твёрдое произношение", "оканье", "акцент на согласных"]
        ),
        .init(
            id: "central",
            titleKey: "dialect.central.title",
            descriptionKey: "dialect.central.description",
            symbolName: "map",
            phoneticMarkers: ["литературная норма", "ровная интонация", "стандарт"]
        )
    ]

    /// Дефолтный — central (литературная норма) для новых пользователей.
    public static let `default`: RegionalDialect = all[4]

    /// Поиск диалекта по идентификатору.
    public static func find(id: String) -> RegionalDialect? {
        all.first { $0.id == id }
    }
}

// MARK: - DialectProfile

/// Профиль выбора диалекта на устройстве.
public struct DialectProfile: Sendable, Equatable {
    public let dialectId: String
    public let appliedAt: Date?
}

// MARK: - DialectAdaptationModels namespace

enum DialectAdaptationModels {

    // MARK: Load

    enum Load {

        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let currentDialect: RegionalDialect
            let availableDialects: [RegionalDialect]
            let appliedAt: Date?
        }

        struct ViewModel: Sendable {
            let currentDialectId: String
            let currentDialectTitle: String
            let appliedAtText: String?
            let dialects: [DialectRow]
        }

        struct DialectRow: Identifiable, Sendable {
            let id: String
            let title: String
            let description: String
            let symbolName: String
            let markers: [String]
            let isSelected: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: Select

    enum Select {

        struct Request: Sendable {
            let childId: String
            let dialectId: String
            let now: Date
        }

        struct Response: Sendable {
            let success: Bool
            let appliedDialect: RegionalDialect
            let appliedAt: Date
        }

        struct ViewModel: Sendable {
            let toastMessage: String
            let dialectTitle: String
            let success: Bool
        }
    }

    // MARK: Reset

    enum Reset {

        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let restored: RegionalDialect
        }

        struct ViewModel: Sendable {
            let toastMessage: String
        }
    }
}
