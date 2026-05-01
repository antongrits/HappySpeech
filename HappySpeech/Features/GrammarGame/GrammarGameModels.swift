import Foundation

// MARK: - GrammarGameMode

/// Четыре падежные игры грамматического блока.
/// rawValue используется как ключ при загрузке контента.
public enum GrammarGameMode: String, CaseIterable, Sendable {
    case oneMany       = "one_many"       // Именит. пад. Ед./Мн.ч.
    case dative        = "dative"         // Дательный — «Кому что нужно?»
    case genitive      = "genitive"       // Родительный — «Откуда взял?»
    case instrumental  = "instrumental"   // Творительный — «С кем дружу?»

    public var localizedTitle: String {
        switch self {
        case .oneMany:      return String(localized: "grammar.game.title.one_many",      bundle: .main)
        case .dative:       return String(localized: "grammar.game.title.dative",        bundle: .main)
        case .genitive:     return String(localized: "grammar.game.title.genitive",      bundle: .main)
        case .instrumental: return String(localized: "grammar.game.title.instrumental",  bundle: .main)
        }
    }
}

// MARK: - GrammarDifficulty

public enum GrammarDifficulty: Int, CaseIterable, Sendable {
    case easy   = 1   // successRate < 60%  — 5 раундов, 2 варианта, подсказка после 1 ошибки
    case medium = 2   // 60–79%             — 7 раундов, 3 варианта, подсказка после 2 ошибок
    case hard   = 3   // ≥ 80%              — 10 раундов, 4 варианта, подсказка после 2 ошибок

    public var totalRounds: Int {
        switch self {
        case .easy: return 5
        case .medium: return 7
        case .hard: return 10
        }
    }

    public var choiceCount: Int {
        switch self {
        case .easy: return 2
        case .medium: return 3
        case .hard: return 4
        }
    }

    public var hintAfterErrors: Int {
        switch self {
        case .easy: return 1
        default: return 2
        }
    }

    public var localizedLabel: String {
        switch self {
        case .easy:   return String(localized: "grammar.game.difficulty.easy",   bundle: .main)
        case .medium: return String(localized: "grammar.game.difficulty.medium", bundle: .main)
        case .hard:   return String(localized: "grammar.game.difficulty.hard",   bundle: .main)
        }
    }
}

// MARK: - GamePhase (state machine)

public enum GrammarGamePhase: Equatable, Sendable {
    case idle
    case loading
    case presenting
    case awaitingAnswer
    case evaluating
    case feedbackCorrect(roundIndex: Int)
    case feedbackIncorrect(roundIndex: Int, errorsCount: Int)
    case hintShown(roundIndex: Int)
    case nextRound
    case completed
}

// MARK: - Raw content types (from pack_grammar.json)

public struct GrammarPackItem: Sendable, Identifiable {
    public let id: String
    public let word: String    // «один кот — много котов» — парная форма
    public let hint: String
    public let difficulty: Int
    public let audioFile: String
}

// MARK: - Round model (runtime)

public struct GrammarRound: Sendable, Identifiable {
    public let id: UUID
    public let mode: GrammarGameMode
    public let sourceItem: GrammarPackItem
    /// Текст вопроса, показываемый ребёнку
    public let questionText: String
    /// Правильный вариант
    public let correctAnswer: String
    /// Все варианты (включает правильный)
    public let choices: [GrammarChoice]
    /// Индекс правильного ответа в choices
    public let correctIndex: Int
    /// Image name (SF Symbol fallback если нет ассета)
    public let imageName: String
    /// Дополнительные данные специфичные для игры (персонажи, контейнеры и т.д.)
    public let extraData: GrammarRoundExtra
}

public enum GrammarRoundExtra: Sendable {
    case none
    case dative(characters: [DativeCharacter], targetCharacterIndex: Int)
    case genitive(containers: [GenitiveContainer], correctContainerIndex: Int)
    case instrumental(partyMode: Bool)
}

public struct GrammarChoice: Sendable, Identifiable {
    public let id: String
    public let text: String
    public let imageName: String?
}

public struct DativeCharacter: Sendable, Identifiable {
    public let id: String
    public let name: String          // именит. «Маша»
    public let dativeName: String    // дат. «Маше»
    public let imageName: String
}

public struct GenitiveContainer: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let genitiveName: String   // «из ящика», «со стола»
    public let imageName: String
}

// MARK: - VIP Models

enum GrammarGameModels {

    // MARK: - LoadGame

    enum LoadGame {
        struct Request: Sendable {
            let mode: GrammarGameMode
            let difficulty: GrammarDifficulty
            let childId: String
        }
        struct Response: Sendable {
            let mode: GrammarGameMode
            let difficulty: GrammarDifficulty
            let rounds: [GrammarRound]
            let totalRounds: Int
        }
        struct ViewModel: Sendable {
            let modeTitle: String
            let difficultyLabel: String
            let totalRounds: Int
        }
    }

    // MARK: - PresentRound

    enum PresentRound {
        struct Request: Sendable {
            let roundIndex: Int
        }
        struct Response: Sendable {
            let round: GrammarRound
            let roundIndex: Int
            let totalRounds: Int
            let mode: GrammarGameMode
            let difficulty: GrammarDifficulty
        }
        struct ViewModel: Sendable {
            let questionText: String
            let choices: [GrammarChoice]
            let imageName: String
            let roundIndex: Int
            let totalRounds: Int
            let extraData: GrammarRoundExtra
            let audioFile: String
        }
    }

    // MARK: - EvaluateAnswer

    enum EvaluateAnswer {
        struct Request: Sendable {
            let selectedChoiceId: String
            let roundIndex: Int
        }
        struct Response: Sendable {
            let isCorrect: Bool
            let correctChoiceId: String
            let selectedChoiceId: String
            let errorsOnThisRound: Int
            let feedbackText: String
            let hintText: String?
            let shouldShowHint: Bool
            let score: Int    // 0 или 1
        }
        struct ViewModel: Sendable {
            let isCorrect: Bool
            let correctChoiceId: String
            let selectedChoiceId: String
            let feedbackText: String
            let hintText: String?
            let showHint: Bool
        }
    }

    // MARK: - DragDrop (Dative)

    enum DragDrop {
        struct Request: Sendable {
            let droppedOnCharacterId: String
            let roundIndex: Int
        }
        struct Response: Sendable {
            let isCorrect: Bool
            let correctCharacterId: String
            let droppedCharacterId: String
            /// Структурные данные для Presenter — не строить строку в Interactor.
            let charDativeName: String    // «Маше»
            let correctAnswer: String     // «книга»
        }
        struct ViewModel: Sendable {
            let isCorrect: Bool
            let correctCharacterId: String
            let droppedCharacterId: String
            let feedbackPhrase: String
        }
    }

    // MARK: - SessionComplete

    enum SessionComplete {
        struct Request: Sendable {}
        struct Response: Sendable {
            let mode: GrammarGameMode
            let difficulty: GrammarDifficulty
            let totalRounds: Int
            let correctCount: Int
            let successRate: Float
            let sessionDurationSeconds: Int
        }
        struct ViewModel: Sendable {
            let resultText: String
            let successRate: Float
            let correctCount: Int
            let totalRounds: Int
            let showReward: Bool
        }
    }

    // MARK: - ExitConfirmation

    enum ExitConfirmation {
        struct Request: Sendable {}
        struct ViewModel: Sendable {
            let title: String
            let body: String
            let confirmLabel: String
            let cancelLabel: String
        }
    }
}
