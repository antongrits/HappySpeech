import Foundation

// MARK: - SentenceBuilderModels (Clean Swift: Models)
//
// F2-004 «Конструктор предложения» (Wave 2).
//
// Синтаксис: порядок слов (СПО / SVO), согласование (род / число прилагательного
// с существительным) и предложно-падежные конструкции (в / на / под / за / у /
// около). GrammarGame (падежи — словоизменение) синтаксис не покрывает: это
// этапы 7–9 коррекции (фраза → предложение → связная речь), стойкая зона
// аграмматизма при ОНР II–IV — пропуск/неверный предлог, нарушение порядка слов,
// рассогласование. (Жукова-Мастюкова-Филичева — формирование фразовой речи;
// Ткаченко — связная речь; Лалаева-Серебрякова — коррекция ОНР; см.
// [[speech-methodology]], [[correction-stages]] этапы 7–9.)
//
// Игровое ядро — ЕДИНСТВЕННАЯ механика Волны 2 с ПОСЛЕДОВАТЕЛЬНОЙ СБОРКОЙ
// (ребёнок выкладывает слова-карточки в ленту-слоты в правильном порядке), а не
// выбором одного ответа. Поэтому оценка — частичная (`matchesPartially`): точное
// совпадение допустимого порядка → hit; ≥ 60 % верных соседних пар или
// перепутан только предлог → almost; светофор без «неправильно». Контент —
// `SentenceBuilderCorpus` (`pack_sentence_builder.json`, offline / on-device).
//
// Отличие от MVP `SentenceBuilderKid` (одна жёстко зашитая фраза, тонкий
// View-only без VIP, точная проверка порядка): здесь полноценный session-based
// VIP-модуль (под-типы, частичная оценка, корпус, fading, SM-2, прогрессия).
//
// Сквозные методические правила (ОБЯЗАТЕЛЬНЫ, как у эталонов):
//   • «Светофор оценки» (FeedbackTier hit/almost/retry), НИКОГДА «неправильно».
//   • Errorless fading: подсказка после 2 промахов подряд (первая карточка
//     «прилипает» в слот), затем мягкое продвижение раунда.
//   • Без таймеров / соревнований (антифатиговое правило).
//   • Ретро-старт: первые 2 раунда — лёгкие (difficulty 1).
//   • Ротация под-типов: никогда 2 одинаковых под-типа подряд.
//   • На hit — система проговаривает собранную фразу целиком (закрепление по
//     слуху; озвучка `spokenSentence` + текстовый субтитр).
//   • SM-2 spaced repetition: soundTarget «грамматика.синтаксис».
//
// `FeedbackTier` НЕ переобъявляется — используется общий тип из
// `SoundDetectiveModels.swift` (платформенный «светофор», переиспользуемый
// FourthExtra, WordFormation, WhoseTail, SyllableSnail и др.).

// MARK: - SentenceSubtask

/// Под-тип задания. Ротируются (никогда 2 одинаковых подряд).
public enum SentenceSubtask: String, Sendable, CaseIterable, Equatable {
    /// Собрать из 3–5 слов фразу в правильном порядке (СПО / SVO). С 6 лет
    /// (с 5,5 при 3 словах — учитывается возрастным гейтом по minAge в корпусе).
    case wordOrder
    /// Согласование прилагательного с существительным (род / число):
    /// «красн{ый/ая/**ое**}» — выбрать верную форму-карточку. С 6 лет.
    case agreement
    /// Вставить верный предлог (в / на / под / за / у / около) в слот по
    /// картинке-ситуации. С 6 лет.
    case preposition

    /// Минимальный возраст (возрастной гейт, методика / F1-018).
    public var minAge: Int {
        switch self {
        case .wordOrder:   return 6
        case .agreement:   return 6
        case .preposition: return 6
        }
    }
}

// MARK: - TokenRole

/// Грамматическая роль карточки-слова (для VoiceOver «предлог на», для
/// частичной оценки «перепутан только предлог» и для разметки слотов).
public enum TokenRole: String, Sendable, CaseIterable, Equatable {
    case subject
    case verb
    case prep
    case object
    case adjective
    case noun
    /// Слот-заглушка для предлога (subtask preposition) — заполняется выбором.
    case prepSlot
}

// MARK: - SentenceToken

/// Карточка-слово банка. `isDistractor` — серверная истина (лишнее слово,
/// которое не входит в фразу-цель), скрыта от ViewModel by design.
public struct SentenceToken: Identifiable, Sendable, Equatable {
    public let id: String
    /// Текст слова на карточке («кот», «на», «красное»).
    public let text: String
    /// Иконка карточки (SF Symbol или asset из word_manifest.json). Для
    /// синтаксиса карточки преимущественно текстовые — иконка опциональна.
    public let imageAsset: String?
    /// Грамматическая роль (для VoiceOver и частичной оценки).
    public let role: TokenRole
    /// Лишнее слово-дистрактор (на medium/hard) — не входит в фразу-цель.
    public let isDistractor: Bool

