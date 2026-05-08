import Foundation

// MARK: - NeurolinguistInsights Namespace
//
// VIP модели для NeurolinguistInsightsScreen (T.4 v17 / Block T).
// Аналитический summary прогресса ребёнка.
//
// В v1.0 — rule-based template (НЕ настоящий MLX LLM inference),
// генерируется из последних N сессий ребёнка. Кешируется на 24 часа.

enum NeurolinguistInsights {

    // MARK: - Requests

    struct LoadRequest: Equatable {
        let childId: String
        /// Если true — игнорирует кэш и форсит регенерацию.
        let forceRefresh: Bool
    }

    struct RefreshRequest: Equatable {
        let childId: String
    }

    // MARK: - Responses

    struct LoadResponse {
        let insight: InsightData
        let metricsSnapshot: MetricsSnapshot
    }

    /// Численные метрики за анализируемый период (7 дней по умолчанию).
    struct MetricsSnapshot: Sendable {
        let sessionsCount: Int
        let totalAttempts: Int
        let averageAccuracy: Double      // 0.0–1.0
        let bestSound: String?           // звук с наибольшим прогрессом
        let challengingSound: String?    // звук с худшим показателем
        let totalMinutes: Int
        let consecutiveDays: Int         // активных дней подряд
        let trend: TrendKind             // overall trend
    }

    enum TrendKind: String, Sendable {
        case improving
        case stable
        case declining
        case insufficientData
    }

    // MARK: - ViewModel

    /// Структурированная карточка summary для UI.
    struct InsightCard: Equatable {
        let title: String                // «Прогресс за неделю»
        let summaryMarkdown: String      // основной текст (markdown)
        let trendBadge: String           // «улучшается», «стабильно» и т.д.
        let trendColorToken: String      // "success" | "warning" | "neutral"
        let recommendation: String
        let primaryFocus: String         // "Р" — основной звук
        let generatedAtText: String      // "Сегодня в 14:30"
    }

    /// Метрика-чип для строки KPI.
    struct MetricChip: Identifiable, Equatable {
        var id: String { label }
        let label: String
        let value: String
        let icon: String
        let colorToken: String
    }

    enum ScreenState: Equatable {
        case loading
        case empty
        case ready
        case error(String)
    }

    // MARK: - Cache TTL

    /// Кэш inline-сгенерированного summary живёт 24 часа.
    static let cacheTTLSeconds: TimeInterval = 24 * 3600
}
