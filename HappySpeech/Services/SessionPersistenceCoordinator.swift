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
    private let childRepository: any ChildRepository
    private let syncService: any SyncService
    private let authService: any AuthService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionSync")

    public init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository,
        syncService: any SyncService,
        authService: any AuthService
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
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

        // 1.5. P0-3: обновляем агрегаты профиля (lastSessionAt / totalSessionMinutes /
        // currentStreak). Это ЕДИНСТВЕННАЯ точка записи этих полей — раньше они
        // никогда не обновлялись, и ParentHome/Family/Specialist/Sync читали вечные
        // нули. Не срывает UX: ошибки логируются, дальше идёт синк.
        await updateChildAggregates(after: session)

        // 2. Синк — только для реального (не анонимного) родителя.
        guard let parent = authService.currentUser, !parent.isAnonymous, !parent.uid.isEmpty else {
            logger.debug("Sync skipped — no authenticated parent (anonymous or signed-out); session stays local")
            return
        }

        await enqueueAndDrain(session, parentId: parent.uid)
    }

    // MARK: - Private

    /// P0-3: пересчитывает и сохраняет агрегаты профиля по только что записанной сессии.
    /// `currentStreak` берётся из РЕАЛЬНЫХ сессий ребёнка (trailing-run `StreakCalculator`,
    /// тот же источник правды, что и в ChildHome/WorldMap), а не из инкрементной эвристики.
    /// `addedMinutes` округляется из секунд (минимум 1 минута за непустую сессию).
    private func updateChildAggregates(after session: SessionDTO) async {
        guard !session.childId.isEmpty else { return }

        let addedMinutes = session.durationSeconds > 0
            ? max(1, Int((Double(session.durationSeconds) / 60.0).rounded()))
            : 0

        // Стрик — по всем сессиям ребёнка (включая только что сохранённую).
        let streak: Int
        do {
            let sessions = try await sessionRepository.fetchAll(childId: session.childId)
            streak = StreakCalculator.activeDayStreak(in: sessions, referenceDate: session.date)
        } catch {
            logger.error("Streak recompute failed: \(error.localizedDescription, privacy: .public)")
            // Безопасный минимум: только что была активность сегодня.
            streak = 1
        }

        do {
            try await childRepository.updateSessionAggregates(
                childId: session.childId,
                lastSessionAt: session.date,
                addedMinutes: addedMinutes,
                streak: streak
            )
            logger.info(
                "Child aggregates updated childId=\(session.childId, privacy: .private) +min=\(addedMinutes) streak=\(streak)"
            )
        } catch {
            logger.error("Child aggregates update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

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
