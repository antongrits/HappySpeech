import FirebaseDatabase
import Foundation
import OSLog

// MARK: - Models

/// Состояние SharePlay сессии для синхронизации между участниками.
public struct SharePlaySessionState: Sendable, Equatable {
    /// Уникальный идентификатор сессии (UUID).
    public let sessionId: String
    /// Идентификатор хоста сессии (создатель).
    public let hostUid: String
    /// Текущий шаг урока (для синхронизации экранов).
    public let currentStep: Int
    /// Идентификатор текущего упражнения.
    public let currentExerciseId: String?
    /// Версия состояния (увеличивается с каждым обновлением, для оптимистичных
    /// конфликт-резолюций).
    public let version: Int
    /// Время последнего обновления.
    public let updatedAt: Date

    public init(
        sessionId: String,
        hostUid: String,
        currentStep: Int,
        currentExerciseId: String?,
        version: Int,
        updatedAt: Date
    ) {
        self.sessionId = sessionId
        self.hostUid = hostUid
        self.currentStep = currentStep
        self.currentExerciseId = currentExerciseId
        self.version = version
        self.updatedAt = updatedAt
    }
}

/// Эфемерное присутствие собеседника в треде чата (онлайн + «печатает…»).
///
/// Снимок собирается из RTDB-узла `chat_presence/{chatId}/{otherUid}` — это
/// присутствие *другого* участника (не моё). Realtime Database выбрана для
/// presence сознательно: узлы эфемерны, авто-очищаются `onDisconnect`, не
/// тарифицируются как Firestore-документы и обновляются с малой задержкой.
///
/// > Important: COPPA — узел содержит только технические флаги (`online`,
/// > `typing`, `lastActive`-timestamp). Никакого имени/PII ребёнка или
/// > родителя. Участники — только auth-связанные parent/specialist треда.
public struct ChatPresence: Sendable, Equatable {
    /// Собеседник сейчас в сети (есть активное соединение с RTDB).
    public let isOnline: Bool
    /// Собеседник сейчас набирает сообщение.
    public let isTyping: Bool
    /// Последняя активность собеседника (для «был(а) в … »). `nil`, если
    /// узел ещё ни разу не записывался.
    public let lastActiveAt: Date?

    public init(isOnline: Bool, isTyping: Bool, lastActiveAt: Date?) {
        self.isOnline = isOnline
        self.isTyping = isTyping
        self.lastActiveAt = lastActiveAt
    }

    /// Нейтральное «никого нет» — используется до получения первого снапшота
    /// и когда узел отсутствует.
    public static let absent = ChatPresence(isOnline: false, isTyping: false, lastActiveAt: nil)
}

// MARK: - Errors

public enum RealtimeDatabaseError: LocalizedError, Sendable {
    case notInitialized
    case writeFailed(String)
    case readFailed(String)
    case decodingFailed(String)
    case sessionNotFound

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "База данных реального времени недоступна."
        case .writeFailed(let detail):
            return "Не удалось обновить данные сессии: \(detail)"
        case .readFailed(let detail):
            return "Не удалось получить данные сессии: \(detail)"
        case .decodingFailed(let detail):
            return "Неверный формат данных сессии: \(detail)"
        case .sessionNotFound:
            return "Сессия не найдена."
        }
    }
}

// MARK: - Subscription handle

/// Хэндл активной подписки на изменения сессии.
///
/// Инкапсулирует логику отмены подписки через замыкание `onCancel`. Live-реализация
/// передаёт замыкание, снимающее Firebase observer; mock — чистый no-op без какой-либо
/// ссылки на Firebase. Cancel вызывается через `RealtimeDatabaseService.cancelObservation(_:)`
/// или автоматически при deinit.
public final class SharePlayObservation: @unchecked Sendable {
    /// Замыкание отмены. Не помечено `@Sendable`: live-реализация захватывает
    /// `DatabaseReference` (non-Sendable). Потокобезопасность гарантируется
    /// `@unchecked Sendable` самого класса — отмена идемпотентна.
    private let onCancel: () -> Void
    private var isCancelled = false

