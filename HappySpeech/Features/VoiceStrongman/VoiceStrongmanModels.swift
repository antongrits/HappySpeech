import Foundation
import SwiftUI

// MARK: - VoiceStrongman VIP Models
//
// «Силач-голос» (expansion 2.10) — фонопедический модуль силы и высоты голоса
// для детей 5-8 в двух режимах:
//   1. Громко-тихо. «Звуковой шар» растёт от громкости голоса (RMS из
//      AudioService): «спой тихо, как мышка / громко, как мишка». Золотая
//      зона-полоса = комфортная средняя громкость (защита от крика —
//      поощряется попадание В ЗОНУ, НЕ максимум).
//   2. Лесенка голоса. Высота тона ведёт цыплёнка-климбера по ступенькам
//      вверх/вниз (reuse питч из KaraokePitch / YINPitchTracker): тянем
//      «у-у-у» по плавной глиссандо-дорожке от низкого к высокому и обратно.
//
// Методика: Е. С. Алмазова, Е. Ф. Архипова (сила и высота голоса при дизартрии
// и ОНР), О. С. Орлова (фонопедия). Без штрафов и баллов — мягкая обратная
// связь, COPPA: запись локальна, on-device, не выгружается.
//
// Open-design: kid-game-voice-strongman-1/2.html. Тёплая палитра; gold/lilac/mint
// акценты — ТОЛЬКО мелкие семантические (зона-полоса, дорожка глиссандо, success-
// кольцо), НИКОГДА не на фоне.
//
// Clean Swift VIP: View → Interactor → Presenter → Models → Workers.

enum VoiceStrongmanModels {

    // MARK: - Start (загрузка задания текущего режима)

    enum Start {
        struct Request {
            let childId: String
        }
    }

    // MARK: - SelectLevel (громкость: выбор зверька-уровня)

    enum SelectLevel {
        struct Request {
            let level: LoudnessLevel
        }
    }

    // MARK: - SelectDirection (высота: вверх/вниз)

    enum SelectDirection {
        struct Request {
            let direction: PitchDirection
        }
    }

    // MARK: - LiveSample (поток RMS / питча во время записи)

    enum LiveSample {
        struct Response {
            /// Нормализованная мгновенная громкость 0…1 (для шара/тиков).
            let loudness: Float
            /// Нормализованная высота тона 0…1 (для климбера на лесенке).
            let pitchNorm: Float
            /// Достигнута ли (мгновенно) комфортная зона / целевая ступень.
            let inTarget: Bool
            /// Живой питч-контур (для глиссандо-дорожки в режиме высоты).
            let liveContour: [PitchPoint]
        }
        struct ViewModel {
            let loudnessNormalised: CGFloat
            let pitchNormalised: CGFloat
            let inTarget: Bool
            let liveContour: [PitchPoint]
        }
    }

    // MARK: - Score (после остановки записи)

    enum Score {
        struct Response {
            let mode: VoiceStrongmanMode
            /// Громкость: средняя нормализованная громкость 0…1 и попадание в зону.
            let loudnessAverage: Float
            let loudnessInBand: Bool
            /// Высота: пройденная доля лесенки 0…1 и совпадение направления.
            let ladderReached: Float
            let directionMatched: Bool
            /// Живой питч-контур попытки (для финальной глиссандо-дорожки).
            let liveContour: [PitchPoint]
            /// Удалось ли в целом (зона / лесенка пройдена достаточно).
            let isMatch: Bool
        }
        struct ViewModel {
            let mode: VoiceStrongmanMode
            let title: String
            let feedbackMessage: String
            let isMatch: Bool
            // Громкость
            let loudnessNormalised: CGFloat
            let loudnessInBand: Bool
            // Высота
            let ladderReached: CGFloat
            let liveContour: [PitchPoint]
            let directionMatched: Bool
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

// MARK: - VoiceStrongmanMode

/// Два режима внутри модуля «Силач-голос».
enum VoiceStrongmanMode: String, Sendable, Equatable, CaseIterable {
    /// Сила голоса: попадание в зону комфортной громкости по RMS (антикрик).
    case loudness
    /// Высота голоса: глиссандо вверх/вниз по питч-лесенке.
    case pitch

    var title: String {
        switch self {
        case .loudness: return String(localized: "voiceStrongman.mode.loudness",
                                      defaultValue: "Громко-тихо")
        case .pitch:    return String(localized: "voiceStrongman.mode.pitch",
                                      defaultValue: "Лесенка голоса")
        }
    }
}

// MARK: - LoudnessLevel

/// Целевой уровень громкости — зверёк-метафора (тихо/средне/громко).
/// Акцент-цвет — ТОЛЬКО мелкий семантический (рамка активной карточки).
enum LoudnessLevel: String, Sendable, Equatable, CaseIterable {
    case quiet    // тихо, как мышка
    case medium   // средне, как котик
    case loud     // громко, как мишка

    var emoji: String {
        switch self {
        case .quiet:  return "🐭"
        case .medium: return "🐱"
        case .loud:   return "🐻"
        }
    }

    var name: String {
        switch self {
        case .quiet:  return String(localized: "voiceStrongman.loud.quiet",
                                    defaultValue: "Тихо")
        case .medium: return String(localized: "voiceStrongman.loud.medium",
                                    defaultValue: "Средне")
        case .loud:   return String(localized: "voiceStrongman.loud.loud",
                                    defaultValue: "Громко")
        }
    }

    var who: String {
        switch self {
        case .quiet:  return String(localized: "voiceStrongman.loud.quiet.who",
                                    defaultValue: "как мышка")
        case .medium: return String(localized: "voiceStrongman.loud.medium.who",
                                    defaultValue: "как котик")
        case .loud:   return String(localized: "voiceStrongman.loud.loud.who",
                                    defaultValue: "как мишка")
        }
    }

