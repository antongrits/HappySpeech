import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
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
//     { id, senderRole, text, audioPath?, audioURL?, audioDurationSec?,
//       createdAt, read }
//
// Аудио-вложения: m4a выгружается в Firebase Storage по parental-gated пути
// `chat_audio/{chatId}/{messageId}.m4a` (см. storage.rules → isChatParticipant),
// а в Firestore пишется `audioPath` (storage-ref) + `audioURL` (download-URL).
// Получатель проигрывает удалённый URL — НИКОГДА локальный путь песочницы
// отправителя (тот недоступен на другом устройстве). COPPA: путь доступен
// только участникам треда (parent/specialist), ребёнок не участвует.
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
    private let storage: Storage
    private let networkMonitor: any NetworkMonitorService

    private enum Path {
        static let links = "chat_links"
        static let chats = "chats"
        static let messages = "messages"
        static let audio = "chat_audio"
    }

    public init(networkMonitor: any NetworkMonitorService) {
        self.firestore = Firestore.firestore()
        self.storage = Storage.storage()
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
    public func sendText(
        identity: ChatIdentity,
        text: String,
        now: Date,
        sender: MessageSender
    ) async -> ChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = ChatMessage(
            id: UUID().uuidString,
            sender: sender,
            text: trimmed,
            createdAt: now,
            status: networkMonitor.isConnected ? .sent : .sending
        )
        await write(message, identity: identity)
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
        let messageId = UUID().uuidString

        // 1. Выгружаем локальный m4a в Firebase Storage (parental-gated путь).
        //    Получатель на другом устройстве не имеет доступа к файлу в песочнице
        //    отправителя — поэтому шлём download-URL, а не локальный путь.
        let upload = await uploadAudio(
            localPath: localAudioPath,
            chatId: identity.chatId,
            messageId: messageId
        )

        let attachment = MessageAttachment(
            id: UUID().uuidString,
            kind: .audioRecording,
            titleKey: titleKey,
            durationSeconds: durationSeconds,
            remoteURL: upload?.downloadURL
        )
        // Если выгрузка не удалась (нет файла/нет сети) — сообщение уходит со
        // статусом .failed без аудио-ref, без фабрикации недоступной ссылки.
        let status: MessageStatus
        if upload != nil {
            status = networkMonitor.isConnected ? .sent : .sending
        } else {
            status = .failed
        }
        let message = ChatMessage(
            id: messageId,
            sender: .parent,
            text: String(localized: "chat.attachment.audio.placeholder"),
            createdAt: now,
            status: status,
            attachment: attachment,
            // Сохраняем локальный путь только если файл реально существует —
            // отправитель проиграет запись с диска сразу, без обращения к Storage.
            localAudioPath: localAudioPath.isEmpty ? nil : localAudioPath
        )
        await write(
            message,
            identity: identity,
            audioPath: upload?.storagePath,
            audioURL: upload?.downloadURL,
            durationSeconds: durationSeconds
        )
        return message
    }

    // MARK: - Download (для воспроизведения входящего аудио)

    public func downloadAudio(remoteURL: URL) async -> URL? {
        // Кэш в caches-директории по имени файла Storage (стабильно между
        // запусками — повторное воспроизведение не качает заново).
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let chatCache = cacheDir.appendingPathComponent("chat_audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: chatCache, withIntermediateDirectories: true)

        // Детерминированное имя файла из полного URL: остаётся стабильным между
        // запусками (в отличие от `hashValue`), поэтому кэш реально переиспользуется.
        let safeName = remoteURL.absoluteString.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        let trimmed = String(String(safeName).suffix(80))
        let localURL = chatCache.appendingPathComponent("\(trimmed).m4a")

        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                logger.error("downloadAudio: HTTP \(http.statusCode)")
                return nil
            }
            try data.write(to: localURL, options: .atomic)
            logger.info("downloadAudio: cached \(data.count, privacy: .public) bytes")
            return localURL
        } catch {
            logger.error("downloadAudio failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Результат выгрузки аудио в Storage: путь-ref и публичный download-URL.
    private struct AudioUpload: Sendable {
        let storagePath: String
        let downloadURL: URL
    }

    /// Выгружает локальный m4a в `chat_audio/{chatId}/{messageId}.m4a` и
    /// возвращает storage-path + download-URL. `nil`, если файла нет или
    /// выгрузка не удалась (честный провал — без фейковой ссылки).
    private func uploadAudio(
        localPath: String,
        chatId: String,
        messageId: String
    ) async -> AudioUpload? {
        guard !localPath.isEmpty else {
            logger.warning("sendAudio: empty localAudioPath — нет файла для выгрузки")
            return nil
        }
        let fileURL = URL(fileURLWithPath: localPath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.warning("sendAudio: файл не найден по пути \(localPath, privacy: .private)")
            return nil
        }
        let storagePath = "\(Path.audio)/\(chatId)/\(messageId).m4a"
        let ref = storage.reference(withPath: storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        do {
            _ = try await ref.putFileAsync(from: fileURL, metadata: metadata)
            let url = try await ref.downloadURL()
            logger.info("sendAudio: выгружено в Storage (\(storagePath, privacy: .public))")
            return AudioUpload(storagePath: storagePath, downloadURL: url)
        } catch {
            logger.error("sendAudio: Storage upload failed — \(error.localizedDescription)")
            return nil
        }
    }

    private func write(
        _ message: ChatMessage,
        identity: ChatIdentity,
        audioPath: String? = nil,
        audioURL: URL? = nil,
        durationSeconds: Double? = nil
    ) async {
        var payload: [String: Any] = [
            "id": message.id,
            "senderRole": message.sender.rawValue,
            "text": message.text,
            "createdAt": Timestamp(date: message.createdAt),
            "read": false
        ]
        if let audioPath { payload["audioPath"] = audioPath }
        if let audioURL { payload["audioURL"] = audioURL.absoluteString }
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
        // P2-11: batch.updateData завалит весь batch, если хотя бы один id не существует
        // (например, pending-локальное сообщение ещё не попало в Firestore).
        // Пишем по-одному через setData(merge: true) — несуществующий документ создаётся,
        // существующий — патчится; каждая операция изолирована.
        for id in messageIds {
            do {
                try await collection.document(id).setData(["read": true], merge: true)
                updated.append(id)
            } catch {
                logger.warning("markAsRead: failed for id=\(id, privacy: .private) — \(error.localizedDescription)")
                // Пропускаем проблемный id, продолжаем остальные.
            }
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
        // Удалённый download-URL аудио (или legacy `audioRef` из старых записей).
        // Вложение показываем только при наличии хоть какого-то аудио-маркера;
        // проигрываемый источник — `audioURL` (Storage download-URL).
        let audioURLString = (data["audioURL"] as? String)
        let hasAudio = audioURLString != nil
            || data["audioPath"] != nil
            || data["audioRef"] != nil
        if hasAudio {
            let remoteURL = audioURLString.flatMap { URL(string: $0) }
            attachment = MessageAttachment(
                id: "\(id)-att",
                kind: .audioRecording,
                titleKey: "chat.attachment.audio.title",
                durationSeconds: data["audioDurationSec"] as? Double,
                remoteURL: remoteURL
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
