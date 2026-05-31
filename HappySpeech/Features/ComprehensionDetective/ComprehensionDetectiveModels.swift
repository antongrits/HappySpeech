import Foundation

// MARK: - ComprehensionDetectiveModels (Clean Swift: Models)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив» (F2-014).
//
// Методика: импрессивная речь — понимание устной инструкции (Р.Е. Левина,
// Жукова-Мастюкова-Филичева, Лалаева). Мишень ОНР/ЗРР: импрессия страдает
// раньше экспрессии. Пять уровней грамматической сложности:
//   1. Одно поручение («покажи мяч»).
//   2. Два поручения («сначала яблоко, потом кружку») — слухоречевая память.
//   3. Три поручения («яблоко, кружку и книгу») — удержание ряда.
//   4. Пространственные предлоги (на/под/над/в/за/перед/между/около).
//   5. Логико-грамматические конструкции (инверсии «мама дочки» vs «дочку
//      мамы», сравнительные «кто быстрее», родительный принадлежности).
//
// Игровое ядро: ребёнок-сыщик слышит инструкцию (Ляля проговаривает), видит
// 4 SF-картинки в сетке 2×2 и тапает правильную. Сессия из фиксированного
// числа раундов (антифатиговое правило), как у SoundDetective/FourthExtra.
//
// Сквозные методические правила (ОБЯЗАТЕЛЬНЫ):
//   • «Светофор оценки» (FeedbackTier hit/almost/retry), НИКОГДА «неправильно».
//   • Errorless: подсказка после 2 промахов (повтор инструкции по частям +
//     пульсация правильной картинки), затем мягкое продвижение.
//   • Без таймеров/соревнований.
//   • Ретро-старт: первые 2 раунда — на лёгком уровне (одно поручение).
//   • Возрастной гейт по `minAge` (5/6/7).
//
// `FeedbackTier` НЕ переобъявляется — используется общий платформенный тип из
// `SoundDetectiveModels.swift`.

// MARK: - GrammarTier

/// Уровень грамматической сложности инструкции (по Левиной).
public enum GrammarTier: Int, CaseIterable, Sendable, Codable {
    /// Одно простое поручение («покажи мяч»).
    case simple = 1
    /// Двухступенчатое поручение («сначала яблоко, потом кружку»).
    case doubleInstruction = 2
    /// Трёхступенчатое поручение («яблоко, кружку и книгу»).
    case tripleInstruction = 3
    /// С пространственным предлогом (на/под/над/в/за/перед/между/около).
    case withPreposition = 4
    /// Логико-грамматическая конструкция (инверсии, сравнительные, род. падеж).
    case logicalGrammatical = 5

    public var titleKey: String {
        switch self {
        case .simple:              return "detective.tier.1.title"
        case .doubleInstruction:   return "detective.tier.2.title"
        case .tripleInstruction:   return "detective.tier.3.title"
        case .withPreposition:     return "detective.tier.4.title"
        case .logicalGrammatical:  return "detective.tier.5.title"
        }
    }

    public var hintKey: String {
        switch self {
        case .simple:              return "detective.tier.1.hint"
        case .doubleInstruction:   return "detective.tier.2.hint"
        case .tripleInstruction:   return "detective.tier.3.hint"
        case .withPreposition:     return "detective.tier.4.hint"
        case .logicalGrammatical:  return "detective.tier.5.hint"
        }
    }

    /// Минимальный возраст уровня (возрастной гейт). Двойные/тройные/предлоги
    /// и логико-грамматика поднимают планку постепенно.
    public var minAge: Int {
        switch self {
        case .simple:              return 5
        case .doubleInstruction:   return 5
        case .tripleInstruction:   return 6
        case .withPreposition:     return 6
        case .logicalGrammatical:  return 7
        }
    }

    /// Следующий уровень сложности (для перехода ≥ 80%).
    public var next: GrammarTier? {
        GrammarTier(rawValue: rawValue + 1)
    }
}