    fileprivate init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        onCancel()
    }

    deinit {
        guard !isCancelled else { return }
        onCancel()
    }
}

// MARK: - Protocol

/// Синхронизация SharePlay сессий через Firebase Realtime Database.
///
/// Используется для multiplayer-режима, когда два устройства участвуют в
/// общей логопедической сессии (родитель-ребёнок, два ребёнка через GroupActivities).
/// Realtime Database выбран вместо Firestore для **малой латентности** (<200ms)
/// типичной для сессий синхронизации.
///
/// > Important: Region — `europe-west1` (closest available для eur3 multi-region).
/// > Реальный SharePlay интегрирован в `HappySpeech/Features/SharePlay/`.
///
/// ## Workflow
/// 1. Хост вызывает `createSession(sessionId:hostUid:)` → возвращает initial state.
/// 2. Гость вызывает `observeSession(sessionId:onChange:)` → получает live updates.
/// 3. Хост обновляет state через `updateSession(sessionId:state:)` — гости получают
///    новое значение через onChange callback.
/// 4. По завершении — `endSession(sessionId:)` удаляет документ.
///
/// ## See Also
/// - SharePlay GroupActivities в `HappySpeech/Features/SharePlay/`
public protocol RealtimeDatabaseServiceProtocol: AnyObject, Sendable {

    /// Создаёт новую SharePlay сессию.
    ///
    /// - Parameters:
    ///   - sessionId: UUID сессии.
    ///   - hostUid: Auth UID хоста.
    /// - Returns: Initial `SharePlaySessionState` с version=1.
    /// - Throws: `RealtimeDatabaseError.writeFailed`.
    func createSession(sessionId: String, hostUid: String) async throws -> SharePlaySessionState

    /// Подписывается на live updates указанной сессии.
    ///
    /// - Parameters:
    ///   - sessionId: UUID сессии.
    ///   - onChange: Callback вызывается на main actor при каждом изменении.
    /// - Returns: `SharePlayObservation` — handle для последующей отмены.
    /// - Throws: `RealtimeDatabaseError.readFailed` если сессия не существует.
    @discardableResult
    func observeSession(
        sessionId: String,
        onChange: @escaping @Sendable (SharePlaySessionState) -> Void
    ) async throws -> SharePlayObservation

    /// Обновляет состояние сессии (только хост).
    ///
    /// - Parameters:
    ///   - sessionId: UUID сессии.
    ///   - currentStep: Новый текущий шаг.
    ///   - currentExerciseId: Новое упражнение (опционально).
    /// - Throws: `RealtimeDatabaseError.writeFailed`.
    func updateSession(
        sessionId: String,
        currentStep: Int,
        currentExerciseId: String?
    ) async throws

    /// Удаляет сессию по завершении.
    ///
    /// - Parameter sessionId: UUID сессии.
    /// - Throws: `RealtimeDatabaseError.writeFailed`.
    func endSession(sessionId: String) async throws

    /// Отменяет активную подписку.
    func cancelObservation(_ observation: SharePlayObservation)

    // MARK: - Chat presence (LogopedistChat)

    /// Объявляет *моё* присутствие в треде чата и регистрирует авто-очистку при
    /// разрыве соединения.
    ///
    /// Пишет узел `chat_presence/{chatId}/{myUid}` со флагами `online=true` и
    /// текущим `typing`. Через `onDisconnect` RTDB сама обнулит `online` и
    /// проставит `lastActive`, когда устройство потеряет связь — поэтому статус
    /// «онлайн» не «залипает» при крэше/потере сети.
    ///
    /// - Parameters:
    ///   - chatId: детерминированный идентификатор треда (`ChatIdentity.chatId`).
    ///   - uid: auth UID текущего участника.
    ///   - isTyping: набирает ли пользователь сообщение прямо сейчас.
    /// - Throws: `RealtimeDatabaseError.writeFailed`.
    func setChatPresence(chatId: String, uid: String, isTyping: Bool) async throws

    /// Снимает *моё* присутствие в треде (online=false, typing=false) —
    /// вызывается при уходе с экрана. Идемпотентно.
    ///
    /// - Parameters:
    ///   - chatId: идентификатор треда.
    ///   - uid: auth UID текущего участника.
    func clearChatPresence(chatId: String, uid: String) async

