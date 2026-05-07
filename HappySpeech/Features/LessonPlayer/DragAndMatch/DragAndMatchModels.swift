import CoreTransferable
import Foundation
import Observation
import UniformTypeIdentifiers

// MARK: - DragAndMatch VIP Models
//
// «Перетащи и совмести» — ребёнок перетаскивает слово (или картинку) в
// правильную корзину. 2–3 корзины (категории), 6–9 слов. Например:
// "слова со звуком С" vs "слова без С". Используется SwiftUI drag & drop
// (`.draggable` + `.dropDestination`) — iOS 16+ API.
//
// Скоринг: доля правильно размещённых слов от общего числа.
//   ≥ 0.9  → 3 звезды
//   ≥ 0.7  → 2 звезды
//   ≥ 0.5  → 1 звезда
//   иначе  → 0 звёзд
//
// Файл содержит только типы: Request/Response/ViewModel + Display store.

// MARK: - Domain: DragWord

/// Перетаскиваемое слово. `Transferable` — для SwiftUI drag & drop.
/// Сериализуется как простой JSON (Codable) через `plainText` contentType.
struct DragWord: Sendable, Identifiable, Equatable, Hashable, Codable {
    let id: String
    let word: String
    let emoji: String
    let correctBucketId: String
    /// Звуковая группа, к которой принадлежит слово (для per-pair статистики).
    let soundGroup: String
}

extension DragWord: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
    }
}

// MARK: - Domain: DragBucket

/// Корзина-категория, в которую можно «складывать» слова.
struct DragBucket: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let emoji: String
    /// Цвет палитры: "mint" | "lilac" | "butter" | "sky" | "rose".
    let color: String
}

// MARK: - Domain: ConfusedPair

/// Пара звуков, которую дифференцирует данный раунд.
/// Например: С/Ш, Р/Л, З/Ж, Б/П и т.д.
struct ConfusedPair: Sendable, Equatable, Hashable {
    let primary: String
    let secondary: String

    var displayLabel: String { "\(primary)/\(secondary)" }
}

// MARK: - Domain: HintLevel

/// Три уровня подсказок в порядке усиления.
enum HintLevel: Int, Sendable, CaseIterable {
    /// Подсветка целевой корзины.
    case highlightBin = 1
    /// Голосовая подсказка от Ляли.
    case voicePrompt = 2
    /// Автоматическое решение (карточка перемещается сама).
    case autoSolve = 3
}

// MARK: - Domain: RoundStats

/// Статистика одного раунда.
struct RoundStats: Sendable, Equatable {
    let roundIndex: Int
    let totalCards: Int
    let correctDrops: Int
    let incorrectDrops: Int
    let hintsUsed: Int
    let durationSeconds: Double

    var accuracy: Double {
        guard totalCards > 0 else { return 0 }
        return Double(correctDrops) / Double(totalCards)
    }
}

// MARK: - Content sets

extension DragWord {