// MARK: - DetectivePicture

public struct DetectivePicture: Sendable, Equatable, Identifiable, Codable, Hashable {
    public let id: String
    /// SF Symbol (бесплатный фолбэк, всегда доступен).
    public let symbolName: String
    /// Подпись для VoiceOver / показа.
    public let label: String

    public init(id: String, symbolName: String, label: String) {
        self.id = id
        self.symbolName = symbolName
        self.label = label
    }
}

// MARK: - DetectiveItem

/// Один пункт корпуса: инструкция + 4 картинки (одна правильная).
public struct DetectiveItem: Sendable, Equatable, Identifiable, Codable {

    public let id: String
    public let tier: GrammarTier
    /// Текст инструкции — озвучивается голосом Ляли.
    public let instruction: String
    /// Все 4 варианта-картинки. Первая в исходном порядке — правильная.
    public let pictures: [DetectivePicture]
    /// ID правильной картинки из массива `pictures`.
    public let correctPictureId: String
    /// Возрастной гейт пункта (5/6/7).
    public let minAge: Int

    public init(
        id: String,
        tier: GrammarTier,
        instruction: String,
        pictures: [DetectivePicture],
        correctPictureId: String,
        minAge: Int = 5
    ) {
        self.id = id
        self.tier = tier
        self.instruction = instruction
        self.pictures = pictures
        self.correctPictureId = correctPictureId
        self.minAge = minAge
    }
}

// MARK: - DetectiveRound

/// Один раунд сессии: пункт + перемешанные картинки.
public struct DetectiveRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let item: DetectiveItem
    /// Картинки в перемешанном порядке (ответ не привязан к позиции).
    public let shuffledPictures: [DetectivePicture]

    public init(id: String, item: DetectiveItem, shuffledPictures: [DetectivePicture]) {
        self.id = id
        self.item = item
        self.shuffledPictures = shuffledPictures
    }
}

// MARK: - ComprehensionDetectiveModels namespace

enum ComprehensionDetectiveModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — форсирует уровень (иначе подбирается по возрасту).
            let preferredTier: GrammarTier?
        }

        struct Response: Sendable {
            let rounds: [DetectiveRound]
            /// «Звук»-цель для record (импрессивная речь — лексическая цель).
            let soundTarget: String
            /// Возраст ребёнка (для гейта/диагностики).
            let childAge: Int
            /// Ведущий уровень сессии (для лейбла/перехода).
            let leadTier: GrammarTier
        }

        struct ViewModel: Sendable {
            let title: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд.
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            /// Уровень сложности раунда (для подписи и фона).
            let tier: GrammarTier
            let tierLabel: String
            let tierHint: String
            /// Текст инструкции (озвучивается Лялей).
            let instruction: String
            let pictures: [PictureViewModel]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        struct PictureViewModel: Identifiable, Sendable, Equatable, Hashable {
            let id: String
            let symbolName: String
            let accessibilityLabel: String
        }
    }

    // MARK: Pick (выбор картинки → светофор)

    enum Pick {
        struct Request: Sendable {
            /// id выбранной ребёнком картинки.
            let pictureId: String
            /// Номер попытки в текущем раунде (для fading-подсказки).
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            let pickedPictureId: String
            let correctPictureId: String
            /// Инструкция текущего раунда (для повтора по частям на подсказке).
            let instruction: String
            /// Показать подсказку (пульсация правильной картинки) — после 2 промахов.
            let showHint: Bool
            /// Переозвучить инструкцию медленнее/по частям (errorless).
            let replaySlowly: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: DetectiveRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            /// Тёплая реплика Ляли (без «неправильно»).
            let lyalyaLine: String
            let correctPictureId: String
            /// id картинки для пульсации-подсказки (nil — без подсказки).
            let hintPictureId: String?
            /// Переозвучить инструкцию медленнее.
            let replaySlowly: Bool
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
