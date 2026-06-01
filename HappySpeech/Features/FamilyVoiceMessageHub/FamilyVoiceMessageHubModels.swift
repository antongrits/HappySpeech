import Foundation

// MARK: - FamilyVoiceMessageHubModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum FamilyVoiceMessageHubModels {

    enum SenderRole: String, Hashable {
        case mom
        case dad
        case kid
        case grandma

        var title: String {
            switch self {
            case .mom:     return "Мама"
            case .dad:     return "Папа"
            case .kid:     return "Ребёнок"
            case .grandma: return "Бабушка"
            }
        }

        var emoji: String {
            switch self {
            case .mom:     return "👩"
            case .dad:     return "👨"
            case .kid:     return "🧒"
            case .grandma: return "👵"
            }
        }
    }

    struct Message: Identifiable, Hashable {
        let id: String
        let sender: SenderRole
        let durationSeconds: Int
        let timeLabel: String
        let preview: String
        var isUnread: Bool
    }

    struct ViewState: Equatable {
        var messages: [Message]

        var unreadCount: Int {
            messages.filter(\.isUnread).count
        }

        var isEmpty: Bool { messages.isEmpty }

        /// Стартовое состояние — пустое: реальных голосовых сообщений семьи нет,
        /// пока они не записаны через основную фичу «Голос семьи». Никаких
        /// выдуманных сообщений. Запись/доставка сообщений — в FamilyVoice.
        static let initial = ViewState(messages: [])
    }
}
