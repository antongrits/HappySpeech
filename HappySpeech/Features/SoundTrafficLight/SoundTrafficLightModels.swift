import Foundation

// MARK: - SoundTrafficLightModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Расширенная слуховая дифференциация акустически близких пар звуков
// (С–Ш, З–Ж, Р–Л и др.) — финальный этап коррекции ([[correction-stages]]
// этап 14). Ребёнок сортирует материал в два «гаража» по целевому звуку.
//
// Этот VIP-модуль реализует полную методическую лестницу дифференциации
// (Ткаченко, Коноваленко): СЛОГ → СЛОВО → ФРАЗА → ТЕКСТ. Контент —
// `SoundTrafficLightCorpus` (8 пар со слогами/фразами/текстами + новая
// пара Л–Й, offline).

// MARK: - DifferentiationLevel

/// Уровень дифференциации по методической лестнице этапа 14.
///
/// Порядок прохождения внутри пары строгий и совпадает с порядком кейсов:
/// слог (14б) → слово (14в) → фраза (14г) → текст (14д). На слоге нет
/// смысловой опоры — самый чистый тест фонематического слуха; текст
/// переносит навык в связную речь со счётной механикой.
public enum DifferentiationLevel: String, CaseIterable, Sendable, Codable {
    case syllable
    case word
    case phrase
    case text

    /// Следующий уровень лестницы; `nil` для последнего (`text`).
    public var next: DifferentiationLevel? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else {
            return nil
        }
        return all[index + 1]
    }

    /// Предыдущий уровень лестницы; `nil` для первого (`syllable`).
    public var previous: DifferentiationLevel? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index > 0 else { return nil }
        return all[index - 1]
    }
}

// MARK: - TrafficLightPhrase

/// Фраза уровня ФРАЗА: текст + разметка слов по целевым звукам пары.
///
/// `wordsA`/`wordsB` могут пересекаться по словам-носителям обоих звуков
/// («Юли» = Й+Л, «поймала» = Й+Л) — это намеренно для подсветки обоих
/// звуков в одном слове.
public struct TrafficLightPhrase: Identifiable, Sendable, Equatable, Codable {

    /// Доминирующий звук фразы: какой «гараж» должен загореться на «светофоре».
    public enum Dominant: String, Sendable, Equatable, Codable {
        case soundA = "A"
        case soundB = "B"
        case both
    }

    public let id: String
    /// Полный текст фразы (речевой стимул).
    public let text: String
    /// Какой звук доминирует во фразе.
    public let dominant: Dominant
    /// Слова фразы, содержащие soundA.
    public let wordsA: [String]
    /// Слова фразы, содержащие soundB.
    public let wordsB: [String]

    public init(
        id: String,
        text: String,
        dominant: Dominant,
        wordsA: [String],
        wordsB: [String]
    ) {
        self.id = id
        self.text = text
        self.dominant = dominant
        self.wordsA = wordsA
        self.wordsB = wordsB
    }
}

// MARK: - TrafficLightText

/// Текст уровня ТЕКСТ: короткий рассказ + эталонные счётчики слов.
///
/// `countA`/`countB` — непересекающиеся: слова-носители обоих звуков
/// отнесены к доминанте, чтобы суммы совпадали с числом помеченных слов
/// (правило подсчёта из спеки методиста).
public struct TrafficLightText: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    /// Заголовок рассказа.
    public let title: String
    /// Предложения рассказа (4–6 коротких строк).
    public let lines: [String]
    /// Эталонное число слов со звуком A.
    public let countA: Int
    /// Эталонное число слов со звуком B.
    public let countB: Int
    /// Происхождение материала (авторский / адаптация чистоговорки и т.п.).
    public let source: String

    public init(
        id: String,
        title: String,
        lines: [String],
        countA: Int,
        countB: Int,
        source: String
    ) {
        self.id = id
        self.title = title
        self.lines = lines
        self.countA = countA
        self.countB = countB
        self.source = source
    }
}

// MARK: - DifferentiationPair

/// Пара дифференцируемых звуков с материалом всех уровней лестницы.
///
/// Уровни слог/фраза/текст необязательны: старые паки без них остаются
/// валидными (обратная совместимость) и поддерживают только уровень СЛОВО.
public struct DifferentiationPair: Identifiable, Sendable, Equatable {
    public let id: String
    /// Первый звук пары (например «С»).
    public let soundA: String
    /// Второй звук пары (например «Ш»).
    public let soundB: String
    /// Слоги со звуком A (уровень СЛОГ).
    public let syllablesA: [String]
    /// Слоги со звуком B (уровень СЛОГ).
    public let syllablesB: [String]
    /// Слова, содержащие soundA (уровень СЛОВО).
    public let wordsA: [String]
    /// Слова, содержащие soundB (уровень СЛОВО).
    public let wordsB: [String]
    /// Фразы пары (уровень ФРАЗА).
    public let phrases: [TrafficLightPhrase]
    /// Тексты пары (уровень ТЕКСТ).
    public let texts: [TrafficLightText]

    public init(
        id: String,
        soundA: String,
        soundB: String,
        syllablesA: [String] = [],
        syllablesB: [String] = [],
        wordsA: [String],
        wordsB: [String],
        phrases: [TrafficLightPhrase] = [],
        texts: [TrafficLightText] = []
    ) {
        self.id = id
        self.soundA = soundA
        self.soundB = soundB
        self.syllablesA = syllablesA
        self.syllablesB = syllablesB
        self.wordsA = wordsA
        self.wordsB = wordsB
        self.phrases = phrases
        self.texts = texts
    }

