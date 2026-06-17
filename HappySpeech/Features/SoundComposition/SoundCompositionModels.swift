import Foundation
import SwiftUI

// MARK: - SoundComposition VIP Models
//
// «Мастерская звукового состава слова» — эльконинский звуковой анализ-синтез.
// Ребёнок раскладывает по «домику» из клеток цветные фишки на каждый звук слова
// (гласный — красный, твёрдый согласный — синий, мягкий согласный — зелёный),
// затем слышит синтез слова обратно из звуков и решает бонус-задания.
//
// 3 шага (см. open-design kid-game-sound-composition-1/2/3.html):
//   1. Слово-схема   — картинка + пустой домик из клеток, протяжная озвучка.
//   2. Раскладка     — звук за звуком: выбрать цвет фишки и поставить в клетку.
//   3. Проверка/синтез — слово собрано, play-слияние; бонус-задания.
//
// Методика: Д. Б. Эльконин, Л. Е. Журова, Г. А. Каше. Контент — pack_sound_analysis.json.
// Цветовая схема каждого звука вычисляется/валидируется в `SoundCompositionBuilder`.

enum SoundCompositionModels {

    // MARK: - Start

    enum Start {
        struct Request {
            let childId: String
        }
        struct Response {
            let words: [SoundCompositionWord]
        }
        struct ViewModel {
            let firstWord: WordViewModel?
            let totalWords: Int
        }
    }

    // MARK: - LoadWord

    enum LoadWord {
        struct Request {
            let wordIndex: Int
        }
        struct Response {
            let word: SoundCompositionWord
            let wordIndex: Int
            let totalWords: Int
        }
    }

    // MARK: - PlaceChip
    //
    // Ребёнок выбрал цвет фишки для текущего звука. Если цвет верный — фишка
    // встаёт в клетку, переходим к следующему звуку. Если нет — мягкая подсказка
    // (не «неправильно»): Ляля повторяет изолированный звук и объясняет признак.

    enum PlaceChip {
        struct Request {
            /// Выбранный ребёнком тип фишки.
            let chosenType: SoundType
        }
        struct Response {
            let isCorrect: Bool
            /// Индекс звука, к которому относится попытка (0-based).
            let soundIndex: Int
            /// Верный тип звука (для подсказки и постановки фишки).
            let correctType: SoundType
            /// Буква текущего звука (для подсказки «послушай: …»).
            let letter: String
            /// Слово полностью разобрано (все фишки на местах).
            let isWordComplete: Bool
        }
        struct ViewModel {
            let placedChips: [PlacedChip]
            /// Индекс следующего «активного» звука или nil, если слово собрано.
            let activeSoundIndex: Int?
            let activeSoundLetter: String
            let activeSoundType: SoundType
            let feedbackCorrect: Bool
            let feedbackText: String
            let isWordComplete: Bool
        }
    }

    // MARK: - Synthesis
    //
    // Шаг 3: слово собрано. Подсветка звуков по очереди + воспроизведение слияния.

    enum Synthesis {
        struct Request {}
        struct Response {
            let word: SoundCompositionWord
            let chips: [PlacedChip]
        }
        struct ViewModel {
            let title: String
            let summaryLine: String
            let chips: [PlacedChip]
            let imageAsset: String
            let bonus: BonusViewModel?
        }
    }

    // MARK: - Bonus
    //
    // Бонус-задание после синтеза: цепочка замены первого звука (мак→рак→лак).

    enum Bonus {
        struct Request {
            /// Индекс выбранного варианта в цепочке.
            let variantIndex: Int
        }
        struct Response {
            let variantIndex: Int
            let isCorrect: Bool
            let resultWord: String
        }
        struct ViewModel {
            let selectedIndex: Int?
            let feedbackText: String
        }
    }

    // MARK: - Complete

    enum Complete {
        struct Request {}
        struct Response {
            let wordsCompleted: Int
            let totalWords: Int
            let score: Float
        }
        struct ViewModel {
            let starsEarned: Int
            let scoreLabel: String
            let completionMessage: String
            let finalScore: Float
        }
    }

    // MARK: - View-side word model

    struct WordViewModel: Equatable {
        let text: String
        let imageAsset: String
        let soundCount: Int
        /// Протяжная подсказка озвучки («м-м-и-и-ш-ш…»).
        let stretchedHint: String
    }
}

// MARK: - Domain types

/// Тип звука по эльконинской классификации. Определяет цвет фишки.
enum SoundType: String, Sendable, Equatable, Codable, CaseIterable {
    case vowel   // гласный — красная фишка
    case hard    // твёрдый согласный — синяя фишка
    case soft    // мягкий согласный — зелёная фишка

