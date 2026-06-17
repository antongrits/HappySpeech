import Foundation
import SwiftUI

// MARK: - LiveSounds VIP Models
//
// «Живые звуки» — устный фонематический синтез (операция, обратная анализу).
// Ляля произносит слово ПО ЗВУКАМ с управляемой паузой ([к]…[о]…[т]); ребёнок
// мысленно сливает звуки в слово и выбирает картинку из 4 (рецептивно-выборочный
// ответ, БЕЗ ASR — стабильно офлайн). На верный ответ кружочки-звуки сдвигаются
// вплотную и под ними появляется слитное слово — это и есть синтез.
//
// Два режима внутри сессии (см. open-design kid-game-live-sounds-1/2.html):
//   • collect (экран 1) — «Собери слово из звуков»: SoundBeadRow (кружочки-звуки),
//     SpeedSegment (управление паузами), PictureGrid 2×2 — выбор картинки.
//   • bench  (экран 2) — «Звуки-человечки встают в ряд»: SoundCharacterRow +
//     SoundBench — собрать ряд человечков по порядку звучания, затем слияние.
//
// Методика: Д. Б. Эльконин, Г. А. Каше — звуковой синтез как предиктор чтения.
// Контент — pack_live_sounds.json. Гласный — rose, согласный — lilac (оба тёплые
// токены палитры).

enum LiveSoundsModels {

    // MARK: - Start

    enum Start {
        struct Request {
            var childId: String
        }
        struct Response {
            var rounds: [LiveSoundsRound]
        }
        struct ViewModel {
            var firstRound: RoundViewModel?
            var totalRounds: Int
        }
    }

    // MARK: - LoadRound

    enum LoadRound {
        struct Request {
            var roundIndex: Int
        }
        struct Response {
            var round: LiveSoundsRound
            var roundIndex: Int
            var totalRounds: Int
        }
    }

    // MARK: - ChoosePicture (collect-режим)
    //
    // Ребёнок выбрал картинку-ответ из 2×2. Верно → звуки сливаются в слово,
    // картинка подсвечивается, остальные приглушаются. Неверно → мягкая
    // подсказка + повтор пофонемной озвучки (без штрафа, errorless).

    enum ChoosePicture {
        struct Request {
            /// Индекс выбранной картинки в сетке (0…3).
            var optionIndex: Int
        }
        struct Response {
            var optionIndex: Int
            var isCorrect: Bool
            /// Индекс правильной картинки в сетке (для подсветки при подсказке).
            var correctIndex: Int
            var word: String
        }
        struct ViewModel {
            var selectedIndex: Int?
            var correctIndex: Int?
            var isCorrect: Bool
            var feedbackText: String
            var solved: Bool
        }
    }

    // MARK: - PlaceCharacter (bench-режим)
    //
    // Ребёнок выбрал человечка-звук со «скамейки» для следующего пустого места
    // в ряду. Верно → человечек встаёт в ряд, активным становится следующее
    // место. Неверно → мягкая подсказка + повтор слова по звукам.

    enum PlaceCharacter {
        struct Request {
            /// Индекс выбранного человечка на «скамейке» (bench).
            var benchIndex: Int
        }
        struct Response {
            var benchIndex: Int
            var isCorrect: Bool
            /// Позиция в ряду, к которой относилась попытка (0-based).
            var slotIndex: Int
            /// Буква-звук выбранного человечка.
            var letter: String
            /// Ряд собран полностью.
            var rowComplete: Bool
        }
        struct ViewModel {
            /// Поставленные в ряд звуки (по порядку).
            var placedLetters: [String]
            /// Использованные индексы «скамейки» (приглушаются).
            var usedBenchIndices: Set<Int>
            /// Следующее активное место в ряду или nil, если ряд собран.
            var activeSlotIndex: Int?
            var feedbackCorrect: Bool
            var feedbackText: String
            var rowComplete: Bool
        }
    }

    // MARK: - Speed (управление паузами)

    enum Speed {
        struct Request {
            var pace: LiveSoundsPace
        }
    }

    // MARK: - Complete

    enum Complete {
        struct Request {}
        struct Response {
            var roundsSolved: Int
            var totalRounds: Int
            var score: Float
        }
        struct ViewModel {
            var starsEarned: Int
            var scoreLabel: String
            var completionMessage: String
            var finalScore: Float
        }
    }

    // MARK: - View-side round model

    struct RoundViewModel: Equatable {
        var word: String
        var imageAsset: String
        var sounds: [LiveSoundUnit]
        var options: [PictureOption]
        var benchLetters: [LiveSoundUnit]
        var mode: LiveSoundsMode
    }
}

// MARK: - Domain types

