import Foundation

// MARK: - FourthExtraModels (Clean Swift: Models)
//
// F2-005 «Четвёртый лишний» (Wave 2).
//
// Классификация и обобщение: из 4 картинок (сетка 2×2) ребёнок убирает
// «лишнюю». Два варианта ([[speech-methodology]], Филичева-Туманова):
//   • semantic — лишнее по смыслу/категории/функции/среде обитания. Развивает
//     операции обобщения и классификации, объём и системность словаря,
//     вербально-логическое мышление (мишень ОНР: бедность словаря и
//     несформированность обобщающих понятий).
//   • phonetic — из 4 слов 3 содержат целевой звук, одно — нет. Развивает
//     фонематическую дифференциацию на уровне слова, поддерживает
//     автоматизацию (мишень ФФН).
//
// Игровое ядро — паттерн «сетка карточек + выбор одной» (как
// AnimalSoundsBingo / PhonemeFamilyMatcher), доведён до полного VIP. Контент —
// `FourthExtraCorpus` (`pack_fourth_extra.json`, offline / on-device).
//
// Сквозные методические правила (ОБЯЗАТЕЛЬНЫ):
//   • «Светофор оценки» (FeedbackTier hit/almost/retry), НИКОГДА «неправильно».
//   • Подсказка после 2 промахов подряд (errorless fading).
//   • Без таймеров/соревнований.
//   • При попадании — озвученное обобщение + обруч-категория (методическое
//     ядро: закрепление обобщающего понятия).
//   • Вербализация «почему лишний» — опционально для 7–8 лет (семантический
//     вариант), без оценки произношения.
//
// `FeedbackTier` НЕ переобъявляется — используется общий тип из
// `SoundDetectiveModels.swift` (платформенный «светофор», переиспользуемый
// SyllableSnail и др.).

// MARK: - ExtraVariant

/// Вариант игры: семантический (по смыслу) или фонетический (по звуку).
public enum ExtraVariant: String, Sendable, CaseIterable, Equatable {
    /// Лишнее по смыслу/категории/функции/среде обитания.
    case semantic
    /// Лишнее по целевому звуку (3 слова со звуком + 1 без).
    case phonetic
}

// MARK: - ExtraRule

/// Признак, по которому объединены «свои» (для формирования обобщения).
public enum ExtraRule: String, Sendable, CaseIterable, Equatable {
    /// По категории (фрукты / транспорт / посуда …).
    case category
    /// По функции (чем пользуются — столовые приборы …).
    case function
    /// По среде обитания (домашние / дикие / лесные / рыбы …).
    case habitat
    /// По целевому звуку (фонетический вариант).
    case sound
}

// MARK: - ExtraCard

/// Карточка-картинка в наборе. `isExtra` — серверная истина, скрыта от
/// ViewModel (Presenter не передаёт её во View, чтобы ответ нельзя было
/// «подсмотреть» из вёрстки).
public struct ExtraCard: Identifiable, Sendable, Equatable {
    public let id: String
    public let word: String
    /// Asset картинки (из word_manifest.json).
    public let imageAsset: String
    /// Является ли карточка «лишней» в наборе (ровно одна на набор).
    public let isExtra: Bool
    /// Почему лишняя (для тёплой подсказки / объяснения).
    public let extraReason: String?

    public init(
        id: String,
        word: String,
        imageAsset: String,
        isExtra: Bool,
        extraReason: String?
    ) {
        self.id = id
        self.word = word
        self.imageAsset = imageAsset
        self.isExtra = isExtra
        self.extraReason = extraReason
    }
}

// MARK: - FourthExtraRound

/// Один раунд: набор из 4 карточек, вариант, правило и обобщение.
public struct FourthExtraRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let variant: ExtraVariant
    public let rule: ExtraRule
    /// Обобщающее понятие «своих» (semantic). nil для phonetic — там обобщение
    /// формируется из targetSound.
    public let categoryLabel: String?
    /// Целевой звук (phonetic). nil для semantic.
    public let targetSound: String?
    /// Карточки набора (порядок перемешивается в Worker/Presenter).
    public let cards: [ExtraCard]
    public let difficulty: Int
    /// Минимальный возраст (возрастной гейт, методика).
    public let minAge: Int

    public init(
        id: String,
        variant: ExtraVariant,
        rule: ExtraRule,
        categoryLabel: String?,
        targetSound: String?,
        cards: [ExtraCard],
        difficulty: Int,
        minAge: Int
    ) {
        self.id = id
        self.variant = variant
        self.rule = rule
        self.categoryLabel = categoryLabel
        self.targetSound = targetSound
        self.cards = cards
        self.difficulty = difficulty
        self.minAge = minAge
    }

    /// id «лишней» карточки набора (ровно одна).
    public var extraCardId: String? {
        cards.first { $0.isExtra }?.id
    }
}

// MARK: - FourthExtraModels namespace

enum FourthExtraModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — форсирует вариант (иначе подбирается по треку/возрасту).
            let preferredVariant: ExtraVariant?
        }

        struct Response: Sendable {
            let rounds: [FourthExtraRound]
            /// «Звук» сессии для record (semantic → "лексика", phonetic → звук).
            let soundTarget: String
            /// Возраст ребёнка (для гейта вербализации «почему лишний»).
            let childAge: Int
        }

        struct ViewModel: Sendable {
            let title: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд (сетка 2×2). `isExtra` НЕ передаётся.
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let variant: ExtraVariant
            /// Реплика Ляли (вопрос).
            let promptLyalya: String
            /// Карточки в перемешанном порядке, без признака «лишний».
            let cards: [CardViewModel]
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        /// Карточка набора (isExtra скрыт by design).
        struct CardViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let imageAsset: String
            let word: String
            let accessibilityLabel: String
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            /// id выбранной ребёнком карточки.
            let chosenCardId: String
            /// Номер попытки в текущем раунде (для fading-подсказки).
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            /// id «лишней» карточки (для подсветки/улёта при hit).
            let extraCardId: String
            /// Обобщение «своих» (для озвучки и обруча-категории).
            let groupingLabel: String?
            /// Почему лишняя (тёплое объяснение на hit).
            let extraReason: String?
            /// id трёх «не-лишних» карточек (подсветка-подсказка после 2 промахов).
            let hintCardIds: [String]
            /// Показать подсказку (сузить выбор) — после 2 промахов.
            let showHint: Bool
            /// Спросить «почему лишний» (7–8 лет, semantic) — после верного выбора.
            let askWhy: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: FourthExtraRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            /// Тёплая реплика Ляли (без «неправильно»).
            let lyalyaLine: String
            let extraCardId: String
            /// Озвученное обобщение («Яблоко, груша, банан — это фрукты»).
            let groupingLabel: String?
            /// id карточек для подсказки (приглушаем/подсвечиваем «своих»).
            let hintCardIds: [String]
            /// Мягкий вопрос «А почему лишний?» (7–8, semantic).
            let askWhy: Bool
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
