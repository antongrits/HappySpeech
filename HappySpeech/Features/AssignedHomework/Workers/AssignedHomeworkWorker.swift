import Foundation
import OSLog

// MARK: - AssignedHomeworkWorkerProtocol

@MainActor
protocol AssignedHomeworkWorkerProtocol: AnyObject {
    /// Загружает список детей и существующих заданий.
    func load(specialistId: String) async -> AssignedHomeworkModels.Load.Response
    /// Сохраняет новое задание.
    func create(request: AssignedHomeworkModels.Create.Request) async -> HomeworkAssignment?
    /// Возвращает все задания ребёнка (для детского / родительского контура).
    func assignments(forChild childId: String) -> [HomeworkAssignment]
}

// MARK: - AssignedHomeworkWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 4 «Домашнее задание от логопеда».
//
// Хранит задания локально (offline-first). Связь специалист↔ребёнок
// моделируется асинхронно: специалист создаёт задание, оно появляется у
// ребёнка при следующем открытии. Хранилище — JSON в UserDefaults
// (COPPA-safe, без сетевых трекеров; синхронизация с Firestore — задача
// существующего SyncService и здесь не дублируется).

@MainActor
final class AssignedHomeworkWorker: AssignedHomeworkWorkerProtocol {

    private let childRepository: any ChildRepository
    private let defaults: UserDefaults

    /// Ключ хранилища заданий.
    static let storageKey = "happyspeech.assignedHomework.v1"

    /// Шаблоны, доступные для назначения (методически безопасное подмножество
    /// 18 шаблонов — без AR-зависимых, чтобы задание выполнялось дома).
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
        defaults: UserDefaults = .standard
    ) {
        self.childRepository = childRepository
        self.defaults = defaults
    }

    // MARK: - Load

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
        let assignments = loadAll().sorted { $0.createdAt > $1.createdAt }
        return .init(
            children: children,
            assignments: assignments,
            availableTemplates: Self.assignableTemplates
        )
    }

    // MARK: - Create

    func create(
        request: AssignedHomeworkModels.Create.Request
    ) async -> HomeworkAssignment? {
        guard !request.childId.isEmpty,
              !request.templateRaws.isEmpty,
              request.repeatsPerExercise > 0 else {
            Self.logger.warning("Invalid assignment request")
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
        var all = loadAll()
        all.append(assignment)
        persist(all)
        Self.logger.debug("Created assignment \(assignment.id, privacy: .public)")
        return assignment
    }

    // MARK: - Query

    func assignments(forChild childId: String) -> [HomeworkAssignment] {
        loadAll()
            .filter { $0.childId == childId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Storage

    private func loadAll() -> [HomeworkAssignment] {
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

    private func persist(_ assignments: [HomeworkAssignment]) {
        do {
            let data = try JSONEncoder().encode(assignments)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            Self.logger.error(
                "Encode failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
