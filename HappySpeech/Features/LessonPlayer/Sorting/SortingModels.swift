import Foundation
import Observation

// MARK: - Sorting VIP Models
//
// «Сортировка по категориям» — ребёнок раскладывает слова по 2 корзинам.
// По каждому слову Interactor проверяет выбор, даёт haptic-фидбек и показывает
// короткую подсветку. После N слов (или по таймеру) — авто-завершение и
// звёзды по комбинированному скору hitRate + timeBonus + streakBonus.
//
// Скоринг:
//   hitRate    = correct / total
//   timeBonus  = max(0, (timeLimit - elapsed) / timeLimit) * 0.2
//   streakBon  = min(0.15, bestStreak * 0.03)
//   score      = clamp(hitRate * 0.75 + timeBonus + streakBon, 0...1)
// Звёзды: ≥0.90 → 3, ≥0.70 → 2, ≥0.50 → 1, иначе 0.
//
// Файл содержит доменные типы (SortingWord / SortingCategory / SortingSet),
// каталог из 6+ наборов, VIP-конверты и @Observable Display-store.

// MARK: - Domain: SortingCategory

struct SortingCategory: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let emoji: String
}

// MARK: - Domain: SortingWord

struct SortingWord: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let word: String
    let emoji: String
    let correctCategory: String
    /// Фонетическая группа целевого звука в слове (для метаданных / телеметрии).
    let soundGroup: String

    /// Проверка — правильно ли слово положено в категорию `targetCategory`.
    func isCorrect(targetCategory: String) -> Bool {
        correctCategory == targetCategory
    }
}

// MARK: - Domain: SortingSet

/// Полный игровой набор: 8 слов + 2 категории.
/// Название набора — человекочитаемая метка для логов и аналитики.
struct SortingSet: Sendable, Equatable, Hashable {
    let id: String
    let title: String
    let soundGroup: String
    let categories: [SortingCategory]
    let words: [SortingWord]
}

// MARK: - Content catalog

extension SortingSet {

    /// «Живое / Неживое» — универсальный, подходит для любой группы.
    static let animateSet = SortingSet(
        id: "animate",
        title: "Живое и неживое",
        soundGroup: "any",
        categories: [
            SortingCategory(id: "living",    title: "Живое",   emoji: "🌱"),
            SortingCategory(id: "nonliving", title: "Неживое", emoji: "🪨")
        ],
        words: [
            SortingWord(id: "kot",    word: "Кот",    emoji: "🐱", correctCategory: "living",    soundGroup: "any"),
            SortingWord(id: "stol",   word: "Стол",   emoji: "🪑", correctCategory: "nonliving", soundGroup: "any"),
            SortingWord(id: "reka",   word: "Река",   emoji: "🌊", correctCategory: "nonliving", soundGroup: "any"),
            SortingWord(id: "sobaka", word: "Собака", emoji: "🐶", correctCategory: "living",    soundGroup: "whistling"),
            SortingWord(id: "derevo", word: "Дерево", emoji: "🌳", correctCategory: "living",    soundGroup: "any"),
            SortingWord(id: "kniga",  word: "Книга",  emoji: "📚", correctCategory: "nonliving", soundGroup: "velar"),
            SortingWord(id: "ryba",   word: "Рыба",   emoji: "🐟", correctCategory: "living",    soundGroup: "sonorant"),
            SortingWord(id: "dom",    word: "Дом",    emoji: "🏠", correctCategory: "nonliving", soundGroup: "any")
        ]
    )

    /// Фрукты и овощи — слова со свистящими С/З/Ц.
    static let fruitsVeggiesSet = SortingSet(
        id: "fruits_veggies",
        title: "Фрукты и овощи",
        soundGroup: "whistling",
        categories: [
            SortingCategory(id: "fruit",  title: "Фрукты",  emoji: "🍎"),
            SortingCategory(id: "veggie", title: "Овощи",   emoji: "🥕")
        ],
        words: [
            SortingWord(id: "sliva",   word: "Слива",   emoji: "🟣", correctCategory: "fruit",  soundGroup: "whistling"),
            SortingWord(id: "svekla",  word: "Свёкла",  emoji: "🟥", correctCategory: "veggie", soundGroup: "whistling"),
            SortingWord(id: "apelsin", word: "Апельсин", emoji: "🍊", correctCategory: "fruit",  soundGroup: "whistling"),
            SortingWord(id: "kapusta", word: "Капуста", emoji: "🥬", correctCategory: "veggie", soundGroup: "whistling"),
            SortingWord(id: "abrikos", word: "Абрикос", emoji: "🍑", correctCategory: "fruit",  soundGroup: "whistling"),
            SortingWord(id: "salat",   word: "Салат",   emoji: "🥗", correctCategory: "veggie", soundGroup: "whistling"),
            SortingWord(id: "persik",  word: "Персик",  emoji: "🍑", correctCategory: "fruit",  soundGroup: "whistling"),
            SortingWord(id: "spar",    word: "Спаржа",  emoji: "🌾", correctCategory: "veggie", soundGroup: "whistling")
        ]
    )

