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
/// Содержит ссылку на Firebase observer handle. Cancel вызывается через
/// `RealtimeDatabaseService.cancelObservation(_:)` или автоматически
/// при deinit через `Task` отмену.
public final class SharePlayObservation: @unchecked Sendable {
    fileprivate let reference: DatabaseReference
    fileprivate let handle: DatabaseHandle

    fileprivate init(reference: DatabaseReference, handle: DatabaseHandle) {
        self.reference = reference
        self.handle = handle
    }

    public func cancel() {
        reference.removeObserver(withHandle: handle)
    }

    deinit {
        reference.removeObserver(withHandle: handle)
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
}

// MARK: - Configuration

private enum RTDBConfig {
    /// Region для базы — `europe-west1` (closest available для eur3).
    /// Realtime Database не поддерживает eur3 multi-region; us-central1 далеко от RU.
    static let databaseURL = "https://happyspeech-dfd95-default-rtdb.europe-west1.firebasedatabase.app"

    /// Корневой путь для SharePlay сессий.
    static let sessionsPath = "shareplay_sessions"
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
        return SharePlayObservation(reference: ref, handle: handle)
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

        // Возвращаем dummy observation — Firebase reference нужен только для cancel().
        // В моке reference указывает на invalid host, removeObserver — no-op.
        let dummyDB = Database.database(url: "https://example.invalid")
        let dummyRef = dummyDB.reference().child("dummy")
        return SharePlayObservation(reference: dummyRef, handle: 0)
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

    private func notifyObservers(sessionId: String, state: SharePlaySessionState) async {
        let callbacks = await store.observerCallbacks(sessionId: sessionId)
        for callback in callbacks {
            callback(state)
        }
    }
}
