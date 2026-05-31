import Foundation

// MARK: - WordFormationModels (Clean Swift: Models)
//
// F2-007 «Назови ласково / Один-много-нет» (Wave 2).
//
// Словообразование (уменьшительно-ласкательные суффиксы) + словоизменение
// (число; родительный множественного «много стульев / нет окон»). Закрывает
// два словообразовательно-чередующих пробела ОНР, не покрытых GrammarGame
// (падежи) и его `oneMany` (именит. ед./множ.):
//   • уменьш.-ласк. формы («стол → столик», «гриб → грибок»);
//   • стойкий аграмматизм родительного множественного («много стульев»,
//     «нет окон/вёдер»).
// (Лалаева-Серебрякова; Ткаченко; Жукова — [[speech-methodology]],
// [[correction-stages]] этапы 6–7.)
//
// Игровое ядро: картинка-основа крупно + текстовые варианты-формы (это про
// ЗВУЧАНИЕ формы, не про картинку производного). Ребёнок выбирает нормативную
// форму среди опций «норма vs ошибка-дистрактор»; дистракторы — намеренно
// типичные детские ошибки (узнавание нормы). Контент — `WordFormationCorpus`
// (`pack_word_formation.json`, offline / on-device).
//
// Сквозные методические правила (ОБЯЗАТЕЛЬНЫ):
//   • «Светофор оценки» (FeedbackTier hit/almost/retry), НИКОГДА «неправильно».
//   • `.almost` при близкой ошибке (nearMiss-дистрактор «стулы») против грубой.
//   • Подсказка после 2 промахов подряд (errorless fading).
//   • Без таймеров/соревнований.
//   • При попадании — система проговаривает нормативную форму (закрепление по
//     слуху). Это методическое ядро словообразования.
//   • Вербализация «повтори форму» — опционально для 7–8 лет, без оценки
//     произношения.
//
// `FeedbackTier` НЕ переобъявляется — используется общий тип из
// `SoundDetectiveModels.swift` (платформенный «светофор», переиспользуемый
// FourthExtra, SyllableSnail и др.).

// MARK: - FormationSubtask

/// Под-тип задания. Ротируются (никогда 2 одинаковых подряд).
/// Прогрессия по нарастанию трудности: diminutive → oneMany → manyOf.
public enum FormationSubtask: String, Sendable, CaseIterable, Equatable {
    /// Уменьшительно-ласкательные (стол → столик, гриб → грибок). С 5 лет.
    case diminutive
    /// Единственное → множественное именительное (стул → стулья). С 5 лет.
    case oneMany
    /// Родительный множественного («много стульев», «нет окон»). С 6 лет.
    case manyOf

    /// Минимальный возраст (возрастной гейт, методика / F1-018).
    public var minAge: Int {
        switch self {
        case .diminutive: return 5
        case .oneMany:    return 5
        case .manyOf:     return 6
        }
    }
}

// MARK: - FormationOption

/// Вариант-форма. `isCorrect` — серверная истина, скрыта от ViewModel.
/// `isNearMiss` помечает «близкую» ошибку (напр. «стулы» вместо «стулья») —
/// при её выборе обратная связь мягче (`.almost`), чем при грубой ошибке.
public struct FormationOption: Identifiable, Sendable, Equatable {
    public let id: String
    public let text: String
    /// Является ли вариант нормативной формой (ровно один на раунд).
    public let isCorrect: Bool
    /// Близкая (типичная) ошибка — мягкий `.almost` вместо грубого промаха.
    public let isNearMiss: Bool

    public init(
        id: String,
        text: String,
        isCorrect: Bool,
        isNearMiss: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isCorrect = isCorrect
        self.isNearMiss = isNearMiss
    }
}

// MARK: - FormationRound

/// Один раунд: картинка-основа + под-тип + варианты-формы.
public struct FormationRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let subtask: FormationSubtask
    /// Слово-основа (стол, стул…).
    public let baseWord: String
    /// Asset картинки основы (из word_manifest.json).
    public let baseImage: String
    /// Реплика-задание под-типа («Назови ласково» / «Чего много?»).
    public let prompt: String
    /// Варианты-формы (перемешиваются в Worker).
    public let options: [FormationOption]
    /// Нормативная форма для озвучки на hit («Столик.» / «Много стульев.»).
    public let spokenForm: String
    public let difficulty: Int
    /// Минимальный возраст (возрастной гейт).
    public let minAge: Int

    public init(
        id: String,
        subtask: FormationSubtask,
        baseWord: String,
        baseImage: String,
        prompt: String,
        options: [FormationOption],
        spokenForm: String,
        difficulty: Int,
        minAge: Int
    ) {
        self.id = id
        self.subtask = subtask
        self.baseWord = baseWord
        self.baseImage = baseImage
        self.prompt = prompt
        self.options = options
        self.spokenForm = spokenForm
        self.difficulty = difficulty
        self.minAge = minAge
    }

    /// id нормативной формы (ровно одна на раунд).
    public var correctOptionId: String? {
        options.first { $0.isCorrect }?.id
    }
}

// MARK: - WordFormationModels namespace

enum WordFormationModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — форсирует под-тип (иначе подбирается по возрасту).
            let preferredSubtask: FormationSubtask?
        }

        struct Response: Sendable {
            let rounds: [FormationRound]
            /// «Звук» сессии для record («грамматика.словообр»).
            let soundTarget: String
            /// Возраст ребёнка (для гейта вербализации «повтори форму»).
            let childAge: Int
        }

        struct ViewModel: Sendable {
            let title: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд. `isCorrect`/`isNearMiss` НЕ передаются.
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let subtask: FormationSubtask
            /// Asset картинки основы.
            let baseImage: String
            /// Слово-основа (подпись под картинкой).
            let baseWord: String
            /// Реплика-вопрос Ляли (под-тип).
            let promptLyalya: String
            /// Варианты-формы в перемешанном порядке (без признака нормы).
            let options: [OptionViewModel]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        /// Вариант-форма (только id + text; нормативность скрыта by design).
        struct OptionViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let text: String
            let accessibilityLabel: String
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            /// id выбранного ребёнком варианта.
            let chosenOptionId: String
            /// Номер попытки в текущем раунде (для fading-подсказки).
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            /// id нормативной формы (для подсветки/подсказки).
            let correctOptionId: String
            /// Нормативная форма для озвучки на hit (методическое ядро).
            let spokenForm: String
            /// Выбранный дистрактор — близкая ошибка («стулы»)? Влияет на тон
            /// реплики Presenter'а (мягкое «послушай форму» против общего).
            let chosenWasNearMiss: Bool
            /// Спросить «повтори форму» (7–8 лет) — после верного выбора.
            let askToRepeat: Bool
            /// Подсветить верный вариант (после 2 промахов).
            let hintOptionId: String?
            let showHint: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: FormationRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            /// Тёплая реплика Ляли (без «неправильно»).
            let lyalyaLine: String
            let correctOptionId: String
            /// Нормативная форма (озвучка + субтитр) на hit.
            let spokenForm: String
            let askToRepeat: Bool
            /// Вариант для пульсации-подсказки (nil — без подсказки).
            let hintOptionId: String?
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
            /// ≥ 0.8 — показать праздник (confetti / static fallback).
            let showCelebration: Bool
        }
    }
}
