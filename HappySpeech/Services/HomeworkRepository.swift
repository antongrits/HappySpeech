import Foundation

// MARK: - HomeworkRepository
//
// Протокол облачного синка домашних заданий специалист ↔ родитель/ребёнок.
//
// Схема Firestore (см. firestore.rules, новые правила для ручного деплоя):
//
//   homework/{assignmentId}          — задание (создаёт специалист)
//     { id, specialistId, childId, familyId, createdAt, dueDate,
//       comment, exercises: [...], status }
//
// Семантика участников:
//   • Специалист создаёт задание → writes homework/{id} со своим specialistId.
//   • Родитель/ребёнок читает по familyId или childId → realtime listener.
//   • Ребёнок обновляет статус упражнения → updateExerciseStatus (patch поля).
//
// Offline-first: Firestore SDK держит дисковый кэш; записи встают в нативную
// offline-очередь и доставляются при восстановлении сети автоматически.
// `assignmentsStream` сначала отдаёт кэш, потом серверные данные —
// поэтому задания видны и без сети (как в LogopedistChat).
//
// COPPA / Kids Category:
//   • familyId = parent uid; childId = идентификатор из Realm (не PII).
//   • Никакого имени ребёнка в Firestore-документе. Только id.
//   • Доступ к репозиторию из детского контура ограничен: ребёнок может
//     только читать и обновлять статус выполнения — не создавать задания.

// MARK: - HomeworkRepositoryError

public enum HomeworkRepositoryError: LocalizedError, Sendable, Equatable {
    case notAuthenticated
    case writeFailedOffline
    case assignmentNotFound
    case backendUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "homework.error.notAuthenticated")
        case .writeFailedOffline:
            return String(localized: "homework.error.writeFailedOffline")
        case .assignmentNotFound:
            return String(localized: "homework.error.notFound")
        case .backendUnavailable(let detail):
            return String(
                format: String(localized: "homework.error.backendUnavailable"),
                detail
            )
        }
    }
}

// MARK: - HomeworkRepository protocol

/// Протокол облачного хранилища домашних заданий.
///
/// Реализован `FirestoreHomeworkRepository` (live) и `MockHomeworkRepository`
/// (preview / тесты). Инъектируется через `AppContainer.homeworkRepository`.
public protocol HomeworkRepository: Sendable {

    /// Публикует задание в облако. Вызывается специалистом после локального
    /// создания в `AssignedHomeworkWorker`. Offline-first: Firestore SDK ставит
    /// запись в очередь, если нет сети.
    ///
    /// - Returns: `.success` / `.failure(HomeworkRepositoryError)`
    func publish(
        assignment: HomeworkAssignment,
        specialistId: String,
        familyId: String
    ) async -> Result<Void, HomeworkRepositoryError>

    /// Подписка на задания ребёнка (для родительского/детского контуров).
    /// Каждый снапшот — полный список заданий, отсортированных по `createdAt` desc.
    /// Live: Firestore `addSnapshotListener`. Mock: single-yield + real-time через actor.
    func assignmentsStream(
        childId: String,
        familyId: String
    ) -> AsyncStream<[HomeworkAssignment]>

    /// Однократная загрузка актуального списка заданий (для refresh / cold start).
    func fetchAssignments(
        childId: String,
        familyId: String
    ) async -> [HomeworkAssignment]

    /// Обновляет статус выполнения конкретного упражнения в задании.
    /// Вызывается из детского/родительского контура после завершения упражнения.
    func updateExerciseStatus(
        assignmentId: String,
        exerciseId: String,
        completedRepeats: Int
    ) async -> Result<Void, HomeworkRepositoryError>

    /// Кол-во невыполненных заданий по childId (для бейджа в ParentHome).
    func pendingCount(childId: String, familyId: String) async -> Int
}
