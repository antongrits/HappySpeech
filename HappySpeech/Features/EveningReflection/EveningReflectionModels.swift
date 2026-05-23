import Foundation

// MARK: - EveningReflectionModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum EveningReflectionModels {

    enum Mood: String, Hashable, CaseIterable, Identifiable {
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
            case .bright: return "Светло"
            case .calm:   return "Спокойно"
            case .sad:    return "Грустно"
            }
        }
    }

    struct Entry: Equatable {
        var fun: String = ""
        var hard: String = ""
        var mood: Mood?
        var savedAt: Date?
    }
}
