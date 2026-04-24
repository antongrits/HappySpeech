import Foundation
import CoreTransferable
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

// MARK: - Content sets

extension DragWord {

    /// Набор для группы свистящих: "Есть звук С" vs "Нет звука С".
    static let whistlingSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "sova",   word: "сова",   emoji: "🦉", correctBucketId: "has_s"),
            DragWord(id: "sobaka", word: "собака", emoji: "🐶", correctBucketId: "has_s"),
            DragWord(id: "sad",    word: "сад",    emoji: "🌳", correctBucketId: "has_s"),
            DragWord(id: "ryba",   word: "рыба",   emoji: "🐟", correctBucketId: "no_s"),
            DragWord(id: "luna",   word: "луна",   emoji: "🌙", correctBucketId: "no_s"),
            DragWord(id: "gora",   word: "гора",   emoji: "⛰️", correctBucketId: "no_s"),
        ],
        [
            DragBucket(id: "has_s", title: "Есть звук «С»", emoji: "✅", color: "mint"),
            DragBucket(id: "no_s",  title: "Нет звука «С»", emoji: "❌", color: "lilac"),
        ]
    )

    /// Набор для шипящих: "Есть звук Ш" vs "Нет звука Ш".
    static let hissingSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "shapka",  word: "шапка",  emoji: "🧢", correctBucketId: "has_sh"),
            DragWord(id: "kashka",  word: "кашка",  emoji: "🥣", correctBucketId: "has_sh"),
            DragWord(id: "mashka",  word: "мышка",  emoji: "🐭", correctBucketId: "has_sh"),
            DragWord(id: "kot",     word: "кот",    emoji: "🐱", correctBucketId: "no_sh"),
            DragWord(id: "dom",     word: "дом",    emoji: "🏠", correctBucketId: "no_sh"),
            DragWord(id: "les",     word: "лес",    emoji: "🌲", correctBucketId: "no_sh"),
        ],
        [
            DragBucket(id: "has_sh", title: "Есть звук «Ш»", emoji: "✅", color: "mint"),
            DragBucket(id: "no_sh",  title: "Нет звука «Ш»", emoji: "❌", color: "lilac"),
        ]
    )

    /// Набор для соноров: "Есть звук Р" vs "Нет звука Р".
    static let sonorantSet: ([DragWord], [DragBucket]) = (
        [
            DragWord(id: "rak",    word: "рак",    emoji: "🦞", correctBucketId: "has_r"),
            DragWord(id: "rosa",   word: "роза",   emoji: "🌹", correctBucketId: "has_r"),
            DragWord(id: "raketa", word: "ракета", emoji: "🚀", correctBucketId: "has_r"),
            DragWord(id: "kot2",   word: "кот",    emoji: "🐱", correctBucketId: "no_r"),
            DragWord(id: "luna2",  word: "луна",   emoji: "🌙", correctBucketId: "no_r"),
            DragWord(id: "vaza",   word: "ваза",   emoji: "🏺", correctBucketId: "no_r"),
        ],
        [
            DragBucket(id: "has_r", title: "Есть звук «Р»", emoji: "✅", color: "mint"),
            DragBucket(id: "no_r",  title: "Нет звука «Р»", emoji: "❌", color: "lilac"),
        ]
    )

    /// Возвращает набор слов+корзин для переданной фонетической группы.
    /// Ключи: "whistling" | "hissing" | "sonorant" | "velar" | "С" | "Ш" | "Р" | "Л" | "К".
    static func set(for soundGroup: String) -> ([DragWord], [DragBucket]) {
        switch soundGroup.lowercased() {
        case "hissing", "ш", "ж", "ч", "щ":
            return hissingSet
        case "sonorant", "р", "л":
            return sonorantSet
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
        }
        struct Response: Sendable {
            let words: [DragWord]
            let buckets: [DragBucket]
            let childName: String
        }
        struct ViewModel: Sendable {
            let words: [DragWord]
            let buckets: [DragBucket]
            let greeting: String
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
        }
        struct ViewModel: Sendable {
            let correct: Bool
            let wordId: String
            let feedbackText: String
        }
    }

    // MARK: CompleteSession
    enum CompleteSession {
        struct Request: Sendable {}
        struct Response: Sendable {
            let correctCount: Int
            let totalWords: Int
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
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

    /// wordId → bucketId (куда слово попало).
    var placedWords: [String: String] = [:]
    var correctWords: Set<String> = []
    var incorrectWords: Set<String> = []
    var feedbackText: String = ""

    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var phase: DragPhase = .loading

    /// Финальный скор пробрасывается в SessionShell через `.onChange`.
    var pendingFinalScore: Float?
}

enum DragPhase: Sendable, Equatable {
    case loading
    case playing
    case completed
}
