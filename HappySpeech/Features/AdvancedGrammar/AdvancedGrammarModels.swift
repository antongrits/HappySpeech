import Foundation

// MARK: - AdvancedGrammarMode
//
// «Грамматический конструктор-2» — три режима сложных грамматических
// конструкций (расширение базового GrammarGame):
//   • complexPreposition — сложные предлоги из-за / из-под / из / возле;
//   • possessive         — притяжательные прилагательные чей/чья/чьё/чьи;
//   • agreement          — согласование прилагательного с сущ. в роде/числе.
// rawValue совпадает с ключом стадии в pack_advanced_grammar.json.

public enum AdvancedGrammarMode: String, CaseIterable, Sendable {
    case complexPreposition = "complex_preposition"
    case possessive         = "possessive"
    case agreement          = "agreement"

    public var localizedTitle: String {
        switch self {
        case .complexPreposition:
            return String(localized: "advancedGrammar.mode.preposition.title",
                          defaultValue: "Сложные предлоги")
        case .possessive:
            return String(localized: "advancedGrammar.mode.possessive.title",
                          defaultValue: "Чей? Чья? Чьё?")
        case .agreement:
            return String(localized: "advancedGrammar.mode.agreement.title",
                          defaultValue: "Договори правильно")
        }
    }

    public var localizedSubtitle: String {
        switch self {
        case .complexPreposition:
            return String(localized: "advancedGrammar.mode.preposition.subtitle",
                          defaultValue: "Выбери маленькое словечко")
        case .possessive:
            return String(localized: "advancedGrammar.mode.possessive.subtitle",
                          defaultValue: "Найди хозяина и скажи правильно")
        case .agreement:
            return String(localized: "advancedGrammar.mode.agreement.subtitle",
                          defaultValue: "Какое окончание подойдёт?")
        }
    }
}

// MARK: - AdvancedGrammarDifficulty

/// Адаптивная сложность по success rate последних сессий (как в GrammarGame).
public enum AdvancedGrammarDifficulty: Int, CaseIterable, Sendable {
    case easy   = 1   // < 60%  — 5 раундов
    case medium = 2   // 60–79% — 7 раундов
    case hard   = 3   // ≥ 80%  — 10 раундов

    public var totalRounds: Int {
        switch self {
        case .easy:   return 5
        case .medium: return 7
        case .hard:   return 10
        }
    }

    public var localizedLabel: String {
        switch self {
        case .easy:
            return String(localized: "advancedGrammar.difficulty.easy", defaultValue: "Лёгкий")
        case .medium:
            return String(localized: "advancedGrammar.difficulty.medium", defaultValue: "Средний")
        case .hard:
            return String(localized: "advancedGrammar.difficulty.hard", defaultValue: "Сложный")
        }
    }

    /// Сопоставление недавнего success rate с уровнем сложности.
    public static func from(successRate: Double) -> AdvancedGrammarDifficulty {
        switch successRate {
        case ..<0.6:  return .easy
        case 0.6..<0.8: return .medium
        default:      return .hard
        }
    }
}

// MARK: - GrammaticalGender

/// Род/число существительного или части тела — определяет правильную форму.
public enum GrammaticalGender: String, Sendable {
    case masculine
    case feminine
    case neuter
    case plural

    /// Локализованная метка «он · …», «она · …» для подсказок под вариантами.
    public func localizedPronoun() -> String {
        switch self {
        case .masculine: return String(localized: "advancedGrammar.gender.he", defaultValue: "он")
        case .feminine:  return String(localized: "advancedGrammar.gender.she", defaultValue: "она")
        case .neuter:    return String(localized: "advancedGrammar.gender.it", defaultValue: "оно")
        case .plural:    return String(localized: "advancedGrammar.gender.they", defaultValue: "они")
        }
    }
}

// MARK: - PrepositionScene

