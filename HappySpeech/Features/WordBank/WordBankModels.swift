import Foundation

// MARK: - WordBankModels (Clean Swift: Models)
//
// F-303 v25 — «Копилка слов».
//
// Сущности фичи:
//   • WordStat — агрегат по освоенному слову
//   • WordTileViewModel — карточка слова в сетке
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: read-only — агрегирует Attempt из Session (через SessionRepository).
// Offline-first, без нового ML.

// MARK: - BankWordStat

/// Агрегат по конкретному освоенному слову.
public struct BankWordStat: Identifiable, Sendable, Equatable {
    public let id: String          // word + "_" + targetSound
    public let word: String
    public let targetSound: String
    public let avgScore: Double
    public let attemptCount: Int
    public let lastPracticedAt: Date
    public let isCorrectCount: Int

    public init(
        id: String,
        word: String,
        targetSound: String,
        avgScore: Double,
        attemptCount: Int,
        lastPracticedAt: Date,
        isCorrectCount: Int
    ) {
        self.id = id
        self.word = word
        self.targetSound = targetSound
        self.avgScore = avgScore
        self.attemptCount = attemptCount
        self.lastPracticedAt = lastPracticedAt
        self.isCorrectCount = isCorrectCount
    }
}

// MARK: - WordTileViewModel

/// Карточка слова в сетке копилки.
public struct WordTileViewModel: Identifiable, Sendable, Equatable {
    public let id: String
    public let word: String
    public let targetSoundLabel: String  // «Ш»
    public let starRating: Int           // 1–3
    public let tileTint: WordTileTint

    public init(
        id: String,
        word: String,
        targetSoundLabel: String,
        starRating: Int,
        tileTint: WordTileTint
    ) {
        self.id = id
        self.word = word
        self.targetSoundLabel = targetSoundLabel
        self.starRating = starRating
        self.tileTint = tileTint
    }
}

// MARK: - WordTileTint

/// Цветовая категория карточки слова — выбирается по числу звёзд.
public enum WordTileTint: Sendable, Equatable {
    case gold    // 3 звезды
    case mint    // 2 звезды
    case neutral // 1 звезда
}

// MARK: - WordBankModels namespace

enum WordBankModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let wordStats: [BankWordStat]
        }

        struct ViewModel: Sendable, Equatable {
            let totalCount: Int
            let counterText: String       // «47»
            let soundFilters: [String]    // ["Ш", "Р", "С"] — только звуки с данными
            let tiles: [WordTileViewModel]
            let isEmpty: Bool
        }
    }

    // MARK: Filter

    enum Filter {
        struct Request: Sendable {
            let soundTarget: String?      // nil — все звуки
        }

        struct Response: Sendable {
            let filtered: [BankWordStat]
        }

        struct ViewModel: Sendable, Equatable {
            let tiles: [WordTileViewModel]
        }
    }

    // MARK: SelectWord

    enum SelectWord {
        struct Request: Sendable {
            let wordId: String
        }

        struct Response: Sendable {
            let stat: BankWordStat
        }

        struct ViewModel: Sendable, Equatable {
            let word: String
            let starRating: Int
            let attemptCountText: String  // «Сказано 4 раза»
            let lastPracticedText: String // «последний раз вчера»
            let targetSound: String
        }
    }

    // MARK: Practice

    enum Practice {
        struct Request: Sendable {
            let word: String
            let targetSound: String
        }
    }
}