    /// Набор для группы свистящих: "Есть звук С" vs "Нет звука С".
    static let whistlingSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "sova", word: "сова", emoji: "word_bird",
                     correctBucketId: "has_s", soundGroup: "whistling"),
            DragWord(id: "sobaka", word: "собака", emoji: "word_dog",
                     correctBucketId: "has_s", soundGroup: "whistling"),
            DragWord(id: "sad", word: "сад", emoji: "word_tree",
                     correctBucketId: "has_s", soundGroup: "whistling"),
            DragWord(id: "solntse", word: "солнце", emoji: "word_sun",
                     correctBucketId: "has_s", soundGroup: "whistling"),
            DragWord(id: "ryba", word: "рыба", emoji: "word_fish",
                     correctBucketId: "no_s", soundGroup: "whistling"),
            DragWord(id: "luna", word: "луна", emoji: "word_moon",
                     correctBucketId: "no_s", soundGroup: "whistling"),
            DragWord(id: "gora", word: "гора", emoji: "word_forest",
                     correctBucketId: "no_s", soundGroup: "whistling"),
            DragWord(id: "dom_s", word: "дом", emoji: "word_house",
                     correctBucketId: "no_s", soundGroup: "whistling")
        ],
        [
            DragBucket(id: "has_s", title: "Есть звук «С»", emoji: "checkmark.circle.fill", color: "mint"),
            DragBucket(id: "no_s", title: "Нет звука «С»", emoji: "xmark.circle.fill", color: "lilac")
        ]
    )

    /// Набор для дифференциации С/Ш.
    static let whistlingVsHissingSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "sova2", word: "сова", emoji: "word_bird",
                     correctBucketId: "sound_s", soundGroup: "whistling"),
            DragWord(id: "sad2", word: "сад", emoji: "word_tree",
                     correctBucketId: "sound_s", soundGroup: "whistling"),
            DragWord(id: "sobaka2", word: "собака", emoji: "word_dog",
                     correctBucketId: "sound_s", soundGroup: "whistling"),
            DragWord(id: "shapka", word: "шапка", emoji: "word_bag",
                     correctBucketId: "sound_sh", soundGroup: "hissing"),
            DragWord(id: "kashka", word: "кашка", emoji: "word_cup",
                     correctBucketId: "sound_sh", soundGroup: "hissing"),
            DragWord(id: "mashka", word: "мышка", emoji: "word_cat",
                     correctBucketId: "sound_sh", soundGroup: "hissing")
        ],
        [
            DragBucket(id: "sound_s", title: "Звук «С»", emoji: "word_butterfly_insect", color: "mint"),
            DragBucket(id: "sound_sh", title: "Звук «Ш»", emoji: "word_fish", color: "lilac")
        ]
    )

    /// Набор для шипящих: "Есть звук Ш" vs "Нет звука Ш".
    static let hissingSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "shapka2", word: "шапка", emoji: "word_bag",
                     correctBucketId: "has_sh", soundGroup: "hissing"),
            DragWord(id: "kashka2", word: "кашка", emoji: "word_cup",
                     correctBucketId: "has_sh", soundGroup: "hissing"),
            DragWord(id: "mashka2", word: "мышка", emoji: "word_cat",
                     correctBucketId: "has_sh", soundGroup: "hissing"),
            DragWord(id: "shuba", word: "шуба", emoji: "word_bag",
                     correctBucketId: "has_sh", soundGroup: "hissing"),
            DragWord(id: "kot2", word: "кот", emoji: "word_cat",
                     correctBucketId: "no_sh", soundGroup: "hissing"),
            DragWord(id: "dom2", word: "дом", emoji: "word_house",
                     correctBucketId: "no_sh", soundGroup: "hissing"),
            DragWord(id: "les", word: "лес", emoji: "word_forest",
                     correctBucketId: "no_sh", soundGroup: "hissing"),
            DragWord(id: "ryba2", word: "рыба", emoji: "word_fish",
                     correctBucketId: "no_sh", soundGroup: "hissing")
        ],
        [
            DragBucket(id: "has_sh", title: "Есть звук «Ш»", emoji: "checkmark.circle.fill", color: "mint"),
            DragBucket(id: "no_sh", title: "Нет звука «Ш»", emoji: "xmark.circle.fill", color: "lilac")
        ]
    )

    /// Набор для дифференциации З/Ж.
    static let zVsZhSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "zont", word: "зонт", emoji: "word_bag",
                     correctBucketId: "sound_z", soundGroup: "whistling"),
            DragWord(id: "zvezda", word: "звезда", emoji: "reward_gold_star",
                     correctBucketId: "sound_z", soundGroup: "whistling"),
            DragWord(id: "zamok", word: "замок", emoji: "word_door",
                     correctBucketId: "sound_z", soundGroup: "whistling"),
            DragWord(id: "zhuk", word: "жук", emoji: "word_butterfly_insect",
                     correctBucketId: "sound_zh", soundGroup: "hissing"),
            DragWord(id: "ezh", word: "ёж", emoji: "word_hare",
                     correctBucketId: "sound_zh", soundGroup: "hissing"),
            DragWord(id: "nozh", word: "нож", emoji: "word_fork",
                     correctBucketId: "sound_zh", soundGroup: "hissing")
        ],
        [
            DragBucket(id: "sound_z", title: "Звук «З»", emoji: "word_butterfly_insect", color: "sky"),
            DragBucket(id: "sound_zh", title: "Звук «Ж»", emoji: "word_butterfly_insect", color: "butter")
        ]
    )

    /// Набор для соноров: "Есть звук Р" vs "Нет звука Р".
    static let sonorantSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "rak", word: "рак", emoji: "word_fish",
                     correctBucketId: "has_r", soundGroup: "sonorant"),
            DragWord(id: "rosa", word: "роза", emoji: "word_flower",
                     correctBucketId: "has_r", soundGroup: "sonorant"),
            DragWord(id: "raketa", word: "ракета", emoji: "reward_rocket",
                     correctBucketId: "has_r", soundGroup: "sonorant"),
            DragWord(id: "ryba3", word: "рыба", emoji: "word_fish",
                     correctBucketId: "has_r", soundGroup: "sonorant"),
            DragWord(id: "kot3", word: "кот", emoji: "word_cat",
                     correctBucketId: "no_r", soundGroup: "sonorant"),
            DragWord(id: "luna3", word: "луна", emoji: "word_moon",
                     correctBucketId: "no_r", soundGroup: "sonorant"),
            DragWord(id: "vaza", word: "ваза", emoji: "word_cup",
                     correctBucketId: "no_r", soundGroup: "sonorant"),
            DragWord(id: "dom3", word: "дом", emoji: "word_house",
                     correctBucketId: "no_r", soundGroup: "sonorant")
        ],
        [
            DragBucket(id: "has_r", title: "Есть звук «Р»", emoji: "checkmark.circle.fill", color: "mint"),
            DragBucket(id: "no_r", title: "Нет звука «Р»", emoji: "xmark.circle.fill", color: "lilac")
        ]
    )

    /// Набор для дифференциации Р/Л.
    static let rVsLSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "rak2", word: "рак", emoji: "word_fish",
                     correctBucketId: "sound_r", soundGroup: "sonorant"),
            DragWord(id: "rosa2", word: "роза", emoji: "word_flower",
                     correctBucketId: "sound_r", soundGroup: "sonorant"),
            DragWord(id: "reka", word: "река", emoji: "word_park",
                     correctBucketId: "sound_r", soundGroup: "sonorant"),
            DragWord(id: "lampa", word: "лампа", emoji: "word_lamp",
                     correctBucketId: "sound_l", soundGroup: "sonorant"),
            DragWord(id: "lodka", word: "лодка", emoji: "word_boat",
                     correctBucketId: "sound_l", soundGroup: "sonorant"),
            DragWord(id: "luna4", word: "луна", emoji: "word_moon",
                     correctBucketId: "sound_l", soundGroup: "sonorant")
        ],
        [
            DragBucket(id: "sound_r", title: "Звук «Р»", emoji: "reward_champion", color: "rose"),
            DragBucket(id: "sound_l", title: "Звук «Л»", emoji: "word_butterfly_insect", color: "sky")
        ]
    )

    /// Набор для заднеязычных: К/Г/Х — три корзины.
    static let velarSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "kot4", word: "кот", emoji: "word_cat",
                     correctBucketId: "sound_k", soundGroup: "velar"),
            DragWord(id: "kub", word: "куб", emoji: "word_window",
                     correctBucketId: "sound_k", soundGroup: "velar"),
            DragWord(id: "klyuch", word: "ключ", emoji: "word_door",
                     correctBucketId: "sound_k", soundGroup: "velar"),
            DragWord(id: "gus", word: "гусь", emoji: "🪿",
                     correctBucketId: "sound_g", soundGroup: "velar"),
            DragWord(id: "gorka", word: "горка", emoji: "word_park",
                     correctBucketId: "sound_g", soundGroup: "velar"),
            DragWord(id: "hleb", word: "хлеб", emoji: "word_cake",
                     correctBucketId: "sound_h", soundGroup: "velar"),
            DragWord(id: "uho", word: "ухо", emoji: "word_bear",
                     correctBucketId: "sound_h", soundGroup: "velar"),
            DragWord(id: "muha", word: "муха", emoji: "🪰",
                     correctBucketId: "sound_h", soundGroup: "velar")
        ],
        [
            DragBucket(id: "sound_k", title: "Звук «К»", emoji: "word_cat", color: "butter"),
            DragBucket(id: "sound_g", title: "Звук «Г»", emoji: "🪿", color: "mint"),
            DragBucket(id: "sound_h", title: "Звук «Х»", emoji: "word_cake", color: "rose")
        ]
    )

    /// Набор для Б/П — глухие/звонкие.
    static let bVsPSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "banan", word: "банан", emoji: "word_apple",
                     correctBucketId: "sound_b", soundGroup: "bilabial"),
            DragWord(id: "bulka", word: "булка", emoji: "word_cake",
                     correctBucketId: "sound_b", soundGroup: "bilabial"),
            DragWord(id: "belka", word: "белка", emoji: "word_hare",
                     correctBucketId: "sound_b", soundGroup: "bilabial"),
            DragWord(id: "papa", word: "папа", emoji: "mascot_lyalya_read",
                     correctBucketId: "sound_p", soundGroup: "bilabial"),
            DragWord(id: "ptica", word: "птица", emoji: "word_bird",
                     correctBucketId: "sound_p", soundGroup: "bilabial"),
            DragWord(id: "pila", word: "пила", emoji: "🪚",
                     correctBucketId: "sound_p", soundGroup: "bilabial")
        ],
        [
            DragBucket(id: "sound_b", title: "Звук «Б»", emoji: "word_lamp", color: "lilac"),
            DragBucket(id: "sound_p", title: "Звук «П»", emoji: "music.note", color: "sky")
        ]
    )

    /// Набор для Д/Т — глухие/звонкие.
    static let dVsTSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "dom4", word: "дом", emoji: "word_house",
                     correctBucketId: "sound_d", soundGroup: "dental"),
            DragWord(id: "dynya", word: "дыня", emoji: "word_apple",
                     correctBucketId: "sound_d", soundGroup: "dental"),
            DragWord(id: "doroga", word: "дорога", emoji: "word_park",
                     correctBucketId: "sound_d", soundGroup: "dental"),
            DragWord(id: "tigr", word: "тигр", emoji: "reward_brave_heart",
                     correctBucketId: "sound_t", soundGroup: "dental"),
            DragWord(id: "tarelka", word: "тарелка", emoji: "word_cup",
                     correctBucketId: "sound_t", soundGroup: "dental"),
            DragWord(id: "telefon", word: "телефон", emoji: "word_lamp",
                     correctBucketId: "sound_t", soundGroup: "dental")
        ],
        [
            DragBucket(id: "sound_d", title: "Звук «Д»", emoji: "word_lamp", color: "butter"),
            DragBucket(id: "sound_t", title: "Звук «Т»", emoji: "music.note", color: "mint")
        ]
    )

    /// Возвращает набор слов+корзин для переданной фонетической группы.
    /// Ключи: "whistling" | "hissing" | "sonorant" | "velar" |
    ///        "С" | "Ш" | "Р" | "Л" | "К" | "С/Ш" | "З/Ж" | "Р/Л" | "Б/П" | "Д/Т"
    static func set(for soundGroup: String) -> ([DragWord], [DragBucket]) {
        switch soundGroup.lowercased() {
        case "hissing", "ш", "ж", "ч", "щ":
            return hissingSet
        case "sonorant", "р", "л":
            return sonorantSet
        case "velar", "к", "г", "х":
            return velarSet
        case "с/ш", "с-ш":
            return whistlingVsHissingSet
        case "з/ж", "з-ж":
            return zVsZhSet
        case "р/л", "р-л":
            return rVsLSet
        case "б/п", "б-п":
            return bVsPSet
        case "д/т", "д-т":
            return dVsTSet
        case "whistling", "с", "з", "ц", "":
            return whistlingSet
        default:
            return whistlingSet
        }
    }
}

