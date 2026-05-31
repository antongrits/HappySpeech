import Foundation
import OSLog

// MARK: - LogopedistChatBusinessLogic

@MainActor
protocol LogopedistChatBusinessLogic: AnyObject {
    func load(request: LogopedistChatModels.Load.Request) async
    func connect(request: LogopedistChatModels.Connect.Request) async
    func send(request: LogopedistChatModels.Send.Request) async
    func attachAudio(request: LogopedistChatModels.AttachAudio.Request) async
    func markAsRead(request: LogopedistChatModels.MarkAsRead.Request) async
    /// Подписаться на real-time обновления треда. Цикл работает до отмены
    /// задачи (View отменяет при исчезновении). Каждое изменение → новый load.
    func subscribe() async
}

// MARK: - LogopedistChatDataStore

@MainActor
protocol LogopedistChatDataStore: AnyObject {
    var parentId: String { get set }
    var specialistId: String { get set }
}

// MARK: - LogopedistChatInteractor (Clean Swift: Interactor)
//
// Block R.2 v32 — реальный чат «родитель ↔ логопед».
//
// Источник данных — `ChatRepository` (Services-протокол), который изолирует
// фичу от Firestore/Sync (project guide §2). Логика:
//
//   1. `load`     — состояние связи + история (offline-first) + unread/outbox
//   2. `connect`  — подключить логопеда по коду-инвайту, затем перезагрузить
//   3. `send`     — отправить текст (online → .sent, offline → очередь .sending)
//   4. `attachAudio` — сообщение с аудио-вложением (запись занятия)
//   5. `markAsRead`  — пометить входящие прочитанными
//   6. `subscribe`   — real-time: каждое изменение треда → пере-`load`
//
// COPPA / Kids Category: участники — только parent и specialist. Ребёнок не
// пишет и не читает. Вызывается строго из родительского контура.
//
// Этика (project guide §11): пока реальный логопед не подключён, экран честно
// показывает форму подключения, а не выдуманного собеседника. Никаких
// авто-ответов «специалиста» — входящие приходят только через реальный
// real-time поток репозитория.

@MainActor
final class LogopedistChatInteractor: LogopedistChatBusinessLogic, LogopedistChatDataStore {

    // MARK: - DataStore

    var parentId: String
    var specialistId: String

    // MARK: - VIP

    var presenter: (any LogopedistChatPresentationLogic)?

    // MARK: - Dependencies