    /// Подписывается на присутствие *собеседника* (узел `otherUid`) в треде.
    ///
    /// - Parameters:
    ///   - chatId: идентификатор треда.
    ///   - otherUid: UID участника, чьё присутствие наблюдаем (НЕ мой).
    ///   - onChange: вызывается при каждом изменении присутствия собеседника.
    /// - Returns: `SharePlayObservation` — handle для отмены (снимает observer).
    /// - Throws: `RealtimeDatabaseError.readFailed`.
    @discardableResult
    func observeChatPresence(
        chatId: String,
        otherUid: String,
        onChange: @escaping @Sendable (ChatPresence) -> Void
    ) async throws -> SharePlayObservation
}

// MARK: - Configuration

private enum RTDBConfig {
    /// Region для базы — `europe-west1` (closest available для eur3).
    /// Realtime Database не поддерживает eur3 multi-region; us-central1 далеко от RU.
    static let databaseURL = "https://happyspeech-dfd95.europe-west1.firebasedatabase.app"

    /// Корневой путь для SharePlay сессий.
    static let sessionsPath = "shareplay_sessions"

    /// Корневой путь для эфемерного присутствия в чате
    /// (`chat_presence/{chatId}/{uid}`).
    static let presencePath = "chat_presence"
}

// MARK: - Live Implementation

