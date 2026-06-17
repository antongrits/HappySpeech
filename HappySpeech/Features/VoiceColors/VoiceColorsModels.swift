import Foundation
import SwiftUI

// MARK: - VoiceColors VIP Models
//
// «Голосовые краски» (expansion 2.4) — просодический модуль для детей 5-8 в трёх
// режимах:
//   1. Интонация    — одну фразу сказать вопросом / восклицанием / спокойно;
//      сравнение pitch-контура ребёнка с целевым через `ContourComparator`.
//   2. Логическое ударение — выделить голосом нужное слово; пословный RMS из
//      `AudioService` определяет, какое слово прозвучало громче.
//   3. Эмоция голоса — сказать фразу весело / грустно / удивлённо;
//      `EmotionDetectionService` распознаёт окраску, Ляля «отражает» эмоцию.
//
// Методика: Е. Ф. Архипова, Л. В. Лопатина (просодика при стёртой дизартрии),
// В. И. Селиверстов (выразительность речи при заикании). Без штрафов и баллов —
// мягкая обратная связь, COPPA: запись локальна, on-device, не выгружается.
//
// Open-design: kid-game-voice-colors-1/2/3.html. Тёплая палитра; интонация- и
// эмоция-акценты (lilac / coral / gold / rose) — ТОЛЬКО мелкие семантические
// акценты на крышах домиков / рамках карточек, НИКОГДА не на фоне.
//
// Clean Swift VIP: View → Interactor → Presenter → Models → Workers.

enum VoiceColorsModels {

    // MARK: - Start (загрузка задания текущего режима)

    enum Start {
        struct Request {
            let childId: String
        }
        struct Response {
            let mode: VoiceColorsMode
            let intonation: IntonationTask?
            let stress: StressTask?
            let emotion: EmotionTask?
            /// 0-based индекс задания в сессии и общее число заданий.
            let taskIndex: Int
            let totalTasks: Int
        }
    }

    // MARK: - SelectMode (интонация: выбор домика; эмоция: выбор карточки; ударение: выбор главного слова)

    enum SelectIntonation {
        struct Request {
            let mode: IntonationMode
        }
        struct Response {
            let mode: IntonationMode
            let mark: String
            let hint: String
            let targetContour: [PitchPoint]
        }
    }

    enum SelectStressWord {
        struct Request {
            let wordIndex: Int
        }
        struct Response {
            /// Индекс слова, выбранного ребёнком как главное.
            let chosenIndex: Int
            /// Индекс слова, которое требует текущий вопрос (целевое ударение).
            let targetIndex: Int
            let question: String
        }
    }

    enum SelectEmotion {
        struct Request {
            let emotion: VoiceEmotion
        }
        struct Response {
            let emotion: VoiceEmotion
            let phrase: String
            let hint: String
        }
    }

    // MARK: - LiveSample (поток pitch / RMS во время записи)

    enum LiveSample {
        struct Response {
            /// Live pitch-контур ребёнка (режим интонации).
            let liveContour: [PitchPoint]
            /// Нормализованная мгновенная громкость 0…1 (для волны записи).
            let amplitude: Float
        }
        struct ViewModel {
            let liveContour: [PitchPoint]
            let amplitudeNormalised: CGFloat
        }
    }

    // MARK: - Score (после остановки записи)
    //
    // Универсальный результат попытки для всех трёх режимов: совпадение
    // интонационного контура / попадание ударения / распознанная эмоция.

    enum Score {
        struct Request {
            /// Pitch-контур ребёнка (режим интонации; иначе пустой).
            let liveContour: [PitchPoint]
            /// Пословные RMS-уровни (режим ударения; иначе пустой).
            let perWordRMS: [Float]
            /// PCM-данные записи для анализа эмоции (режим эмоции; иначе nil).
            let pcmData: Data?
        }
        struct Response {
            let mode: VoiceColorsMode
            /// Интонация: сходство контура 0…1.
            let intonationSimilarity: Double
            let modelContour: [PitchPoint]
            let liveContour: [PitchPoint]
            /// Ударение: распознанный громче всех индекс слова и целевой индекс.
            let loudestWordIndex: Int
            let targetWordIndex: Int
            let perWordRMS: [Float]
            /// Эмоция: распознанная окраска и выбранная ребёнком.
            let detectedEmotion: VoiceEmotion
            let chosenEmotion: VoiceEmotion
            /// Удалось ли (контур близок / ударение совпало / эмоция совпала).
            let isMatch: Bool
        }
        struct ViewModel {
            let mode: VoiceColorsMode
            let title: String
            let feedbackMessage: String
            let isMatch: Bool
            // Интонация
            let modelContour: [PitchPoint]
            let liveContour: [PitchPoint]
            // Ударение
            let perWordHeights: [CGFloat]
            let loudestWordIndex: Int
            // Эмоция
            let reflectedEmotion: VoiceEmotion
            let accessibilityLabel: String
        }
    }

    // MARK: - Complete

