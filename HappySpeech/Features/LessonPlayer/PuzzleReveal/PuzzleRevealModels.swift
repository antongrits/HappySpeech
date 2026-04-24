import Foundation
import Observation

// MARK: - PuzzleReveal VIP Models
//
// «Сложи пазл»: 9 плиток (3×3) закрывают картинку. За каждое правильно
// произнесённое слово открывается одна плитка. После 9 попыток весь пазл
// виден — переход к следующему пазлу. Всего 5 пазлов в сессии.
//
// Режима два:
//   • с ASR (WhisperKit готов) — пишем аудио, транскрибируем;
//   • fallback — кнопка «Я произнёс!» + pseudo-random score в диапазоне,
//     который всегда даёт ребёнку ощущение прогресса.

enum PuzzleRevealModels {

    // MARK: - LoadPuzzle

    enum LoadPuzzle {
        struct Request {
            let activity: SessionActivity
            let puzzleIndex: Int
        }
        struct Response {
            let tiles: [PuzzleTile]
            let word: String
            let emoji: String
            let hintText: String
            let puzzleIndex: Int
            let totalPuzzles: Int
            let attemptNumber: Int
            let isASRAvailable: Bool
        }
        struct ViewModel {
            let tiles: [PuzzleTile]
            let word: String
            let emoji: String
            let hintText: String
            let puzzleIndex: Int
            let totalPuzzles: Int
            let attemptNumber: Int
            let progressFraction: Double
            let isASRAvailable: Bool
        }
    }

    // MARK: - StartRecord

    enum StartRecord {
        struct Request {}
        struct Response {}
        struct ViewModel {}
    }

    // MARK: - StopRecord

    enum StopRecord {
        struct Request {}
        struct Response {}
        struct ViewModel {}
    }

    // MARK: - RevealTile

    enum RevealTile {
        struct Request {
            let tileIndex: Int
            let score: Float
        }
        struct Response {
            let tileIndex: Int
            let score: Float
            let tiles: [PuzzleTile]
            let allRevealed: Bool
            let attemptNumber: Int
        }
        struct ViewModel {
            let tileIndex: Int
            let tiles: [PuzzleTile]
            let feedbackText: String
            let lastScore: Float
            let progressFraction: Double
            let attemptNumber: Int
            let allRevealed: Bool
        }
    }

    // MARK: - NextPuzzle

    enum NextPuzzle {
        struct Request {}
        struct Response {
            let hasNext: Bool
        }
        struct ViewModel {
            let hasNext: Bool
        }
    }

    // MARK: - Complete

    enum Complete {
        struct Request {}
        struct Response {
            let averageScore: Float
            let starsEarned: Int
        }
        struct ViewModel {
            let finalScore: Float
            let starsEarned: Int
            let scoreLabel: String
            let completionMessage: String
        }
    }
}

// MARK: - Domain

struct PuzzleTile: Identifiable, Sendable, Equatable {
    let id: UUID
    let index: Int          // 0..8
    var isRevealed: Bool
    var revealScore: Float  // 0.0, пока не открыта

    init(id: UUID = UUID(), index: Int, isRevealed: Bool = false, revealScore: Float = 0) {
        self.id = id
        self.index = index
        self.isRevealed = isRevealed
        self.revealScore = revealScore
    }
}

struct PuzzleItem: Sendable, Equatable {
    let word: String        // целевое слово
    let emoji: String       // показывается под открытой плиткой
    let soundGroup: String
    let hintText: String    // «Произнеси слово с буквой «Р»»
}

enum PuzzlePhase: Sendable, Equatable {
    case loading
    case ready           // пазл закрыт, ждём нажатия «Говори»
    case recording       // запись идёт
    case evaluating      // ASR / fallback считает score
    case tileReveal      // только что открыли плитку — анимация
    case puzzleComplete  // все 9 плиток открыты
    case completed       // финал всей сессии (5 пазлов пройдены)
}

// MARK: - PuzzleRevealDisplay

@Observable
@MainActor
final class PuzzleRevealDisplay {

    // Plate / grid
    var tiles: [PuzzleTile] = []
    var word: String = ""
    var emoji: String = ""
    var hintText: String = ""

    // Phase & progress
    var phase: PuzzlePhase = .loading
    var puzzleIndex: Int = 0
    var totalPuzzles: Int = 5
    var attemptNumber: Int = 0     // 1..9 — какая плитка открывается следующей
    var progressFraction: Double = 0

    // Feedback / scoring
    var lastScore: Float = 0
    var lastFeedback: String = ""
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var finalScore: Float = 0

    // Environment
    var isASRAvailable: Bool = false
    var revealingTileIndex: Int? = nil   // текущая плитка в анимации

    // Publishing hook — когда View готов передать score наверх.
    var pendingFinalScore: Float? = nil
}
