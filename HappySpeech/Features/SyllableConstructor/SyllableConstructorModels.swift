import Foundation

// MARK: - SyllableConstructorModels (Clean Swift: Models)
//
// v31 Волна B, Функция Ф.1 «Слог-конструктор».
//
// Методика: классы Марковой по сложности слоговой структуры (А.К. Маркова,
// «Преодоление общего недоразвития речи у дошкольников»). Ребёнок собирает
// слово из перемешанных слогов — это упражнение на сохранение слоговой
// структуры, ключевое в коррекции ОНР и стёртой дизартрии.
//
// 4 уровня сложности:
//  1. Открытый односложный («ма») — двухсложные открытые («ма-ма»).
//  2. Двухсложные открытые с разнотипной структурой («во-да»).
//  3. Трёхсложные, включая закрытый слог («ма-ши-на»).
//  4. Со стечением согласных («стол», «кни-га»).
//
// Контент — `SyllableConstructorCorpus`, читается из bundled JSON. Полностью
// offline / on-device.

// MARK: - SyllableTier

/// Уровень сложности слоговой структуры.
public enum SyllableTier: Int, CaseIterable, Sendable, Codable {
    case oneSyllableOpen = 1
    case twoSyllablesOpen = 2
    case threeSyllablesWithClosed = 3
    case consonantCluster = 4

    public var titleKey: String {
        switch self {
        case .oneSyllableOpen:           return "syllable.tier.1.title"
        case .twoSyllablesOpen:          return "syllable.tier.2.title"
        case .threeSyllablesWithClosed:  return "syllable.tier.3.title"
        case .consonantCluster:          return "syllable.tier.4.title"
        }
    }

    public var hintKey: String {
        switch self {
        case .oneSyllableOpen:           return "syllable.tier.1.hint"
        case .twoSyllablesOpen:          return "syllable.tier.2.hint"
        case .threeSyllablesWithClosed:  return "syllable.tier.3.hint"
        case .consonantCluster:          return "syllable.tier.4.hint"
        }
    }
}

// MARK: - SyllableWord

/// Слово корпуса — целевая запись + методически верное разбиение на слоги.
public struct SyllableWord: Sendable, Equatable, Identifiable, Codable {

    public let id: String
    /// Целевое слово в виде «как пишется» (нижний регистр).
    public let word: String
    /// Слоги в правильном порядке, методически верно разбитые.
    public let syllables: [String]
    public let tier: SyllableTier
    /// Опциональный SF Symbol (для визуального ключа).
    public let symbolName: String?
    /// Опциональный идентификатор аудио (m4a), если в `Audio/Lyalya/lessons/` есть запись.
    public let audioPhraseId: String?

    public init(
        id: String,
        word: String,
        syllables: [String],
        tier: SyllableTier,
        symbolName: String? = nil,
        audioPhraseId: String? = nil
    ) {
        self.id = id
        self.word = word
        self.syllables = syllables
        self.tier = tier
        self.symbolName = symbolName
        self.audioPhraseId = audioPhraseId
    }
}

// MARK: - SyllableConstructorModels namespace

enum SyllableConstructorModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            let preferredTier: SyllableTier?
        }

        struct Response: Sendable {
            let tier: SyllableTier
            let word: SyllableWord
            let shuffledTiles: [SyllableTile]
            let availableTiers: [SyllableTier]
            let totalWordsInTier: Int
            let wordIndex: Int
        }

        struct ViewModel: Sendable {
            let title: String
            let tierLabel: String
            let tierHint: String
            let wordLabel: String
            let placeholdersCount: Int
            let tiles: [TileViewModel]
            let availableTiers: [TierChip]
            let progressLabel: String
            let symbolName: String?
            let accessibilityLabel: String
        }

        struct TileViewModel: Identifiable, Sendable, Equatable, Hashable {
            let id: String
            let text: String
            let accessibilityLabel: String
        }

        struct TierChip: Identifiable, Sendable, Equatable, Hashable {
            let id: Int
            let title: String
            let isSelected: Bool
        }
    }

    // MARK: SubmitGuess

    enum SubmitGuess {
        struct Request: Sendable {
            let tileIds: [String]
        }

        struct Response: Sendable {
            let isCorrect: Bool
            let assembled: String
            let expected: String
        }

        struct ViewModel: Sendable {
            let isCorrect: Bool
            let toastTitle: String
            let toastDetail: String
            let assembled: String
        }
    }

    // MARK: NextWord

    enum NextWord {
        struct Request: Sendable {
            let nextTier: SyllableTier?
        }
    }
}

// MARK: - SyllableTile

/// Внутренняя модель плитки слога с уникальным id (могут быть повторяющиеся
/// слоги, например «ма-ма», поэтому id отличается от текста).
public struct SyllableTile: Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}
