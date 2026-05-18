import Foundation

// MARK: - SoundTrafficLightModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Расширенная слуховая дифференциация акустически близких пар звуков
// (С–Ш, З–Ж, Р–Л и др.) — финальный этап коррекции ([[correction-stages]]
// этап 14). Ребёнок сортирует слова в два «гаража» по целевому звуку.
//
// Этот VIP-модуль реализует слуховой уровень дифференциации (выбор гаража).
// Контент — `SoundTrafficLightCorpus` (8 пар, offline).

// MARK: - DifferentiationPair

/// Пара дифференцируемых звуков с набором слов.
public struct DifferentiationPair: Identifiable, Sendable, Equatable {
    public let id: String
    /// Первый звук пары (например «С»).
    public let soundA: String
    /// Второй звук пары (например «Ш»).
    public let soundB: String
    /// Слова, содержащие soundA.
    public let wordsA: [String]
    /// Слова, содержащие soundB.
    public let wordsB: [String]

    public init(
        id: String,
        soundA: String,
        soundB: String,
        wordsA: [String],
        wordsB: [String]
    ) {
        self.id = id
        self.soundA = soundA
        self.soundB = soundB
        self.wordsA = wordsA
        self.wordsB = wordsB
    }
}

// MARK: - TrafficLightRound

/// Один раунд: слово, которое нужно отсортировать, и правильный гараж.
public struct TrafficLightRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let word: String
    /// true — слово относится к soundA («левый гараж»).
    public let belongsToA: Bool

    public init(id: String, word: String, belongsToA: Bool) {
        self.id = id
        self.word = word
        self.belongsToA = belongsToA
    }
}

// MARK: - SoundTrafficLightModels namespace

enum SoundTrafficLightModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let pair: DifferentiationPair
            let rounds: [TrafficLightRound]
        }

        struct ViewModel: Sendable {
            let title: String
            let instruction: String
            let garageALabel: String
            let garageBLabel: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let word: String
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }
    }

    // MARK: Sort

    enum Sort {
        struct Request: Sendable {
            /// true — ребёнок выбрал «левый гараж» (soundA).
            let pickedGarageA: Bool
        }

        struct Response: Sendable {
            let wasCorrect: Bool
            let isFinished: Bool
            let nextRound: TrafficLightRound?
            /// Индекс следующего раунда (0-based); nil, если сессия завершена.
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let wasCorrect: Bool
            let feedbackText: String
            let isFinished: Bool
            let nextRound: Start.RoundViewModel?
            /// Заполняется только когда `isFinished == true`.
            let summary: SummaryViewModel?
        }

        struct SummaryViewModel: Sendable {
            let title: String
            let scoreText: String
            let correctCount: Int
            let totalRounds: Int
            let accuracyFraction: Double
            let encouragement: String
        }
    }
}
