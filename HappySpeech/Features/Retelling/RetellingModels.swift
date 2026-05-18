import Foundation

// MARK: - RetellingModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 2 «Расскажи по-настоящему» — продвинутый пересказ.
//
// Пересказ короткого текста с опорой на картинки-кадры и смысловые звенья
// (герой / место / проблема / решение) — отдельная высокая ступень связной
// речи (Ткаченко, Нищева), ключевая для подготовки к школе.
//
// VIP-модуль; контент — `RetellingCorpus` (offline / on-device).

// MARK: - SemanticLinkKind

/// Тип смыслового звена текста.
public enum SemanticLinkKind: String, Sendable, CaseIterable {
    case hero
    case place
    case problem
    case solution

    public var symbolName: String {
        switch self {
        case .hero:     return "person.fill"
        case .place:    return "mappin.circle.fill"
        case .problem:  return "exclamationmark.bubble.fill"
        case .solution: return "checkmark.seal.fill"
        }
    }
}

// MARK: - StoryFrame

/// Кадр истории — одно предложение-опора с привязкой к смысловому звену.
public struct StoryFrame: Identifiable, Sendable, Equatable {
    public let id: String
    /// Текст-предложение кадра.
    public let sentence: String
    /// Смысловое звено, которое несёт кадр.
    public let link: SemanticLinkKind
    /// SF Symbol-иллюстрация кадра.
    public let symbolName: String

    public init(id: String, sentence: String, link: SemanticLinkKind, symbolName: String) {
        self.id = id
        self.sentence = sentence
        self.link = link
        self.symbolName = symbolName
    }
}

// MARK: - RetellingStory

/// Короткая история для пересказа.
public struct RetellingStory: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    /// Кадры в сюжетном порядке (4–8 предложений).
    public let frames: [StoryFrame]

    public init(id: String, title: String, frames: [StoryFrame]) {
        self.id = id
        self.title = title
        self.frames = frames
    }

    /// Полный текст истории (для эталонного прослушивания).
    public var fullText: String {
        frames.map(\.sentence).joined(separator: " ")
    }
}

// MARK: - RetellingModels namespace

enum RetellingModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let story: RetellingStory
        }

        struct ViewModel: Sendable {
            let title: String
            let storyTitle: String
            let fullText: String
            let frames: [FrameViewModel]
            let listenPrompt: String
        }

        struct FrameViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let sentence: String
            let symbolName: String
            let linkLabel: String
            let accessibilityLabel: String
        }
    }

    // MARK: ToggleLink

    enum ToggleLink {
        struct Request: Sendable {
            /// Идентификатор кадра, который ребёнок отметил как озвученный.
            let frameId: String
        }

        struct Response: Sendable {
            let coveredFrameIds: Set<String>
            let totalFrames: Int
        }

        struct ViewModel: Sendable {
            let coveredFrameIds: Set<String>
            let coverageLabel: String
            let coverageFraction: Double
        }
    }

    // MARK: Finish

    enum Finish {
        struct Request: Sendable {
            let voiceRecorded: Bool
        }

        struct Response: Sendable {
            let coveredCount: Int
            let totalFrames: Int
            let missedLinks: [SemanticLinkKind]
        }

        struct ViewModel: Sendable {
            let title: String
            let scoreText: String
            let coverageFraction: Double
            /// Наводящие вопросы по пропущенным смысловым звеньям.
            let hints: [String]
            let encouragement: String
        }
    }
}
