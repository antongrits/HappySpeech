import Foundation
import OSLog

// MARK: - LogopedistChatBusinessLogic

@MainActor
protocol LogopedistChatBusinessLogic: AnyObject {
    func load(request: LogopedistChatModels.Load.Request) async
    func send(request: LogopedistChatModels.Send.Request) async
    func attachAudio(request: LogopedistChatModels.AttachAudio.Request) async
    func markAsRead(request: LogopedistChatModels.MarkAsRead.Request) async
}

// MARK: - LogopedistChatDataStore

@MainActor
protocol LogopedistChatDataStore: AnyObject {
    var parentId: String { get set }
    var specialistId: String { get set }
}

// MARK: - LogopedistChatInteractor (Clean Swift: Interactor)
//
// Block R.2 v18 — чат родитель ↔ специалист.
//
// Логика:
//   1. `load` — собрать данные о специалисте + историю messages
//   2. `send` — добавить parent message, optionally с auto-reply seed
//   3. `attachAudio` — добавить parent message с audio attachment
//   4. `markAsRead` — пометить delivered → read
//
// Persistence: in-memory (на parent layer) + UserDefaults seed для preview.
// Production: должен заменить на Firestore listener (см. ParentChild scheme).
//
// COPPA: вся логика только в parent контуре.
// Note: т.к. Firestore listener в MVP не реализован, используется seed-данные
// + локальное эхо. Это допустимо для дипломной демонстрации.

@MainActor
final class LogopedistChatInteractor: LogopedistChatBusinessLogic, LogopedistChatDataStore {

    // MARK: - DataStore

    var parentId: String
    var specialistId: String

    // MARK: - VIP

    var presenter: (any LogopedistChatPresentationLogic)?

    // MARK: - In-memory thread

    private var messages: [ChatMessage]
    private var specialistInfo: SpecialistInfo?
    private var autoReplyTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let userDefaults: UserDefaults
    private let hapticService: any HapticService
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "LogopedistChat")

    // MARK: - UserDefaults keys

    private enum Keys {
        static let prefix = "happyspeech.chat."
        static func threadJSON(_ parentId: String, _ specialistId: String) -> String {
            "\(prefix)\(parentId).\(specialistId).thread"
        }
    }

    // MARK: - Init

    init(
        parentId: String,
        specialistId: String,
        hapticService: any HapticService,
        userDefaults: UserDefaults = .standard
    ) {
        self.parentId = parentId
        self.specialistId = specialistId
        self.hapticService = hapticService
        self.userDefaults = userDefaults
        self.messages = []
        self.specialistInfo = nil
    }

    // MARK: - Load

    func load(request: LogopedistChatModels.Load.Request) async {
        // Specialist info — seed.
        let specialist = makeSeedSpecialist()
        specialistInfo = specialist

        // Загружаем messages: либо seed, либо в памяти.
        if messages.isEmpty {
            messages = makeSeedMessages(specialistName: specialist.displayName)
        }

        let response = LogopedistChatModels.Load.Response(
            specialist: specialist,
            messages: messages,
            isConnected: true
        )

        await presenter?.presentLoad(response: response)
    }

    // MARK: - Send

    func send(request: LogopedistChatModels.Send.Request) async {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let parentMessage = ChatMessage(
            id: UUID().uuidString,
            sender: .parent,
            text: request.text,
            createdAt: request.now,
            status: .sent,
            attachment: nil,
            isOptional: false
        )
        messages.append(parentMessage)
        Self.logger.info("Parent message sent (\(request.text.count) chars)")

        // Cancel предыдущий auto-reply если есть (защита от накопления при rapid send).
        autoReplyTask?.cancel()

        // Через 2 секунды (моделируем delay) добавляем auto-reply от specialist
        // — для дипломной демонстрации.
        let autoReply = ChatMessage(
            id: UUID().uuidString,
            sender: .specialist,
            text: makeAutoReply(for: request.text),
            createdAt: request.now.addingTimeInterval(2),
            status: .delivered,
            attachment: nil,
            isOptional: true
        )

        let response = LogopedistChatModels.Send.Response(
            createdMessage: parentMessage,
            appendedMessages: [parentMessage]
        )
        await presenter?.presentSend(response: response)

        // Fire-and-forget auto-reply через 2 секунды (cancellable).
        autoReplyTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            await self.appendAutoReply(autoReply, parentMessage: parentMessage)
        }
    }

    private func appendAutoReply(_ autoReply: ChatMessage, parentMessage: ChatMessage) async {
        messages.append(autoReply)
        let response = LogopedistChatModels.Send.Response(
            createdMessage: parentMessage,
            appendedMessages: [autoReply]
        )
        await presenter?.presentSend(response: response)
    }

    // MARK: - AttachAudio

    func attachAudio(request: LogopedistChatModels.AttachAudio.Request) async {
        let attachment = MessageAttachment(
            id: UUID().uuidString,
            kind: .audioRecording,
            titleKey: "chat.attachment.audio.title",
            durationSeconds: request.durationSeconds
        )

        let message = ChatMessage(
            id: UUID().uuidString,
            sender: .parent,
            text: String(localized: "chat.attachment.audio.placeholder"),
            createdAt: request.now,
            status: .sent,
            attachment: attachment,
            isOptional: false
        )
        messages.append(message)

        Self.logger.info("Audio attachment sent (\(request.durationSeconds)s)")

        let response = LogopedistChatModels.AttachAudio.Response(
            createdMessage: message
        )

        await presenter?.presentAttachAudio(response: response)
    }

    // MARK: - MarkAsRead

    func markAsRead(request: LogopedistChatModels.MarkAsRead.Request) async {
        let updatedIds = request.messageIds.filter { id in
            messages.contains { $0.id == id }
        }

        // Ничего не делаем с UI — это no-op в MVP.
        Self.logger.debug("MarkAsRead: \(updatedIds.count) messages")
    }

    // MARK: - Seed builders

    private func makeSeedSpecialist() -> SpecialistInfo {
        SpecialistInfo(
            displayName: String(localized: "chat.specialist.seed.name"),
            credentialsKey: "chat.specialist.seed.credentials",
            isOnline: true,
            lastSeenAt: nil
        )
    }

    private func makeSeedMessages(specialistName: String) -> [ChatMessage] {
        let now = Date()
        return [
            ChatMessage(
                id: "seed.welcome",
                sender: .specialist,
                text: String(
                    format: String(localized: "chat.seed.welcome"),
                    specialistName
                ),
                createdAt: now.addingTimeInterval(-3600 * 24 * 2),
                status: .read,
                attachment: nil,
                isOptional: true
            ),
            ChatMessage(
                id: "seed.intro",
                sender: .specialist,
                text: String(localized: "chat.seed.intro"),
                createdAt: now.addingTimeInterval(-3600 * 24 * 2 + 30),
                status: .read,
                attachment: nil,
                isOptional: true
            )
        ]
    }

    /// Заглушка auto-reply: специалист «отвечает» в зависимости от длины
    /// родительского сообщения. Для дипломной демонстрации.
    private func makeAutoReply(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return String(localized: "chat.autoreply.fallback")
        }
        if trimmed.count < 30 {
            return String(localized: "chat.autoreply.short")
        }
        if trimmed.lowercased().contains("спасибо") {
            return String(localized: "chat.autoreply.thanks")
        }
        if trimmed.contains("?") {
            return String(localized: "chat.autoreply.question")
        }
        return String(localized: "chat.autoreply.default")
    }
}
