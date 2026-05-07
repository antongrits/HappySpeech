import Foundation
import Observation

// MARK: - Sorting VIP Models
//
// «Сортировка по категориям» — ребёнок раскладывает слова по 2–4 корзинам.
//
// 5 типов задач (SortingTaskType):
//   .firstSound       — по первому звуку (С / Ш / Р / Л)
//   .soundPosition    — начало / середина / конец
//   .syllableCount    — 1 / 2 / 3 слога
//   .vowelConsonant   — гласные vs согласные
//   .voicedUnvoiced   — звонкие vs глухие
//   .semantic         — смысловые категории (живое/неживое, фрукт/овощ…)
//
// Hints (3 уровня):
//   1 — подсветить правильную корзину
//   2 — голосовая подсказка
//   3 — авто-placement без баллов
//
// Auto-distribute: если бездействие 30 с — авторасставить оставшиеся слова.
//
// Скоринг:
//   hitRate    = correct / total  (авто-placed не считаются)
//   timeBonus  = max(0, (timeLimit - elapsed) / timeLimit) * 0.15
//   streakBon  = min(0.15, bestStreak * 0.03)
//   autoPen    = (autoPlacedCount / 3) * 0.05
//   score      = clamp(hitRate * 0.70 + timeBonus + streakBon - autoPen, 0...1)
// Звёзды: ≥0.90 → 3, ≥0.70 → 2, ≥0.50 → 1, иначе 0.

// MARK: - SortingTaskType

enum SortingTaskType: String, Sendable, Equatable, Hashable {
    case firstSound       = "first_sound"
    case soundPosition    = "sound_position"
    case syllableCount    = "syllable_count"
    case vowelConsonant   = "vowel_consonant"
    case voicedUnvoiced   = "voiced_unvoiced"
    case semantic         = "semantic"
}

// MARK: - Domain: SortingCategory

struct SortingCategory: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let emoji: String
    /// Цветовой акцент для Drop Zone (accessibility color-coded).
    let colorKey: String
}

// MARK: - Domain: SortingWord

struct SortingWord: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let word: String
    let emoji: String
    let correctCategory: String
    /// Фонетическая группа целевого звука в слове (для метаданных / телеметрии).
    let soundGroup: String
    /// Количество слогов (для taskType=syllableCount).
    let syllableCount: Int
    /// Первый звук (для taskType=firstSound).
    let firstSound: String
    /// Позиция звука: "initial" | "medial" | "final" (для taskType=soundPosition).
    let soundPosition: String

    /// Проверка — правильно ли слово положено в категорию `targetCategory`.
    func isCorrect(targetCategory: String) -> Bool {
        correctCategory == targetCategory
    }
}

// MARK: - Domain: SortingSet

/// Полный игровой набор: слова + категории + тип задачи.
struct SortingSet: Sendable, Equatable, Hashable {
    let id: String
    let title: String
    let soundGroup: String
    let taskType: SortingTaskType
    /// Краткое описание задачи для ребёнка (показывается в начале раунда).
    let taskDescription: String
    let categories: [SortingCategory]
    let words: [SortingWord]
}

// MARK: - Content catalog

extension SortingSet {

    // MARK: Task 1: По первому звуку (С / Ш)

    static let firstSoundSet = SortingSet(
        id: "first_sound_s_sh",
        title: "Начало слова",
        soundGroup: "whistling",
        taskType: .firstSound,
        taskDescription: "Разложи слова: в синюю — на звук «С», в зелёную — на звук «Ш»",
        categories: [
            SortingCategory(id: "sound_s", title: "Звук С", emoji: "circle.fill", colorKey: "blue"),
            SortingCategory(id: "sound_sh", title: "Звук Ш", emoji: "circle.fill", colorKey: "green")
        ],
        words: [
            SortingWord(id: "sok_fs", word: "Сок", emoji: "word_cup", correctCategory: "sound_s",
                        soundGroup: "whistling", syllableCount: 1, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "shapka_fs", word: "Шапка", emoji: "word_bag", correctCategory: "sound_sh",
                        soundGroup: "hissing", syllableCount: 2, firstSound: "Ш", soundPosition: "initial"),
            SortingWord(id: "sumka_fs", word: "Сумка", emoji: "word_bag", correctCategory: "sound_s",
                        soundGroup: "whistling", syllableCount: 2, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "shina_fs", word: "Шина", emoji: "word_window", correctCategory: "sound_sh",
                        soundGroup: "hissing", syllableCount: 2, firstSound: "Ш", soundPosition: "initial"),
            SortingWord(id: "slon_fs", word: "Слон", emoji: "word_elephant", correctCategory: "sound_s",
                        soundGroup: "whistling", syllableCount: 1, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "shkaf_fs", word: "Шкаф", emoji: "word_door", correctCategory: "sound_sh",
                        soundGroup: "hissing", syllableCount: 1, firstSound: "Ш", soundPosition: "initial"),
            SortingWord(id: "stol_fs", word: "Стол", emoji: "🪑", correctCategory: "sound_s",
                        soundGroup: "whistling", syllableCount: 1, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "sharf_fs", word: "Шарф", emoji: "word_bag", correctCategory: "sound_sh",
                        soundGroup: "hissing", syllableCount: 1, firstSound: "Ш", soundPosition: "initial")
        ]
    )

