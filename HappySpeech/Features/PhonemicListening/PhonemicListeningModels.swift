import Foundation

// MARK: - PhonemicListeningModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 12 «Слушай внимательно».
//
// Фонематический анализ продвинутого уровня — высшие операции звукового
// анализа: позиция звука в слове, количество звуков, синтез слова из
// последовательно названных звуков. Прямая профилактика дисграфии/дислексии
// ([[speech-methodology]], Ткаченко, Каше; [[correction-stages]]).
//
// VIP-модуль реализует три операции; контент — `PhonemicListeningCorpus`
// (offline / on-device, без сети).

// MARK: - PhonemeOperation

/// Тип операции фонематического анализа в раунде.
public enum PhonemeOperation: String, Sendable, CaseIterable {
    /// Уровень 1: определить позицию звука в слове (начало / середина / конец).
    case position
    /// Уровень 2: посчитать количество звуков в слове.
    case count
    /// Уровень 3: синтез — собрать слово из последовательно названных звуков.
    case synthesis
}

// MARK: - PhonemePosition

/// Позиция звука в слове.
public enum PhonemePosition: String, Sendable, CaseIterable {
    case start
    case middle
    case end
}

// MARK: - PhonemicWord

/// Слово с полной звуковой разметкой для упражнений анализа.
public struct PhonemicWord: Identifiable, Sendable, Equatable {
    public let id: String
    /// Само слово (для отображения).
    public let text: String
    /// Целевой звук, с которым работает раунд (для операции `position`).
    public let targetSound: String
    /// Позиция целевого звука в слове.
    public let position: PhonemePosition
    /// Полная последовательность звуков слова (для `count` и `synthesis`).
    public let sounds: [String]

    public init(
        id: String,
        text: String,
        targetSound: String,
        position: PhonemePosition,
        sounds: [String]
    ) {
        self.id = id
        self.text = text
        self.targetSound = targetSound
        self.position = position
        self.sounds = sounds
    }

    /// Количество звуков в слове.
    public var soundCount: Int { sounds.count }
}

// MARK: - PhonemicRound

/// Один раунд упражнения.
public struct PhonemicRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let operation: PhonemeOperation
    public let word: PhonemicWord

    public init(id: String, operation: PhonemeOperation, word: PhonemicWord) {
        self.id = id
        self.operation = operation
        self.word = word
    }
}

// MARK: - PhonemicListeningModels namespace

enum PhonemicListeningModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let rounds: [PhonemicRound]
        }

        struct ViewModel: Sendable {
            let title: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд: вопрос, варианты ответа, прогресс.
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let operation: PhonemeOperation
            let word: String
            /// Инструкция-вопрос для ребёнка.
            let prompt: String
            /// Подписи кнопок-вариантов ответа.
            let options: [OptionViewModel]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        struct OptionViewModel: Identifiable, Sendable, Equatable {
            /// Стабильный индекс варианта (0-based).
            let id: Int
            let label: String
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            /// Индекс выбранного варианта ответа.
            let optionIndex: Int
        }

        struct Response: Sendable {
            let wasCorrect: Bool
            let isFinished: Bool
            let nextRound: PhonemicRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let wasCorrect: Bool
            let feedbackText: String
            let isFinished: Bool
            let nextRound: Start.RoundViewModel?
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
