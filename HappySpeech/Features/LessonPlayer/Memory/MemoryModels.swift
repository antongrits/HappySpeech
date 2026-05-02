import Foundation
import Observation

// MARK: - Memory VIP Models
//
// Классическая игра «Найди пару»: сетка из пар карточек. Ребёнок открывает по
// две; если совпали — остаются лицом вверх, если нет — закрываются через 1.5 с.
//
// Сложности:
//   easy   → 4×4 (8 пар, лимит 60 с)
//   medium → 4×6 (12 пар, лимит 90 с)
//   hard   → 6×6 (18 пар, лимит 120 с)
//
// Структура: 3 раунда (easy→medium→hard) за одну сессию.
// Стрик: 3 матча подряд → streakBonus, 5 подряд → megaStreak.
// Подсказки: 3 уровня (одна карта, пара, все несовпавшие).
//
// Скоринг (per round):
//   base   = matchedPairs / totalPairs
//   bonus  = max(0, (timeLimit - elapsed) / timeLimit) * 0.3
//   score  = clamp(base * 0.7 + bonus, 0...1)
// Итоговый score = среднее по завершённым раундам.
// Звёзды: ≥0.85 → 3, ≥0.65 → 2, ≥0.40 → 1, иначе 0.

// MARK: - MemoryDifficulty

enum MemoryDifficulty: Int, Sendable, CaseIterable, Equatable {
    case easy   = 0
    case medium = 1
    case hard   = 2

    var columns: Int {
        switch self {
        case .easy:   return 4
        case .medium: return 4
        case .hard:   return 6
        }
    }

    var rows: Int {
        switch self {
        case .easy:   return 4
        case .medium: return 6
        case .hard:   return 6
        }
    }

    var pairCount: Int { columns * rows / 2 }

    var timeLimit: Int {
        switch self {
        case .easy:   return 60
        case .medium: return 90
        case .hard:   return 120
        }
    }

    var localizedTitle: String {
        switch self {
        case .easy:   return String(localized: "Лёгкий")
        case .medium: return String(localized: "Средний")
        case .hard:   return String(localized: "Сложный")
        }
    }
}

// MARK: - MemoryCard

struct MemoryCard: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let pairId: String
    let emoji: String
    let word: String
    let soundGroup: String
    var isFaceUp: Bool = false
    var isMatched: Bool = false
    var flipCount: Int = 0
    var firstFlipTimestamp: TimeInterval?
}

// MARK: - MemoryCard deck factory

extension MemoryCard {

    static func deck(for soundGroup: String, difficulty: MemoryDifficulty) -> [MemoryCard] {
        let allPairs = pairs(for: soundGroup)
        let needed = difficulty.pairCount
        let selected = Array(allPairs.shuffled().prefix(needed))
        var cards: [MemoryCard] = []
        for (i, pair) in selected.enumerated() {
            let pid = "pair_\(i)"
            cards.append(MemoryCard(
                id: "\(pid)_a", pairId: pid,
                emoji: pair.emoji, word: pair.word,
                soundGroup: soundGroup
            ))
            cards.append(MemoryCard(
                id: "\(pid)_b", pairId: pid,
                emoji: pair.emoji, word: pair.word,
                soundGroup: soundGroup
            ))
        }
        return cards.shuffled()
    }