    public init(
        id: String,
        text: String,
        imageAsset: String? = nil,
        role: TokenRole,
        isDistractor: Bool = false
    ) {
        self.id = id
        self.text = text
        self.imageAsset = imageAsset
        self.role = role
        self.isDistractor = isDistractor
    }
}

// MARK: - SentenceRound

/// Один раунд: сцена-подсказка + банк слов-карточек + допустимые порядки.
public struct SentenceRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let subtask: SentenceSubtask
    /// Asset/символ сцены-ситуации (крупно сверху). SF Symbol или asset.
    public let sceneImage: String
    /// Карточки-кандидаты банка (включая дистракторы; перемешиваются в Worker).
    public let bankTokens: [SentenceToken]
    /// Число слотов в ленте (длина фразы-цели, без дистракторов).
    public let slotCount: Int
    /// Допустимые последовательности id токенов (серверная истина для оценки).
    /// Может быть несколько вариантов порядка (синонимичные построения).
    public let acceptedOrders: [[String]]
    /// Целевая фраза для озвучки на hit («Кот спит на диване.»).
    public let spokenSentence: String
    public let difficulty: Int
    /// Минимальный возраст (возрастной гейт).
    public let minAge: Int

    public init(
        id: String,
        subtask: SentenceSubtask,
        sceneImage: String,
        bankTokens: [SentenceToken],
        slotCount: Int,
        acceptedOrders: [[String]],
        spokenSentence: String,
        difficulty: Int,
        minAge: Int
    ) {
        self.id = id
        self.subtask = subtask
        self.sceneImage = sceneImage
        self.bankTokens = bankTokens
        self.slotCount = slotCount
        self.acceptedOrders = acceptedOrders
        self.spokenSentence = spokenSentence
        self.difficulty = difficulty
        self.minAge = minAge
    }

    /// id токенов-дистракторов (не входят ни в один допустимый порядок).
    public var distractorIds: Set<String> {
        Set(bankTokens.filter(\.isDistractor).map(\.id))
    }

    /// Канонический допустимый порядок (первый из `acceptedOrders`) — для
    /// подсказки/подсветки.
    public var canonicalOrder: [String] {
        acceptedOrders.first ?? []
    }

    /// id первой карточки канонического порядка («прилипает» в слот при retry).
    public var firstHintTokenId: String? {
        canonicalOrder.first
    }

    /// Роль токена по id (для частичной оценки «перепутан только предлог»).
    public func role(of tokenId: String) -> TokenRole? {
        bankTokens.first { $0.id == tokenId }?.role
    }
}

// MARK: - SentenceBuilderModels namespace

enum SentenceBuilderModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — форсирует под-тип (иначе подбирается по возрасту).
            let preferredSubtask: SentenceSubtask?
        }

        struct Response: Sendable {
            let rounds: [SentenceRound]
            /// «Звук» сессии для record («грамматика.синтаксис»).
            let soundTarget: String
            /// Возраст ребёнка.
            let childAge: Int
        }

        struct ViewModel: Sendable {
            let title: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд. Признак `isDistractor`/`acceptedOrders` НЕ
        /// передаётся во ViewModel (серверная истина остаётся в Interactor).
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let subtask: SentenceSubtask
            /// Реплика-вопрос Ляли по сцене.
            let promptLyalya: String
            let sceneImage: String
            /// Число слотов ленты (длина фразы-цели).
            let slotCount: Int
            /// Карточки банка в перемешанном порядке (без признака дистрактора).
            let bankCards: [CardViewModel]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        /// Карточка-слово (id + текст + опц. иконка + роль для VoiceOver).
        struct CardViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let text: String
            let imageAsset: String?
            let role: TokenRole
            let accessibilityLabel: String
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            /// Последовательность id карточек, которые ребёнок выложил в слоты.
            let placedOrder: [String]
            /// Номер попытки в текущем раунде (для fading-подсказки).
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            /// Канонический допустимый порядок (для подсветки/подсказки).
            let correctOrder: [String]
            /// Фраза целиком для озвучки на hit (закрепление по слуху).
            let spokenSentence: String
            /// id первой карточки — «прилипает» в слот при retry-подсказке.
            let firstHintTokenId: String?
            let showHint: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: SentenceRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            /// Тёплая реплика Ляли (без «неправильно»).
            let lyalyaLine: String
            /// Озвучка собранной фразы на hit (+ субтитр).
            let spokenSentence: String
            /// Порядок подсветки слотов на retry-подсказке.
            let highlightOrder: [String]
            /// id карточки-подсказки (nil — без подсказки).
            let hintTokenId: String?
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