    /// Уровни, для которых у пары есть материал, в методическом порядке.
    /// Уровень СЛОВО присутствует всегда; остальные — если контент задан.
    public var availableLevels: [DifferentiationLevel] {
        DifferentiationLevel.allCases.filter { level in
            switch level {
            case .syllable: return !syllablesA.isEmpty && !syllablesB.isEmpty
            case .word:     return !wordsA.isEmpty && !wordsB.isEmpty
            case .phrase:   return !phrases.isEmpty
            case .text:     return !texts.isEmpty
            }
        }
    }
}

// MARK: - TrafficLightRound

/// Один раунд сортировки (слог или слово): материал и правильный гараж.
public struct TrafficLightRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let word: String
    /// true — материал относится к soundA («левый гараж»).
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
            /// Текущий уровень лестницы для этой сессии.
            let level: DifferentiationLevel
            /// Раунды сортировки (для уровней слог / слово).
            let rounds: [TrafficLightRound]
            /// Фразы (для уровня фраза).
            let phrases: [TrafficLightPhrase]
            /// Тексты (для уровня текст).
            let texts: [TrafficLightText]

            init(
                pair: DifferentiationPair,
                level: DifferentiationLevel = .word,
                rounds: [TrafficLightRound] = [],
                phrases: [TrafficLightPhrase] = [],
                texts: [TrafficLightText] = []
            ) {
                self.pair = pair
                self.level = level
                self.rounds = rounds
                self.phrases = phrases
                self.texts = texts
            }
        }

        struct ViewModel: Sendable {
            let title: String
            let instruction: String
            let levelLabel: String
            let level: DifferentiationLevel
            let garageALabel: String
            let garageBLabel: String
            let totalRounds: Int
            let firstRound: RoundViewModel?
            /// Заполняется на уровне ФРАЗА.
            let firstPhrase: PhraseViewModel?
            /// Заполняется на уровне ТЕКСТ.
            let firstText: TextViewModel?
        }

        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let word: String
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        /// Слово фразы с разметкой целевых звуков (для подсветки/тапа).
        struct PhraseTokenViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let text: String
            let containsA: Bool
            let containsB: Bool
        }

        struct PhraseViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let text: String
            let tokens: [PhraseTokenViewModel]
            let progressLabel: String
            let progressFraction: Double
            /// Правильный «гараж» по доминанте: A / B / оба.
            let correctSide: TrafficLightPhrase.Dominant
            let accessibilityLabel: String
        }

        struct TextViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let title: String
            let lines: [String]
            let progressLabel: String
            let progressFraction: Double
            /// Эталонное число слов со звуком A.
            let answerA: Int
            /// Эталонное число слов со звуком B.
            let answerB: Int
            /// Максимум для степпера счёта.
            let maxCount: Int
            let accessibilityLabel: String
        }
    }

    // MARK: Sort (уровни слог / слово)

    enum Sort {
        struct Request: Sendable {
            /// true — ребёнок выбрал «левый гараж» (soundA).
            let pickedGarageA: Bool
        }

        struct Response: Sendable {
            let wasCorrect: Bool
            let isFinished: Bool
            let nextRound: TrafficLightRound?
            /// Индекс следующего раунда (0-based); nil, если уровень завершён.
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
            let level: DifferentiationLevel
            /// Уровень, рекомендованный после завершения текущего (по критерию).
            let nextLevel: DifferentiationLevel?
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
            /// Подпись «следующий уровень» если критерий перехода выполнен.
            let nextLevelLabel: String?
        }
    }

    // MARK: ChoosePhrase (уровень фраза)

    enum ChoosePhrase {
        struct Request: Sendable {
            /// Выбор ребёнка: какой звук доминирует во фразе.
            let pickedSide: TrafficLightPhrase.Dominant
        }

        struct Response: Sendable {
            let wasCorrect: Bool
            let isFinished: Bool
            let nextPhrase: TrafficLightPhrase?
            let nextPhraseIndex: Int?
            let correctCount: Int
            let totalPhrases: Int
            let nextLevel: DifferentiationLevel?
        }

        struct ViewModel: Sendable {
            let wasCorrect: Bool
            let feedbackText: String
            let isFinished: Bool
            let nextPhrase: Start.PhraseViewModel?
            let summary: Sort.SummaryViewModel?
        }
    }

    // MARK: CountText (уровень текст)

    enum CountText {
        struct Request: Sendable {
            /// Введённое ребёнком число слов со звуком A.
            let answerA: Int
            /// Введённое ребёнком число слов со звуком B.
            let answerB: Int
        }

        struct Response: Sendable {
            /// Верно ли A (с допуском ±1, см. критерий ТЕКСТ).
            let correctA: Bool
            /// Верно ли B (с допуском ±1).
            let correctB: Bool
            /// Оба в допуске — текст засчитан.
            let textPassed: Bool
            let isFinished: Bool
            let nextText: TrafficLightText?
            let nextTextIndex: Int?
            let passedCount: Int
            let totalTexts: Int
            let pairCompleted: Bool
        }

        struct ViewModel: Sendable {
            let feedbackText: String
            let correctA: Bool
            let correctB: Bool
            let isFinished: Bool
            let nextText: Start.TextViewModel?
            let summary: Sort.SummaryViewModel?
        }
    }
}
