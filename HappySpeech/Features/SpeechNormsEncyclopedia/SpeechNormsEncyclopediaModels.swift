import Foundation

// MARK: - SpeechNormsEncyclopediaModels (Clean Swift: Models)
//
// v31 Волна A, Функция Ф10 «Что должно быть в возрасте».
//
// Энциклопедия речевых норм для родителей: возрастные ориентиры 5–8 лет
// по 5 осям (звуки, словарь, грамматика, связная речь, моторика/понимание)
// + красные флаги. Контент основан на методологии:
// Гвоздев А.Н. «Вопросы изучения детской речи»; Цейтлин С.Н. «Язык и ребёнок»;
// Архипова Е.Ф. «Стёртая дизартрия у детей»; Филичёва Т.Б., Чиркина Г.В.
// «Подготовка к школе детей с ОНР».
//
// Эти карточки — справка, а не диагноз. Контент полностью offline.

// MARK: - NormAge

/// Возраст ребёнка, к которому относится карточка нормы.
public enum NormAge: Int, CaseIterable, Sendable {
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8

    public var titleKey: String {
        switch self {
        case .five:  return "speechNorms.age.5"
        case .six:   return "speechNorms.age.6"
        case .seven: return "speechNorms.age.7"
        case .eight: return "speechNorms.age.8"
        }
    }
}

// MARK: - NormAxis

/// Ось содержания карточки: 5 содержательных осей + красные флаги + обзорный материал.
public enum NormAxis: String, CaseIterable, Sendable {
    case overview
    case sounds
    case vocabulary
    case grammar
    case connected
    case motor
    case redflags

    public var titleKey: String {
        switch self {
        case .overview:   return "speechNorms.axis.overview"
        case .sounds:     return "speechNorms.axis.sounds"
        case .vocabulary: return "speechNorms.axis.vocabulary"
        case .grammar:    return "speechNorms.axis.grammar"
        case .connected:  return "speechNorms.axis.connected"
        case .motor:      return "speechNorms.axis.motor"
        case .redflags:   return "speechNorms.axis.redflags"
        }
    }

    public var symbolName: String {
        switch self {
        case .overview:   return "book.closed.fill"
        case .sounds:     return "waveform"
        case .vocabulary: return "text.book.closed.fill"
        case .grammar:    return "textformat"
        case .connected:  return "bubble.left.and.bubble.right.fill"
        case .motor:      return "hand.draw.fill"
        case .redflags:   return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - NormCard

/// Одна карточка справочника возрастных норм речи.
public struct NormCard: Identifiable, Sendable, Equatable {
    public let id: String
    public let age: NormAge
    public let axis: NormAxis
    public let title: String
    public let summary: String
    public let body: String
    public let sources: [String]

    public init(
        id: String,
        age: NormAge,
        axis: NormAxis,
        title: String,
        summary: String,
        body: String,
        sources: [String]
    ) {
        self.id = id
        self.age = age
        self.axis = axis
        self.title = title
        self.summary = summary
        self.body = body
        self.sources = sources
    }
}

// MARK: - SpeechNormsEncyclopediaModels namespace

enum SpeechNormsEncyclopediaModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let initialAge: NormAge
            let query: String
        }

        struct Response: Sendable {
            let cards: [NormCard]
            let selectedAge: NormAge
            let query: String
        }

        struct ViewModel: Sendable {
            let headerTitle: String
            let headerSubtitle: String
            let ethicsNote: String
            let ageTabs: [AgeTabViewModel]
            let selectedAge: NormAge
            let query: String
            let sections: [SectionViewModel]
            let isEmpty: Bool
            let emptyMessage: String
        }

        struct AgeTabViewModel: Identifiable, Sendable, Equatable {
            let id: Int
            let age: NormAge
            let title: String
            let isSelected: Bool
            let accessibilityLabel: String
        }

        struct SectionViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let axis: NormAxis
            let title: String
            let symbolName: String
            let isRedFlag: Bool
            let cards: [CardViewModel]
        }

        struct CardViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let title: String
            let summary: String
            let body: String
            let sources: [String]
            let isRedFlag: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: SelectAge

    enum SelectAge {
        struct Request: Sendable {
            let age: NormAge
        }
    }

    // MARK: Search

    enum Search {
        struct Request: Sendable {
            let query: String
        }
    }
}
