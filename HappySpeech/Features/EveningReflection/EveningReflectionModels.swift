import Foundation

// MARK: - EveningReflectionModels

/// Модели вечерней рефлексии.
///
/// Запись дня (что было весело/трудно + настроение) персистится в локальный
/// дневник (`EveningReflectionStore`) и доступна в истории.
enum EveningReflectionModels {

    enum Mood: String, Hashable, CaseIterable, Identifiable, Codable {
        /// «Грустно» — ребёнок расстроен.
        case sad
        /// «Так себе» — нейтрально-негативное.
        case meh
        /// «Норм» — нейтральное.
        case calm
        /// «Горжусь» — хорошее настроение.
        case bright
        /// «Супер!» — отличное настроение.
        case fantastic

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .sad:       return "😢"
            case .meh:       return "😐"
            case .calm:      return "🙂"
            case .bright:    return "😊"
            case .fantastic: return "🌟"
            }
        }

        var label: String {
            switch self {
            case .sad:       return String(localized: "evening.mood.sad",       defaultValue: "Грустно")
            case .meh:       return String(localized: "evening.mood.meh",       defaultValue: "Так себе")
            case .calm:      return String(localized: "evening.mood.calm",      defaultValue: "Норм")
            case .bright:    return String(localized: "evening.mood.bright",    defaultValue: "Горжусь")
            case .fantastic: return String(localized: "evening.mood.fantastic", defaultValue: "Супер")
            }
        }
    }

    struct Entry: Equatable, Codable, Identifiable {
        var id: UUID = UUID()
        var fun: String = ""
        var hard: String = ""
        var mood: Mood?
        var savedAt: Date?
    }
}