    enum Complete {
        struct Response {
            let tasksCompleted: Int
            let totalTasks: Int
            /// Доля совпавших попыток (для SM-2; без жёсткого «провала» —
            /// модуль безоценочный, ребёнок всегда продвигается).
            let matchRate: Float
        }
        struct ViewModel {
            let starsEarned: Int
            let completionMessage: String
            let matchRate: Float
        }
    }
}

// MARK: - VoiceColorsMode

/// Три режима внутри модуля «Голосовые краски».
enum VoiceColorsMode: String, Sendable, Equatable, CaseIterable {
    /// Типы интонации (вопрос / восклицание / спокойно) + дорожка мелодии.
    case intonation
    /// Логическое ударение (выделить главное слово голосом, пословный RMS).
    case stress
    /// Эмоциональная окраска голоса (весело / грустно / удивлённо).
    case emotion

    var title: String {
        switch self {
        case .intonation: return String(localized: "voiceColors.mode.intonation",
                                        defaultValue: "Голосовые краски")
        case .stress:     return String(localized: "voiceColors.mode.stress",
                                        defaultValue: "Главное слово")
        case .emotion:    return String(localized: "voiceColors.mode.emotion",
                                        defaultValue: "Эмоции голоса")
        }
    }
}

// MARK: - IntonationMode

/// Тип интонации — «домик» с цветной крышей.
/// Акцент-цвет (lilac / coral / gold) — ТОЛЬКО на крыше домика и рамке, не на фоне.
enum IntonationMode: String, Sendable, Equatable, CaseIterable {
    case question      // вопрос — мелодия вверх (lilac)
    case exclamation   // восклицание — всплеск (coral)
    case calm          // спокойно — ровно (gold)

    var mark: String {
        switch self {
        case .question:    return "?"
        case .exclamation: return "!"
        case .calm:        return "."
        }
    }

    var name: String {
        switch self {
        case .question:    return String(localized: "voiceColors.intonation.question",
                                         defaultValue: "Вопрос")
        case .exclamation: return String(localized: "voiceColors.intonation.exclamation",
                                         defaultValue: "Восклицание")
        case .calm:        return String(localized: "voiceColors.intonation.calm",
                                         defaultValue: "Спокойно")
        }
    }

    /// Стрелка-метафора формы мелодии (для карточки-домика).
    var arrow: String {
        switch self {
        case .question:    return "↗"
        case .exclamation: return "⤴"
        case .calm:        return "→"
        }
    }

    /// SF Symbol для подсказки / a11y.
    var symbol: String {
        switch self {
        case .question:    return "questionmark"
        case .exclamation: return "exclamationmark"
        case .calm:        return "minus"
        }
    }

    /// Мелкий семантический акцент (крыша домика, рамка активного состояния).
    var accent: Color {
        switch self {
        case .question:    return ColorTokens.Brand.lilac
        case .exclamation: return ColorTokens.Brand.primary
        case .calm:        return ColorTokens.Brand.gold
        }
    }

    /// Ключ для построения целевого pitch-контура в `VoiceColorsCorpus`.
    var contourKey: String {
        switch self {
        case .question:    return "question"
        case .exclamation: return "exclamation"
        case .calm:        return "statement"
        }
    }
}

// MARK: - VoiceEmotion

/// Эмоциональная окраска голоса в режиме «Эмоции голоса».
/// Маппится в `DetectedEmotion` (модель EmotionDetection) для распознавания.
enum VoiceEmotion: String, Sendable, Equatable, CaseIterable {
    case joy        // весело (butter-gold)
    case sad        // грустно (lilac)
    case surprise   // удивлённо (rose)

    var emoji: String {
        switch self {
        case .joy:      return "😄"
        case .sad:      return "😢"
        case .surprise: return "😮"
        }
    }

    var name: String {
        switch self {
        case .joy:      return String(localized: "voiceColors.emotion.joy",
                                      defaultValue: "Весело")
        case .sad:      return String(localized: "voiceColors.emotion.sad",
                                      defaultValue: "Грустно")
        case .surprise: return String(localized: "voiceColors.emotion.surprise",
                                      defaultValue: "Удивлённо")
        }
    }

    /// Имя для «зеркала» Ляли («Ляля услышала: Радость 😄»).
    var reflectionName: String {
        switch self {
        case .joy:      return String(localized: "voiceColors.emotion.reflection.joy",
                                      defaultValue: "Радость")
        case .sad:      return String(localized: "voiceColors.emotion.reflection.sad",
                                      defaultValue: "Грусть")
        case .surprise: return String(localized: "voiceColors.emotion.reflection.surprise",
                                      defaultValue: "Удивление")
        }
    }

    /// Мелкий семантический акцент карточки эмоции (рамка / зеркало).
    var accent: Color {
        switch self {
        case .joy:      return ColorTokens.Brand.gold
        case .sad:      return ColorTokens.Brand.lilac
        case .surprise: return ColorTokens.Brand.rose
        }
    }

    /// Состояние маскота, отражающее эмоцию.
    var lyalyaState: LyalyaState {
        switch self {
        case .joy:      return .happy
        case .sad:      return .sad
        case .surprise: return .thinking
        }
    }