    // MARK: Task 2: По положению звука (начало / конец)

    static let soundPositionSet = SortingSet(
        id: "position_s",
        title: "Где звук «С»?",
        soundGroup: "whistling",
        taskType: .soundPosition,
        taskDescription: "Звук «С» в начале или в конце слова?",
        categories: [
            SortingCategory(id: "initial", title: "В начале", emoji: "⬆️", colorKey: "purple"),
            SortingCategory(id: "final", title: "В конце", emoji: "⬇️", colorKey: "orange")
        ],
        words: [
            SortingWord(id: "sok_pos", word: "Сок", emoji: "word_cup", correctCategory: "initial",
                        soundGroup: "whistling", syllableCount: 1, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "nos_pos", word: "Нос", emoji: "mouth.fill", correctCategory: "final",
                        soundGroup: "whistling", syllableCount: 1, firstSound: "Н", soundPosition: "final"),
            SortingWord(id: "sumka_pos", word: "Сумка", emoji: "word_bag", correctCategory: "initial",
                        soundGroup: "whistling", syllableCount: 2, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "les_pos", word: "Лес", emoji: "word_forest", correctCategory: "final",
                        soundGroup: "whistling", syllableCount: 1, firstSound: "Л", soundPosition: "final"),
            SortingWord(id: "son_pos", word: "Сон", emoji: "moon.zzz.fill", correctCategory: "initial",
                        soundGroup: "whistling", syllableCount: 1, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "pes_pos", word: "Пёс", emoji: "word_dog", correctCategory: "final",
                        soundGroup: "whistling", syllableCount: 1, firstSound: "П", soundPosition: "final"),
            SortingWord(id: "sabaka_pos", word: "Собака", emoji: "word_dog", correctCategory: "initial",
                        soundGroup: "whistling", syllableCount: 3, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "kolos_pos", word: "Колос", emoji: "word_flower", correctCategory: "final",
                        soundGroup: "whistling", syllableCount: 2, firstSound: "К", soundPosition: "final")
        ]
    )

    // MARK: Task 3: По количеству слогов (1 / 2 / 3)

    static let syllableCountSet = SortingSet(
        id: "syllable_count",
        title: "Сколько слогов?",
        soundGroup: "any",
        taskType: .syllableCount,
        taskDescription: "Разложи слова по количеству слогов",
        categories: [
            SortingCategory(id: "one", title: "1 слог", emoji: "1️⃣", colorKey: "red"),
            SortingCategory(id: "two", title: "2 слога", emoji: "2️⃣", colorKey: "blue"),
            SortingCategory(id: "three", title: "3 слога", emoji: "3️⃣", colorKey: "green")
        ],
        words: [
            SortingWord(id: "dom_sc", word: "Дом", emoji: "word_house", correctCategory: "one",
                        soundGroup: "any", syllableCount: 1, firstSound: "Д", soundPosition: "initial"),
            SortingWord(id: "koshka_sc", word: "Кошка", emoji: "word_cat", correctCategory: "two",
                        soundGroup: "any", syllableCount: 2, firstSound: "К", soundPosition: "initial"),
            SortingWord(id: "sobaka_sc", word: "Собака", emoji: "word_dog", correctCategory: "three",
                        soundGroup: "any", syllableCount: 3, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "les_sc", word: "Лес", emoji: "word_forest", correctCategory: "one",
                        soundGroup: "any", syllableCount: 1, firstSound: "Л", soundPosition: "initial"),
            SortingWord(id: "reka_sc", word: "Река", emoji: "word_fish", correctCategory: "two",
                        soundGroup: "any", syllableCount: 2, firstSound: "Р", soundPosition: "initial"),
            SortingWord(id: "malina_sc", word: "Малина", emoji: "word_apple", correctCategory: "three",
                        soundGroup: "any", syllableCount: 3, firstSound: "М", soundPosition: "initial"),
            SortingWord(id: "kit_sc", word: "Кит", emoji: "word_fish", correctCategory: "one",
                        soundGroup: "any", syllableCount: 1, firstSound: "К", soundPosition: "initial"),
            SortingWord(id: "ryba_sc", word: "Рыба", emoji: "word_fish", correctCategory: "two",
                        soundGroup: "any", syllableCount: 2, firstSound: "Р", soundPosition: "initial")
        ]
    )

