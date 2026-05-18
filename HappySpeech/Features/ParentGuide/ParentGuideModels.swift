import Foundation

// MARK: - ParentGuideModels (Clean Swift: Models)
//
// v29 Фаза 8, Функция 3 «Логопед для родителей».
//
// Обучающая база для родителя как со-терапевта: библиотека коротких
// карточек-уроков («Как делать артикуляционную гимнастику», «Что нельзя
// говорить ребёнку с заиканием» и т.д.). Контент адаптивен — карточки
// приоритизируются по цели ребёнка (целевые звуки → группа).
//
// Контент — статический корпус (`ParentGuideCorpus`), полностью offline.
// Этические границы: педагогические рекомендации, не медицинские назначения.

// MARK: - GuideTopic

/// Тематическая рубрика обучающих карточек.
public enum GuideTopic: String, CaseIterable, Sendable {
    case basics          // основы домашних занятий
    case articulation    // артикуляционная гимнастика
    case sounds          // постановка и автоматизация звуков
    case phonemic        // фонематический слух
    case fluency         // плавность речи / заикание
    case motivation      // мотивация и похвала

    public var titleKey: String {
        switch self {
        case .basics:       return "parentGuide.topic.basics"
        case .articulation: return "parentGuide.topic.articulation"
        case .sounds:       return "parentGuide.topic.sounds"
        case .phonemic:     return "parentGuide.topic.phonemic"
        case .fluency:      return "parentGuide.topic.fluency"
        case .motivation:   return "parentGuide.topic.motivation"
        }
    }

    public var symbolName: String {
        switch self {
        case .basics:       return "house.fill"
        case .articulation: return "mouth.fill"
        case .sounds:       return "waveform"
        case .phonemic:     return "ear.fill"
        case .fluency:      return "wind"
        case .motivation:   return "heart.fill"
        }
    }
}

// MARK: - GuideLesson

/// Одна карточка-урок: заголовок, краткое резюме, полный текст.
/// Тексты — ключи Localizable.xcstrings.
public struct GuideLesson: Identifiable, Sendable, Equatable {
    public let id: String
    public let topic: GuideTopic
    public let titleKey: String
    public let summaryKey: String
    public let bodyKey: String
    /// Группы звуков, для которых урок особенно релевантен (для приоритизации).
    /// Пустой массив — урок универсален.
    public let relevantSoundGroups: [String]
    public let readMinutes: Int

    public init(
        id: String,
        topic: GuideTopic,
        titleKey: String,
        summaryKey: String,
        bodyKey: String,
        relevantSoundGroups: [String],
        readMinutes: Int
    ) {
        self.id = id
        self.topic = topic
        self.titleKey = titleKey
        self.summaryKey = summaryKey
        self.bodyKey = bodyKey
        self.relevantSoundGroups = relevantSoundGroups
        self.readMinutes = readMinutes
    }
}

// MARK: - ParentGuideModels namespace

enum ParentGuideModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let lessons: [GuideLesson]
            /// Группы звуков ребёнка — для приоритизации релевантных уроков.
            let childSoundGroups: [String]
            /// Идентификаторы прочитанных уроков.
            let readLessonIds: Set<String>
            /// Идентификаторы избранных уроков.
            let favoriteLessonIds: Set<String>
        }

        struct ViewModel: Sendable {
            let headerTitle: String
            let headerSubtitle: String
            /// «Совет дня» — один рекомендованный урок.
            let tipOfDay: LessonViewModel?
            let topics: [TopicViewModel]
        }

        struct TopicViewModel: Identifiable, Sendable {
            let id: String
            let title: String
            let symbolName: String
            let lessons: [LessonViewModel]
        }

        struct LessonViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let title: String
            let summary: String
            let body: String
            let topicTitle: String
            let symbolName: String
            let readLabel: String
            let isRead: Bool
            let isFavorite: Bool
            let isRecommended: Bool
            let accessibilityLabel: String
        }
    }

    // MARK: MarkRead

    enum MarkRead {
        struct Request: Sendable {
            let lessonId: String
        }

        struct Response: Sendable {
            let lessonId: String
            let isRead: Bool
        }

        struct ViewModel: Sendable {
            let lessonId: String
            let isRead: Bool
        }
    }

    // MARK: ToggleFavorite

    enum ToggleFavorite {
        struct Request: Sendable {
            let lessonId: String
        }

        struct Response: Sendable {
            let lessonId: String
            let isFavorite: Bool
        }

        struct ViewModel: Sendable {
            let lessonId: String
            let isFavorite: Bool
        }
    }
}
