import Foundation

// MARK: - PacingModels
//
// VIP envelope-типы для упражнения «Темп речи» (фразовый пейсинг).
//
// Методическая основа (Fluency Shaping, ТЗ модуля заикания):
// Пейсинг — тренировка плавной связной речи в заданном замедленном темпе
// на уровне ФРАЗЫ. В отличие от метронома (отдельные слова по слогам под
// звуковой тик), пейсинг работает с предложением целиком и использует
// ВИЗУАЛЬНЫЙ ориентир — бегунок, который равномерно проходит по слогам.
// Ребёнок ведёт речь за бегунком, тренируя темповый самоконтроль и
// слитные межсловные переходы — мост между «Метрономом» (слова) и
// «Дневником речи» (свободный текст) в иерархии слог → слово → фраза.

enum PacingModels {

    // MARK: - StartSession

    enum StartSession {
        struct Request {
            var difficulty: StutteringDifficulty = .easy
        }
        struct Response {
            var phrase: PacingPhrase
            var roundIndex: Int
            var totalRounds: Int
            var beatIntervalSec: TimeInterval
        }
        struct ViewModel {
            var syllables: [PacingSyllableViewModel]
            var phraseText: String
            var progressLabel: String
            var beatIntervalSec: TimeInterval
        }
    }

    // MARK: - AdvanceBeat

    enum AdvanceBeat {
        struct Response {
            var activeSyllableIndex: Int
            var totalSyllables: Int
        }
        struct ViewModel {
            var activeSyllableIndex: Int
            var sliderProgress: Double          // 0.0–1.0
            var progressLabel: String
        }
    }

    // MARK: - PhraseComplete

    enum PhraseComplete {
        struct Response {
            var roundIndex: Int
            var totalRounds: Int
            var isSessionComplete: Bool
        }
        struct ViewModel {
            var showRoundReward: Bool
            var isSessionComplete: Bool
            var summaryText: String
        }
    }
}

// MARK: - PacingPhrase

/// Фраза для упражнения пейсинга: текст разбит на слоги для подсветки.
struct PacingPhrase: Sendable, Identifiable {
    let id: Int
    /// Слова фразы — для отображения и группировки слогов.
    let words: [PacingWord]

    /// Полный текст фразы (для VoiceOver и заголовка).
    var plainText: String {
        words.map(\.text).joined(separator: " ")
    }

    /// Плоский список всех слогов фразы по порядку.
    var allSyllables: [String] {
        words.flatMap(\.syllables)
    }
}

// MARK: - PacingWord

/// Слово фразы с послоговой разбивкой.
struct PacingWord: Sendable, Identifiable {
    let id: Int
    let text: String
    let syllables: [String]
}

// MARK: - PacingSyllableViewModel

struct PacingSyllableViewModel: Identifiable, Sendable {
    var id: Int { index }
    var index: Int
    var text: String
    /// Индекс слова, к которому относится слог — для отрисовки пробелов между словами.
    var wordIndex: Int
    /// true — слог последний в своём слове (после него ставится пробел).
    var isWordEnd: Bool
    var state: PacingSyllableState
    var accessibilityLabel: String
}

enum PacingSyllableState: Sendable, Equatable {
    case waiting
    case active
    case spoken
}
