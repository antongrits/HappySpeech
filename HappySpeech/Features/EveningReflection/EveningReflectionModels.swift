import Foundation

// MARK: - EveningReflectionModels

/// Модели вечерней рефлексии.
///
/// Запись дня (что было весело/трудно + настроение) персистится в локальный
/// дневник (`EveningReflectionStore`) и доступна в истории.
enum EveningReflectionModels {

    enum Mood: String, Hashable, CaseIterable, Identifiable, Codable {
        case bright
        case calm
        case sad

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .bright: return "🌟"
            case .calm:   return "🌿"
            case .sad:    return "🌧️"
            }
        }

        var label: String {
            switch self {
            case .bright: return String(localized: "evening.mood.bright")
            case .calm:   return String(localized: "evening.mood.calm")
            case .sad:    return String(localized: "evening.mood.sad")
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
