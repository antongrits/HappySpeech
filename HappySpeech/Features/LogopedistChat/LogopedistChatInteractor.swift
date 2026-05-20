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
// Block R.2 v18 — чат родитель ↔ реальный специалист.
//
// Логика:
//   1. `load` — собрать данные о подключённом специалисте + историю messages
//   2. `send` — добавить parent message в локальный тред (исходящая очередь)
//   3. `attachAudio` — добавить parent message с audio attachment
//   4. `markAsRead` — пометить delivered → read
//
// Persistence: in-memory (на parent layer).
// Production: должен заменить на Firestore listener (см. ParentChild scheme).
//
// COPPA: вся логика только в parent контуре.
//
// Этика (project guide §11): приложение НЕ заменяет живого логопеда и НЕ
// имитирует его. Пока к семье не подключён реальный специалист, экран
// показывает честное пустое состояние — без выдуманного собеседника,
// фейковых сообщений и индикатора «В сети». Никаких авто-ответов:
// сообщения от специалиста появляются только когда реальный логопед
// действительно ответит (через Firestore listener в production).

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
        // Подтягиваем реального подключённого специалиста.
        // Пока интеграция с Firestore не реализована, реального специалиста
        // нет — поэтому возвращаем `nil`. Presenter покажет честное пустое
        // состояние «Подключите логопеда вашего ребёнка», а не фейковую
        // переписку с выдуманным собеседником (project guide §11).
        let specialist = connectedSpecialist()
        specialistInfo = specialist

        let response = LogopedistChatModels.Load.Response(
            specialist: specialist,
            messages: messages,
            isConnected: specialist != nil
        )

        await presenter?.presentLoad(response: response)
    }

    // MARK: - Send

    func send(request: LogopedistChatModels.Send.Request) async {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        // Сообщение можно отправить только реальному подключённому специалисту.
        guard connectedSpecialist() != nil else { return }

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
        Self.logger.info("Parent message queued for specialist (\(request.text.count) chars)")

        // Никаких авто-ответов: ответ появится только когда реальный логопед
        // ответит через Firestore listener (project guide §11 — не имитируем специалиста).
        let response = LogopedistChatModels.Send.Response(
            createdMessage: parentMessage,
            appendedMessages: [parentMessage]
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

    // MARK: - Specialist resolution

    /// Возвращает реально подключённого к семье специалиста или `nil`.
    ///
    /// Production: чтение из Firestore (ParentChild scheme) — специалист,
    /// которого родитель сам пригласил/подтвердил для своего ребёнка.
    /// Пока интеграция не реализована, подключённого специалиста нет —
    /// экран честно показывает пустое состояние и не выдумывает собеседника.
    private func connectedSpecialist() -> SpecialistInfo? {
        nil
    }
}
