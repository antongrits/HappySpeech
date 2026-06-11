import Foundation
import OSLog

// MARK: - SessionPersistenceCoordinating

/// Координатор offline-first персистентности завершённой сессии.
///
/// Закрывает пробел аудита (#2): сессии сохранялись в Realm, но **никогда не
/// ставились в очередь синхронизации**, поэтому прогресс ребёнка не уходил в
/// Firestore. Этот координатор — единственная точка, которая:
///   1. Сохраняет `SessionDTO` локально через `SessionRepository` (offline-first).
///   2. Если родитель **аутентифицирован и не анонимен** — ставит сессию в
///      `SyncService` очередь и мягко дренит её (при наличии сети). Анонимные
///      аккаунты не синкаются по правилам приватности (COPPA / api-contracts:
///      облачные документы живут под `users/{parentId}` реального аккаунта).
///
/// Сетевые ошибки/офлайн не теряют данные: сессия остаётся в Realm + в очереди и
/// будет до-синхронизирована при следующем дренаже (NetworkMonitor / app-foreground).
public protocol SessionPersistenceCoordinating: Sendable {
    /// Сохраняет сессию и (для аутентифицированного родителя) ставит в очередь синка.
    /// Никогда не бросает — все ошибки логируются; цель — не сорвать UX завершения.
    func persistAndSync(_ session: SessionDTO) async
}

// MARK: - LiveSessionPersistenceCoordinator

public final class LiveSessionPersistenceCoordinator: SessionPersistenceCoordinating, @unchecked Sendable {

    private let sessionRepository: any SessionRepository
    private let syncService: any SyncService
    private let authService: any AuthService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionSync")

    public init(
        sessionRepository: any SessionRepository,
        syncService: any SyncService,
        authService: any AuthService
    ) {
        self.sessionRepository = sessionRepository
        self.syncService = syncService
        self.authService = authService
    }

    public func persistAndSync(_ session: SessionDTO) async {
        // 1. Локальное сохранение (всегда, offline-first).
        do {
            try await sessionRepository.save(session)
            logger.info(
                "Session persisted id=\(session.id, privacy: .public) sound=\(session.targetSound, privacy: .public) synced=\(session.isSynced)"
            )
        } catch {
            logger.error("Session persist failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        // 2. Синк — только для реального (не анонимного) родителя.
        guard let parent = authService.currentUser, !parent.isAnonymous, !parent.uid.isEmpty else {
            logger.debug("Sync skipped — no authenticated parent (anonymous or signed-out); session stays local")
            return
        }

        await enqueueAndDrain(session, parentId: parent.uid)
    }

    // MARK: - Private

    private func enqueueAndDrain(_ session: SessionDTO, parentId: String) async {
        guard let payload = Self.sessionPayloadJSON(session, parentId: parentId) else {
            logger.error("Session sync skipped — payload serialisation failed id=\(session.id, privacy: .public)")
            return
        }
        let operation = SyncOperation(
            entityType: "session",
            entityId: session.id,
            operation: "upsert",
            payload: payload
        )
        do {
            try await syncService.enqueue(operation: operation)
            logger.info("Session enqueued for sync id=\(session.id, privacy: .public)")
        } catch {
            logger.error("Session enqueue failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        // Мягкий дренаж: если онлайн — выгрузит сейчас; если офлайн — SyncService
        // залогирует и оставит в очереди до следующего дренажа (NetworkMonitor/foreground).
        do {
            try await syncService.drainQueue()
        } catch {
            logger.debug("Session sync drain deferred: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Сериализует сессию в JSON-payload, совместимый с `SyncService.performNetworkUpload`
    /// (`entityType == "session"`): обязательны `parentId` + `childId`. Схема полей
    /// идентична `SessionSnapshot.firestoreDict(parentId:)`.
    static func sessionPayloadJSON(_ session: SessionDTO, parentId: String) -> String? {
        let dict: [String: Any] = [
            "id": session.id,
            "parentId": parentId,
            "childId": session.childId,
            "date": session.date.timeIntervalSince1970,
            "templateType": session.templateType,
            "targetSound": session.targetSound,
            "stage": session.stage,
            "durationSeconds": session.durationSeconds,
            "totalAttempts": session.totalAttempts,
            "correctAttempts": session.correctAttempts,
            "fatigueDetected": session.fatigueDetected
        ]
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }
}
