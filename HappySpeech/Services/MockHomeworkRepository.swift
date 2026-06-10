import Foundation
import OSLog

// MARK: - MockHomeworkRepository
//
// In-memory реализация `HomeworkRepository` для preview, snapshot и unit-тестов.
// Повторяет паттерн `MockChatRepository`:
//   • actor — внутреннее состояние сериализовано, нет гонок;
//   • real-time поток через `AsyncStream` + continuation на каждое изменение;
//   • offline-симуляция через `isOnline`;
//   • сидинг начальных данных через `seededAssignments`.

public actor MockHomeworkRepository: HomeworkRepository {

    // MARK: - Configurable seed

    /// Признак сети. `false` → publish уходит в outbox, но поток всё равно обновляется.
    public var isOnline: Bool

    // MARK: - State

    private var assignments: [String: HomeworkAssignment] = [:]
    private var continuations: [UUID: AsyncStream<[HomeworkAssignment]>.Continuation] = [:]

    // Pending publish outbox when offline.
    private var publishOutbox: [HomeworkAssignment] = []

    private var lastPublishedSpecialistId: String?
    private var lastPublishedFamilyId: String?

    private(set) var publishCallCount = 0
    private(set) var updateStatusCallCount = 0

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "HomeworkRepository.Mock"
    )

    // MARK: - Init

    public init(
        isOnline: Bool = true,
        seededAssignments: [HomeworkAssignment] = []
    ) {
        self.isOnline = isOnline
        for a in seededAssignments {
            self.assignments[a.id] = a
        }
    }

    // MARK: - HomeworkRepository

    public func publish(
        assignment: HomeworkAssignment,
        specialistId: String,
        familyId: String
    ) async -> Result<Void, HomeworkRepositoryError> {
        publishCallCount += 1
        lastPublishedSpecialistId = specialistId
        lastPublishedFamilyId = familyId

        if isOnline {
            assignments[assignment.id] = assignment
            broadcast(childId: assignment.childId, familyId: familyId)
            Self.logger.info("Mock publish: assignment \(assignment.id, privacy: .public) stored")
        } else {
            publishOutbox.append(assignment)
            Self.logger.info("Mock publish: assignment queued offline")
        }
        return .success(())
    }

    public nonisolated func assignmentsStream(
        childId: String,
        familyId: String
    ) -> AsyncStream<[HomeworkAssignment]> {
        AsyncStream { continuation in
            let token = UUID()
            Task {
                await self.registerContinuation(
                    continuation,
                    token: token,
                    childId: childId,
                    familyId: familyId
                )
            }
            continuation.onTermination = { _ in
                Task { await self.unregisterContinuation(token: token) }
            }
        }
    }

    public func fetchAssignments(
        childId: String,
        familyId: String
    ) async -> [HomeworkAssignment] {
        filteredAssignments(childId: childId, familyId: familyId)
    }

    public func updateExerciseStatus(
        assignmentId: String,
        exerciseId: String,
        completedRepeats: Int
    ) async -> Result<Void, HomeworkRepositoryError> {
        updateStatusCallCount += 1
        guard var assignment = assignments[assignmentId] else {
            return .failure(.assignmentNotFound)
        }
        for index in assignment.exercises.indices {
            guard assignment.exercises[index].id == exerciseId else { continue }
            assignment.exercises[index] = HomeworkExerciseItem(
                id: assignment.exercises[index].id,
                templateRaw: assignment.exercises[index].templateRaw,
                repeats: assignment.exercises[index].repeats,
                completedRepeats: completedRepeats
            )
            break
        }
        assignments[assignmentId] = assignment
        broadcastAssignment(assignment)
        return .success(())
    }

    public func pendingCount(childId: String, familyId: String) async -> Int {
        filteredAssignments(childId: childId, familyId: familyId)
            .filter { !$0.isComplete }
            .count
    }

    // MARK: - Test helpers

    /// Переводит mock в online и доставляет содержимое outbox.
    public func goOnlineAndFlush() {
        isOnline = true
        for a in publishOutbox {
            assignments[a.id] = a
            broadcastAssignment(a)
        }
        publishOutbox.removeAll()
        Self.logger.info("Mock outbox flushed (\(self.publishOutbox.count) items)")
    }

    /// Симулирует входящее задание от специалиста (для real-time тестов).
    public func injectAssignment(_ assignment: HomeworkAssignment, familyId: String) {
        assignments[assignment.id] = assignment
        broadcast(childId: assignment.childId, familyId: familyId)
    }

    // MARK: - Private

    private func registerContinuation(
        _ continuation: AsyncStream<[HomeworkAssignment]>.Continuation,
        token: UUID,
        childId: String,
        familyId: String
    ) {
        continuations[token] = continuation
        continuation.yield(filteredAssignments(childId: childId, familyId: familyId))
    }

    private func unregisterContinuation(token: UUID) {
        continuations[token] = nil
    }

    private func filteredAssignments(childId: String, familyId: String) -> [HomeworkAssignment] {
        assignments.values
            .filter { $0.childId == childId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func broadcast(childId: String, familyId: String) {
        let snapshot = filteredAssignments(childId: childId, familyId: familyId)
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func broadcastAssignment(_ assignment: HomeworkAssignment) {
        let snapshot = assignments.values
            .filter { $0.childId == assignment.childId }
            .sorted { $0.createdAt > $1.createdAt }
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }
}