/// Темп пофонемной озвучки — длина паузы между звуками. SpeedSegment в UI.
enum LiveSoundsPace: String, Sendable, Equatable, CaseIterable {
    case slow      // длинные паузы
    case medium    // средние
    case fast      // быстро

    /// Пауза между звуками в секундах (управляет «живостью» синтеза).
    var gapSeconds: Double {
        switch self {
        case .slow:   return 1.1
        case .medium: return 0.6
        case .fast:   return 0.25
        }
    }

    var displayName: String {
        switch self {
        case .slow:   return String(localized: "liveSounds.pace.slow", defaultValue: "Длинные")
        case .medium: return String(localized: "liveSounds.pace.medium", defaultValue: "Средние")
        case .fast:   return String(localized: "liveSounds.pace.fast", defaultValue: "Быстро")
        }
    }
}

/// Режим раунда внутри сессии.
enum LiveSoundsMode: String, Sendable, Equatable {
    /// Экран 1: собрать слово из звуков → выбрать картинку.
    case collect
    /// Экран 2: звуки-человечки встают в ряд → слияние.
    case bench
}

/// Тип звука для цвета кружочка/человечка. Гласный — rose, согласный — lilac
/// (оба тёплые токены палитры; не off-palette).
enum LiveSoundType: String, Sendable, Equatable, Codable {
    case vowel
    case consonant

    /// Цвет кружочка/головы человечка — ТОЛЬКО на круглой фишке, не на фоне.
    var beadColor: Color {
        switch self {
        case .vowel:     return ColorTokens.Brand.rose
        case .consonant: return ColorTokens.Brand.lilac
        }
    }
}

/// Один звук слова (звуковая единица, заглавная буква).
struct LiveSoundUnit: Sendable, Equatable, Identifiable {
    var id: String { letter + "·" + String(position) }
    var letter: String
    var type: LiveSoundType
    /// Позиция в слове (0-based) — делает id уникальным при повторах букв.
    var position: Int
}

/// Один вариант-картинка в сетке 2×2 collect-режима.
struct PictureOption: Sendable, Equatable, Identifiable {
    var id: Int
    var word: String
    var imageAsset: String
    var isCorrect: Bool
}

/// Раунд игры: слово для синтеза + варианты + «скамейка» человечков.
struct LiveSoundsRound: Sendable, Equatable, Identifiable {
    var id: String
    var word: String
    var imageAsset: String
    var sounds: [LiveSoundUnit]
    /// 4 картинки-ответа (collect). Ровно одна `isCorrect`.
    var options: [PictureOption]
    /// Человечки на «скамейке» (bench): верные звуки слова + 1–2 отвлекающих,
    /// в перемешанном порядке.
    var benchLetters: [LiveSoundUnit]
    var mode: LiveSoundsMode

    var soundCount: Int { sounds.count }
}

/// Фаза экрана — управляет переключением подвью.
enum LiveSoundsPhase: Sendable, Equatable {
    case loading
    case collect     // экран 1: собрать слово из звуков → выбор картинки
    case bench       // экран 2: человечки встают в ряд
    case completed
}

// MARK: - View display state

@MainActor
@Observable
final class LiveSoundsDisplay {

    // Раунд
    var word: String = ""
    var imageAsset: String = ""
    var sounds: [LiveSoundUnit] = []
    var options: [PictureOption] = []
    var benchLetters: [LiveSoundUnit] = []
    var mode: LiveSoundsMode = .collect

    // Прогресс по раундам сессии
    var roundIndex: Int = 0
    var totalRounds: Int = 1

    // Темп пофонемной озвучки
    var pace: LiveSoundsPace = .medium

    // Озвучка / подсветка
    var isPlaying: Bool = false
    /// Индекс звука, который Ляля произносит «сейчас» (подпрыгивает); nil — пауза.
    var nowSoundIndex: Int?

    // collect-режим: выбор картинки
    var selectedOptionIndex: Int?
    var correctOptionIndex: Int?
    var solved: Bool = false

    // bench-режим: ряд человечков
    var placedLetters: [String] = []
    var usedBenchIndices: Set<Int> = []
    var activeSlotIndex: Int?
    var rowComplete: Bool = false

    // Обратная связь
    var feedbackCorrect: Bool = false
    var feedbackText: String = ""
    var showFeedback: Bool = false

    // Фаза
    var phase: LiveSoundsPhase = .loading

    // Финал
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
    var pendingExit: Bool = false
}

// MARK: - Scoring

enum LiveSoundsScoring {
    /// ≥0.9→3, ≥0.7→2, ≥0.5→1, иначе 0.
    static func stars(for score: Float) -> Int {
        switch score {
        case 0.9...:    return 3
        case 0.7..<0.9: return 2
        case 0.5..<0.7: return 1
        default:        return 0
        }
    }
}
