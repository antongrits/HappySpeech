import Foundation

// MARK: - ConversationStartersParentModels

/// Модели «Темы для разговора». Контент — `ConversationStartersContent`,
/// избранное накладывается интерактором из `UserDefaults`.
enum ConversationStartersParentModels {

    struct Question: Identifiable, Hashable {
        let id: String
        let text: String
        let category: Category
        var isFavorite: Bool
    }

    enum Category: String, CaseIterable, Hashable {
        case daily
        case feelings
        case imagination
        case learning

        var title: String {
            switch self {
            case .daily:       return String(localized: "conversationStarters.cat.daily")
            case .feelings:    return String(localized: "conversationStarters.cat.feelings")
            case .imagination: return String(localized: "conversationStarters.cat.imagination")
            case .learning:    return String(localized: "conversationStarters.cat.learning")
            }
        }
    }

    struct ViewState: Equatable {
        var questions: [Question]

        var favorites: [Question] {
            questions.filter(\.isFavorite)
        }
    }
}
