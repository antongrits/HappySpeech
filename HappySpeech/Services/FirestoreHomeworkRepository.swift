import FirebaseFirestore
import Foundation
import OSLog

// MARK: - FirestoreHomeworkRepository
//
// Продакшн-реализация `HomeworkRepository` поверх Cloud Firestore.
//
// Схема Firestore (правила — см. firestore.rules; нужно добавить блок
// /homework/{assignmentId} перед ручным деплоем — см. отчёт):
//
//   homework/{assignmentId}
//     { id, specialistId, childId, familyId, createdAt, dueDate,
//       comment, exercises: [{ id, templateRaw, repeats, completedRepeats }],
//       status: "pending" | "inProgress" | "complete" }
//
// Offline-first: Firestore SDK включает дисковую персистенцию (см.
// `FirebaseBootstrap`). Записи встают в нативную offline-очередь SDK
// автоматически и доставляются при восстановлении сети.
// `addSnapshotListener` сначала отдаёт кэш (`metadata.isFromCache`), затем
// серверные данные — задания видны и без сети.
//
// COPPA: childId — внутренний идентификатор (не имя, не PII). familyId —
// parent uid. Доступ в Firestore rules ограничен (specialistId или familyId).
//
// `@unchecked Sendable` оправдан: `Firestore` — потокобезопасный синглтон;
// собственного мутируемого состояния класс не держит.