/// Тип пространственной сцены, который рисуется SwiftUI-фигурами.
public enum PrepositionScene: String, Sendable {
    case behind   // позади предмета → из-за
    case under    // под предметом → из-под
    case inside   // внутри предмета → из
    case beside   // рядом → возле

    /// Локализованная подсказка-значение под предлогом.
    public func localizedMeaning() -> String {
        switch self {
        case .behind: return String(localized: "advancedGrammar.scene.behind", defaultValue: "сбоку, позади")
        case .under:  return String(localized: "advancedGrammar.scene.under", defaultValue: "снизу")
        case .inside: return String(localized: "advancedGrammar.scene.inside", defaultValue: "изнутри")
        case .beside: return String(localized: "advancedGrammar.scene.beside", defaultValue: "рядом")
        }
    }
}

// MARK: - Choice

/// Универсальный вариант ответа во всех трёх режимах.
/// `primary` — крупный текст (предлог / вопрос-слово / окончание),
/// `secondary` — мелкая поясняющая подпись (значение / пример рода).
public struct AdvancedGrammarChoice: Sendable, Identifiable, Equatable {
    public let id: String
    public let primary: String
    public let secondary: String
    /// Гендер-акцент (только для притяжательных: он=coral, она=rose, оно=lilac, они=mint).
    public let gender: GrammaticalGender?

    public init(id: String, primary: String, secondary: String, gender: GrammaticalGender? = nil) {
        self.id = id
        self.primary = primary
        self.secondary = secondary
        self.gender = gender
    }
}

// MARK: - Round (runtime)

/// Один раунд игры (сцена + варианты). Построен Worker'ом из пака.
public struct AdvancedGrammarRound: Sendable, Identifiable {
    public let id: String
    public let mode: AdvancedGrammarMode
    /// Заголовок-вопрос («Откуда выглянул котёнок?»).
    public let title: String
    /// Подзаголовок («Выбери маленькое словечко»).
    public let subtitle: String
    /// Текст «фразы с пропуском», показываемый в карточке-сцене / build-карточке.
    public let promptTemplate: String
    /// Картинка-предмет (имя ассета `word_*` или SF Symbol).
    public let imageName: String
    /// Сцена для предложного режима (nil для остальных).
    public let scene: PrepositionScene?
    /// Род/число объекта (для согласования и притяжательных).
    public let gender: GrammaticalGender?
    /// Варианты ответа (включает правильный).
    public let choices: [AdvancedGrammarChoice]
    /// id правильного варианта.
    public let correctChoiceId: String
    /// Полная правильная фраза для проговаривания («Котёнок выглянул из-под стола»).
    public let fullPhrase: String
    /// Подсказка-объяснение от Ляли.
    public let hint: String
}

// MARK: - Phase (state machine)

public enum AdvancedGrammarPhase: Equatable, Sendable {
    case loading
    case question
    case completed
}

// MARK: - VIP Models

enum AdvancedGrammarModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }
        struct Response: Sendable {
            let mode: AdvancedGrammarMode
            let difficulty: AdvancedGrammarDifficulty
            let totalRounds: Int
            let firstRound: AdvancedGrammarRound?
        }
    }

    // MARK: PresentRound

    enum PresentRound {
        struct Response: Sendable {
            let round: AdvancedGrammarRound
            let roundIndex: Int
            let totalRounds: Int
        }
    }

    // MARK: Evaluate

    enum Evaluate {
        struct Request: Sendable {
            let selectedChoiceId: String
        }
        struct Response: Sendable {
            let isCorrect: Bool
            let selectedChoiceId: String
            let correctChoiceId: String
            let fullPhrase: String
            /// Мягкая коррекция при ошибке (без слова «неправильно»).
            let correctionText: String
            let isFirstAttempt: Bool
        }
    }

    // MARK: Complete

    enum Complete {
        struct Response: Sendable {
            let mode: AdvancedGrammarMode
            let totalRounds: Int
            let correctFirstTry: Int
            let successRate: Float
        }
    }
}