    /// Центр комфортной зоны громкости (нормализованный 0…1).
    var bandCenter: Float {
        switch self {
        case .quiet:  return 0.30
        case .medium: return 0.55
        case .loud:   return 0.78
        }
    }

    /// Полуширина зоны вокруг центра — «удобная громкость» (защита от крика:
    /// верхняя граница не достигает максимума даже для «громко»).
    var bandHalfWidth: Float { 0.16 }

    var lowerBound: Float { max(0, bandCenter - bandHalfWidth) }
    var upperBound: Float { min(1, bandCenter + bandHalfWidth) }

    /// Мелкий семантический акцент карточки уровня (рамка активного состояния).
    var accent: Color {
        switch self {
        case .quiet:  return ColorTokens.Brand.lilac
        case .medium: return ColorTokens.Brand.gold
        case .loud:   return ColorTokens.Brand.primary
        }
    }

    /// Ключ уровня в паке.
    var packKey: String { rawValue }
}

// MARK: - PitchDirection

/// Направление глиссандо на лесенке голоса.
enum PitchDirection: String, Sendable, Equatable, CaseIterable {
    case up    // вверх — тонким голоском
    case down  // вниз — низким голосом

    var arrow: String {
        switch self {
        case .up:   return "↗"
        case .down: return "↘"
        }
    }

    var name: String {
        switch self {
        case .up:   return String(localized: "voiceStrongman.dir.up",
                                  defaultValue: "Вверх")
        case .down: return String(localized: "voiceStrongman.dir.down",
                                  defaultValue: "Вниз")
        }
    }

    var who: String {
        switch self {
        case .up:   return String(localized: "voiceStrongman.dir.up.who",
                                  defaultValue: "тонким голоском")
        case .down: return String(localized: "voiceStrongman.dir.down.who",
                                  defaultValue: "низким голосом")
        }
    }

    var symbol: String {
        switch self {
        case .up:   return "arrow.up.right"
        case .down: return "arrow.down.right"
        }
    }
}

// MARK: - Domain tasks (из pack_voice_power.json)

/// Задание режима «громко-тихо»: гласный + целевой уровень громкости.
struct LoudnessExercise: Sendable, Equatable, Identifiable {
    let id: String
    let vowel: String
    let prompt: String
    let level: LoudnessLevel
    let animal: String
    let hint: String
}

/// Задание режима «лесенка голоса»: гласный + направление + число ступеней.
struct PitchExercise: Sendable, Equatable, Identifiable {
    let id: String
    let vowel: String
    let prompt: String
    let direction: PitchDirection
    let steps: Int
    let hint: String
}

// MARK: - VoiceStrongmanSession

/// Собранная сессия: списки заданий по каждому режиму.
struct VoiceStrongmanSession: Sendable, Equatable {
    let loudness: [LoudnessExercise]
    let pitch: [PitchExercise]

    var isEmpty: Bool { loudness.isEmpty && pitch.isEmpty }
}

// MARK: - Phase

/// Фаза экрана — переключает подвью.
enum VoiceStrongmanPhase: Sendable, Equatable {
    case loading
    case loudness   // звуковой шар + зона-полоса + RMS-тики
    case pitch      // лесенка + глиссандо-дорожка + климбер
    case completed
}

// MARK: - VoiceStrongmanDisplay (Observable view state)

@MainActor
@Observable
final class VoiceStrongmanDisplay {

    // Текущий режим / фаза / прогресс
    var phase: VoiceStrongmanPhase = .loading
    var mode: VoiceStrongmanMode = .loudness
    var taskIndex: Int = 0
    var totalTasks: Int = 1

    // Запись / воспроизведение
    var isRecording: Bool = false
    var isPlaying: Bool = false

    // Заголовок / подсказка
    var title: String = ""
    var subtitle: String = ""
    var mascotText: String = ""
    var mascotState: LyalyaState = .explaining

    // Гласный текущего задания (для шара / лесенки).
    var vowel: String = ""

    // --- Громкость ---
    var loudnessLevel: LoudnessLevel = .medium
    var animal: String = "🐱"
    /// Мгновенная нормализованная громкость 0…1 (растёт шар, живые тики).
    var liveLoudness: CGFloat = 0
    var bandLower: CGFloat = 0
    var bandUpper: CGFloat = 1
    var loudnessInBand: Bool = false

    // --- Высота ---
    var pitchDirection: PitchDirection = .up
    var ladderSteps: Int = 5
    /// Мгновенная нормализованная высота 0…1 (позиция климбера).
    var livePitch: CGFloat = 0
    var ladderReached: CGFloat = 0
    var liveContour: [PitchPoint] = []
    var directionMatched: Bool = false

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

enum VoiceStrongmanScoring {
    /// Звёзды по доле совпавших попыток: ≥0.8→3, ≥0.5→2, иначе 1
    /// (минимум 1 — модуль безоценочный, ребёнок всегда уходит с успехом).
    static func stars(for matchRate: Float) -> Int {
        switch matchRate {
        case 0.8...: return 3
        case 0.5...: return 2
        default:     return 1
        }
    }

    /// Доля кадров записи, которые должны попасть в зону, чтобы засчитать
    /// попадание в комфортную громкость.
    static let loudnessInBandFraction: Float = 0.45

    /// Доля лесенки, которую нужно пройти, чтобы засчитать глиссандо.
    static let ladderReachThreshold: Float = 0.6

    /// Нижний порог частоты детского голоса для нормализации высоты (Hz).
    static let pitchFloorHz: Double = 160

    /// Верхний порог частоты для нормализации высоты (Hz).
    static let pitchCeilHz: Double = 440
}