    private static func pairs(for soundGroup: String) -> [(emoji: String, word: String)] {
        switch soundGroup {
        case "whistling":
            return [
                ("🦉", "сова"), ("🐍", "змея"), ("🌞", "солнце"),
                ("🍊", "апельсин"), ("🐘", "слон"), ("🌿", "зелень"),
                ("🦢", "цапля"), ("🌸", "цветок"), ("🧲", "замок"),
                ("🚂", "поезд"), ("🦓", "зебра"), ("🌙", "звезда"),
                ("🦋", "стрекоза"), ("🍋", "лимон"), ("🌊", "земля"),
                ("🏔️", "зима"), ("🎵", "звук"), ("🦅", "сокол")
            ]
        case "hissing":
            return [
                ("🐍", "жаба"), ("🌳", "шишка"), ("🐻", "медведь"),
                ("🧸", "мишка"), ("🚂", "машина"), ("🦔", "ёжик"),
                ("🦁", "лев"), ("🐦", "птица"), ("🌲", "ель"),
                ("🍄", "гриб"), ("🏠", "крыша"), ("🐝", "пчела"),
                ("🌼", "ромашка"), ("🎪", "цирк"), ("🐠", "рыба"),
                ("🧃", "щавель"), ("🌺", "чашка"), ("🦜", "попугай")
            ]
        case "sonorant":
            return [
                ("🚀", "ракета"), ("🐟", "рыба"), ("🌹", "роза"),
                ("🐸", "лягушка"), ("🌙", "луна"), ("🐱", "лиса"),
                ("🦁", "лев"), ("🐊", "крокодил"), ("🌈", "радуга"),
                ("🦋", "бабочка"), ("🎸", "лира"), ("🏔️", "гора"),
                ("🐶", "кролик"), ("🌻", "лютик"), ("🎯", "руль"),
                ("🦊", "лось"), ("🌿", "лопух"), ("🐘", "лопата")
            ]
        case "velar":
            return [
                ("🐱", "кот"), ("⛰️", "гора"), ("🦢", "гусь"),
                ("🐟", "карась"), ("🧁", "торт"), ("🐔", "курица"),
                ("🌿", "трава"), ("🎪", "кегля"), ("🎯", "кольцо"),
                ("🦌", "козёл"), ("🐦", "кукушка"), ("🌺", "герань"),
                ("🏠", "коридор"), ("🦅", "ястреб"), ("🎵", "гитара"),
                ("🐊", "крокодил"), ("🌙", "хомяк"), ("🍁", "клён")
            ]
        default:
            return [
                ("🦉", "сова"), ("🐶", "собака"), ("🌳", "дерево"),
                ("🐟", "рыба"), ("🚀", "ракета"), ("🌙", "луна"),
                ("🐱", "кот"), ("⛰️", "гора"), ("🌻", "цветок"),
                ("🦋", "бабочка"), ("🐸", "лягушка"), ("🌈", "радуга"),
                ("🐻", "медведь"), ("🎈", "шарик"), ("🐦", "птица"),
                ("🍎", "яблоко"), ("🚂", "поезд"), ("🌊", "волна")
            ]
        }
    }
}

// MARK: - MemoryCardStat

struct MemoryCardStat: Sendable {
    let pairId: String
    let word: String
    let flipCount: Int
    let matchTimeSeconds: Double
}

// MARK: - MemoryRoundResult

struct MemoryRoundResult: Sendable {
    let difficulty: MemoryDifficulty
    let matchedPairs: Int
    let totalPairs: Int
    let elapsedSeconds: Int
    let timeLimit: Int
    let reason: MemoryGameOverReason
    let cardStats: [MemoryCardStat]
    let streakBonus: Bool
    let megaStreakBonus: Bool

    var score: Float {
        let base = Float(matchedPairs) / Float(max(totalPairs, 1))
        let remaining = max(0, timeLimit - elapsedSeconds)
        let bonus = Float(remaining) / Float(max(timeLimit, 1)) * 0.3
        return min(1, max(0, base * 0.7 + bonus))
    }
}

// MARK: - MemoryGameOverReason

enum MemoryGameOverReason: Sendable, Equatable {
    case allMatched
    case timeExpired
}

// MARK: - MemoryHintLevel

enum MemoryHintLevel: Int, Sendable, CaseIterable, Equatable {
    case single = 1
    case pair   = 2
    case all    = 3
}

// MARK: - VIP Envelopes

enum MemoryModels {

    // MARK: LoadSession
    enum LoadSession {
        struct Request: Sendable {
            let soundGroup: String
            let childName: String
            let startDifficulty: MemoryDifficulty
        }
        struct Response: Sendable {
            let cards: [MemoryCard]
            let childName: String
            let timeLimit: Int
            let difficulty: MemoryDifficulty
            let roundIndex: Int
            let totalRounds: Int
            let hintsRemaining: Int
        }
        struct ViewModel: Sendable {
            let cards: [MemoryCard]
            let greeting: String
            let timeLimitLabel: String
            let difficultyLabel: String
            let roundLabel: String
            let hintsRemaining: Int
            let columns: Int
        }
    }

