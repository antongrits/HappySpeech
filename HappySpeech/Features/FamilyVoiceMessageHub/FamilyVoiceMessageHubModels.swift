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

        static let initial = ViewState(messages: [
            Message(id: "m1", sender: .mom, durationSeconds: 12,
                    timeLabel: "Сегодня 09:14",
                    preview: "Анечка, доброе утро!", isUnread: true),
            Message(id: "m2", sender: .dad, durationSeconds: 8,
                    timeLabel: "Сегодня 12:30",
                    preview: "Ты молодец!", isUnread: true),
            Message(id: "m3", sender: .grandma, durationSeconds: 22,
                    timeLabel: "Вчера 18:45",
                    preview: "Расскажи стишок", isUnread: false),
            Message(id: "m4", sender: .kid, durationSeconds: 6,
                    timeLabel: "Вчера 19:00",
                    preview: "У меня получилось «Р»!", isUnread: false),
            Message(id: "m5", sender: .mom, durationSeconds: 15,
                    timeLabel: "2 дня назад",
                    preview: "Перед сном — сказка", isUnread: false)
        ])
    }
}
