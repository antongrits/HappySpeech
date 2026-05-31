import Foundation
import OSLog

// MARK: - MockChatRepository
//
// Block R.2 v32 — in-memory реализация `ChatRepository` для preview, snapshot
// и unit-тестов. Воспроизводит всю бизнес-логику живого репозитория без сети:
//   • connect по коду (валидный код задаётся через `validCode`);
//   • локальный кэш сообщений + offline-очередь;
//   • симуляция оффлайна через `isOnline` — сообщения копятся в outbox и
//     доставляются при `flushOutbox()` / возврате `isOnline = true`;
//   • real-time поток через `AsyncStream` + continuation на каждое изменение;
//   • unread-подсчёт и markAsRead.
//
// Actor — внутреннее состояние сериализовано, гонок нет. Конфигурируемые
// сидинг-поля (`seededMessages`, `validCode`, `connectedSpecialist`) позволяют
// тестам и preview задать любое начальное состояние.

public actor MockChatRepository: ChatRepository {

    // MARK: - Configurable seed

    /// Валидный код подключения. Любой другой → `.codeNotFound`.
    public var validCode: String
    /// Специалист, который «подключится» при вводе `validCode`.
    public var connectedSpecialist: SpecialistInfo
    /// Признак сети. `false` → отправка уходит в outbox.
    public var isOnline: Bool

    /// Если `true`, любой тред считается подключённым к `connectedSpecialist`,
    /// а пустые треды отдают `seedThread` (для preview / snapshot — любой identity).
    private let autoConnectAll: Bool
    private let seedThread: [ChatMessage]

    // MARK: - State

    private var linkStates: [String: ChatLinkState] = [:]
    private var threads: [String: [ChatMessage]] = [:]
    private var outbox: [String: [ChatMessage]] = [:]
    private var continuations: [String: [UUID: AsyncStream<[ChatMessage]>.Continuation]] = [:]

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "ChatRepository.Mock")

    // MARK: - Init

    public init(
        validCode: String = "ABCD23",
        connectedSpecialist: SpecialistInfo = SpecialistInfo(
            displayName: "Ирина Петрова",
            credentialsKey: "specialist.credentials.logopedist",
            isOnline: true,
            lastSeenAt: nil
        ),
        isOnline: Bool = true,
        autoConnectAll: Bool = false,
        seedThread: [ChatMessage] = [],
        seededLinks: [ChatIdentity: ChatLinkState] = [:],
        seededMessages: [ChatIdentity: [ChatMessage]] = [:]
    ) {
        self.validCode = validCode
        self.connectedSpecialist = connectedSpecialist
        self.isOnline = isOnline
        self.autoConnectAll = autoConnectAll
        self.seedThread = seedThread.sorted { $0.createdAt < $1.createdAt }
        for (identity, state) in seededLinks {
            linkStates[identity.chatId] = state
        }
        for (identity, messages) in seededMessages {
            threads[identity.chatId] = messages.sorted { $0.createdAt < $1.createdAt }
            // Если есть сообщения, но связь не задана — считаем подключённым.
            if linkStates[identity.chatId] == nil {
                linkStates[identity.chatId] = .connected(connectedSpecialist)
            }
        }
    }

    /// Preview / snapshot фабрика: любой тред подключён к логопеду и наполнен
    /// демонстрационной перепиской (родитель ↔ специалист, оба дня).
    public static func previewSeeded() -> MockChatRepository {
        let base = Date(timeIntervalSince1970: 1_714_000_000) // фикс. дата (детерминизм)
        let yesterday = base.addingTimeInterval(-86_400)
        let thread: [ChatMessage] = [
            ChatMessage(
                id: "seed-1", sender: .specialist,
                text: "Добрый день! Посмотрела последние занятия — звук «С» уже стабильнее.",
                createdAt: yesterday.addingTimeInterval(3_600), status: .read
            ),
            ChatMessage(
                id: "seed-2", sender: .parent,
                text: "Здравствуйте! Да, дома повторяем каждый день по 10 минут.",
                createdAt: yesterday.addingTimeInterval(3_900), status: .read
            ),
            ChatMessage(
                id: "seed-3", sender: .specialist,
                text: "Отлично. На этой неделе добавьте слоги «са-со-су» перед зеркалом.",
                createdAt: base.addingTimeInterval(600), status: .delivered
            ),
            ChatMessage(
                id: "seed-4", sender: .parent,
                text: "Поняла, спасибо! Прикладываю запись сегодняшнего занятия.",
                createdAt: base.addingTimeInterval(900), status: .sent,
                attachment: MessageAttachment(
                    id: "seed-att", kind: .audioRecording,
                    titleKey: "chat.attachment.audio.title", durationSeconds: 28
                )
            )
        ]
        return MockChatRepository(autoConnectAll: true, seedThread: thread)
    }

    // MARK: - Test / preview hooks

    /// Имитирует входящее сообщение от логопеда (для preview/тестов real-time).
    public func receiveSpecialistMessage(identity: ChatIdentity, text: String, at date: Date = Date()) {
        let message = ChatMessage(
            id: UUID().uuidString,
            sender: .specialist,
            text: text,
            createdAt: date,
            status: .delivered
        )
        appendAndPublish(message, chatId: identity.chatId)
    }

    /// Переводит репозиторий в online и доставляет всё из outbox.
    public func goOnlineAndFlush(identity: ChatIdentity) {
        isOnline = true
        flushOutbox(chatId: identity.chatId)
    }

    // MARK: - ChatRepository

    public func linkState(identity: ChatIdentity) async -> ChatLinkState {
        if let explicit = linkStates[identity.chatId] { return explicit }
        return autoConnectAll ? .connected(connectedSpecialist) : .notConnected
    }

    public func connectSpecialist(familyId: String, code: String) async -> ChatLinkState {
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 6 else {
            return .failed(.invalidCode)
        }
        guard normalized == validCode.uppercased() else {
            return .failed(.codeNotFound)
        }
        let identity = ChatIdentity(familyId: familyId, specialistId: connectedSpecialist.displayName)
        let state = ChatLinkState.connected(connectedSpecialist)
        linkStates[identity.chatId] = state
        Self.logger.info("Mock connect: family linked to specialist via code")
        return state
    }

    public func loadHistory(identity: ChatIdentity) async -> [ChatMessage] {
        if let thread = threads[identity.chatId] { return thread }
        if autoConnectAll, !seedThread.isEmpty {
            threads[identity.chatId] = seedThread
            return seedThread
        }
        return []
    }

    public nonisolated func messageStream(identity: ChatIdentity) -> AsyncStream<[ChatMessage]> {
        let chatId = identity.chatId
        return AsyncStream { continuation in
            let token = UUID()
            Task {
                await self.register(continuation: continuation, token: token, chatId: chatId)
            }
            continuation.onTermination = { _ in
                Task { await self.unregister(token: token, chatId: chatId) }
            }
        }
    }

    private func register(
        continuation: AsyncStream<[ChatMessage]>.Continuation,
        token: UUID,
        chatId: String
    ) {
        continuations[chatId, default: [:]][token] = continuation
        if threads[chatId] == nil, autoConnectAll, !seedThread.isEmpty {
            threads[chatId] = seedThread
        }
        continuation.yield(threads[chatId] ?? [])
    }

    private func unregister(token: UUID, chatId: String) {
        continuations[chatId]?[token] = nil
    }

    @discardableResult
    public func sendText(identity: ChatIdentity, text: String, now: Date) async -> ChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = ChatMessage(
            id: UUID().uuidString,
            sender: .parent,
            text: trimmed,
            createdAt: now,
            status: isOnline ? .sent : .sending
        )
        deliver(message, identity: identity)
        return message
    }

    @discardableResult
    public func sendAudio(
        identity: ChatIdentity,
        localAudioPath: String,
        durationSeconds: Double,
        titleKey: String,
        now: Date
    ) async -> ChatMessage {
        let attachment = MessageAttachment(
            id: UUID().uuidString,
            kind: .audioRecording,
            titleKey: titleKey,
            durationSeconds: durationSeconds
        )
        let message = ChatMessage(
            id: UUID().uuidString,
            sender: .parent,
            text: String(localized: "chat.attachment.audio.placeholder"),
            createdAt: now,
            status: isOnline ? .sent : .sending,
            attachment: attachment
        )
        deliver(message, identity: identity)
        return message
    }

    @discardableResult
    public func markAsRead(identity: ChatIdentity, messageIds: [String]) async -> [String] {
        let chatId = identity.chatId
        guard var thread = threads[chatId] else { return [] }
        var updated: [String] = []
        for index in thread.indices {
            let msg = thread[index]
            guard msg.sender == .specialist,
                  messageIds.contains(msg.id),
                  msg.status != .read else { continue }
            thread[index] = ChatMessage(
                id: msg.id,
                sender: msg.sender,
                text: msg.text,
                createdAt: msg.createdAt,
                status: .read,
                attachment: msg.attachment,
                isOptional: msg.isOptional
            )
            updated.append(msg.id)
        }
        if !updated.isEmpty {
            threads[chatId] = thread
            publish(chatId: chatId)
        }
        return updated
    }

    public func unreadCount(identity: ChatIdentity) async -> Int {
        (threads[identity.chatId] ?? []).filter {
            $0.sender == .specialist && $0.status != .read
        }.count
    }

    public func pendingOutboxCount(identity: ChatIdentity) async -> Int {
        (outbox[identity.chatId] ?? []).count
    }

    // MARK: - Private

    private func deliver(_ message: ChatMessage, identity: ChatIdentity) {
        if isOnline {
            appendAndPublish(message, chatId: identity.chatId)
        } else {
            outbox[identity.chatId, default: []].append(message)
            appendAndPublish(message, chatId: identity.chatId)
            Self.logger.info("Mock send queued offline (outbox=\(self.outbox[identity.chatId]?.count ?? 0))")
        }
    }

    private func flushOutbox(chatId: String) {
        guard let queued = outbox[chatId], !queued.isEmpty else { return }
        outbox[chatId] = []
        guard var thread = threads[chatId] else { return }
        for queuedMessage in queued {
            if let index = thread.firstIndex(where: { $0.id == queuedMessage.id }) {
                thread[index] = ChatMessage(
                    id: queuedMessage.id,
                    sender: queuedMessage.sender,
                    text: queuedMessage.text,
                    createdAt: queuedMessage.createdAt,
                    status: .sent,
                    attachment: queuedMessage.attachment,
                    isOptional: queuedMessage.isOptional
                )
            }
        }
        threads[chatId] = thread
        publish(chatId: chatId)
        Self.logger.info("Mock outbox flushed (\(queued.count) messages)")
    }

    private func appendAndPublish(_ message: ChatMessage, chatId: String) {
        threads[chatId, default: []].append(message)
        threads[chatId]?.sort { $0.createdAt < $1.createdAt }
        publish(chatId: chatId)
    }

    private func publish(chatId: String) {
        let snapshot = threads[chatId] ?? []
        for continuation in (continuations[chatId] ?? [:]).values {
            continuation.yield(snapshot)
        }
    }
}