    // MARK: Task 4: Гласные vs Согласные

    static let vowelConsonantSet = SortingSet(
        id: "vowel_consonant",
        title: "Гласный или согласный?",
        soundGroup: "any",
        taskType: .vowelConsonant,
        taskDescription: "Послушай слово. Первый звук — гласный или согласный?",
        categories: [
            SortingCategory(id: "vowel", title: "Гласный", emoji: "circle.fill", colorKey: "red"),
            SortingCategory(id: "consonant", title: "Согласный", emoji: "circle.fill", colorKey: "blue")
        ],
        words: [
            SortingWord(id: "aist_vc", word: "Аист", emoji: "word_bird", correctCategory: "vowel",
                        soundGroup: "any", syllableCount: 2, firstSound: "А", soundPosition: "initial"),
            SortingWord(id: "baran_vc", word: "Баран", emoji: "word_cow", correctCategory: "consonant",
                        soundGroup: "any", syllableCount: 2, firstSound: "Б", soundPosition: "initial"),
            SortingWord(id: "utka_vc", word: "Утка", emoji: "word_bird", correctCategory: "vowel",
                        soundGroup: "any", syllableCount: 2, firstSound: "У", soundPosition: "initial"),
            SortingWord(id: "gora_vc", word: "Гора", emoji: "word_forest", correctCategory: "consonant",
                        soundGroup: "any", syllableCount: 2, firstSound: "Г", soundPosition: "initial"),
            SortingWord(id: "orel_vc", word: "Орёл", emoji: "word_bird", correctCategory: "vowel",
                        soundGroup: "any", syllableCount: 2, firstSound: "О", soundPosition: "initial"),
            SortingWord(id: "dom_vc", word: "Дом", emoji: "word_house", correctCategory: "consonant",
                        soundGroup: "any", syllableCount: 1, firstSound: "Д", soundPosition: "initial"),
            SortingWord(id: "igla_vc", word: "Игла", emoji: "🪡", correctCategory: "vowel",
                        soundGroup: "any", syllableCount: 2, firstSound: "И", soundPosition: "initial"),
            SortingWord(id: "kot_vc", word: "Кот", emoji: "word_cat", correctCategory: "consonant",
                        soundGroup: "any", syllableCount: 1, firstSound: "К", soundPosition: "initial")
        ]
    )

    // MARK: Task 5: Звонкие vs Глухие

    static let voicedUnvoicedSet = SortingSet(
        id: "voiced_unvoiced",
        title: "Звонкий или глухой?",
        soundGroup: "any",
        taskType: .voicedUnvoiced,
        taskDescription: "Первый согласный звук — звонкий или глухой?",
        categories: [
            SortingCategory(id: "voiced", title: "Звонкий", emoji: "bell.fill", colorKey: "yellow"),
            SortingCategory(id: "unvoiced", title: "Глухой", emoji: "bell.slash.fill", colorKey: "gray")
        ],
        words: [
            SortingWord(id: "bochka_vu", word: "Бочка", emoji: "🪣", correctCategory: "voiced",
                        soundGroup: "any", syllableCount: 2, firstSound: "Б", soundPosition: "initial"),
            SortingWord(id: "papa_vu", word: "Папа", emoji: "mascot_lyalya_read", correctCategory: "unvoiced",
                        soundGroup: "any", syllableCount: 2, firstSound: "П", soundPosition: "initial"),
            SortingWord(id: "dub_vu", word: "Дуб", emoji: "word_tree", correctCategory: "voiced",
                        soundGroup: "any", syllableCount: 1, firstSound: "Д", soundPosition: "initial"),
            SortingWord(id: "tortik_vu", word: "Тортик", emoji: "birthday.cake.fill", correctCategory: "unvoiced",
                        soundGroup: "any", syllableCount: 2, firstSound: "Т", soundPosition: "initial"),
            SortingWord(id: "vaza_vu", word: "Ваза", emoji: "leaf.fill", correctCategory: "voiced",
                        soundGroup: "any", syllableCount: 2, firstSound: "В", soundPosition: "initial"),
            SortingWord(id: "futbol_vu", word: "Футбол", emoji: "soccerball", correctCategory: "unvoiced",
                        soundGroup: "any", syllableCount: 2, firstSound: "Ф", soundPosition: "initial"),
            SortingWord(id: "gnom_vu", word: "Гном", emoji: "person.fill", correctCategory: "voiced",
                        soundGroup: "any", syllableCount: 1, firstSound: "Г", soundPosition: "initial"),
            SortingWord(id: "korol_vu", word: "Король", emoji: "crown.fill", correctCategory: "unvoiced",
                        soundGroup: "any", syllableCount: 2, firstSound: "К", soundPosition: "initial")
        ]
    )