    /// Цвет фишки. ТОЛЬКО на круглых фишках/легенде/палитре — НЕ на фонах.
    /// Эльконинский методический стандарт; согласовано с open-design
    /// (--chip-vowel #FF4D6A, --chip-hard #3B9EFF, --chip-soft #34C78A).
    var chipColor: Color {
        switch self {
        case .vowel: return ColorTokens.Chip.vowel
        case .hard:  return ColorTokens.Chip.hard
        case .soft:  return ColorTokens.Chip.soft
        }
    }

    /// Локализованное имя признака для палитры/подсказки.
    var displayName: String {
        switch self {
        case .vowel: return String(localized: "soundComposition.type.vowel", defaultValue: "Гласный")
        case .hard:  return String(localized: "soundComposition.type.hard", defaultValue: "Твёрдый")
        case .soft:  return String(localized: "soundComposition.type.soft", defaultValue: "Мягкий")
        }
    }

    /// Короткая «детская» подпись-пример под палитрой.
    var example: String {
        switch self {
        case .vowel: return String(localized: "soundComposition.type.vowel.ex", defaultValue: "поётся")
        case .hard:  return String(localized: "soundComposition.type.hard.ex", defaultValue: "братик-силач")
        case .soft:  return String(localized: "soundComposition.type.soft.ex", defaultValue: "братик-ласка")
        }
    }
}

/// Один звук в слове (звуковая, а не буквенная единица).
struct SoundUnit: Sendable, Equatable, Codable {
    /// Отображаемая буква-звук (заглавная), например «М».
    let letter: String
    let type: SoundType
}

/// Слово для звукового анализа.
struct SoundCompositionWord: Sendable, Equatable, Identifiable {
    let id: String
    let text: String
    let imageAsset: String
    /// 1-based индекс ударного гласного звука.
    let stressIndex: Int
    let syllables: [String]
    let sounds: [SoundUnit]
    /// Опциональная бонус-цепочка замены первого звука (мак→рак→лак).
    let chain: SoundChain?

    var soundCount: Int { sounds.count }
}

/// Цепочка замены первого звука для бонус-задания.
struct SoundChain: Sendable, Equatable {
    let baseText: String
    let baseAsset: String
    let variants: [Variant]

    struct Variant: Sendable, Equatable {
        /// Звук, на который заменяем первый (заглавная буква).
        let swapTo: String
        let text: String
        let asset: String
    }
}

/// Поставленная в клетку фишка.
struct PlacedChip: Sendable, Equatable {
    let letter: String
    let type: SoundType
}

/// Фаза экрана — управляет переключением подвью.
enum SoundCompositionPhase: Sendable, Equatable {
    case loading
    case scheme       // шаг 1: картинка + пустой домик + протяжная озвучка
    case placing      // шаг 2: раскладка фишек по звукам
    case synthesis    // шаг 3: слово собрано, синтез + бонус
    case completed    // финал со звёздами
}

// MARK: - View display state

@MainActor
@Observable
final class SoundCompositionDisplay {

    // Слово
    var wordText: String = ""
    var imageAsset: String = ""
    var soundCount: Int = 0
    var stretchedHint: String = ""

    // Прогресс по словам сессии
    var wordIndex: Int = 0
    var totalWords: Int = 1

    // Раскладка фишек
    var placedChips: [PlacedChip] = []
    var activeSoundIndex: Int?       // 0-based; nil → слово собрано
    var activeSoundLetter: String = ""
    var activeSoundType: SoundType = .vowel

    // Шаг прогресса (1…3) внутри слова.
    var step: Int = 1

    // Обратная связь
    var feedbackCorrect: Bool = false
    var feedbackText: String = ""
    var showFeedback: Bool = false

    // Синтез / бонус
    var synthesisTitle: String = ""
    var synthesisSummary: String = ""
    var bonus: SoundCompositionModels.BonusViewModel?
    var bonusSelectedIndex: Int?
    var bonusFeedback: String = ""

    // Фаза
    var phase: SoundCompositionPhase = .loading
    var isPlaying: Bool = false

    // Финал
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
    var pendingExit: Bool = false
}

// MARK: - Bonus view model

extension SoundCompositionModels {
    struct BonusViewModel: Equatable {
        let prompt: String
        let baseText: String
        let baseAsset: String
        let firstLetter: String
        let variants: [BonusVariant]
        /// Индекс «целевого» варианта (тот, что Ляля просит собрать).
        let targetIndex: Int

        struct BonusVariant: Equatable, Identifiable {
            let id: Int
            let text: String
            let asset: String
            let firstLetter: String
        }
    }
}

// MARK: - Scoring

enum SoundCompositionScoring {
    /// Жёсткая шкала: ≥0.9→3, ≥0.7→2, ≥0.5→1, иначе 0.
    static func stars(for score: Float) -> Int {
        switch score {
        case 0.9...:    return 3
        case 0.7..<0.9: return 2
        case 0.5..<0.7: return 1
        default:        return 0
        }
    }
}
