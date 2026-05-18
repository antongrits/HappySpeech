import Foundation

// MARK: - ProsodyModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 1 «Голосовые краски» — просодия и интонация.
//
// Просодика (интонация, логическое ударение, мелодика фразы) — самостоятельный
// компонент речи (Лопатина). При дизартрии и ОНР страдает первой и почти не
// покрыта сегментными шаблонами. Модуль работает над различением и
// воспроизведением трёх типов интонации.
//
// VIP-модуль; контент — `ProsodyCorpus` (offline / on-device, без сети).

// MARK: - IntonationType

/// Тип интонации фразы.
public enum IntonationType: String, Sendable, CaseIterable {
    /// Повествование — спокойный нисходящий тон.
    case declarative
    /// Вопрос — восходящий тон к концу фразы.
    case interrogative
    /// Восклицание — эмоциональный, с усилением.
    case exclamatory

    /// Имя SF Symbol для визуальной подсказки.
    public var symbolName: String {
        switch self {
        case .declarative:   return "minus.circle.fill"
        case .interrogative: return "questionmark.circle.fill"
        case .exclamatory:   return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - ProsodyPhrase

/// Фраза с разметкой по типу интонации для упражнений просодии.
public struct ProsodyPhrase: Identifiable, Sendable, Equatable {
    public let id: String
    /// Текст фразы для отображения и повтора.
    public let text: String
    /// Целевой тип интонации.
    public let intonation: IntonationType
    /// Лексическая тема (связь с Функцией 7 «Мир слов»).
    public let theme: String

    public init(id: String, text: String, intonation: IntonationType, theme: String) {
        self.id = id
        self.text = text
        self.intonation = intonation
        self.theme = theme
    }
}

// MARK: - ProsodyStage

/// Этап раунда — методическая прогрессия (различение → повтор → продуцирование).
public enum ProsodyStage: String, Sendable, CaseIterable {
    /// Уровень 1: различить интонацию на слух (выбрать тип).
    case discriminate
    /// Уровень 2: повторить фразу с заданной интонацией по эталону.
    case imitate
    /// Уровень 3: произнести фразу с нужной интонацией без эталона.
    case produce
}

// MARK: - ProsodyRound

/// Один раунд упражнения.
public struct ProsodyRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let stage: ProsodyStage
    public let phrase: ProsodyPhrase

    public init(id: String, stage: ProsodyStage, phrase: ProsodyPhrase) {
        self.id = id
        self.stage = stage
        self.phrase = phrase
    }
}

// MARK: - ProsodyModels namespace

enum ProsodyModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let rounds: [ProsodyRound]
        }

        struct ViewModel: Sendable {
            let title: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд.
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let stage: ProsodyStage
            let phraseText: String
            /// Инструкция для ребёнка.
            let prompt: String
            /// Символ целевой интонации (для подсказки на уровнях 2–3).
            let intonationSymbol: String
            /// Варианты ответа на этапе различения (пусто для imitate/produce).
            let options: [OptionViewModel]
            /// Нужен ли микрофон на этом этапе (imitate/produce).
            let needsVoice: Bool
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        struct OptionViewModel: Identifiable, Sendable, Equatable {
            let id: Int
            let label: String
            let symbol: String
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            /// Для discriminate — индекс выбранного варианта.
            /// Для imitate/produce — попытка озвучивания (индекс не используется).
            let optionIndex: Int
            /// Голосовая попытка засчитана (микрофонные этапы).
            let voiceAttempted: Bool
        }

        struct Response: Sendable {
            let wasCorrect: Bool
            let isFinished: Bool
            let nextRound: ProsodyRound?
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
