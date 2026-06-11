import Foundation
import OSLog

// MARK: - AssignedHomeworkWorkerProtocol

@MainActor
protocol AssignedHomeworkWorkerProtocol: AnyObject {
    /// Загружает список детей и существующих заданий (для экрана специалиста).
    func load(specialistId: String) async -> AssignedHomeworkModels.Load.Response

    /// Сохраняет новое задание локально и публикует в Firestore.
    func create(request: AssignedHomeworkModels.Create.Request) async -> HomeworkAssignment?

    /// Возвращает все задания ребёнка из локального хранилища (offline-first).
    func assignments(forChild childId: String) -> [HomeworkAssignment]

    /// Загружает задания ребёнка из Firestore (для родительского/детского контура).
    func fetchAssignments(childId: String, familyId: String) async -> [HomeworkAssignment]

    /// Обновляет выполнение упражнения локально и в Firestore.
    func updateExerciseStatus(
        request: AssignedHomeworkModels.UpdateStatus.Request
    ) async -> AssignedHomeworkModels.UpdateStatus.Response

    /// Публикует задание в Firestore (вызывается Interactor'ом после create()).
    /// Отделено от create() чтобы Interactor мог передать specialistId/familyId,
    /// которых Worker не хранит.
    func publishToCloud(
        assignment: HomeworkAssignment,
        specialistId: String,
        familyId: String
    ) async

    /// Real-time поток заданий для ребёнка (родительский/детский контуры).
    func assignmentsStream(
        childId: String,
        familyId: String
    ) -> AsyncStream<[HomeworkAssignment]>
}

// MARK: - AssignedHomeworkWorker (Clean Swift: Worker)
//
// Offline-first: задания сначала сохраняются в UserDefaults (локальный кэш),
// затем публикуются в Firestore через `HomeworkRepository`. При отсутствии сети
// Firestore SDK ставит запись в offline-очередь и доставляет при восстановлении
// соединения (нативный механизм — без дополнительного SyncService).
//
// Связь специалист ↔ семья:
//   • Специалист: create() → UserDefaults + HomeworkRepository.publish()
//   • Родитель/ребёнок: fetchAssignments() / assignmentsStream() ← Firestore
//   • Обновление статуса: updateExerciseStatus() → UserDefaults + Firestore
//
// Уведомление о дедлайне: при создании задания планируется одноразовое
// локальное уведомление за 1 день до dueDate через `NotificationService`.

@MainActor
final class AssignedHomeworkWorker: AssignedHomeworkWorkerProtocol {

    private let childRepository: any ChildRepository
    private let homeworkRepository: any HomeworkRepository
    private let notificationService: (any NotificationService)?
    private let defaults: UserDefaults

    /// Ключ хранилища заданий в UserDefaults.
    static let storageKey = "happyspeech.assignedHomework.v1"

