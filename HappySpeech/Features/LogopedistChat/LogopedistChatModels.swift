import Foundation

// MARK: - LogopedistChatModels (Clean Swift: Models)
//
// Block R.2 v18 — LogopedistChat Screen.
//
// Сущности фичи:
//   • ChatMessage — одно сообщение в треде parent ↔ specialist
//   • MessageAttachment — приложенный аудио-файл (highlight сессии)
//   • MessageSender — parent | specialist (НЕ child — COPPA-safe)
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: in-memory + UserDefaults seed.
// Производство: Firestore real-time listener (не реализуется в MVP).
//
// COPPA: ребёнок никогда не пишет и не читает chat. Чат строго parent →
// specialist. Доступ только из parent контура.

// MARK: - MessageSender

public enum MessageSender: String, Sendable, Equatable {
    case parent
    case specialist
}

// MARK: - MessageStatus

/// Статус доставки сообщения.
public enum MessageStatus: String, Sendable, Equatable {
    case sending     // сейчас отправляется
    case sent        // ушло на сервер
    case delivered   // доставлено получателю
    case read        // прочитано
    case failed      // ошибка отправки (offline)
}

// MARK: - MessageAttachment

/// Приложение к сообщению — пока только аудио (session highlight).
public struct MessageAttachment: Identifiable, Sendable, Hashable {
    public let id: String
    public let kind: Kind
    public let titleKey: String
    public let durationSeconds: Double?

    public enum Kind: String, Sendable {
        case audioRecording
        case sessionHighlight
        case progressReport
    }

    public var symbolName: String {
        switch kind {
        case .audioRecording:    return "waveform"
        case .sessionHighlight:  return "play.rectangle.fill"
        case .progressReport:    return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - ChatMessage

public struct ChatMessage: Identifiable, Sendable, Equatable {

    public let id: String
    public let sender: MessageSender
    public let text: String
    public let createdAt: Date
    public let status: MessageStatus
    public let attachment: MessageAttachment?
    public let isOptional: Bool   // для seed/preview сообщений

    public init(
        id: String,
        sender: MessageSender,
        text: String,
        createdAt: Date,
        status: MessageStatus = .sent,
        attachment: MessageAttachment? = nil,
        isOptional: Bool = false
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.attachment = attachment
        self.isOptional = isOptional
    }
}

// MARK: - SpecialistInfo

/// Информация о подключённом специалисте.
public struct SpecialistInfo: Sendable, Equatable {
    public let displayName: String
    public let credentialsKey: String  // «Логопед-дефектолог», «Нейропсихолог»
    public let isOnline: Bool
    public let lastSeenAt: Date?
}

// MARK: - LogopedistChatModels namespace

enum LogopedistChatModels {

    // MARK: Load

    enum Load {

        struct Request: Sendable {
            let parentId: String
            let specialistId: String
        }

        struct Response: Sendable {
            let specialist: SpecialistInfo?
            let messages: [ChatMessage]
            let isConnected: Bool
        }

        struct ViewModel: Sendable {
            let specialistName: String
            let credentials: String
            let onlineStatusLabel: String
            let isOnline: Bool
            let isConnected: Bool
            let connectionHint: String?
            let messages: [MessageRow]
            let composerEnabled: Bool
        }

        struct MessageRow: Identifiable, Sendable {
            let id: String
            let isFromParent: Bool
            let text: String
            let timeLabel: String
            let statusLabel: String
            let statusSymbol: String?
            let isRead: Bool
            let attachment: AttachmentRow?
            let accessibilityLabel: String
        }

        struct AttachmentRow: Identifiable, Sendable {
            let id: String
            let title: String
            let symbolName: String
            let durationLabel: String?
        }
    }

    // MARK: Send

    enum Send {

        struct Request: Sendable {
            let parentId: String
            let specialistId: String
            let text: String
            let now: Date
        }

        struct Response: Sendable {
            let createdMessage: ChatMessage
            let appendedMessages: [ChatMessage]
        }

        struct ViewModel: Sendable {
            let confirmationMessage: String
            let success: Bool
        }
    }

    // MARK: AttachAudio

    enum AttachAudio {

        struct Request: Sendable {
            let parentId: String
            let specialistId: String
            let attachmentTitle: String
            let durationSeconds: Double
            let now: Date
        }

        struct Response: Sendable {
            let createdMessage: ChatMessage
        }

        struct ViewModel: Sendable {
            let confirmationMessage: String
        }
    }

    // MARK: MarkAsRead

    enum MarkAsRead {

        struct Request: Sendable {
            let parentId: String
            let messageIds: [String]
        }

        struct Response: Sendable {
            let updatedIds: [String]
        }
    }
}