// MARK: - VIP Envelopes

enum DragAndMatchModels {

    // MARK: LoadSession
    enum LoadSession {
        struct Request: Sendable {
            let soundGroup: String
            let childName: String
            let totalRounds: Int
        }
        struct Response: Sendable {
            let words: [DragWord]
            let buckets: [DragBucket]
            let childName: String
            let roundIndex: Int
            let totalRounds: Int
            let confusedPair: ConfusedPair?
        }
        struct ViewModel: Sendable {
            let words: [DragWord]
            let buckets: [DragBucket]
            let greeting: String
            let roundLabel: String
            let confusedPairLabel: String?
        }
    }

    // MARK: DropWord
    enum DropWord {
        struct Request: Sendable {
            let wordId: String
            let bucketId: String
        }
        struct Response: Sendable {
            let correct: Bool
            let wordId: String
            let feedbackText: String
            let streakCount: Int
            let isStreakBonus: Bool
            let hintBucketId: String?
        }
        struct ViewModel: Sendable {
            let correct: Bool
            let wordId: String
            let feedbackText: String
            let showStreakBonus: Bool
            let streakLabel: String?
            let hintBucketId: String?
        }
    }

    // MARK: RequestHint
    enum RequestHint {
        struct Request: Sendable {
            let wordId: String
        }
        struct Response: Sendable {
            let level: HintLevel
            let targetBucketId: String?
            let voicePromptText: String?
            let autoSolvedWordId: String?
            let autoSolvedBucketId: String?
            let hintsRemaining: Int
        }
        struct ViewModel: Sendable {
            let level: HintLevel
            let targetBucketId: String?
            let voicePromptText: String?
            let autoSolvedWordId: String?
            let autoSolvedBucketId: String?
            let hintsRemainingLabel: String
        }
    }

