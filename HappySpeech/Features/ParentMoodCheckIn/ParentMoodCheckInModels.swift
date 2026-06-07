import Foundation

// MARK: - ParentMoodCheckInModels

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
enum ParentMoodCheckInModels {

    enum Mood: String, CaseIterable, Identifiable, Hashable {
        case energised
        case okay
        case tired
        case overwhelmed

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .energised:    return "🌞"
            case .okay:         return "🙂"
            case .tired:        return "🥱"
            case .overwhelmed:  return "🌧️"
            }
        }

        var label: String {
            switch self {
            case .energised:    return "Энергично"
            case .okay:         return "Нормально"
            case .tired:        return "Устаю"
            case .overwhelmed:  return "Тяжело"
            }
        }
    }

    struct Entry: Equatable {
        var mood: Mood?
        var note: String = ""
    }
}
