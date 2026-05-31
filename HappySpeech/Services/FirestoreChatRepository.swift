import FirebaseAuth
import FirebaseFirestore
import Foundation
import OSLog

// MARK: - FirestoreChatRepository
//
// Block R.2 v32 — продакшн-реализация `ChatRepository` поверх Cloud Firestore.
//
// Схема Firestore (см. firestore.rules → /chat_links и /chats):
//
//   chat_links/{shortCode}        — инвайт-связь, создаётся специалистом
//     { specialistId, displayName, credentialsKey, expiresAt, consumed,
//       consumedBy, consumedAt, chatId }
//
//   chats/{chatId}                — метаданные треда (chatId детерминирован)
//     { familyId, specialistId, createdAt, lastMessageAt }
//   chats/{chatId}/messages/{id}  — сообщения
//     { id, senderRole, text, audioRef?, audioDurationSec?, createdAt, read }
//
// Offline-first: Firestore SDK включает дисковую персистенцию (см.
// `FirebaseBootstrap`), поэтому записи ставятся в нативную offline-очередь SDK
// и доставляются при восстановлении сети автоматически. `addSnapshotListener`
// сначала отдаёт кэш (`metadata.isFromCache`), затем серверные данные — поэтому
// история и real-time доступны и в оффлайне. Дополнительно мы считаем
// собственный outbox по `metadata.hasPendingWrites` для индикатора в UI.
//
// COPPA: участники — только parent (familyId) и specialist. Сообщения не
// содержат PII ребёнка; chatId — непрозрачная пара uid. Никогда не вызывается
// из детского контура.
//
// `@unchecked Sendable` оправдан: `Firestore`/`Auth` — потокобезопасные
// синглтоны; собственного мутируемого состояния класс не держит.

public final class FirestoreChatRepository: ChatRepository, @unchecked Sendable {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ChatRepository.Firestore")
    private let firestore: Firestore
    private let networkMonitor: any NetworkMonitorService

    private enum Path {
        static let links = "chat_links"
        static let chats = "chats"
        static let messages = "messages"
    }

    public init(networkMonitor: any NetworkMonitorService) {
        self.firestore = Firestore.firestore()
        self.networkMonitor = networkMonitor
    }

    // MARK: - Link state

    public func linkState(identity: ChatIdentity) async -> ChatLinkState {
        let ref = firestore.collection(Path.chats).document(identity.chatId)
        do {
            let snapshot = try await ref.getDocument()
            guard snapshot.exists, let data = snapshot.data() else {
                return .notConnected
            }
            let specialist = Self.specialist(from: data)
            return .connected(specialist)
        } catch {
            logger.error("linkState read failed: \(error.localizedDescription)")
            // Оффлайн без кэша — честно показываем «не подключён», без выдумок.
            return .notConnected
        }
    }

    public func connectSpecialist(familyId: String, code: String) async -> ChatLinkState {
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 6 else { return .failed(.invalidCode) }
        guard !familyId.isEmpty else { return .failed(.notAuthenticated) }

        let linkRef = firestore.collection(Path.links).document(normalized)
        do {
            let snapshot = try await linkRef.getDocument()
            guard snapshot.exists, let data = snapshot.data() else {
                return .failed(.codeNotFound)
            }
            if let consumed = data["consumed"] as? Bool, consumed,
               let consumedBy = data["consumedBy"] as? String, consumedBy != familyId {
                return .failed(.alreadyConnected)
            }
            if let expiresAt = data["expiresAt"] as? Timestamp, expiresAt.dateValue() < Date() {
                return .failed(.codeExpired)
            }
            guard let specialistId = data["specialistId"] as? String, !specialistId.isEmpty else {
                return .failed(.codeNotFound)
            }

            let identity = ChatIdentity(familyId: familyId, specialistId: specialistId)
            let specialist = Self.specialist(from: data)

            // Атомарно: помечаем инвайт consumed + создаём метаданные чата.
            let chatRef = firestore.collection(Path.chats).document(identity.chatId)
            let batch = firestore.batch()
            batch.updateData(
                ["consumed": true,
                 "consumedBy": familyId,
                 "consumedAt": FieldValue.serverTimestamp()],
                forDocument: linkRef
            )
            batch.setData(
                ["familyId": familyId,
                 "specialistId": specialistId,
                 "specialistName": specialist.displayName,
                 "specialistCredentialsKey": specialist.credentialsKey,
                 "createdAt": FieldValue.serverTimestamp(),
                 "lastMessageAt": FieldValue.serverTimestamp()],
                forDocument: chatRef,
                merge: true
            )
            try await batch.commit()
            logger.info("Specialist connected to family via code")
            return .connected(specialist)
        } catch {
            logger.error("connectSpecialist failed: \(error.localizedDescription)")
            return .failed(.backendUnavailable(error.localizedDescription))
        }
    }

    // MARK: - History

    public func loadHistory(identity: ChatIdentity) async -> [ChatMessage] {
        let ref = messagesCollection(identity)
            .order(by: "createdAt", descending: false)
        do {
            let snapshot = try await ref.getDocuments()
            return snapshot.documents.compactMap { Self.message(from: $0.data()) }
        } catch {
            logger.error("loadHistory failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Real-time stream

    public func messageStream(identity: ChatIdentity) -> AsyncStream<[ChatMessage]> {
        let query = messagesCollection(identity).order(by: "createdAt", descending: false)
        return AsyncStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    self.logger.error("messageStream listener error: \(error.localizedDescription)")
                    return
                }
                guard let snapshot else { return }
                let messages = snapshot.documents.compactMap { Self.message(from: $0.data()) }
                continuation.yield(messages)
            }
            // `ListenerRegistration` не Sendable — оборачиваем в Sendable-холдер,
            // чтобы безопасно захватить в `@Sendable` onTermination замыкании.
            let holder = ListenerHolder(listener)
            continuation.onTermination = { _ in
                holder.remove()
            }
        }
    }

