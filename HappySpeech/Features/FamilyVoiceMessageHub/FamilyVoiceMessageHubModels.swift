import Foundation

// MARK: - FamilyVoiceMessageHubModels

/// Модели хаба семейных голосовых сообщений (thin VIP: Interactor `@Observable` +
/// View). Запись и доставка сообщений живут в фиче «Голос семьи» (FamilyVoice);
/// хаб отображает входящие и помечает прочитанными.
enum FamilyVoiceMessageHubModels {

    enum SenderRole: String, Hashable {
        case mom
        case dad
        case kid
        case grandma

        var title: String {
            switch self {
            case .mom:     return String(localized: "familyVoiceHub.role.mom")
            case .dad:     return String(localized: "familyVoiceHub.role.dad")
            case .kid:     return String(localized: "familyVoiceHub.role.kid")
            case .grandma: return String(localized: "familyVoiceHub.role.grandma")
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
