import Foundation

// MARK: - SoundDetectiveModels (Clean Swift: Models)
//
// F2-009 «Звуковой детектив» (Wave 2).
//
// Позиционный фонематический анализ — определение позиции целевого звука
// в линейном звуковом ряду слова (начало / середина / конец / отсутствует).
// Высшая операция фонематического восприятия (зона Вернике), прямая
// профилактика дисграфии/дислексии ([[speech-methodology]], Ткаченко, Каше,
// Филичева-Чевелёва; [[correction-stages]] — стык wordInit/wordMed/wordFinal
// и diff).
//
// Игровое ядро: Ляля-детектив, картинка-улика, «полоска слова» из зон-окошек
// (начало · середина · конец · «звука нет»), «лупа» — ребёнок ищет
// спрятавшийся звук. Контент — `SoundDetectiveCorpus`
// (`pack_sound_detective.json`, offline / on-device).
//
// Сквозные методические правила (ОБЯЗАТЕЛЬНЫ):
//   • «Светофор оценки» (FeedbackTier hit/almost/retry), НИКОГДА «неправильно».
//   • Подсказка после 2 промахов подряд (errorless fading).
//   • Без таймеров/соревнований.
//   • Ретро-старт: первые 2 раунда — на лёгком уровне.

// MARK: - SoundZone

/// Позиция звука в слове (зона «полоски слова»). Совместимо с
/// `PhonemePosition` из PhonemicListening (start/middle/end) + `absent` для
/// уровня withAbsent (негативный фонематический выбор — звука в слове нет).
public enum SoundZone: String, Sendable, CaseIterable, Equatable {
    case start
    case middle
    case end
    /// Звука в слове нет вовсе (уровень withAbsent).
    case absent
}

// MARK: - SoundDetectiveLevel

/// Уровень сложности «детектива»: число доступных зон.
public enum SoundDetectiveLevel: String, Sendable, CaseIterable, Equatable {
    /// 2 зоны (начало / конец). Возраст ≥ 5.
    case binary
    /// 3 зоны (начало / середина / конец). Возраст ≥ 6.
    case ternary
    /// 4 зоны (+ «звука нет»). Возраст ≥ 7.
    case withAbsent

    /// Доступные для выбора зоны на этом уровне.
    public var zones: [SoundZone] {
        switch self {
        case .binary:     return [.start, .end]
        case .ternary:    return [.start, .middle, .end]
        case .withAbsent: return [.start, .middle, .end, .absent]
        }
    }

    /// Минимальный возраст (возрастной гейт, F1-018 / методика).
    public var minAge: Int {
        switch self {
        case .binary:     return 5
        case .ternary:    return 6
        case .withAbsent: return 7
        }
    }

    /// Следующий уровень сложности (для перехода 80% × 2 сессии).
    public var next: SoundDetectiveLevel? {
        switch self {
        case .binary:     return .ternary
        case .ternary:    return .withAbsent
        case .withAbsent: return nil
        }
    }
}

// MARK: - FeedbackTier

/// «Светофор оценки» (F1-019). Ни одного слова «неправильно».
public enum FeedbackTier: String, Sendable, Equatable {
    /// Попал — зелёный, success-хаптика, Ляля радуется.
    case hit
    /// Почти — жёлтый, мягко переслушать с интонационным выделением.
    case almost
    /// Попробуем ещё — нейтрально-тёплый, подсказка (после 2 промахов).
    case retry
}

// MARK: - SoundDetectiveItem

