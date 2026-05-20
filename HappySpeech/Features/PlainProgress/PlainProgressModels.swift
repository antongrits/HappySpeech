import Foundation

// MARK: - PlainProgressModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 9 «Понятный прогресс».
//
// Родительская аналитика с человеческими выводами: вместо сухих метрик —
// еженедельный нарратив («За неделю Миша лучше произносит Р в начале слова»),
// «вехи» прогресса и сравнение «месяц назад / сейчас».
//
// Этические границы (project guide §11): только педагогические формулировки,
// без диагнозов и гарантий. Тексты собираются из размеченных шаблонов
// (`PlainProgressTemplates`) подстановкой реальных метрик — без выдумок.

// MARK: - PlainProgressDirection

/// Направление изменения метрики за период.
public enum PlainProgressDirection: String, Sendable, Equatable {
    case improved   // заметный рост
    case steady     // стабильно
    case declined   // снижение (мягкая формулировка «нужно поддержать»)
    case noData     // данных недостаточно

    public var symbolName: String {
        switch self {
        case .improved: return "arrow.up.right.circle.fill"
        case .steady:   return "equal.circle.fill"
        case .declined: return "arrow.down.right.circle.fill"
        case .noData:   return "questionmark.circle.fill"
        }
    }
}

// MARK: - ProgressMilestone

/// Понятная «веха» — достижение, описанное обычным языком.
public struct ProgressMilestone: Identifiable, Sendable, Equatable {
    public let id: String
    public let titleKey: String
    public let symbolName: String
    public let reached: Bool

    public init(id: String, titleKey: String, symbolName: String, reached: Bool) {
        self.id = id
        self.titleKey = titleKey
        self.symbolName = symbolName
        self.reached = reached
    }
}

// MARK: - PlainProgressModels namespace

enum PlainProgressModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
        }

        /// Агрегированные за период метрики — основа для нарратива.
        struct Response: Sendable {
            let childName: String
            let childAge: Int
            /// Точность за последнюю неделю (0...1).
            let weekSuccessRate: Double
            /// Точность за предыдущую неделю (0...1) — для сравнения.
            let previousWeekSuccessRate: Double
            /// Точность за месяц назад (0...1) — для блока «месяц назад / сейчас».
            let monthAgoSuccessRate: Double
            let sessionsThisWeek: Int
            let practiceMinutesThisWeek: Int
            /// Звук, по которому больше всего практики на неделе.
            let focusSound: String
            /// Точность по focusSound за неделю (0...1).
            let focusSoundRate: Double
            /// Целевые звуки ребёнка.
            let targetSounds: [String]
            let currentStreak: Int
            let trend: PlainProgressDirection
            /// Есть ли вообще сессии за неделю.
            let hasWeekData: Bool
        }

        struct ViewModel: Sendable {
            let headerTitle: String
            let headerSubtitle: String
            /// Карточка-нарратив недели — основной блок.
            let narrative: NarrativeViewModel
            /// «Месяц назад / сейчас».
            let comparison: ComparisonViewModel?
            let milestones: [MilestoneViewModel]
            let recommendationTitle: String
            let recommendationText: String
            let shareButtonTitle: String
            let emptyStateText: String?
        }

        struct NarrativeViewModel: Sendable {
            let title: String
            /// 2–3 предложения связного текста.
            let body: String
            let trendSymbol: String
            let trendTint: TrendTint
            let metricsLine: String
        }

        struct ComparisonViewModel: Sendable, Identifiable {
            let id = "comparison"
            let title: String
            let monthAgoLabel: String
            let monthAgoValue: String
            let nowLabel: String
            let nowValue: String
            let deltaText: String
            let monthAgoFraction: Double
            let nowFraction: Double
        }

        struct MilestoneViewModel: Identifiable, Sendable {
            let id: String
            let title: String
            let symbolName: String
            let reached: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: Share

    enum Share {
        struct Request: Sendable {}

        struct Response: Sendable {
            let summaryText: String
        }

        struct ViewModel: Sendable {
            let summaryText: String
        }
    }
}

// MARK: - TrendTint

/// Семантический цвет тренда — конкретный `Color` выбирает View из токенов.
enum TrendTint: Sendable, Equatable {
    case positive
    case neutral
    case attention
}
