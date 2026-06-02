import Foundation

// MARK: - LyalyaMailModels
//
// «Письма от Ляли» — ежедневные мини-сообщения от маскота ребёнку
// (мотивация / поздравление / напоминание). Список писем в виде почтового
// ящика. Подсветка непрочитанных, expand-detail с озвучкой.
//
// Контур: kid. Все письма — на русском, тёплый тон, без сложных оборотов.
//
// Persistence: Realm (`LyalyaLetterObject` через RealmActor). «Прочитано»/
// «удалено» сохраняются между запусками. Письма генерируются по реальным
// событиям ребёнка (см. LyalyaMailLetters в Interactor).

enum LyalyaMailModels {

    // MARK: - LoadMail (стартовый список)

    enum LoadMail {
        struct Request {
            let childId: String
        }

        struct Response {
            let childId: String
            let letters: [LyalyaLetterDTO]
        }

        struct ViewModel {
            let unreadCount: Int
            let isEmpty: Bool
            let rows: [LyalyaLetterRowViewModel]
            let accessibilitySummary: String
        }
    }

    // MARK: - OpenLetter (детальный экран — отметка как прочитанное)

    enum OpenLetter {
        struct Request {
            let letterId: UUID
        }

        struct Response {
            let letter: LyalyaLetterDTO
        }

        struct ViewModel {
            let title: String
            let body: String
            let dateLabel: String
            let mascotState: LyalyaState
            let hasAudio: Bool
            let audioFileName: String?
        }
    }

    // MARK: - Delete (свайп / контекстное меню)

    enum Delete {
        struct Request {
            let letterId: UUID
        }

        struct Response {
            let removedId: UUID
        }
    }
}

// MARK: - LyalyaLetterDTO

struct LyalyaLetterDTO: Sendable, Identifiable, Equatable {
    let id: UUID
    let childId: String
    let kind: LetterKind
    let title: String
    let body: String
    let date: Date
    var isRead: Bool
    let audioFileName: String?
}

// MARK: - LetterKind

enum LetterKind: String, Sendable, CaseIterable {
    case welcome
    case streak
    case firstSound
    case family
    case weekendReminder
    case achievement

    var mascotState: LyalyaState {
        switch self {
        case .welcome:         return .waving
        case .streak:          return .celebrating
        case .firstSound:      return .happy
        case .family:          return .explaining
        case .weekendReminder: return .pointing
        case .achievement:     return .celebrating
        }
    }
}

// MARK: - LyalyaLetterRowViewModel

struct LyalyaLetterRowViewModel: Identifiable, Sendable {
    let id: UUID
    let title: String
    let preview: String
    let dateLabel: String
    let isRead: Bool
    let mascotState: LyalyaState
    let accessibilityLabel: String
}
