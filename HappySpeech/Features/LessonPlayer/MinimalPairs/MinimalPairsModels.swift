import Foundation
import Observation

// MARK: - MinimalPairs VIP Models
//
// «Минимальные пары» — ключевой логопедический шаблон для дифференциации
// фонетически близких звуков русского языка. Ребёнок слушает слово и
// выбирает правильную картинку из двух вариантов (target vs foil).
//
// Расширенный каталог: 16+ confused pairs (С/Ш, З/Ж, Р/Л, Б/П, Д/Т,
// Г/К, В/Ф, Ж/Ш, Ч/Щ, С/З, Ш/Щ, Л/Й …).
//
// Скоринг:
//   ≥ 0.9 → 3 звезды, ≥ 0.7 → 2, ≥ 0.5 → 1, иначе 0

// MARK: - MinimalPairsHintLevel

/// Два уровня подсказок в игре «Минимальные пары».
enum MinimalPairsHintLevel: Int, Sendable, CaseIterable {
    /// Визуальная подсветка правильной карточки на 1 секунду.
    case highlight = 1
    /// Голосовая подсказка: «Это слово на звук Ш».
    case voiceClarification = 2
}

// MARK: - Domain: MinimalPairRound

/// Один раунд минимальной пары: целевое слово + фоил.
/// `targetIsLeft` рандомизируется при каждом создании раунда в `buildRounds()`.
struct MinimalPairRound: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let targetWord: String
    let foilWord: String
    let targetEmoji: String
    let foilEmoji: String
    /// Фонетический контраст: «С-Ш», «Р-Л», «З-Ж» и т.д.
    let soundContrast: String
    let targetIsLeft: Bool
}

extension MinimalPairRound {

    // MARK: - Расширенный каталог (16+ пар, источник: Коноваленко «Дифференциация звуков»)