    /// Транспорт и животные — слова с шипящими Ш/Ж/Ч/Щ.
    static let transportAnimalsSet = SortingSet(
        id: "transport_animals",
        title: "Транспорт и животные",
        soundGroup: "hissing",
        categories: [
            SortingCategory(id: "transport", title: "Транспорт", emoji: "🚗"),
            SortingCategory(id: "animal",    title: "Животные",  emoji: "🐾")
        ],
        words: [
            SortingWord(id: "mashina",  word: "Машина", emoji: "🚗", correctCategory: "transport", soundGroup: "hissing"),
            SortingWord(id: "zhiraf",   word: "Жираф",  emoji: "🦒", correctCategory: "animal",    soundGroup: "hissing"),
            SortingWord(id: "shluka",   word: "Шлюпка", emoji: "🛶", correctCategory: "transport", soundGroup: "hissing"),
            SortingWord(id: "yozh",     word: "Ёжик",   emoji: "🦔", correctCategory: "animal",    soundGroup: "hissing"),
            SortingWord(id: "shina",    word: "Шина",   emoji: "🛞", correctCategory: "transport", soundGroup: "hissing"),
            SortingWord(id: "medvezh",  word: "Медвежонок", emoji: "🐻", correctCategory: "animal", soundGroup: "hissing"),
            SortingWord(id: "parovoz",  word: "Паровоз", emoji: "🚂", correctCategory: "transport", soundGroup: "hissing"),
            SortingWord(id: "cherep",   word: "Черепаха", emoji: "🐢", correctCategory: "animal",   soundGroup: "hissing")
        ]
    )

    /// Посуда и одежда — слова с сонорами Р/Л.
    static let dishesClothesSet = SortingSet(
        id: "dishes_clothes",
        title: "Посуда и одежда",
        soundGroup: "sonorant",
        categories: [
            SortingCategory(id: "dish",    title: "Посуда",  emoji: "🍽️"),
            SortingCategory(id: "clothes", title: "Одежда",  emoji: "👕")
        ],
        words: [
            SortingWord(id: "tarelka", word: "Тарелка", emoji: "🍽️", correctCategory: "dish",    soundGroup: "sonorant"),
            SortingWord(id: "rubashka", word: "Рубашка", emoji: "👔", correctCategory: "clothes", soundGroup: "sonorant"),
            SortingWord(id: "kastrul",  word: "Кастрюля", emoji: "🥘", correctCategory: "dish",   soundGroup: "sonorant"),
            SortingWord(id: "plat",     word: "Платье",  emoji: "👗", correctCategory: "clothes", soundGroup: "sonorant"),
            SortingWord(id: "lozhka",   word: "Ложка",   emoji: "🥄", correctCategory: "dish",    soundGroup: "sonorant"),
            SortingWord(id: "shlyapa",  word: "Шляпа",   emoji: "🎩", correctCategory: "clothes", soundGroup: "sonorant"),
            SortingWord(id: "chaynik",  word: "Чайник",  emoji: "🫖", correctCategory: "dish",    soundGroup: "sonorant"),
            SortingWord(id: "kurtka",   word: "Куртка",  emoji: "🧥", correctCategory: "clothes", soundGroup: "sonorant")
        ]
    )

    /// Небо и земля — слова с заднеязычными К/Г/Х.
    static let skyEarthSet = SortingSet(
        id: "sky_earth",
        title: "Небо и земля",
        soundGroup: "velar",
        categories: [
            SortingCategory(id: "sky",   title: "Небо",  emoji: "☁️"),
            SortingCategory(id: "earth", title: "Земля", emoji: "🌍")
        ],
        words: [
            SortingWord(id: "oblako",  word: "Облако", emoji: "☁️",  correctCategory: "sky",   soundGroup: "velar"),
            SortingWord(id: "kamen",   word: "Камень", emoji: "🪨",  correctCategory: "earth", soundGroup: "velar"),
            SortingWord(id: "samolet", word: "Самолёт", emoji: "✈️", correctCategory: "sky",   soundGroup: "velar"),
            SortingWord(id: "gora",    word: "Гора",   emoji: "⛰️",  correctCategory: "earth", soundGroup: "velar"),
            SortingWord(id: "luna",    word: "Луна",   emoji: "🌙",  correctCategory: "sky",   soundGroup: "velar"),
            SortingWord(id: "kust",    word: "Куст",   emoji: "🌳",  correctCategory: "earth", soundGroup: "velar"),
            SortingWord(id: "raduga",  word: "Радуга", emoji: "🌈",  correctCategory: "sky",   soundGroup: "velar"),
            SortingWord(id: "kolodets", word: "Колодец", emoji: "🪣", correctCategory: "earth", soundGroup: "velar")
        ]
    )