    // MARK: Task 6: Семантика (живое / неживое) — универсальный

    static let animateSet = SortingSet(
        id: "animate",
        title: "Живое и неживое",
        soundGroup: "any",
        taskType: .semantic,
        taskDescription: "Разложи: живое или неживое?",
        categories: [
            SortingCategory(id: "living", title: "Живое", emoji: "leaf.fill", colorKey: "green"),
            SortingCategory(id: "nonliving", title: "Неживое", emoji: "🪨", colorKey: "gray")
        ],
        words: [
            SortingWord(id: "kot_an", word: "Кот", emoji: "word_cat", correctCategory: "living",
                        soundGroup: "any", syllableCount: 1, firstSound: "К", soundPosition: "initial"),
            SortingWord(id: "stol_an", word: "Стол", emoji: "🪑", correctCategory: "nonliving",
                        soundGroup: "any", syllableCount: 1, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "reka_an", word: "Река", emoji: "word_fish", correctCategory: "nonliving",
                        soundGroup: "any", syllableCount: 2, firstSound: "Р", soundPosition: "initial"),
            SortingWord(id: "sobaka_an", word: "Собака", emoji: "word_dog", correctCategory: "living",
                        soundGroup: "any", syllableCount: 3, firstSound: "С", soundPosition: "initial"),
            SortingWord(id: "derevo_an", word: "Дерево", emoji: "word_tree", correctCategory: "living",
                        soundGroup: "any", syllableCount: 3, firstSound: "Д", soundPosition: "initial"),
            SortingWord(id: "kniga_an", word: "Книга", emoji: "books.vertical.fill", correctCategory: "nonliving",
                        soundGroup: "any", syllableCount: 2, firstSound: "К", soundPosition: "initial"),
            SortingWord(id: "ryba_an", word: "Рыба", emoji: "word_fish", correctCategory: "living",
                        soundGroup: "any", syllableCount: 2, firstSound: "Р", soundPosition: "initial"),
            SortingWord(id: "dom_an", word: "Дом", emoji: "word_house", correctCategory: "nonliving",
                        soundGroup: "any", syllableCount: 1, firstSound: "Д", soundPosition: "initial")
        ]
    )

    // MARK: - Catalog lookup

    /// Весь каталог (6 наборов).
    static let catalog: [SortingSet] = [
        .animateSet,
        .firstSoundSet,
        .soundPositionSet,
        .syllableCountSet,
        .vowelConsonantSet,
        .voicedUnvoicedSet
    ]

    /// Выбирает подходящий набор для указанной фонетической группы.
    static func set(for soundGroup: String) -> SortingSet {
        switch soundGroup {
        case "whistling": return soundPositionSet
        case "hissing":   return firstSoundSet
        case "sonorant":  return syllableCountSet
        case "velar":     return voicedUnvoicedSet
        default:          return animateSet
        }
    }
}

// MARK: - CategoryStat (per-task summary)

extension SortingModels {
    struct CategoryStat: Sendable, Equatable {
        let categoryId: String
        let title: String
        let correct: Int
        let total: Int
        let accuracy: Float
    }
}

// MARK: - VIP Envelopes

enum SortingModels {

    // MARK: LoadSession

    enum LoadSession {
        struct Request: Sendable {
            let soundGroup: String
            let childName: String
        }
        struct Response: Sendable {
            let setTitle: String
            let taskType: SortingTaskType
            let taskDescription: String
            let words: [SortingWord]
            let categories: [SortingCategory]
            let childName: String
            let timeLimit: Int
        }
        struct ViewModel: Sendable {
            let setTitle: String
            let taskType: SortingTaskType
            let taskDescription: String
            let words: [SortingWord]
            let categories: [SortingCategory]
            let greeting: String
            let timeLimit: Int
        }
    }

    // MARK: ClassifyWord

