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
            targetEmoji: "word_cup", foilEmoji: "word_bear",
            soundContrast: "С-Ш", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "sova_shuba",
            targetWord: "сова", foilWord: "шуба",
            targetEmoji: "word_bird", foilEmoji: "word_bag",
            soundContrast: "С-Ш", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "suk_shuk",
            targetWord: "сук", foilWord: "шук",
            targetEmoji: "word_flower", foilEmoji: "word_flower",
            soundContrast: "С-Ш", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "kosa_kosha",
            targetWord: "коса", foilWord: "кошка",
            targetEmoji: "word_flower", foilEmoji: "word_cat",
            soundContrast: "С-Ш", targetIsLeft: false
        ),

        // MARK: З/Ж
        MinimalPairRound(
            id: "zima_zhima",
            targetWord: "зима", foilWord: "жима",
            targetEmoji: "word_window", foilEmoji: "reward_brave_heart",
            soundContrast: "З-Ж", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "zuk_zhuk",
            targetWord: "зук", foilWord: "жук",
            targetEmoji: "word_flower", foilEmoji: "word_butterfly_insect",
            soundContrast: "З-Ж", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "zaba_zhaba",
            targetWord: "заба", foilWord: "жаба",
            targetEmoji: "word_flower", foilEmoji: "word_frog",
            soundContrast: "З-Ж", targetIsLeft: false
        ),

        // MARK: Р/Л
        MinimalPairRound(
            id: "rak_lak",
            targetWord: "рак", foilWord: "лак",
            targetEmoji: "word_fish", foilEmoji: "word_apple",
            soundContrast: "Р-Л", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "rama_lama",
            targetWord: "рама", foilWord: "лама",
            targetEmoji: "word_window", foilEmoji: "word_cow",
            soundContrast: "Р-Л", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "rot_lot",
            targetWord: "рот", foilWord: "лот",
            targetEmoji: "mouth.fill", foilEmoji: "textformat.123",
            soundContrast: "Р-Л", targetIsLeft: true
        ),

        // MARK: Б/П
        MinimalPairRound(
            id: "bochka_pochka",
            targetWord: "бочка", foilWord: "почка",
            targetEmoji: "word_bag", foilEmoji: "word_apple",
            soundContrast: "Б-П", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "bala_pala",
            targetWord: "бала", foilWord: "пала",
            targetEmoji: "balloon.fill", foilEmoji: "word_tree",
            soundContrast: "Б-П", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "bant_pant",
            targetWord: "бант", foilWord: "пант",
            targetEmoji: "ribbon", foilEmoji: "word_bear",
            soundContrast: "Б-П", targetIsLeft: true
        ),

        // MARK: Д/Т
        MinimalPairRound(
            id: "dom_tom",
            targetWord: "дом", foilWord: "том",
            targetEmoji: "word_house", foilEmoji: "books.vertical.fill",
            soundContrast: "Д-Т", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "duk_tuk",
            targetWord: "дук", foilWord: "тук",
            targetEmoji: "word_flower", foilEmoji: "hammer.fill",
            soundContrast: "Д-Т", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "dama_tama",
            targetWord: "дама", foilWord: "тама",
            targetEmoji: "mascot_lyalya_read", foilEmoji: "word_flower",
            soundContrast: "Д-Т", targetIsLeft: false
        ),

        // MARK: Г/К
        MinimalPairRound(
            id: "kot_god",
            targetWord: "кот", foilWord: "год",
            targetEmoji: "word_cat", foilEmoji: "calendar",
            soundContrast: "К-Г", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "gora_kora",
            targetWord: "гора", foilWord: "кора",
            targetEmoji: "word_forest", foilEmoji: "🪵",
            soundContrast: "К-Г", targetIsLeft: true
        ),

        // MARK: В/Ф
        MinimalPairRound(
            id: "vaza_faza",
            targetWord: "ваза", foilWord: "фаза",
            targetEmoji: "word_cup", foilEmoji: "bolt.fill",
            soundContrast: "В-Ф", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "volk_folk",
            targetWord: "волк", foilWord: "фолк",
            targetEmoji: "word_fox", foilEmoji: "music.note",
            soundContrast: "В-Ф", targetIsLeft: false
        ),

        // MARK: Ж/Ш
        MinimalPairRound(
            id: "zhuk_shuk_2",
            targetWord: "жук", foilWord: "шук",
            targetEmoji: "word_butterfly_insect", foilEmoji: "word_flower",
            soundContrast: "Ж-Ш", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "zhar_shar",
            targetWord: "жар", foilWord: "шар",
            targetEmoji: "flame.fill", foilEmoji: "balloon.fill",
            soundContrast: "Ж-Ш", targetIsLeft: false
        ),

        // MARK: Ч/Щ
        MinimalPairRound(
            id: "chelka_shelka",
            targetWord: "чёлка", foilWord: "щёлка",
            targetEmoji: "scissors", foilEmoji: "lock.open.fill",
            soundContrast: "Ч-Щ", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "chit_shit",
            targetWord: "чит", foilWord: "щит",
            targetEmoji: "rectangle.fill.on.rectangle.fill", foilEmoji: "shield.fill",
            soundContrast: "Ч-Щ", targetIsLeft: false
        ),

        // MARK: С/З
        MinimalPairRound(
            id: "sort_zort",
            targetWord: "сорт", foilWord: "зорт",
            targetEmoji: "folder.fill", foilEmoji: "word_flower",
            soundContrast: "С-З", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "suk_zuk",
            targetWord: "сук", foilWord: "зук",
            targetEmoji: "word_flower", foilEmoji: "word_flower",
            soundContrast: "С-З", targetIsLeft: false
        ),

        // MARK: Ш/Щ
        MinimalPairRound(
            id: "sholk_shcholk",
            targetWord: "шёлк", foilWord: "щёлк",
            targetEmoji: "scissors", foilEmoji: "hand.point.up.fill",
            soundContrast: "Ш-Щ", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "shit_shchit",
            targetWord: "шит", foilWord: "щит",
            targetEmoji: "🪡", foilEmoji: "shield.fill",
            soundContrast: "Ш-Щ", targetIsLeft: false
        ),

        // MARK: Л/Й
        MinimalPairRound(
            id: "les_yes",
            targetWord: "лес", foilWord: "ес",
            targetEmoji: "word_forest", foilEmoji: "word_flower",
            soundContrast: "Л-Й", targetIsLeft: true
        ),

        // MARK: М/Н
        MinimalPairRound(
            id: "mama_nana",
            targetWord: "мама", foilWord: "нана",
            targetEmoji: "mascot_lyalya_read", foilEmoji: "mascot_lyalya_read",
            soundContrast: "М-Н", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "mol_nol",
            targetWord: "моль", foilWord: "ноль",
            targetEmoji: "word_butterfly_insect", foilEmoji: "0️⃣",
            soundContrast: "М-Н", targetIsLeft: false
        ),

        // MARK: Г/Х
        MinimalPairRound(
            id: "gora_hora",
            targetWord: "гора", foilWord: "хора",
            targetEmoji: "word_forest", foilEmoji: "figure.dance",
            soundContrast: "Г-Х", targetIsLeft: true
        ),

        // MARK: Л/Л' (мягкость)
        MinimalPairRound(
            id: "lisa_lysa",
            targetWord: "лиса", foilWord: "лыса",
            targetEmoji: "word_fox", foilEmoji: "person.fill",
            soundContrast: "Л-Л'", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "luk_lyuk",
            targetWord: "лук", foilWord: "люк",
            targetEmoji: "word_apple", foilEmoji: "word_door",
            soundContrast: "Л-Л'", targetIsLeft: false
        ),

        // MARK: Р/К
        MinimalPairRound(
            id: "roza_koza",
            targetWord: "роза", foilWord: "коза",
            targetEmoji: "word_flower", foilEmoji: "word_cow",
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