    /// Шаблоны, доступные для назначения (методически безопасное подмножество —
    /// без AR-зависимых, чтобы задание выполнялось дома).
    static let assignableTemplates: [TemplateType] = [
        .listenAndChoose, .repeatAfterModel, .dragAndMatch, .storyCompletion,
        .sorting, .memory, .bingo, .soundHunter, .articulationImitation,
        .visualAcoustic, .breathing, .rhythm, .minimalPairs
    ]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AssignedHomework.Worker"
    )

    init(
        childRepository: any ChildRepository,
        homeworkRepository: any HomeworkRepository,
        notificationService: (any NotificationService)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.childRepository = childRepository
        self.homeworkRepository = homeworkRepository
        self.notificationService = notificationService
        self.defaults = defaults
    }

    // MARK: - Load (specialist screen)

    func load(specialistId: String) async -> AssignedHomeworkModels.Load.Response {
        var children: [AssignedHomeworkModels.Load.ChildOption] = []
        do {
            children = try await childRepository.fetchAll().map {
                .init(id: $0.id, name: $0.name)
            }
        } catch {
            Self.logger.error(
                "Failed to load children: \(error.localizedDescription, privacy: .public)"
            )
        }
        let stored = loadAllLocal().sorted { $0.createdAt > $1.createdAt }
        return .init(
            children: children,
            assignments: stored,
            availableTemplates: Self.assignableTemplates
        )
    }

    // MARK: - Create (specialist assigns homework)

    func create(
        request: AssignedHomeworkModels.Create.Request
    ) async -> HomeworkAssignment? {
        guard !request.childId.isEmpty,
              !request.templateRaws.isEmpty,
              request.repeatsPerExercise > 0 else {
            Self.logger.warning("Invalid assignment request — childId or templates empty")
            return nil
        }
        let exercises = request.templateRaws.map { raw in
            HomeworkExerciseItem(templateRaw: raw, repeats: request.repeatsPerExercise)
        }
        let due = Calendar.current.date(
            byAdding: .day,
            value: max(1, request.dueInDays),
            to: Date()
        ) ?? Date()
        let assignment = HomeworkAssignment(
            childId: request.childId,
            dueDate: due,
            comment: request.comment,
            exercises: exercises
        )

        // 1. Persist locally (offline-first source of truth).
        var all = loadAllLocal()
        all.append(assignment)
        persistLocal(all)
        Self.logger.debug("Created assignment locally: \(assignment.id, privacy: .public)")

        // 2. Publish to Firestore: Interactor calls publishToCloud() after create()
        //    because it holds specialistId/familyId (not the Worker). The Worker
        //    exposes publishToCloud() via the protocol for that purpose.

        // 3. Schedule a deadline notification (1 day before dueDate).
        await scheduleDeadlineNotification(for: assignment)

        return assignment
    }

    /// Publishes a locally-created assignment to Firestore.
    /// Called by `AssignedHomeworkInteractor` which holds specialistId + familyId.
    func publishToCloud(
        assignment: HomeworkAssignment,
        specialistId: String,
        familyId: String
    ) async {
        let result = await homeworkRepository.publish(
            assignment: assignment,
            specialistId: specialistId,
            familyId: familyId
        )
        switch result {
        case .success:
            Self.logger.info(
                "Homework \(assignment.id, privacy: .public) published to Firestore"
            )
        case .failure(let error):
            Self.logger.error(
                "Homework publish failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Query (local offline-first)

    func assignments(forChild childId: String) -> [HomeworkAssignment] {
        loadAllLocal()
            .filter { $0.childId == childId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Fetch from Firestore (parent / child context)

    func fetchAssignments(childId: String, familyId: String) async -> [HomeworkAssignment] {
        let remote = await homeworkRepository.fetchAssignments(
            childId: childId,
            familyId: familyId
        )
        // Merge remote into local cache (remote is source of truth when online).
        if !remote.isEmpty {
            mergeRemoteIntoLocal(remote)
        }
        return remote.isEmpty ? assignments(forChild: childId) : remote
    }

    // MARK: - Update exercise status

    func updateExerciseStatus(
        request: AssignedHomeworkModels.UpdateStatus.Request
    ) async -> AssignedHomeworkModels.UpdateStatus.Response {
        // 1. Update locally.
        var all = loadAllLocal()
        var updated: HomeworkAssignment?
        for idx in all.indices {
            guard all[idx].id == request.assignmentId else { continue }
            for exIdx in all[idx].exercises.indices {
                guard all[idx].exercises[exIdx].id == request.exerciseId else { continue }
                all[idx].exercises[exIdx] = HomeworkExerciseItem(
                    id: all[idx].exercises[exIdx].id,
                    templateRaw: all[idx].exercises[exIdx].templateRaw,
                    repeats: all[idx].exercises[exIdx].repeats,
                    completedRepeats: request.completedRepeats
                )
                break
            }
            updated = all[idx]
            break
        }
        persistLocal(all)

        // 2. Sync to Firestore.
        let cloudResult = await homeworkRepository.updateExerciseStatus(
            assignmentId: request.assignmentId,
            exerciseId: request.exerciseId,
            completedRepeats: request.completedRepeats
        )
        let cloudSucceeded: Bool
        switch cloudResult {
        case .success:
            cloudSucceeded = true
        case .failure(let error):
            cloudSucceeded = false
            Self.logger.error(
                "updateExerciseStatus cloud sync failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        // Успех, если статус удалось обновить хотя бы в одном хранилище:
        // локальный кэш ИЛИ облако. Задание, пришедшее по real-time потоку и
        // ещё не осевшее в локальном кэше, обновляется через облако — это
        // валидный сценарий детского/родительского контура.
        return .init(
            didSucceed: updated != nil || cloudSucceeded,
            updatedAssignment: updated
        )
    }

    // MARK: - Real-time stream

    func assignmentsStream(
        childId: String,
        familyId: String
    ) -> AsyncStream<[HomeworkAssignment]> {
        homeworkRepository.assignmentsStream(childId: childId, familyId: familyId)
    }

    // MARK: - Notification

    private func scheduleDeadlineNotification(for assignment: HomeworkAssignment) async {
        guard let notificationService else { return }
        // Fire 1 day before due date.
        let notifDate = assignment.dueDate.addingTimeInterval(-86_400)
        guard notifDate > Date() else { return }
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: notifDate
        )
        let identifier = "hs.homework.deadline.\(assignment.id)"
        do {
            try await notificationService.scheduleCalendarReminder(
                identifier: identifier,
                title: String(localized: "homework.notification.deadline.title"),
                body: String(localized: "homework.notification.deadline.body"),
                at: components
            )
            Self.logger.info(
                "Deadline notification scheduled for assignment \(assignment.id, privacy: .public)"
            )
        } catch {
            Self.logger.error(
                "Deadline notification scheduling failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Local UserDefaults storage

    private func loadAllLocal() -> [HomeworkAssignment] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([HomeworkAssignment].self, from: data)
        } catch {
            Self.logger.error(
                "Decode failed: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    private func persistLocal(_ assignments: [HomeworkAssignment]) {
        do {
            let data = try JSONEncoder().encode(assignments)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            Self.logger.error(
                "Encode failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Merges remote assignments into local cache, overwriting entries with the
    /// same id (remote is authoritative when network is available).
    private func mergeRemoteIntoLocal(_ remote: [HomeworkAssignment]) {
        var local = loadAllLocal()
        for remote in remote {
            if let idx = local.firstIndex(where: { $0.id == remote.id }) {
                local[idx] = remote
            } else {
                local.append(remote)
            }
        }
        persistLocal(local)
    }
}
