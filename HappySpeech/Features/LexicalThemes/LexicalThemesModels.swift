import Foundation

// MARK: - LexicalThemesModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 7 «Мир слов» — словарь по лексическим темам.
//
// Словарь и обобщающие понятия — фундамент связной речи и грамматики
// (Филичёва, Чиркина организуют коррекцию ОНР именно по лексическим темам).
// Модуль даёт систему лексических тем с мини-играми: называние, обобщение,
// «четвёртый лишний», признаки и действия.
//
// VIP-модуль; контент — `LexicalThemesCorpus` (offline / on-device).

// MARK: - LexicalWord

/// Слово словаря с методической разметкой.
public struct LexicalWord: Identifiable, Sendable, Equatable {
    public let id: String
    /// Само слово (существительное предметного словаря).
    public let text: String
    /// Типичное действие (глагольный словарь): «что делает?».
    public let action: String
    /// Типичный признак (словарь признаков): «какой?».
    public let attribute: String

    public init(id: String, text: String, action: String, attribute: String) {
        self.id = id
        self.text = text
        self.action = action
        self.attribute = attribute
    }
}

// MARK: - LexicalTheme

/// Лексическая тема — группа слов под одним обобщающим понятием.
public struct LexicalTheme: Identifiable, Sendable, Equatable {
    public let id: String
    /// Название темы для отображения («Овощи», «Дикие животные»).
    public let title: String
    /// Обобщающее понятие — ответ на «назови одним словом».
    public let generalization: String
    /// SF Symbol темы.
    public let symbolName: String
    /// Слова темы.
    public let words: [LexicalWord]

    public init(
        id: String,
        title: String,
        generalization: String,
        symbolName: String,
        words: [LexicalWord]
    ) {
        self.id = id
        self.title = title
        self.generalization = generalization
        self.symbolName = symbolName
        self.words = words
    }
}

// MARK: - LexicalGameKind

/// Тип мини-игры внутри темы — методическая прогрессия.
public enum LexicalGameKind: String, Sendable, CaseIterable {
    /// Уровень 1: узнавание и называние слова темы.
    case naming
    /// Уровень 2: обобщение — «назови одним словом».
    case generalization
    /// Уровень 2: «четвёртый лишний» — классификация.
    case oddOneOut
    /// Уровень 3: слово в действии — «что делает?».
    case action

    public var symbolName: String {
        switch self {
        case .naming:         return "tag.fill"
        case .generalization: return "square.grid.2x2.fill"
        case .oddOneOut:      return "xmark.circle.fill"
        case .action:         return "figure.run"
        }
    }
}

// MARK: - LexicalRound

/// Один раунд мини-игры.
public struct LexicalRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let kind: LexicalGameKind
    /// Слово, вокруг которого построен раунд.
    public let word: LexicalWord
    /// Тема раунда.
    public let themeId: String

    public init(id: String, kind: LexicalGameKind, word: LexicalWord, themeId: String) {
        self.id = id
        self.kind = kind
        self.word = word
        self.themeId = themeId
    }
}

// MARK: - LexicalThemesModels namespace

enum LexicalThemesModels {

    // MARK: LoadThemes

    enum LoadThemes {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let themes: [LexicalTheme]
            /// Идентификаторы освоенных тем (для отметки «звезда»).
            let masteredThemeIds: Set<String>
        }

        struct ViewModel: Sendable {
            let title: String
            let themes: [ThemeCardViewModel]
            let masteredCountLabel: String
        }

        struct ThemeCardViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let title: String
            let symbolName: String
            let wordCountLabel: String
            let isMastered: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: StartTheme

    enum StartTheme {
        struct Request: Sendable {
            let themeId: String
        }

        struct Response: Sendable {
            let theme: LexicalTheme
            let rounds: [LexicalRound]
        }

        struct ViewModel: Sendable {
            let themeTitle: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let kind: LexicalGameKind
            let prompt: String
            /// Слово в фокусе раунда (для naming/action).
            let focusWord: String
            let options: [OptionViewModel]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        struct OptionViewModel: Identifiable, Sendable, Equatable {
            let id: Int
            let label: String
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            let optionIndex: Int
        }

        struct Response: Sendable {
            let wasCorrect: Bool
            let isFinished: Bool
            let nextRound: LexicalRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let wasCorrect: Bool
            let feedbackText: String
            let isFinished: Bool
            let nextRound: StartTheme.RoundViewModel?
            let summary: SummaryViewModel?
        }

        struct SummaryViewModel: Sendable {
            let title: String
            let scoreText: String
            let correctCount: Int
            let totalRounds: Int
            let accuracyFraction: Double
            let isThemeMastered: Bool
            let encouragement: String
        }
    }
}