    /// Маппинг распознанной моделью эмоции голоса в один из трёх режимов игры.
    /// Модель различает happy / sad / frustrated / neutral; «удивление» в
    /// акустике близко к высокой энергии и подъёму тона — мы трактуем
    /// frustrated/neutral c доминантой подъёма как surprise по сигналу
    /// контура, а здесь даём детерминированный безопасный fallback на
    /// выбранную ребёнком эмоцию (модуль безоценочный — см. Interactor).
    static func from(detected: DetectedEmotion) -> VoiceEmotion {
        switch detected {
        case .happy:      return .joy
        case .sad:        return .sad
        case .frustrated: return .surprise
        case .neutral:    return .joy
        }
    }

    var detected: DetectedEmotion {
        switch self {
        case .joy:      return .happy
        case .sad:      return .sad
        case .surprise: return .frustrated
        }
    }
}

// MARK: - Domain tasks (из pack_prosody_plus.json)

/// Задание режима «интонация»: одна фраза в трёх интонационных вариантах.
struct IntonationTask: Sendable, Equatable, Identifiable {
    let id: String
    let text: String
    let variants: [Variant]

    struct Variant: Sendable, Equatable {
        let mode: IntonationMode
        let mark: String
        let hint: String
    }

    func variant(for mode: IntonationMode) -> Variant? {
        variants.first { $0.mode == mode }
    }
}

/// Задание режима «логическое ударение»: фраза-слова + целевые позиции ударения.
struct StressTask: Sendable, Equatable, Identifiable {
    let id: String
    let words: [String]
    let targets: [Target]

    struct Target: Sendable, Equatable {
        /// Индекс слова, которое нужно выделить голосом.
        let index: Int
        /// Вопрос, на который отвечает выделение этого слова.
        let question: String
        /// Эмодзи-подсказка слова (на чипе).
        let emoji: String
    }
}

/// Задание режима «эмоция голоса»: одна фраза в трёх эмоциональных окрасках.
struct EmotionTask: Sendable, Equatable, Identifiable {
    let id: String
    let text: String
    let options: [Option]

    struct Option: Sendable, Equatable {
        let emotion: VoiceEmotion
        /// Текст фразы с эмоциональной пунктуацией («Снег пошёл!»).
        let phrase: String
        let emoji: String
        let name: String
        let hint: String
    }

    func option(for emotion: VoiceEmotion) -> Option? {
        options.first { $0.emotion == emotion }
    }
}

// MARK: - Phase

/// Фаза экрана — переключает подвью.
enum VoiceColorsPhase: Sendable, Equatable {
    case loading
    case intonation   // три домика интонации + дорожка мелодии
    case stress       // главное слово + пословные RMS-столбики
    case emotion      // три эмоции + зеркало Ляли
    case completed
}

// MARK: - VoiceColorsDisplay (Observable view state)

@MainActor
@Observable
final class VoiceColorsDisplay {

    // Текущий режим / фаза / прогресс
    var phase: VoiceColorsPhase = .loading
    var mode: VoiceColorsMode = .intonation
    var taskIndex: Int = 0
    var totalTasks: Int = 1

    // Запись / воспроизведение
    var isRecording: Bool = false
    var isPlaying: Bool = false
    var liveAmplitude: CGFloat = 0

    // Заголовок / подсказка
    var title: String = ""
    var subtitle: String = ""
    var mascotText: String = ""
    var mascotState: LyalyaState = .explaining

    // --- Интонация ---
    var phraseText: String = ""
    var intonationMode: IntonationMode = .question
    var intonationMark: String = "?"
    var modelContour: [PitchPoint] = []
    var liveContour: [PitchPoint] = []
    var doneIntonationModes: Set<IntonationMode> = []

    // --- Ударение ---
    var stressWords: [String] = []
    var stressEmojis: [String] = []
    var stressQuestion: String = ""
    var stressQuestionEmoji: String = ""
    var targetWordIndex: Int = 0
    var chosenWordIndex: Int = 0
    var perWordHeights: [CGFloat] = []
    var loudestWordIndex: Int = -1

    // --- Эмоция ---
    var emotionPhrase: String = ""
    var chosenEmotion: VoiceEmotion = .joy
    var reflectedEmotion: VoiceEmotion?

    // Результат попытки
    var showResult: Bool = false
    var resultMatch: Bool = false
    var resultMessage: String = ""

    // Финал
    var starsEarned: Int = 0
    var completionMessage: String = ""
    var matchRate: Float = 0

    var pendingExit: Bool = false
}

// MARK: - Scoring helpers

enum VoiceColorsScoring {
    /// Звёзды по доле совпавших попыток: ≥0.8→3, ≥0.5→2, иначе 1
    /// (минимум 1 — модуль безоценочный, ребёнок всегда уходит с успехом).
    static func stars(for matchRate: Float) -> Int {
        switch matchRate {
        case 0.8...: return 3
        case 0.5...: return 2
        default:     return 1
        }
    }

    /// Порог «совпадения» интонационного контура с целевым.
    static let intonationMatchThreshold: Double = 0.55
}