/// Продакшн-реализация `RealtimeDatabaseServiceProtocol`.
///
/// Использует Firebase Realtime Database в регионе `europe-west1`.
/// `@unchecked Sendable` оправдан: `Database.database()` thread-safe singleton.
public final class LiveRealtimeDatabaseService: RealtimeDatabaseServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "RealtimeDB")
    private let database: Database

    public init() {
        self.database = Database.database(url: RTDBConfig.databaseURL)
    }

    // MARK: - RealtimeDatabaseServiceProtocol

    public func createSession(sessionId: String, hostUid: String) async throws -> SharePlaySessionState {
        guard !sessionId.isEmpty, !hostUid.isEmpty else {
            throw RealtimeDatabaseError.writeFailed("sessionId или hostUid пустой")
        }

        let initialState = SharePlaySessionState(
            sessionId: sessionId,
            hostUid: hostUid,
            currentStep: 0,
            currentExerciseId: nil,
            version: 1,
            updatedAt: Date()
        )

        let payload: [String: Any] = encodeState(initialState)
        let ref = database.reference()
            .child(RTDBConfig.sessionsPath)
            .child(sessionId)

        do {
            try await ref.setValue(payload)
            logger.info("SharePlay session created: id=\(sessionId, privacy: .public)")
            return initialState
        } catch {
            logger.error("createSession failed: \(error.localizedDescription)")
            throw RealtimeDatabaseError.writeFailed(error.localizedDescription)
        }
    }

    @discardableResult
    public func observeSession(
        sessionId: String,
        onChange: @escaping @Sendable (SharePlaySessionState) -> Void
    ) async throws -> SharePlayObservation {
        guard !sessionId.isEmpty else {
            throw RealtimeDatabaseError.readFailed("sessionId пустой")
        }

        let ref = database.reference()
            .child(RTDBConfig.sessionsPath)
            .child(sessionId)

        let handle = ref.observe(.value) { [weak self] snapshot in
            guard let self else { return }
            guard snapshot.exists(), let dict = snapshot.value as? [String: Any] else {
                self.logger.warning("observeSession: snapshot not exists")
                return
            }
            do {
                let state = try self.decodeState(from: dict, fallbackSessionId: sessionId)
                onChange(state)
            } catch {
                self.logger.error("observeSession decode failed: \(error.localizedDescription)")
            }
        } withCancel: { [weak self] error in
            self?.logger.error("observeSession cancelled: \(error.localizedDescription)")
        }

        logger.info("SharePlay observation started: id=\(sessionId, privacy: .public)")
        return SharePlayObservation { ref.removeObserver(withHandle: handle) }
    }

    public func updateSession(
        sessionId: String,
        currentStep: Int,
        currentExerciseId: String?
    ) async throws {
        guard !sessionId.isEmpty else {
            throw RealtimeDatabaseError.writeFailed("sessionId пустой")
        }

        let ref = database.reference()
            .child(RTDBConfig.sessionsPath)
            .child(sessionId)

        // Атомарный update — увеличиваем version через transaction.
        do {
            try await ref.runTransactionBlock { currentData in
                guard var dict = currentData.value as? [String: Any] else {
                    return TransactionResult.abort()
                }
                let oldVersion = (dict["version"] as? Int) ?? 0
                dict["currentStep"] = currentStep
                dict["currentExerciseId"] = currentExerciseId ?? NSNull()
                dict["version"] = oldVersion + 1
                dict["updatedAt"] = Date().timeIntervalSince1970
                currentData.value = dict
                return TransactionResult.success(withValue: currentData)
            }
            logger.info("SharePlay session updated: id=\(sessionId, privacy: .public), step=\(currentStep)")
        } catch {
            logger.error("updateSession failed: \(error.localizedDescription)")
            throw RealtimeDatabaseError.writeFailed(error.localizedDescription)
        }
    }

    public func endSession(sessionId: String) async throws {
        guard !sessionId.isEmpty else { return }

        let ref = database.reference()
            .child(RTDBConfig.sessionsPath)
            .child(sessionId)

        do {
            try await ref.removeValue()
            logger.info("SharePlay session ended: id=\(sessionId, privacy: .public)")
        } catch {
            logger.error("endSession failed: \(error.localizedDescription)")
            throw RealtimeDatabaseError.writeFailed(error.localizedDescription)
        }
    }

    public func cancelObservation(_ observation: SharePlayObservation) {
        observation.cancel()
    }

    // MARK: - Chat presence

    public func setChatPresence(chatId: String, uid: String, isTyping: Bool) async throws {
        guard !chatId.isEmpty, !uid.isEmpty else {
            throw RealtimeDatabaseError.writeFailed("chatId или uid пустой")
        }

        let ref = database.reference()
            .child(RTDBConfig.presencePath)
            .child(chatId)
            .child(uid)

        // onDisconnect регистрируем ДО записи online=true: если соединение
        // оборвётся между регистрацией и записью, RTDB всё равно сбросит статус.
        // `online=false` + серверный timestamp `lastActive` — собеседник увидит
        // «не в сети», а не вечный «онлайн».
        _ = try? await ref.onDisconnectSetValue([
            "online": false,
            "typing": false,
            "lastActive": ServerValue.timestamp()
        ])

        let payload: [String: Any] = [
            "online": true,
            "typing": isTyping,
            "lastActive": ServerValue.timestamp()
        ]

        do {
            try await ref.setValue(payload)
        } catch {
            logger.error("setChatPresence failed: \(error.localizedDescription)")
            throw RealtimeDatabaseError.writeFailed(error.localizedDescription)
        }
    }

    public func clearChatPresence(chatId: String, uid: String) async {
        guard !chatId.isEmpty, !uid.isEmpty else { return }

        let ref = database.reference()
            .child(RTDBConfig.presencePath)
            .child(chatId)
            .child(uid)

        // Отменяем отложенную onDisconnect-операцию (мы уходим штатно) и пишем
        // финальный offline-снимок синхронно.
        _ = try? await ref.cancelDisconnectOperations()
        do {
            try await ref.setValue([
                "online": false,
                "typing": false,
                "lastActive": ServerValue.timestamp()
            ])
        } catch {
            // Очистка best-effort: при оффлайне сработает onDisconnect на сервере.
            logger.notice("clearChatPresence best-effort failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func observeChatPresence(
        chatId: String,
        otherUid: String,
        onChange: @escaping @Sendable (ChatPresence) -> Void
    ) async throws -> SharePlayObservation {
        guard !chatId.isEmpty, !otherUid.isEmpty else {
            throw RealtimeDatabaseError.readFailed("chatId или otherUid пустой")
        }

        let ref = database.reference()
            .child(RTDBConfig.presencePath)
            .child(chatId)
            .child(otherUid)

        let handle = ref.observe(.value) { snapshot in
            guard snapshot.exists(), let dict = snapshot.value as? [String: Any] else {
                onChange(.absent)
                return
            }
            let online = (dict["online"] as? Bool) ?? false
            let typing = (dict["typing"] as? Bool) ?? false
            // RTDB ServerValue.timestamp() материализуется в миллисекунды.
            let lastActive: Date?
            if let ms = dict["lastActive"] as? Double {
                lastActive = Date(timeIntervalSince1970: ms / 1000)
            } else {
                lastActive = nil
            }
            onChange(ChatPresence(isOnline: online, isTyping: typing, lastActiveAt: lastActive))
        } withCancel: { [weak self] error in
            self?.logger.error("observeChatPresence cancelled: \(error.localizedDescription)")
        }

        logger.info("Chat presence observation started")
        return SharePlayObservation { ref.removeObserver(withHandle: handle) }
    }

    // MARK: - Private Helpers

    private func encodeState(_ state: SharePlaySessionState) -> [String: Any] {
        var dict: [String: Any] = [
            "sessionId": state.sessionId,
            "hostUid": state.hostUid,
            "currentStep": state.currentStep,
            "version": state.version,
            "updatedAt": state.updatedAt.timeIntervalSince1970
        ]
        if let exerciseId = state.currentExerciseId {
            dict["currentExerciseId"] = exerciseId
        } else {
            dict["currentExerciseId"] = NSNull()
        }
        return dict
    }

    private func decodeState(
        from dict: [String: Any],
        fallbackSessionId: String
    ) throws -> SharePlaySessionState {
        guard let hostUid = dict["hostUid"] as? String else {
            throw RealtimeDatabaseError.decodingFailed("отсутствует hostUid")
        }
        let sessionId = (dict["sessionId"] as? String) ?? fallbackSessionId
        let currentStep = (dict["currentStep"] as? Int) ?? 0
        let currentExerciseId = dict["currentExerciseId"] as? String
        let version = (dict["version"] as? Int) ?? 1
        let updatedAtTs = (dict["updatedAt"] as? Double) ?? Date().timeIntervalSince1970
        let updatedAt = Date(timeIntervalSince1970: updatedAtTs)

        return SharePlaySessionState(
            sessionId: sessionId,
            hostUid: hostUid,
            currentStep: currentStep,
            currentExerciseId: currentExerciseId,
            version: version,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Mock

/// Preview / test реализация. Имитирует in-memory store без сети.
///
/// Использует `actor` для thread-safe доступа в Swift 6 strict concurrency.
public final class MockRealtimeDatabaseService: RealtimeDatabaseServiceProtocol, @unchecked Sendable {

    /// Actor-based store — Swift 6 strict concurrency safe.
    private actor Store {
        var sessions: [String: SharePlaySessionState] = [:]
        var observers: [String: [@Sendable (SharePlaySessionState) -> Void]] = [:]
        var createCalls: Int = 0
        var updateCalls: Int = 0
        var endCalls: Int = 0

        func put(_ state: SharePlaySessionState) {
            sessions[state.sessionId] = state
            createCalls += 1
        }

        func update(_ state: SharePlaySessionState) {
            sessions[state.sessionId] = state
            updateCalls += 1
        }

        func remove(_ sessionId: String) {
            sessions.removeValue(forKey: sessionId)
            observers.removeValue(forKey: sessionId)
            endCalls += 1
        }

        func get(_ sessionId: String) -> SharePlaySessionState? {
            return sessions[sessionId]
        }

        func addObserver(
            sessionId: String,
            callback: @escaping @Sendable (SharePlaySessionState) -> Void
        ) -> SharePlaySessionState? {
            observers[sessionId, default: []].append(callback)
            return sessions[sessionId]
        }

        func observerCallbacks(sessionId: String) -> [@Sendable (SharePlaySessionState) -> Void] {
            return observers[sessionId] ?? []
        }

        // Presence (key: "chatId/uid").
        var presence: [String: ChatPresence] = [:]
        var presenceObservers: [String: [@Sendable (ChatPresence) -> Void]] = [:]

        func setPresence(_ value: ChatPresence, key: String) {
            presence[key] = value
        }

        func addPresenceObserver(
            key: String,
            callback: @escaping @Sendable (ChatPresence) -> Void
        ) -> ChatPresence {
            presenceObservers[key, default: []].append(callback)
            return presence[key] ?? .absent
        }

        func presenceCallbacks(key: String) -> [@Sendable (ChatPresence) -> Void] {
            presenceObservers[key] ?? []
        }
    }

    private let store = Store()

    public var shouldThrowError: RealtimeDatabaseError?

    public init() {}

    public func createSession(
        sessionId: String,
        hostUid: String
    ) async throws -> SharePlaySessionState {
        if let error = shouldThrowError { throw error }
        let state = SharePlaySessionState(
            sessionId: sessionId,
            hostUid: hostUid,
            currentStep: 0,
            currentExerciseId: nil,
            version: 1,
            updatedAt: Date()
        )
        await store.put(state)
        await notifyObservers(sessionId: sessionId, state: state)
        return state
    }

    @discardableResult
    public func observeSession(
        sessionId: String,
        onChange: @escaping @Sendable (SharePlaySessionState) -> Void
    ) async throws -> SharePlayObservation {
        if let error = shouldThrowError { throw error }
        let snapshot = await store.addObserver(sessionId: sessionId, callback: onChange)

        if let snapshot {
            onChange(snapshot)
        }

        // Чистый in-memory observation: mock НИКОГДА не обращается к Firebase.
        // cancel — no-op, in-memory store не требует снятия observer'а.
        return SharePlayObservation {}
    }

    public func updateSession(
        sessionId: String,
        currentStep: Int,
        currentExerciseId: String?
    ) async throws {
        if let error = shouldThrowError { throw error }
        guard let existing = await store.get(sessionId) else {
            throw RealtimeDatabaseError.sessionNotFound
        }
        let updated = SharePlaySessionState(
            sessionId: existing.sessionId,
            hostUid: existing.hostUid,
            currentStep: currentStep,
            currentExerciseId: currentExerciseId,
            version: existing.version + 1,
            updatedAt: Date()
        )
        await store.update(updated)
        await notifyObservers(sessionId: sessionId, state: updated)
    }

    public func endSession(sessionId: String) async throws {
        if let error = shouldThrowError { throw error }
        await store.remove(sessionId)
    }

    public func cancelObservation(_ observation: SharePlayObservation) {
        observation.cancel()
    }

    public func setChatPresence(chatId: String, uid: String, isTyping: Bool) async throws {
        if let error = shouldThrowError { throw error }
        let key = "\(chatId)/\(uid)"
        let value = ChatPresence(isOnline: true, isTyping: isTyping, lastActiveAt: Date())
        await store.setPresence(value, key: key)
        await notifyPresenceObservers(key: key, value: value)
    }

    public func clearChatPresence(chatId: String, uid: String) async {
        let key = "\(chatId)/\(uid)"
        let value = ChatPresence(isOnline: false, isTyping: false, lastActiveAt: Date())
        await store.setPresence(value, key: key)
        await notifyPresenceObservers(key: key, value: value)
    }

    @discardableResult
    public func observeChatPresence(
        chatId: String,
        otherUid: String,
        onChange: @escaping @Sendable (ChatPresence) -> Void
    ) async throws -> SharePlayObservation {
        if let error = shouldThrowError { throw error }
        let key = "\(chatId)/\(otherUid)"
        let snapshot = await store.addPresenceObserver(key: key, callback: onChange)
        onChange(snapshot)
        return SharePlayObservation {}
    }

    private func notifyObservers(sessionId: String, state: SharePlaySessionState) async {
        let callbacks = await store.observerCallbacks(sessionId: sessionId)
        for callback in callbacks {
            callback(state)
        }
    }

    private func notifyPresenceObservers(key: String, value: ChatPresence) async {
        let callbacks = await store.presenceCallbacks(key: key)
        for callback in callbacks {
            callback(value)
        }
    }
}