    enum ClassifyWord {
        struct Request: Sendable {
            let wordId: String
            let categoryId: String
        }
        struct Response: Sendable {
            let correct: Bool
            let wordId: String
            let categoryId: String
            let streak: Int
            let streakBonusTriggered: Bool
            let feedback: String
            let remainingCount: Int
        }
        struct ViewModel: Sendable {
            let correct: Bool
            let wordId: String
            let categoryId: String
            let feedbackText: String
            let streakBadgeVisible: Bool
            let remainingCount: Int
        }
    }

    // MARK: RequestHint

    enum RequestHint {
        struct Request: Sendable {
            let wordId: String
        }
        struct Response: Sendable {
            let wordId: String
            let hintLevel: Int
            let highlightCategoryId: String
            let hintText: String
            let isAutoPlace: Bool
        }
        struct ViewModel: Sendable {
            let wordId: String
            let hintLevel: Int
            let highlightCategoryId: String
            let hintText: String
            let isAutoPlace: Bool
        }
    }

    // MARK: AutoPlace

    enum AutoPlace {
        struct Response: Sendable {
            let wordId: String
            let categoryId: String
        }
        struct ViewModel: Sendable {
            let wordId: String
            let categoryId: String
        }
    }

    // MARK: StreakBonus

    enum StreakBonus {
        struct Response: Sendable {
            let streak: Int
        }
        struct ViewModel: Sendable {
            let streak: Int
            let bonusText: String
        }
    }

    // MARK: TimerTick

    enum TimerTick {
        struct Response: Sendable {
            let remaining: Int
            let expired: Bool
        }
        struct ViewModel: Sendable {
            let timerLabel: String
            let timerColor: String  // "green" | "orange" | "red"
            let expired: Bool
        }
    }

    // MARK: CompleteSession

    enum CompleteSession {
        enum Reason: Sendable, Equatable {
            case allClassified
            case timeExpired
            case autoDistributed
        }
        struct Request: Sendable {}
        struct Response: Sendable {
            let correctCount: Int
            let total: Int
            let humanCorrect: Int
            let humanTotal: Int
            let elapsedSeconds: Int
            let timeLimit: Int
            let bestStreak: Int
            let autoPlacedCount: Int
            let reason: Reason
            let finalScore: Float
            let categoryBreakdown: [CategoryStat]
            let bestCategoryTitle: String?
            let worstCategoryTitle: String?
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            let finalScore: Float
            let categoryBreakdown: [CategoryStat]
            let bestCategoryTitle: String?
            let worstCategoryTitle: String?
            let autoPlacedCount: Int
        }
    }
}

// MARK: - Phase

enum SortingPhase: Sendable, Equatable {
    case loading
    case classifying
    case feedback
    case completed
}

// MARK: - Display Store

@Observable
@MainActor
final class SortingDisplay {
    var setTitle: String = ""
    var taskDescription: String = ""
    var taskType: SortingTaskType = .semantic
    var words: [SortingWord] = []
    var categories: [SortingCategory] = []
    var greeting: String = ""

    /// wordId → categoryId, куда ребёнок положил слово.
    var classifiedWords: [String: String] = [:]
    var correctWords: Set<String> = []
    var incorrectWords: Set<String> = []
    /// Подсвеченная корзина (hint level 1).
    var highlightedCategoryId: String?
    /// Слова, расставленные авто (hint level 3 / auto-distribute).
    var autoPlacedWords: Set<String> = []

    /// Индекс текущего слова в `words` (0…words.count-1).
    var currentWordIndex: Int = 0

    /// Текущая серия правильных ответов подряд.
    var currentStreak: Int = 0
    /// Видим ли сейчас значок «streak!».
    var streakBadgeVisible: Bool = false

    /// Таймер.
    var timeLimit: Int = 90
    var timerLabel: String = "01:30"
    var timerColor: String = "green"

    /// Текст для короткого feedback-оверлея.
    var feedbackText: String = ""
    /// Результат последнего классификационного хода.
    var lastClassificationCorrect: Bool?

    /// Hint.
    var hintText: String = ""
    var hintVisible: Bool = false
    var hintLevel: Int = 0

    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var finalScore: Float = 0
    var categoryBreakdown: [SortingModels.CategoryStat] = []
    var bestCategoryTitle: String?
    var worstCategoryTitle: String?
    var autoPlacedCount: Int = 0
    var phase: SortingPhase = .loading

    /// Финальный скор пробрасывается в SessionShell через `.onChange`.
    var pendingFinalScore: Float?
}
