import Foundation

// MARK: - WhoseTailModels (Clean Swift: Models)
//
// F2-006 «Чей хвост / чей домик» (Wave 2).
//
// Словообразование: притяжательные прилагательные («лис-ий хвост», «медвеж-ья
// лапа») и относительные («деревянн-ый стол», «стеклянн-ый стакан»). GrammarGame
// (падежи) словообразование прилагательных не покрывает — это отдельный
// высокочастотный, стойкий дефект ОНР II–IV (типичные ошибки «лисячий»,
// «волковый», «медведий», «деревьянный»). (Лалаева-Серебрякова — «Коррекция
// ОНР», словообразование; Филичева-Чевелёва; Жукова — [[speech-methodology]],
// [[correction-stages]] этапы 6–8.)
//
// Игровое ядро: «улика» крупно сверху (хвост / домик / предмет) + ряд карточек-
// вариантов (звери / материалы). Ребёнок сопоставляет улику с правильным
// зверем/материалом; при попадании система проговаривает целевую форму
// прилагательного («Это лисий хвост!») — закрепление формы по слуху, методическое
// ядро словообразования. Контент — `WhoseTailCorpus` (`pack_whose_tail.json`,
// offline / on-device).
//
// Сквозные методические правила (ОБЯЗАТЕЛЬНЫ):
//   • «Светофор оценки» (FeedbackTier hit/almost/retry), НИКОГДА «неправильно».
//   • Дефектные формы («лисячий», «волковый») НЕ присутствуют в `options`
//     (стоп-лист) — чтобы не путать ребёнка ошибочной продукцией.
//   • Подсказка после 2 промахов подряд (errorless fading).
//   • Без таймеров/соревнований.
//   • При попадании — система проговаривает целевую форму (закрепление по слуху).
//   • Вербализация «скажи, чей хвост?» — опционально для 7–8 лет, без оценки
//     произношения; не для relativeMaterial (там форма-конструкция «Стол …»).
//
// `FeedbackTier` НЕ переобъявляется — используется общий тип из
// `SoundDetectiveModels.swift` (платформенный «светофор», переиспользуемый
// FourthExtra, WordFormation, SyllableSnail и др.).

// MARK: - WhoseSubtask

/// Под-тип задания. Ротируются (никогда 2 одинаковых подряд).
/// Прогрессия по онтогенезу: притяжательные (раньше) → относительные (позже).
public enum WhoseSubtask: String, Sendable, CaseIterable, Equatable {
    /// Притяжательные: чей хвост / лапа / ухо (животные). С 5 лет.
    case possessiveTail
    /// Притяжательно-локативное: чей домик (нора → лисья нора). С 6 лет.
    case animalHome
    /// Относительные: «из чего сделан» (дерево → деревянный). С 6 лет.
    case relativeMaterial

    /// Минимальный возраст (возрастной гейт, методика / F1-018).
    public var minAge: Int {
        switch self {
        case .possessiveTail:  return 5
        case .animalHome:      return 6
        case .relativeMaterial: return 6
        }
    }
}

// MARK: - WhoseOption

/// Вариант-карточка (зверь / материал). `isCorrect` — серверная истина, скрыта
/// от ViewModel. `form` — целевая форма прилагательного для озвучки на hit.
public struct WhoseOption: Identifiable, Sendable, Equatable {
    public let id: String
    /// Слово-владелец / материал (лиса, дерево…) — подпись под картинкой.
    public let word: String
    /// Asset картинки (из word_manifest.json) или SF Symbol.
    public let imageAsset: String
    /// Является ли вариант правильным сопоставлением (ровно один на раунд).
    public let isCorrect: Bool
    /// Целевая форма прилагательного («лисий хвост») — озвучка/субтитр.
    public let form: String

    public init(
        id: String,
        word: String,
        imageAsset: String,
        isCorrect: Bool,
        form: String
    ) {
        self.id = id
        self.word = word
        self.imageAsset = imageAsset
        self.isCorrect = isCorrect
        self.form = form
    }
}

// MARK: - WhoseRound

/// Один раунд: улика-картинка + вопрос + варианты-карточки.
public struct WhoseRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let subtask: WhoseSubtask
    /// Asset/символ «улики» (хвост / домик / предмет) — крупно сверху.
    public let cueImage: String
    /// Вопрос Ляли («Чей это хвост?» / «Из чего сделан стол?»).
    public let question: String
    /// Варианты-карточки (перемешиваются в Worker).
    public let options: [WhoseOption]
    /// Целевая форма для озвучки на hit («Это лисий хвост.»).
    public let spokenForm: String
    public let difficulty: Int
    /// Минимальный возраст (возрастной гейт).
    public let minAge: Int

    public init(
        id: String,
        subtask: WhoseSubtask,
        cueImage: String,
        question: String,
        options: [WhoseOption],
        spokenForm: String,
        difficulty: Int,
        minAge: Int
    ) {
        self.id = id
        self.subtask = subtask
        self.cueImage = cueImage
        self.question = question
        self.options = options
        self.spokenForm = spokenForm
        self.difficulty = difficulty
        self.minAge = minAge
    }

    /// id правильного варианта (ровно один на раунд).
    public var correctOptionId: String? {
        options.first { $0.isCorrect }?.id
    }

    /// Целевая форма правильного варианта (для озвучки на hit).
    public var correctForm: String {
        options.first { $0.isCorrect }?.form ?? spokenForm
    }
}

// MARK: - WhoseTailModels namespace

enum WhoseTailModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — форсирует под-тип (иначе подбирается по возрасту).
            let preferredSubtask: WhoseSubtask?
        }

        struct Response: Sendable {
            let rounds: [WhoseRound]
            /// «Звук» сессии для record («грамматика.притяжат»).
            let soundTarget: String
            /// Возраст ребёнка (для гейта вербализации «скажи, чей хвост?»).
            let childAge: Int
        }

        struct ViewModel: Sendable {
            let title: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд. `isCorrect`/`form` НЕ передаются явно
        /// (форма раскрывается только на hit через Answer.ViewModel).
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let subtask: WhoseSubtask
            /// Asset/символ улики.
            let cueImage: String
            /// Реплика-вопрос Ляли (улика).
            let promptLyalya: String
            /// Варианты-карточки в перемешанном порядке (без признака нормы).
            let options: [OptionViewModel]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        /// Вариант-карточка (id + слово + картинка; нормативность скрыта by design).
        struct OptionViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let word: String
            let imageAsset: String
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
            /// id правильного варианта (для подсветки/подсказки).
            let correctOptionId: String
            /// Целевая форма для озвучки на hit (методическое ядро).
            let spokenForm: String
            /// Спросить «скажи, чей хвост?» (7–8 лет) — после верного выбора;
            /// не для relativeMaterial.
            let askToRepeat: Bool
            /// Подсветить верный вариант (после 2 промахов).
            let hintOptionId: String?
            let showHint: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: WhoseRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            /// Тёплая реплика Ляли (без «неправильно»).
            let lyalyaLine: String
            let correctOptionId: String
            /// Целевая форма (озвучка + субтитр) на hit.
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