    // MARK: - Send

    @discardableResult
    public func sendText(identity: ChatIdentity, text: String, now: Date) async -> ChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = ChatMessage(
            id: UUID().uuidString,
            sender: .parent,
            text: trimmed,
            createdAt: now,
            status: networkMonitor.isConnected ? .sent : .sending
        )
        await write(message, identity: identity, audioRef: nil, durationSeconds: nil)
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
            status: networkMonitor.isConnected ? .sent : .sending,
            attachment: attachment
        )
        await write(
            message,
            identity: identity,
            audioRef: localAudioPath,
            durationSeconds: durationSeconds
        )
        return message
    }

    private func write(
        _ message: ChatMessage,
        identity: ChatIdentity,
        audioRef: String?,
        durationSeconds: Double?
    ) async {
        var payload: [String: Any] = [
            "id": message.id,
            "senderRole": message.sender.rawValue,
            "text": message.text,
            "createdAt": Timestamp(date: message.createdAt),
            "read": false
        ]
        if let audioRef { payload["audioRef"] = audioRef }
        if let durationSeconds { payload["audioDurationSec"] = durationSeconds }

        let docRef = messagesCollection(identity).document(message.id)
        // Async `setData` резолвится по коммиту в локальный кэш (НЕ ждёт серверный
        // ack) — поэтому в оффлайне запись ставится в нативную очередь SDK
        // мгновенно, а реальная доставка происходит при восстановлении сети.
        do {
            try await docRef.setData(payload)
        } catch {
            logger.error("message write failed (queued/offline): \(error.localizedDescription)")
        }
        // Обновляем lastMessageAt в метаданных чата (best-effort).
        try? await firestore.collection(Path.chats).document(identity.chatId)
            .setData(["lastMessageAt": Timestamp(date: message.createdAt)], merge: true)
    }

    // MARK: - Read / counters

    @discardableResult
    public func markAsRead(identity: ChatIdentity, messageIds: [String]) async -> [String] {
        guard !messageIds.isEmpty else { return [] }
        let collection = messagesCollection(identity)
        var updated: [String] = []
        let batch = firestore.batch()
        for id in messageIds {
            batch.updateData(["read": true], forDocument: collection.document(id))
            updated.append(id)
        }
        do {
            try await batch.commit()
        } catch {
            logger.error("markAsRead batch failed: \(error.localizedDescription)")
        }
        return updated
    }

    public func unreadCount(identity: ChatIdentity) async -> Int {
        let query = messagesCollection(identity)
            .whereField("senderRole", isEqualTo: MessageSender.specialist.rawValue)
            .whereField("read", isEqualTo: false)
        do {
            let snapshot = try await query.getDocuments()
            return snapshot.documents.count
        } catch {
            logger.error("unreadCount query failed: \(error.localizedDescription)")
            return 0
        }
    }

    public func pendingOutboxCount(identity: ChatIdentity) async -> Int {
        // Считаем сообщения с локальными незакоммиченными записями (offline-очередь SDK).
        do {
            let snapshot = try await messagesCollection(identity).getDocuments(source: .cache)
            return snapshot.documents.filter { $0.metadata.hasPendingWrites }.count
        } catch {
            return 0
        }
    }

    // MARK: - Helpers

    private func messagesCollection(_ identity: ChatIdentity) -> CollectionReference {
        firestore.collection(Path.chats)
            .document(identity.chatId)
            .collection(Path.messages)
    }

    private static func specialist(from data: [String: Any]) -> SpecialistInfo {
        let name = (data["specialistName"] as? String) ?? String(localized: "chat.specialist.unknown")
        let credentials = (data["specialistCredentialsKey"] as? String)
            ?? (data["credentialsKey"] as? String)
            ?? "specialist.credentials.logopedist"
        let isOnline = (data["isOnline"] as? Bool) ?? false
        let lastSeen = (data["lastSeenAt"] as? Timestamp)?.dateValue()
        return SpecialistInfo(
            displayName: name,
            credentialsKey: credentials,
            isOnline: isOnline,
            lastSeenAt: lastSeen
        )
    }

    private static func message(from data: [String: Any]) -> ChatMessage? {
        guard let id = data["id"] as? String,
              let roleRaw = data["senderRole"] as? String,
              let sender = MessageSender(rawValue: roleRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        let text = (data["text"] as? String) ?? ""
        let read = (data["read"] as? Bool) ?? false

        var attachment: MessageAttachment?
        if data["audioRef"] != nil {
            attachment = MessageAttachment(
                id: "\(id)-att",
                kind: .audioRecording,
                titleKey: "chat.attachment.audio.title",
                durationSeconds: data["audioDurationSec"] as? Double
            )
        }

        let status: MessageStatus = (sender == .specialist)
            ? (read ? .read : .delivered)
            : .sent
        return ChatMessage(
            id: id,
            sender: sender,
            text: text,
            createdAt: createdAt,
            status: status,
            attachment: attachment
        )
    }
}

// MARK: - ListenerHolder

/// Sendable-обёртка над `ListenerRegistration` (который non-Sendable), чтобы
/// безопасно захватить его в `@Sendable` onTermination-замыкании `AsyncStream`.
/// `@unchecked` оправдан: `remove()` идемпотентен и thread-safe в Firestore SDK.
private final class ListenerHolder: @unchecked Sendable {
    private let listener: any ListenerRegistration
    init(_ listener: any ListenerRegistration) { self.listener = listener }
    func remove() { listener.remove() }
}