public final class FirestoreHomeworkRepository: HomeworkRepository, @unchecked Sendable {

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "HomeworkRepository.Firestore"
    )
    private let firestore: Firestore

    private enum Path {
        static let homework = "homework"
    }

    // MARK: - Field keys (Firestore document schema)

    private enum Field {
        static let id = "id"
        static let specialistId = "specialistId"
        static let childId = "childId"
        static let familyId = "familyId"
        static let createdAt = "createdAt"
        static let dueDate = "dueDate"
        static let comment = "comment"
        static let exercises = "exercises"
        static let status = "status"
        // Exercise sub-fields
        static let exerciseId = "id"
        static let templateRaw = "templateRaw"
        static let repeats = "repeats"
        static let completedRepeats = "completedRepeats"
    }

    // MARK: - Init

    public init() {
        self.firestore = Firestore.firestore()
    }

    // MARK: - Publish (specialist creates assignment)

    public func publish(
        assignment: HomeworkAssignment,
        specialistId: String,
        familyId: String
    ) async -> Result<Void, HomeworkRepositoryError> {
        guard !specialistId.isEmpty, !familyId.isEmpty else {
            return .failure(.notAuthenticated)
        }
        let payload = encode(assignment: assignment, specialistId: specialistId, familyId: familyId)
        let docRef = firestore.collection(Path.homework).document(assignment.id)
        do {
            try await docRef.setData(payload)
            logger.info("Published homework \(assignment.id, privacy: .public)")
            return .success(())
        } catch {
            logger.error("publish failed: \(error.localizedDescription, privacy: .public)")
            // Firestore SDK queues the write offline — still report as success so
            // the specialist sees confirmation immediately (same pattern as chat send).
            if (error as NSError).domain == FirestoreErrorDomain,
               (error as NSError).code == FirestoreErrorCode.unavailable.rawValue {
                return .success(())
            }
            return .failure(.backendUnavailable(error.localizedDescription))
        }
    }

    // MARK: - Real-time stream (parent / child reads)

    public func assignmentsStream(
        childId: String,
        familyId: String
    ) -> AsyncStream<[HomeworkAssignment]> {
        let query = firestore.collection(Path.homework)
            .whereField(Field.childId, isEqualTo: childId)
            .whereField(Field.familyId, isEqualTo: familyId)
            .order(by: Field.createdAt, descending: true)

        return AsyncStream { continuation in
            let listener = query.addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    self?.logger.error(
                        "assignmentsStream listener error: \(error.localizedDescription, privacy: .public)"
                    )
                    return
                }
                guard let snapshot else { return }
                let assignments = snapshot.documents.compactMap {
                    Self.decodeAssignment(from: $0.data())
                }
                continuation.yield(assignments)
            }
            let holder = ListenerHolder(listener)
            continuation.onTermination = { _ in
                holder.remove()
            }
        }
    }

    // MARK: - One-shot fetch

    public func fetchAssignments(
        childId: String,
        familyId: String
    ) async -> [HomeworkAssignment] {
        let query = firestore.collection(Path.homework)
            .whereField(Field.childId, isEqualTo: childId)
            .whereField(Field.familyId, isEqualTo: familyId)
            .order(by: Field.createdAt, descending: true)
        do {
            let snapshot = try await query.getDocuments()
            return snapshot.documents.compactMap { Self.decodeAssignment(from: $0.data()) }
        } catch {
            logger.error("fetchAssignments failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Update exercise status

    public func updateExerciseStatus(
        assignmentId: String,
        exerciseId: String,
        completedRepeats: Int
    ) async -> Result<Void, HomeworkRepositoryError> {
        guard !assignmentId.isEmpty, !exerciseId.isEmpty else {
            return .failure(.assignmentNotFound)
        }
        // Firestore arrays-of-objects must be updated by re-reading + replacing,
        // or by using a transaction. We use a transaction to be concurrent-safe.
        let docRef = firestore.collection(Path.homework).document(assignmentId)
        do {
            try await firestore.runTransaction { transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(docRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                guard snapshot.exists, var data = snapshot.data() else {
                    errorPointer?.pointee = NSError(
                        domain: "ru.happyspeech.homework",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Assignment not found"]
                    )
                    return nil
                }
                guard var exercises = data[Field.exercises] as? [[String: Any]] else {
                    return nil
                }
                // Patch the matching exercise entry.
                for index in exercises.indices {
                    guard exercises[index][Field.exerciseId] as? String == exerciseId else { continue }
                    exercises[index][Field.completedRepeats] = completedRepeats
                    break
                }
                data[Field.exercises] = exercises
                // Recompute status field.
                let isComplete = exercises.allSatisfy { ex in
                    let done = ex[Field.completedRepeats] as? Int ?? 0
                    let total = ex[Field.repeats] as? Int ?? 1
                    return done >= total
                }
                let hasProgress = exercises.contains { ex in
                    (ex[Field.completedRepeats] as? Int ?? 0) > 0
                }
                data[Field.status] = isComplete ? "complete" : (hasProgress ? "inProgress" : "pending")
                transaction.setData(data, forDocument: docRef)
                return nil
            }
            logger.info(
                "Updated exercise \(exerciseId, privacy: .public) in assignment \(assignmentId, privacy: .public)"
            )
            return .success(())
        } catch {
            logger.error("updateExerciseStatus failed: \(error.localizedDescription, privacy: .public)")
            if (error as NSError).code == 404 {
                return .failure(.assignmentNotFound)
            }
            return .failure(.backendUnavailable(error.localizedDescription))
        }
    }

    // MARK: - Pending count (badge)

    public func pendingCount(childId: String, familyId: String) async -> Int {
        let query = firestore.collection(Path.homework)
            .whereField(Field.childId, isEqualTo: childId)
            .whereField(Field.familyId, isEqualTo: familyId)
            .whereField(Field.status, isEqualTo: "pending")
        do {
            let snapshot = try await query.getDocuments()
            return snapshot.documents.count
        } catch {
            logger.error("pendingCount query failed: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    // MARK: - Encoding

    private func encode(
        assignment: HomeworkAssignment,
        specialistId: String,
        familyId: String
    ) -> [String: Any] {
        let exercises: [[String: Any]] = assignment.exercises.map { ex in
            [
                Field.exerciseId: ex.id,
                Field.templateRaw: ex.templateRaw,
                Field.repeats: ex.repeats,
                Field.completedRepeats: ex.completedRepeats
            ]
        }
        return [
            Field.id: assignment.id,
            Field.specialistId: specialistId,
            Field.childId: assignment.childId,
            Field.familyId: familyId,
            Field.createdAt: Timestamp(date: assignment.createdAt),
            Field.dueDate: Timestamp(date: assignment.dueDate),
            Field.comment: assignment.comment,
            Field.exercises: exercises,
            Field.status: assignment.isComplete ? "complete" : "pending"
        ]
    }

    // MARK: - Decoding

    static func decodeAssignment(from data: [String: Any]) -> HomeworkAssignment? {
        guard let id = data[Field.id] as? String,
              let childId = data[Field.childId] as? String,
              let createdAtTS = data[Field.createdAt] as? Timestamp,
              let dueDateTS = data[Field.dueDate] as? Timestamp else {
            return nil
        }
        let comment = (data[Field.comment] as? String) ?? ""
        let exerciseData = (data[Field.exercises] as? [[String: Any]]) ?? []
        let exercises = exerciseData.compactMap { ex -> HomeworkExerciseItem? in
            guard let eid = ex[Field.exerciseId] as? String,
                  let raw = ex[Field.templateRaw] as? String else { return nil }
            let repeats = (ex[Field.repeats] as? Int) ?? 1
            let completed = (ex[Field.completedRepeats] as? Int) ?? 0
            return HomeworkExerciseItem(
                id: eid,
                templateRaw: raw,
                repeats: repeats,
                completedRepeats: completed
            )
        }
        return HomeworkAssignment(
            id: id,
            childId: childId,
            createdAt: createdAtTS.dateValue(),
            dueDate: dueDateTS.dateValue(),
            comment: comment,
            exercises: exercises
        )
    }
}

// MARK: - ListenerHolder

/// Sendable-обёртка над `ListenerRegistration` (non-Sendable) для захвата
/// в `@Sendable` onTermination-замыкании `AsyncStream`. Повторяет паттерн
/// `FirestoreChatRepository`.
private final class ListenerHolder: @unchecked Sendable {
    private let listener: any ListenerRegistration
    init(_ listener: any ListenerRegistration) { self.listener = listener }
    func remove() { listener.remove() }
}