    private let repository: any ChatRepository
    private let hapticService: any HapticService
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "LogopedistChat")

    // MARK: - State

    /// Текущая связь (обновляется в `load` / `connect`).
    private var linkState: ChatLinkState = .notConnected

    private var identity: ChatIdentity {
        ChatIdentity(familyId: parentId, specialistId: specialistId)
    }

    private var isConnected: Bool {
        if case .connected = linkState { return true }
        return false
    }

    private var connectedSpecialist: SpecialistInfo? {
        if case .connected(let specialist) = linkState { return specialist }
        return nil
    }

    // MARK: - Init

    /// Designated init с инъекцией `ChatRepository`.
    init(
        parentId: String,
        specialistId: String,
        repository: any ChatRepository,
        hapticService: any HapticService
    ) {
        self.parentId = parentId
        self.specialistId = specialistId
        self.repository = repository
        self.hapticService = hapticService
    }

    /// Совместимый init без репозитория — для существующих тестов и кода,
    /// которые ещё не передают `ChatRepository`. По умолчанию используется
    /// «пустой» репозиторий без подключённого специалиста: экран честно
    /// показывает форму подключения, `send` игнорируется (нет адресата).
    /// `userDefaults` принимается для бинарной совместимости вызовов (no-op).
    convenience init(
        parentId: String,
        specialistId: String,
        hapticService: any HapticService,
        userDefaults: UserDefaults = .standard
    ) {
        _ = userDefaults
        self.init(
            parentId: parentId,
            specialistId: specialistId,
            repository: EmptyChatRepository(),
            hapticService: hapticService
        )
    }

    // MARK: - Load

    func load(request: LogopedistChatModels.Load.Request) async {
        linkState = await repository.linkState(identity: identity)

        let specialist = connectedSpecialist
        let messages = isConnected ? await repository.loadHistory(identity: identity) : []
        let unread = isConnected ? await repository.unreadCount(identity: identity) : 0
        let pending = isConnected ? await repository.pendingOutboxCount(identity: identity) : 0

        let response = LogopedistChatModels.Load.Response(
            specialist: specialist,
            messages: messages,
            isConnected: isConnected,
            unreadCount: unread,
            pendingOutboxCount: pending,
            linkState: linkState
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - Connect

    func connect(request: LogopedistChatModels.Connect.Request) async {
        let trimmed = request.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await presenter?.presentConnect(response: .init(resultState: .failed(.invalidCode)))
            return
        }

        let result = await repository.connectSpecialist(familyId: request.familyId, code: trimmed)
        linkState = result

        switch result {
        case .connected:
            hapticService.notification(.success)
            Self.logger.info("Specialist connected via code")
        case .failed:
            hapticService.notification(.error)
        case .connecting, .notConnected:
            break
        }

        await presenter?.presentConnect(response: .init(resultState: result))
        // После успешного подключения сразу перезагружаем тред.
        if case .connected = result {
            await load(request: .init(parentId: parentId, specialistId: specialistId))
        }
    }

    // MARK: - Send

    func send(request: LogopedistChatModels.Send.Request) async {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        // Сообщение можно отправить только реально подключённому специалисту.
        guard isConnected else { return }

        let created = await repository.sendText(
            identity: identity,
            text: request.text,
            now: request.now
        )
        hapticService.selection()
        Self.logger.info("Parent message sent (status=\(created.status.rawValue))")

        let response = LogopedistChatModels.Send.Response(
            createdMessage: created,
            appendedMessages: [created]
        )
        await presenter?.presentSend(response: response)
        await load(request: .init(parentId: parentId, specialistId: specialistId))
    }

    // MARK: - AttachAudio

    func attachAudio(request: LogopedistChatModels.AttachAudio.Request) async {
        guard isConnected else { return }

        let created = await repository.sendAudio(
            identity: identity,
            localAudioPath: "",
            durationSeconds: request.durationSeconds,
            titleKey: "chat.attachment.audio.title",
            now: request.now
        )
        Self.logger.info("Audio attachment sent (\(request.durationSeconds)s, status=\(created.status.rawValue))")

        let response = LogopedistChatModels.AttachAudio.Response(createdMessage: created)
        await presenter?.presentAttachAudio(response: response)
        await load(request: .init(parentId: parentId, specialistId: specialistId))
    }

    // MARK: - MarkAsRead

    func markAsRead(request: LogopedistChatModels.MarkAsRead.Request) async {
        guard isConnected, !request.messageIds.isEmpty else { return }
        let updated = await repository.markAsRead(identity: identity, messageIds: request.messageIds)
        if !updated.isEmpty {
            Self.logger.debug("MarkAsRead: \(updated.count) messages")
            await load(request: .init(parentId: parentId, specialistId: specialistId))
        }
    }

    // MARK: - Subscribe (real-time)

    func subscribe() async {
        // Подписка имеет смысл только при подключённом специалисте.
        if !isConnected {
            linkState = await repository.linkState(identity: identity)
        }
        guard isConnected else { return }

        let stream = repository.messageStream(identity: identity)
        for await _ in stream {
            // Любое изменение треда → перезагрузка (пере-маппинг секций/unread).
            // Cancellation выходит из цикла естественно.
            if Task.isCancelled { break }
            await load(request: .init(parentId: parentId, specialistId: specialistId))
        }
    }
}

// MARK: - EmptyChatRepository

/// Репозиторий-заглушка: никакого подключённого логопеда, пустой тред.
/// Используется как дефолт для совместимого init без `ChatRepository`
/// (честное пустое состояние, project guide §11).
private struct EmptyChatRepository: ChatRepository {
    func linkState(identity: ChatIdentity) async -> ChatLinkState { .notConnected }
    func connectSpecialist(familyId: String, code: String) async -> ChatLinkState { .failed(.codeNotFound) }
    func loadHistory(identity: ChatIdentity) async -> [ChatMessage] { [] }
    func messageStream(identity: ChatIdentity) -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }
    @discardableResult
    func sendText(identity: ChatIdentity, text: String, now: Date) async -> ChatMessage {
        ChatMessage(id: UUID().uuidString, sender: .parent, text: text, createdAt: now, status: .failed)
    }
    @discardableResult
    func sendAudio(
        identity: ChatIdentity,
        localAudioPath: String,
        durationSeconds: Double,
        titleKey: String,
        now: Date
    ) async -> ChatMessage {
        ChatMessage(id: UUID().uuidString, sender: .parent, text: "", createdAt: now, status: .failed)
    }
    @discardableResult
    func markAsRead(identity: ChatIdentity, messageIds: [String]) async -> [String] { [] }
    func unreadCount(identity: ChatIdentity) async -> Int { 0 }
    func pendingOutboxCount(identity: ChatIdentity) async -> Int { 0 }
}