    static let extendedCatalog: [MinimalPairRound] = [

        // MARK: С/Ш
        MinimalPairRound(
            id: "miska_mishka",
            targetWord: "миска", foilWord: "мишка",
            targetEmoji: "🥣", foilEmoji: "🐻",
            soundContrast: "С-Ш", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "sova_shuba",
            targetWord: "сова", foilWord: "шуба",
            targetEmoji: "🦉", foilEmoji: "🧥",
            soundContrast: "С-Ш", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "suk_shuk",
            targetWord: "сук", foilWord: "шук",
            targetEmoji: "🌿", foilEmoji: "🌀",
            soundContrast: "С-Ш", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "kosa_kosha",
            targetWord: "коса", foilWord: "кошка",
            targetEmoji: "🌾", foilEmoji: "🐱",
            soundContrast: "С-Ш", targetIsLeft: false
        ),

        // MARK: З/Ж
        MinimalPairRound(
            id: "zima_zhima",
            targetWord: "зима", foilWord: "жима",
            targetEmoji: "❄️", foilEmoji: "💪",
            soundContrast: "З-Ж", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "zuk_zhuk",
            targetWord: "зук", foilWord: "жук",
            targetEmoji: "🌀", foilEmoji: "🐛",
            soundContrast: "З-Ж", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "zaba_zhaba",
            targetWord: "заба", foilWord: "жаба",
            targetEmoji: "🌀", foilEmoji: "🐸",
            soundContrast: "З-Ж", targetIsLeft: false
        ),

        // MARK: Р/Л
        MinimalPairRound(
            id: "rak_lak",
            targetWord: "рак", foilWord: "лак",
            targetEmoji: "🦞", foilEmoji: "💅",
            soundContrast: "Р-Л", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "rama_lama",
            targetWord: "рама", foilWord: "лама",
            targetEmoji: "🪟", foilEmoji: "🦙",
            soundContrast: "Р-Л", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "rot_lot",
            targetWord: "рот", foilWord: "лот",
            targetEmoji: "👄", foilEmoji: "🔢",
            soundContrast: "Р-Л", targetIsLeft: true
        ),

        // MARK: Б/П
        MinimalPairRound(
            id: "bochka_pochka",
            targetWord: "бочка", foilWord: "почка",
            targetEmoji: "🛢️", foilEmoji: "🫘",
            soundContrast: "Б-П", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "bala_pala",
            targetWord: "бала", foilWord: "пала",
            targetEmoji: "🎈", foilEmoji: "🌴",
            soundContrast: "Б-П", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "bant_pant",
            targetWord: "бант", foilWord: "пант",
            targetEmoji: "🎀", foilEmoji: "🦌",
            soundContrast: "Б-П", targetIsLeft: true
        ),

        // MARK: Д/Т
        MinimalPairRound(
            id: "dom_tom",
            targetWord: "дом", foilWord: "том",
            targetEmoji: "🏠", foilEmoji: "📖",
            soundContrast: "Д-Т", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "duk_tuk",
            targetWord: "дук", foilWord: "тук",
            targetEmoji: "🌀", foilEmoji: "🔨",
            soundContrast: "Д-Т", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "dama_tama",
            targetWord: "дама", foilWord: "тама",
            targetEmoji: "👩", foilEmoji: "🌀",
            soundContrast: "Д-Т", targetIsLeft: false
        ),

        // MARK: Г/К
        MinimalPairRound(
            id: "kot_god",
            targetWord: "кот", foilWord: "год",
            targetEmoji: "🐱", foilEmoji: "📅",
            soundContrast: "К-Г", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "gora_kora",
            targetWord: "гора", foilWord: "кора",
            targetEmoji: "⛰️", foilEmoji: "🪵",
            soundContrast: "К-Г", targetIsLeft: true
        ),

        // MARK: В/Ф
        MinimalPairRound(
            id: "vaza_faza",
            targetWord: "ваза", foilWord: "фаза",
            targetEmoji: "🏺", foilEmoji: "⚡",
            soundContrast: "В-Ф", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "volk_folk",
            targetWord: "волк", foilWord: "фолк",
            targetEmoji: "🐺", foilEmoji: "🎵",
            soundContrast: "В-Ф", targetIsLeft: false
        ),

        // MARK: Ж/Ш
        MinimalPairRound(
            id: "zhuk_shuk_2",
            targetWord: "жук", foilWord: "шук",
            targetEmoji: "🐛", foilEmoji: "🌀",
            soundContrast: "Ж-Ш", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "zhar_shar",
            targetWord: "жар", foilWord: "шар",
            targetEmoji: "🔥", foilEmoji: "🎈",
            soundContrast: "Ж-Ш", targetIsLeft: false
        ),

        // MARK: Ч/Щ
        MinimalPairRound(
            id: "chelka_shelka",
            targetWord: "чёлка", foilWord: "щёлка",
            targetEmoji: "💇", foilEmoji: "🔓",
            soundContrast: "Ч-Щ", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "chit_shit",
            targetWord: "чит", foilWord: "щит",
            targetEmoji: "🃏", foilEmoji: "🛡️",
            soundContrast: "Ч-Щ", targetIsLeft: false
        ),

        // MARK: С/З
        MinimalPairRound(
            id: "sort_zort",
            targetWord: "сорт", foilWord: "зорт",
            targetEmoji: "🗂️", foilEmoji: "🌀",
            soundContrast: "С-З", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "suk_zuk",
            targetWord: "сук", foilWord: "зук",
            targetEmoji: "🌿", foilEmoji: "🌀",
            soundContrast: "С-З", targetIsLeft: false
        ),

        // MARK: Ш/Щ
        MinimalPairRound(
            id: "sholk_shcholk",
            targetWord: "шёлк", foilWord: "щёлк",
            targetEmoji: "🧵", foilEmoji: "👆",
            soundContrast: "Ш-Щ", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "shit_shchit",
            targetWord: "шит", foilWord: "щит",
            targetEmoji: "🪡", foilEmoji: "🛡️",
            soundContrast: "Ш-Щ", targetIsLeft: false
        ),

        // MARK: Л/Й
        MinimalPairRound(
            id: "les_yes",
            targetWord: "лес", foilWord: "ес",
            targetEmoji: "🌲", foilEmoji: "🌀",
            soundContrast: "Л-Й", targetIsLeft: true
        ),

        // MARK: М/Н
        MinimalPairRound(
            id: "mama_nana",
            targetWord: "мама", foilWord: "нана",
            targetEmoji: "👩", foilEmoji: "👵",
            soundContrast: "М-Н", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "mol_nol",
            targetWord: "моль", foilWord: "ноль",
            targetEmoji: "🦋", foilEmoji: "0️⃣",
            soundContrast: "М-Н", targetIsLeft: false
        ),

        // MARK: Г/Х
        MinimalPairRound(
            id: "gora_hora",
            targetWord: "гора", foilWord: "хора",
            targetEmoji: "⛰️", foilEmoji: "💃",
            soundContrast: "Г-Х", targetIsLeft: true
        ),

        // MARK: Л/Л' (мягкость)
        MinimalPairRound(
            id: "lisa_lysa",
            targetWord: "лиса", foilWord: "лыса",
            targetEmoji: "🦊", foilEmoji: "👤",
            soundContrast: "Л-Л'", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "luk_lyuk",
            targetWord: "лук", foilWord: "люк",
            targetEmoji: "🧅", foilEmoji: "🚪",
            soundContrast: "Л-Л'", targetIsLeft: false
        ),

        // MARK: Р/К
        MinimalPairRound(
            id: "roza_koza",
            targetWord: "роза", foilWord: "коза",
            targetEmoji: "🌹", foilEmoji: "🐐",
            soundContrast: "Р-К", targetIsLeft: true
        )
    ]

    /// Обратная совместимость: старый каталог (первые 10 пар).
    static let catalog: [MinimalPairRound] = Array(extendedCatalog.prefix(10))