    /// Начало и конец слова — тренировка позиции звука.
    static let positionSet = SortingSet(
        id: "position_s",
        title: "Звук в начале или в конце",
        soundGroup: "whistling",
        categories: [
            SortingCategory(id: "initial", title: "В начале", emoji: "🔤"),
            SortingCategory(id: "final",   title: "В конце",  emoji: "🔚")
        ],
        words: [
            SortingWord(id: "sok",    word: "Сок",   emoji: "🧃", correctCategory: "initial", soundGroup: "whistling"),
            SortingWord(id: "nos",    word: "Нос",   emoji: "👃", correctCategory: "final",   soundGroup: "whistling"),
            SortingWord(id: "sumka",  word: "Сумка", emoji: "👜", correctCategory: "initial", soundGroup: "whistling"),
            SortingWord(id: "les",    word: "Лес",   emoji: "🌲", correctCategory: "final",   soundGroup: "whistling"),
            SortingWord(id: "son",    word: "Сон",   emoji: "💤", correctCategory: "initial", soundGroup: "whistling"),
            SortingWord(id: "pes",    word: "Пёс",   emoji: "🐕", correctCategory: "final",   soundGroup: "whistling"),
            SortingWord(id: "sobaka", word: "Собака", emoji: "🐶", correctCategory: "initial", soundGroup: "whistling"),
            SortingWord(id: "kolos",  word: "Колос", emoji: "🌾", correctCategory: "final",   soundGroup: "whistling")
        ]
    )

    // MARK: - Catalog lookup

    /// Весь каталог (6 наборов).
    static let catalog: [SortingSet] = [
        .animateSet,
        .fruitsVeggiesSet,
        .transportAnimalsSet,
        .dishesClothesSet,
        .skyEarthSet,
        .positionSet
    ]

    /// Выбирает подходящий набор для указанной фонетической группы.
    /// Если для группы ничего нет — возвращает универсальный animateSet.
    static func set(for soundGroup: String) -> SortingSet {
        let matches = catalog.filter { $0.soundGroup == soundGroup }
        if let first = matches.first { return first }
        return animateSet
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
            let words: [SortingWord]
            let categories: [SortingCategory]
            let childName: String
            let timeLimit: Int      // секунды
        }
        struct ViewModel: Sendable {
            let setTitle: String
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
            let streak: Int
            let streakBonusTriggered: Bool
            let feedback: String
        }
        struct ViewModel: Sendable {
            let correct: Bool
            let wordId: String
            let feedbackText: String
            let streakBadgeVisible: Bool
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
        }
        struct Request: Sendable {}
        struct Response: Sendable {
            let correctCount: Int
            let total: Int
            let elapsedSeconds: Int
            let timeLimit: Int
            let bestStreak: Int
            let reason: Reason
            let finalScore: Float
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            let finalScore: Float
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
    var words: [SortingWord] = []
    var categories: [SortingCategory] = []
    var greeting: String = ""

    /// wordId → categoryId, куда ребёнок положил слово.
    var classifiedWords: [String: String] = [:]
    var correctWords: Set<String> = []
    var incorrectWords: Set<String> = []

    /// Индекс текущего слова в `words` (0…words.count-1).
    var currentWordIndex: Int = 0

    /// Текущая серия правильных ответов подряд.
    var currentStreak: Int = 0
    /// Видим ли сейчас значок «streak!» (сбрасывается с phase=classifying).
    var streakBadgeVisible: Bool = false

    /// Таймер.
    var timeLimit: Int = 90
    var timerLabel: String = "01:30"
    var timerColor: String = "green"

    /// Текст для короткого feedback-оверлея («Верно!»/«Попробуй ещё…»).
    var feedbackText: String = ""
    /// Результат последнего классификационного хода (для подсветки оверлея).
    var lastClassificationCorrect: Bool?

    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var finalScore: Float = 0
    var phase: SortingPhase = .loading

    /// Финальный скор пробрасывается в SessionShell через `.onChange`.
    var pendingFinalScore: Float?
}
