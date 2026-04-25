import Foundation

// MARK: - Demo VIP Models
//
// 15-шаговый walkthrough приложения. Spotlight-overlay подсвечивает целевой
// блок, маскот Ляля даёт текстовую подсказку, прогресс «Шаг N из 15».
//
// На уровне моделей хранятся не только тексты, но и dataclass-описание
// каждого шага: какой emoji-постер показывать, какое состояние Ляли
// (idle / waving / explaining / celebrating и т.д.), какой акцентный цвет
// ColorToken'а использовать для градиента и кнопок, есть ли у шага
// интерактивный CTA («Попробовать!»).
//
// Слой View рендерит шаг как полноэкранный «слайд» с динамическим
// градиентом, иллюстрацией и Лялей. Слой Presenter — чистая трансформация
// Response → ViewModel без UIKit/SwiftUI зависимостей.

// MARK: - DemoAccentColor
//
// Семантический ключ цвета шага. Конкретный `Color` resolved во View через
// helper `DemoAccentColor.resolvedColor`. Это нужно, чтобы Models / Presenter
// оставались UIKit-free, а тестовый код не зависел от Asset Catalog.

public enum DemoAccentColor: String, Sendable, CaseIterable, Hashable {
    case primary
    case purple
    case orange
    case teal
    case green
    case sky
    case mint
    case lilac
    case butter
    case gold
    case rose
    case parent
    case spec

    /// Default accent for unknown values from older seed files.
    public static let fallback: DemoAccentColor = .primary

    /// Парсит legacy `highlightColor`-строку. Не выбрасывает исключений.
    public static func parse(_ raw: String) -> DemoAccentColor {
        DemoAccentColor(rawValue: raw) ?? .fallback
    }
}

// MARK: - DemoStep (DTO)

public struct DemoStep: Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    /// Подзаголовок: короткий тег под заголовком (например, «Знакомство»).
    public let subtitle: String
    public let description: String
    public let mascotText: String
    public let screenEmoji: String
    /// SF Symbol для крупной иллюстрации шага (опционально).
    /// Если пустой — используется `screenEmoji` как fallback.
    public let illustrationSymbol: String
    /// Семантический ключ цвета (legacy `highlightColor` хранится для совместимости).
    public let highlightColor: String
    /// Типизированный акцент для градиента и кнопок.
    public let accent: DemoAccentColor
    /// Состояние маскота на этом шаге.
    public let lyalyaState: LyalyaState
    /// Есть ли у шага интерактивный CTA («Попробовать!»).
    public let hasInteractive: Bool
    /// Заголовок интерактивной кнопки (если `hasInteractive == true`).
    public let actionTitle: String?

    public init(
        id: Int,
        title: String,
        subtitle: String = "",
        description: String,
        mascotText: String,
        screenEmoji: String,
        illustrationSymbol: String = "",
        highlightColor: String,
        accent: DemoAccentColor? = nil,
        lyalyaState: LyalyaState = .explaining,
        hasInteractive: Bool = false,
        actionTitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.mascotText = mascotText
        self.screenEmoji = screenEmoji
        self.illustrationSymbol = illustrationSymbol
        self.highlightColor = highlightColor
        self.accent = accent ?? DemoAccentColor.parse(highlightColor)
        self.lyalyaState = lyalyaState
        self.hasInteractive = hasInteractive
        self.actionTitle = actionTitle
    }
}

// MARK: - VIP scenes

// swiftlint:disable nesting
enum DemoModels {

    // MARK: - LoadDemo

    enum LoadDemo {
        struct Request: Sendable {}
        struct Response: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
        }
        struct ViewModel: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
            let totalSteps: Int
            let progress: Double
            let progressLabel: String
            let isFirst: Bool
            let isLast: Bool
            let backTitle: String
            let nextTitle: String
            let stepTitle: String
            let stepSubtitle: String
            let stepDescription: String
            let mascotText: String
            let screenEmoji: String
            let illustrationSymbol: String
            let accent: DemoAccentColor
            let lyalyaState: LyalyaState
            let hasInteractive: Bool
            let actionTitle: String?
        }
    }

    // MARK: - AdvanceStep

    enum AdvanceStep {
        struct Request: Sendable {}
        struct Response: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
            let isCompleted: Bool
        }
        struct ViewModel: Sendable {
            let currentIndex: Int
            let totalSteps: Int
            let progress: Double
            let progressLabel: String
            let isFirst: Bool
            let isLast: Bool
            let backTitle: String
            let nextTitle: String
            let stepTitle: String
            let stepSubtitle: String
            let stepDescription: String
            let mascotText: String
            let screenEmoji: String
            let illustrationSymbol: String
            let accent: DemoAccentColor
            let lyalyaState: LyalyaState
            let hasInteractive: Bool
            let actionTitle: String?
            let isCompleted: Bool
        }
    }

    // MARK: - GoBack

    enum GoBack {
        struct Request: Sendable {}
        struct Response: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
        }
        struct ViewModel: Sendable {
            let currentIndex: Int
            let progress: Double
            let progressLabel: String
            let isFirst: Bool
            let isLast: Bool
            let backTitle: String
            let nextTitle: String
            let stepTitle: String
            let stepSubtitle: String
            let stepDescription: String
            let mascotText: String
            let screenEmoji: String
            let illustrationSymbol: String
            let accent: DemoAccentColor
            let lyalyaState: LyalyaState
            let hasInteractive: Bool
            let actionTitle: String?
        }
    }

    // MARK: - JumpTo (свайп / прямой выбор индекса)

    enum JumpTo {
        struct Request: Sendable {
            let index: Int
        }
        struct Response: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
        }
        struct ViewModel: Sendable {
            let currentIndex: Int
            let progress: Double
            let progressLabel: String
            let isFirst: Bool
            let isLast: Bool
            let backTitle: String
            let nextTitle: String
            let stepTitle: String
            let stepSubtitle: String
            let stepDescription: String
            let mascotText: String
            let screenEmoji: String
            let illustrationSymbol: String
            let accent: DemoAccentColor
            let lyalyaState: LyalyaState
            let hasInteractive: Bool
            let actionTitle: String?
        }
    }

    // MARK: - InteractiveTap (нажатие «Попробовать!»)

    enum InteractiveTap {
        struct Request: Sendable {}
        struct Response: Sendable {
            let stepId: Int
            let stepTitle: String
        }
        struct ViewModel: Sendable {
            let stepId: Int
            let toastMessage: String
        }
    }

    // MARK: - Skip

    enum SkipDemo {
        struct Request: Sendable {}
        struct Response: Sendable {}
        struct ViewModel: Sendable {}
    }

    // MARK: - Complete

    enum CompleteDemo {
        struct Request: Sendable {}
        struct Response: Sendable {}
        struct ViewModel: Sendable {}
    }
}
// swiftlint:enable nesting