    // MARK: FlipCard
    enum FlipCard {
        struct Request: Sendable {
            let cardId: String
        }
        struct Response: Sendable {
            let cards: [MemoryCard]
            let matchFound: Bool
            let matchedPairId: String?
            let gameOver: Bool
            let streakCount: Int
            let megaStreak: Bool
            let voiceCue: MemoryVoiceCue?
        }
        struct ViewModel: Sendable {
            let cards: [MemoryCard]
            let matchedPairId: String?
            let gameOverReason: MemoryGameOverReason?
            let streakCount: Int
            let megaStreak: Bool
            let voiceCue: MemoryVoiceCue?
        }
    }

    // MARK: TimerTick
    enum TimerTick {
        struct Request: Sendable {
            let elapsed: Int
        }
        struct Response: Sendable {
            let remaining: Int
            let expired: Bool
        }
        struct ViewModel: Sendable {
            let timerLabel: String
            let expired: Bool
            let timerColor: String
        }
    }

    // MARK: UseHint
    enum UseHint {
        struct Request: Sendable { }
        struct Response: Sendable {
            let highlightedCardIds: [String]
            let hintLevel: MemoryHintLevel
            let hintsRemaining: Int
        }
        struct ViewModel: Sendable {
            let highlightedCardIds: [String]
            let hintLevel: MemoryHintLevel
            let hintsRemaining: Int
            let hintButtonEnabled: Bool
        }
    }

    // MARK: CompleteRound
    enum CompleteRound {
        struct Request: Sendable {
            let result: MemoryRoundResult
            let hasNextRound: Bool
        }
        struct Response: Sendable {
            let result: MemoryRoundResult
            let hasNextRound: Bool
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            let roundSummary: String
            let hasNextRound: Bool
            let finalScore: Float
        }
    }

    // MARK: CompleteSession (legacy alias used by Presenter/View)
    enum CompleteSession {
        struct Request: Sendable {
            let matchedPairs: Int
            let elapsedSeconds: Int
            let reason: MemoryGameOverReason
        }
        struct Response: Sendable {
            let starsEarned: Int
            let scoreLabel: String
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

// MARK: - MemoryVoiceCue

enum MemoryVoiceCue: String, Sendable, Equatable {
    case welcome      = "Найди пары!"
    case match        = "Молодец, пара найдена!"
    case mismatch     = "Ох, не пара. Попробуй другую"
    case streak3      = "Три подряд — отлично!"
    case megaStreak   = "Невероятно! Пять подряд!"
    case roundDone    = "Раунд пройден!"
    case allDone      = "Ты нашёл все пары!"
    case timeWarning  = "Торопись, мало времени!"
    case timeExpired  = "Время вышло — попробуй ещё раз!"
    case hintUsed     = "Я подсказала! Ищи скорее."
}

// MARK: - MemoryPhase

enum MemoryPhase: Sendable, Equatable {
    case loading
    case playing
    case roundCompleted
    case completed
}

// MARK: - Display Store

@Observable
@MainActor
final class MemoryDisplay {
    var cards: [MemoryCard] = []
    var greeting: String = ""
    var timeLimit: Int = 60
    var timerLabel: String = "01:00"
    var timerColor: String = "green"
    var matchedPairs: Int = 0
    var totalPairs: Int = 8
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var roundSummary: String = ""
    var finalScore: Float = 0
    var phase: MemoryPhase = .loading
    var difficultyLabel: String = ""
    var roundLabel: String = ""
    var columns: Int = 4
    var hintsRemaining: Int = 3
    var hintButtonEnabled: Bool = true
    var highlightedCardIds: [String] = []
    var streakCount: Int = 0
    var megaStreak: Bool = false
    var hasNextRound: Bool = false
    var voiceCue: MemoryVoiceCue?

    var lastMatchedPairId: String?
    var isFlipDisabled: Bool = false
    var pendingFinalScore: Float?
}