/// Слово-улика с позиционной разметкой целевого звука.
public struct SoundDetectiveItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let word: String
    /// Asset картинки-улики (из word_manifest.json).
    public let imageAsset: String
    public let targetSound: String
    public let soundFamily: String
    /// Позиция целевого звука (или `.absent`, если звука нет).
    public let position: SoundZone
    /// Полная звуковая последовательность слова (для интонационного
    /// выделения целевого звука и анализа).
    public let sounds: [String]
    public let difficulty: Int
    /// Минимальный уровень, на котором допустимо это слово.
    public let minLevel: SoundDetectiveLevel

    public init(
        id: String,
        word: String,
        imageAsset: String,
        targetSound: String,
        soundFamily: String,
        position: SoundZone,
        sounds: [String],
        difficulty: Int,
        minLevel: SoundDetectiveLevel
    ) {
        self.id = id
        self.word = word
        self.imageAsset = imageAsset
        self.targetSound = targetSound
        self.soundFamily = soundFamily
        self.position = position
        self.sounds = sounds
        self.difficulty = difficulty
        self.minLevel = minLevel
    }

    /// Индекс первого вхождения целевого звука в `sounds` (для анимации
    /// «звук подпрыгивает»). `nil`, если звука нет (position == .absent).
    public var targetSoundIndex: Int? {
        let target = targetSound.lowercased()
        return sounds.firstIndex { $0.lowercased() == target }
    }
}

// MARK: - SoundDetectiveRound

/// Один раунд «детектива»: улика + уровень + доступные зоны.
public struct SoundDetectiveRound: Identifiable, Sendable, Equatable {
    public let id: String
    public let item: SoundDetectiveItem
    public let level: SoundDetectiveLevel
    public let availableZones: [SoundZone]

    public init(id: String, item: SoundDetectiveItem, level: SoundDetectiveLevel) {
        self.id = id
        self.item = item
        self.level = level
        self.availableZones = level.zones
    }
}

// MARK: - SoundDetectiveModels namespace

enum SoundDetectiveModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            /// Если задан — форсирует уровень (иначе подбирается по возрасту).
            let preferredLevel: SoundDetectiveLevel?
        }

        struct Response: Sendable {
            let rounds: [SoundDetectiveRound]
            let targetSound: String
            let level: SoundDetectiveLevel
        }

        struct ViewModel: Sendable {
            let title: String
            let totalRounds: Int
            let firstRound: RoundViewModel
        }

        /// Готовый к показу раунд.
        struct RoundViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let imageAsset: String
            let wordText: String
            /// Реплика Ляли-детектива (вопрос).
            let promptLyalya: String
            let zones: [ZoneViewModel]
            /// id озвучки слова (для кнопки «Ещё разок»).
            let audioWordId: String
            let progressLabel: String
            let progressFraction: Double
            let accessibilityLabel: String
        }

        /// Зона-окошко «полоски слова».
        struct ZoneViewModel: Identifiable, Sendable, Equatable {
            let id: SoundZone
            /// Подпись («в начале» / «в серединке» / «в конце» / «звука нет»).
            let label: String
            /// Мнемонический цвет окошка (НЕ оценка): зелёный/жёлтый/красный/серый.
            let colorHint: ZoneColorHint
            let accessibilityLabel: String
        }

        /// Мнемонический цвет зоны (а не «светофор оценки»).
        enum ZoneColorHint: String, Sendable, Equatable {
            case start   // зелёный
            case middle  // жёлтый
            case end     // красный
            case absent  // серый
        }
    }

    // MARK: Answer

    enum Answer {
        struct Request: Sendable {
            /// Выбранная ребёнком зона.
            let chosenZone: SoundZone
            /// Номер попытки в текущем раунде (для fading-подсказки).
            let attemptInRound: Int
        }

        struct Response: Sendable {
            let feedback: FeedbackTier
            let correctZone: SoundZone
            /// Индекс целевого звука для анимации (nil для absent).
            let highlightSoundIndex: Int?
            /// Показать подсказку (пульсация целевой зоны) — после 2 промахов.
            let showHint: Bool
            /// Переиграть слово с интонационным выделением (на almost/retry).
            let replayWithEmphasis: Bool
            let advancedToNextRound: Bool
            let isFinished: Bool
            let nextRound: SoundDetectiveRound?
            let nextRoundIndex: Int?
            let correctCount: Int
            let totalRounds: Int
        }

        struct ViewModel: Sendable {
            let feedback: FeedbackTier
            /// Тёплая реплика Ляли (без «неправильно»).
            let lyalyaLine: String
            let correctZone: SoundZone
            let highlightSoundIndex: Int?
            let replayWithEmphasis: Bool
            /// Зона для пульсации-подсказки (nil — без подсказки).
            let hintZone: SoundZone?
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