    // MARK: CompleteRound
    enum CompleteRound {
        struct Request: Sendable {}
        struct Response: Sendable {
            let stats: RoundStats
            let hasNextRound: Bool
            let nextRoundIndex: Int
        }
        struct ViewModel: Sendable {
            let accuracyLabel: String
            let hintsLabel: String
            let durationLabel: String
            let hasNextRound: Bool
            let ctaLabel: String
        }
    }

    // MARK: CompleteSession
    enum CompleteSession {
        struct Request: Sendable {}
        struct Response: Sendable {
            let correctCount: Int
            let totalWords: Int
            let allRoundStats: [RoundStats]
            let totalHintsUsed: Int
            let totalDurationSeconds: Double
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            let accuracyPercent: String
            let hintsUsedLabel: String
            let durationLabel: String
        }
    }
}

// MARK: - Display Store

@Observable
@MainActor
final class DragAndMatchDisplay {
    var words: [DragWord] = []
    var buckets: [DragBucket] = []
    var greeting: String = ""
    var roundLabel: String = ""
    var confusedPairLabel: String?

    /// wordId → bucketId (куда слово попало).
    var placedWords: [String: String] = [:]
    var correctWords: Set<String> = []
    var incorrectWords: Set<String> = []
    var feedbackText: String = ""

    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var accuracyPercent: String = ""
    var hintsUsedLabel: String = ""
    var durationLabel: String = ""

    var phase: DragPhase = .loading

    /// Подсвеченная подсказкой корзина.
    var hintHighlightBucketId: String?

    /// Сообщение стрика (бонус за серию).
    var streakBonusLabel: String?
    var showStreakBonus: Bool = false

    /// Финальный скор пробрасывается в SessionShell через `.onChange`.
    var pendingFinalScore: Float?

    // MARK: - Round Complete overlay state
    var showRoundComplete: Bool = false
    var roundCompleteAccuracyLabel: String = ""
    var roundCompleteHintsLabel: String = ""
    var roundCompleteDurationLabel: String = ""
    var roundCompleteHasNext: Bool = false
    var roundCompleteCtaLabel: String = ""
}

enum DragPhase: Sendable, Equatable {
    case loading
    case playing
    case completed
}
