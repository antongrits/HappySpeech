import Foundation

// MARK: - SpeechTempoModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Работа над темпом и ритмом речи: ребёнок «ведёт машинку Ляли» по дорожке,
// проговаривая считалку/чистоговорку послогово. Машинка едет ровно при
// стабильном темпе. Без таймеров-соревнований — это запрещено для заикания
// ([[exercise-templates]]). Цель — нормализация темпа, ритмизация, слоговая
// структура слова (заикание, ЗРР, дизартрия, ОНР).
//
// VIP-модуль реализует ритмический «слогобой»: ребёнок отбивает слоги
// чистоговорки в ровном темпе; модуль измеряет равномерность межслоговых
// интервалов (коэффициент вариации). Контент — `SpeechTempoCorpus`.

// MARK: - TempoRhyme

/// Считалка / чистоговорка с разметкой слогового рисунка.
public struct TempoRhyme: Identifiable, Sendable, Equatable {
    public let id: String
    /// Текст для показа целиком.
    public let text: String
    /// Слоги по порядку — ребёнок отбивает каждый.
    public let syllables: [String]

    public init(id: String, text: String, syllables: [String]) {
        self.id = id
        self.text = text
        self.syllables = syllables
    }

    public var syllableCount: Int { syllables.count }
}

// MARK: - TempoRating

/// Качественная оценка ровности темпа — без числовых таймеров для ребёнка.
public enum TempoRating: String, Sendable {
    /// Темп ровный — машинка едет плавно.
    case smooth
    /// Темп немного неровный — машинка слегка подпрыгивает.
    case slightlyUneven
    /// Темп рваный — стоит попробовать ещё спокойнее.
    case uneven
}

// MARK: - SpeechTempoModels namespace

enum SpeechTempoModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let rhymes: [TempoRhyme]
        }

        struct ViewModel: Sendable {
            let title: String
            let instruction: String
            let totalRhymes: Int
            let firstRhyme: RhymeViewModel
        }

        struct RhymeViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let text: String
            let syllables: [String]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }
    }

    // MARK: Beat
    //
    // Один «удар» — отбитый слог. View передаёт момент времени удара.

    enum Beat {
        struct Request: Sendable {
            /// Абсолютное время удара (с момента старта попытки).
            let timestamp: TimeInterval
        }
    }

    // MARK: Finish
    //
    // Завершение проговаривания текущей чистоговорки.

    enum Finish {
        struct Request: Sendable {}

        struct Response: Sendable {
            let rating: TempoRating
            /// Коэффициент вариации межслоговых интервалов (0 — идеально ровно).
            let variationCoefficient: Double
            let beatsCounted: Int
            let expectedSyllables: Int
            let isFinished: Bool
            let nextRhyme: TempoRhyme?
            let nextRhymeIndex: Int?
            let smoothCount: Int
            let totalRhymes: Int
        }

        struct ViewModel: Sendable {
            let rating: TempoRating
            let ratingText: String
            let isFinished: Bool
            let nextRhyme: Start.RhymeViewModel?
            let summary: SummaryViewModel?
        }

        struct SummaryViewModel: Sendable {
            let title: String
            let scoreText: String
            let smoothCount: Int
            let totalRhymes: Int
            let encouragement: String
        }
    }
}