    /// Строит список раундов (обратная совместимость).
    static func rounds(count: Int = 10, contrast: String = "") -> [MinimalPairRound] {
        let pool: [MinimalPairRound] = contrast.isEmpty
            ? extendedCatalog
            : extendedCatalog.filter { $0.soundContrast == contrast }
        let source = pool.isEmpty ? extendedCatalog : pool
        let shuffled = source.shuffled()
        var result: [MinimalPairRound] = []
        result.reserveCapacity(count)
        var idx = 0
        while result.count < count, !shuffled.isEmpty {
            let base = shuffled[idx % shuffled.count]
            let side = Bool.random()
            result.append(MinimalPairRound(
                id: "\(base.id)-\(result.count)",
                targetWord: base.targetWord,
                foilWord: base.foilWord,
                targetEmoji: base.targetEmoji,
                foilEmoji: base.foilEmoji,
                soundContrast: base.soundContrast,
                targetIsLeft: side
            ))
            idx += 1
        }
        return result
    }
}

// MARK: - VIP Envelopes

enum MinimalPairsModels {

    // MARK: LoadSession

    enum LoadSession {
        struct Request: Sendable {
            let soundContrast: String
            let childName: String
            var childId: String = ""
            var childAge: Int = 6
        }
        struct Response: Sendable {
            let rounds: [MinimalPairRound]
            let childName: String
            let totalRounds: Int
        }
        struct ViewModel: Sendable {
            let totalRounds: Int
            let greeting: String
        }
    }

    // MARK: StartRound

    enum StartRound {
        struct Request: Sendable {
            let roundIndex: Int
        }
        struct Response: Sendable {
            let pair: MinimalPairRound
            let roundNumber: Int
            let total: Int
            let hintsAvailable: Int
        }
        struct ViewModel: Sendable {
            let pair: MinimalPairRound
            let progressLabel: String
            let promptText: String
            let targetWord: String
            let hintsAvailable: Int
        }
    }

    // MARK: SelectOption

    enum SelectOption {
        struct Request: Sendable {
            let selectedIsTarget: Bool
        }
        struct Response: Sendable {
            let correct: Bool
            let correctAnswer: String
            let foilAnswer: String
            let soundContrast: String
            let streakCount: Int
            let isStreakBonus: Bool
            let hintsUsedThisRound: Int
            let roundDurationSeconds: Double
        }
        struct ViewModel: Sendable {
            let correct: Bool
            let feedbackText: String
            let correctAnswer: String
            let isStreakBonus: Bool
            let streakLabel: String?
        }
    }

    // MARK: ReplayWord

    enum ReplayWord {
        struct Response: Sendable {
            let word: String
            let replaysRemaining: Int
            let capReached: Bool
        }
        struct ViewModel: Sendable {
            let replaysRemaining: Int
            let capReached: Bool
            let toastMessage: String?
        }
    }

    // MARK: RequestHint

    enum RequestHint {
        struct Request: Sendable {}
        struct Response: Sendable {
            let level: MinimalPairsHintLevel
            let highlightDuration: Double
            let voiceText: String?
            let hintsRemaining: Int
            let capReached: Bool
        }
        struct ViewModel: Sendable {
            let level: MinimalPairsHintLevel
            let highlightDuration: Double
            let toastMessage: String
            let hintsRemaining: Int
            let capReached: Bool
        }
    }

    // MARK: BonusRoundAdded

    enum BonusRoundAdded {
        struct Response: Sendable {
            let message: String
            let totalRounds: Int
        }
        struct ViewModel: Sendable {
            let toastMessage: String
            let totalRounds: Int
        }
    }

    // MARK: CompleteSession

    enum CompleteSession {
        struct Request: Sendable {}
        struct Response: Sendable {
            let correctCount: Int
            let totalRounds: Int
            /// Точность по каждой паре звуков (soundContrast → 0…1).
            let pairAccuracy: [String: Double]
            let maxStreak: Int
            let totalHintsUsed: Int
            let totalDurationSeconds: Double
            let sm2Quality: SM2Quality
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            let pairSummary: [PairSummaryItem]
        }
    }

    // MARK: PairSummaryItem

    struct PairSummaryItem: Sendable, Identifiable {
        let id: String
        let contrast: String
        let accuracyPercent: Int
        let accuracyLabel: String
    }
}

// MARK: - Display Store

/// Наблюдаемое состояние экрана. Хранит фазу игры + все viewmodel-поля.
@Observable
@MainActor
final class MinimalPairsDisplay {
    var totalRounds: Int = 10
    var greeting: String = ""
    var currentPair: MinimalPairRound?
    var progressLabel: String = ""
    var promptText: String = ""
    var hintsAvailable: Int = 2
    var correct: Bool = false
    var feedbackText: String = ""
    var correctAnswer: String = ""
    var isStreakBonus: Bool = false
    var streakLabel: String?
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var pairSummary: [MinimalPairsModels.PairSummaryItem] = []
    var phase: MinimalPairsPhase = .loading
    var isAnswered: Bool = false
    var selectedIsTarget: Bool?
    var pendingFinalScore: Float?
    var toastMessage: String?
    var showHintHighlight: Bool = false
    var hintHighlightDuration: Double = 1.0
    var replaysRemaining: Int = 3

    // Локальные счётчики для финального скора.
    var answeredCount: Int = 0
    var correctCount: Int = 0
}

enum MinimalPairsPhase: Sendable, Equatable {
    case loading
    case round
    case feedback
    case completed
}
