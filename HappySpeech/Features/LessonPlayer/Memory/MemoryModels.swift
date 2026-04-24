import Foundation
import Observation

// MARK: - Memory VIP Models
//
// Классическая игра «Найди пару»: сетка 4×4 = 16 карточек (8 пар). Ребёнок
// открывает по две; если совпали — остаются лицом вверх, если нет —
// закрываются через 1 с. Игра заканчивается, когда открыты все пары или
// истёк таймер (60 с).
//
// Скоринг:
//   base   = matchedPairs / 8
//   bonus  = max(0, (timeLimit - elapsed) / timeLimit) * 0.3
//   score  = clamp(base * 0.7 + bonus, 0...1)
// Звёзды: ≥0.85 → 3, ≥0.65 → 2, ≥0.40 → 1, иначе 0.

// MARK: - Domain: MemoryCard

struct MemoryCard: Sendable, Identifiable, Equatable, Hashable {
    let id: String          // уникальный, напр. "pair_0_a" / "pair_0_b"
    let pairId: String      // одинаковый у пары
    let emoji: String
    let word: String
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

extension MemoryCard {

    /// Колода из 8 пар = 16 карточек, перемешанная.
    /// Набор универсальный и подходит под любую фонетическую группу (звуки
    /// представлены разнообразно: С, Р, К, Б, М и т.д.).
    static func deck(for soundGroup: String) -> [MemoryCard] {
        _ = soundGroup
        let pairs: [(emoji: String, word: String)] = [
            ("🦉", "сова"),
            ("🐶", "собака"),
            ("🌳", "дерево"),
            ("🐟", "рыба"),
            ("🚀", "ракета"),
            ("🌙", "луна"),
            ("🐱", "кот"),
            ("⛰️", "гора")
        ]
        var cards: [MemoryCard] = []
        for (i, pair) in pairs.enumerated() {
            let pid = "pair_\(i)"
            cards.append(MemoryCard(
                id: "\(pid)_a", pairId: pid, emoji: pair.emoji, word: pair.word
            ))
            cards.append(MemoryCard(
                id: "\(pid)_b", pairId: pid, emoji: pair.emoji, word: pair.word
            ))
        }
        return cards.shuffled()
    }
}

// MARK: - Game over reason

enum MemoryGameOverReason: Sendable, Equatable {
    case allMatched
    case timeExpired
}

// MARK: - VIP Envelopes

enum MemoryModels {

    // MARK: LoadSession
    enum LoadSession {
        struct Request: Sendable {
            let soundGroup: String
            let childName: String
        }
        struct Response: Sendable {
            let cards: [MemoryCard]
            let childName: String
            let timeLimit: Int          // секунды
        }
        struct ViewModel: Sendable {
            let cards: [MemoryCard]
            let greeting: String
            let timeLimitLabel: String
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
        }
        struct ViewModel: Sendable {
            let cards: [MemoryCard]
            let matchedPairId: String?
            let gameOverReason: MemoryGameOverReason?
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
            let timerColor: String      // "green" | "orange" | "red"
        }
    }

    // MARK: CompleteSession
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

// MARK: - Phase

enum MemoryPhase: Sendable, Equatable {
    case loading
    case playing
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
    var finalScore: Float = 0
    var phase: MemoryPhase = .loading

    /// PairId последней найденной пары — для анимации.
    var lastMatchedPairId: String?
    /// Блок переворотов пока ждём проверку пары (1 с).
    var isFlipDisabled: Bool = false

    /// Финальный скор пробрасывается в SessionShell через `.onChange`.
    var pendingFinalScore: Float?
}
