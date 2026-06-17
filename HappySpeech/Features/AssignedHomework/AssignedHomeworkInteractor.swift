import Foundation
import OSLog

// MARK: - AssignedHomeworkBusinessLogic

@MainActor
protocol AssignedHomeworkBusinessLogic: AnyObject {
    /// Загружает экран специалиста (дети + локальные задания).
    func load(request: AssignedHomeworkModels.Load.Request) async
    /// Создаёт задание (локально + публикует в Firestore).
    func create(request: AssignedHomeworkModels.Create.Request) async
    /// Обновляет выполнение упражнения (локально + Firestore).
    func updateExerciseStatus(request: AssignedHomeworkModels.UpdateStatus.Request) async
    /// Удаляет задание (локально + Firestore + отмена дедлайн-уведомления).
    func delete(request: AssignedHomeworkModels.Delete.Request) async
    /// Загружает задания для родительского/детского контура из Firestore.
    func loadForFamily(request: AssignedHomeworkModels.FamilyLoad.Request) async
}

// MARK: - AssignedHomeworkDataStore

@MainActor
protocol AssignedHomeworkDataStore: AnyObject {
    var specialistId: String { get set }
    /// familyId для маршрутизации к правильному треду в Firestore.
    /// Устанавливается из родительского контура перед вызовом `loadForFamily`.
    var familyId: String { get set }
}

// MARK: - AssignedHomeworkInteractor (Clean Swift: Interactor)
//
// Бизнес-логика конструктора заданий.
//
// Firestore-синк:
//   1. Специалист создаёт задание → `create()` → Worker.create() (local) +
//      Worker.publishToCloud() (Firestore, offline-queue при нет сети).
//   2. Родитель/ребёнок читает → `loadForFamily()` → Worker.fetchAssignments()
//      (Firestore → merge local). Или подписывается на `assignmentsStream`.
//   3. Ребёнок отмечает выполнение → `updateExerciseStatus()` → Worker (local
//      + Firestore transaction). Статус пишется обратно в облако.

@MainActor
final class AssignedHomeworkInteractor: AssignedHomeworkBusinessLogic, AssignedHomeworkDataStore {

    // MARK: - DataStore

    var specialistId: String
    var familyId: String

    // MARK: - VIP

    var presenter: (any AssignedHomeworkPresentationLogic)?

    // MARK: - Deps

    private let worker: any AssignedHomeworkWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AssignedHomework.Interactor"
    )

    // MARK: - Init

    init(
        specialistId: String,
        familyId: String = "",
        worker: any AssignedHomeworkWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.specialistId = specialistId
        self.familyId = familyId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Load (specialist screen)

    func load(request: AssignedHomeworkModels.Load.Request) async {
        specialistId = request.specialistId
        let response = await worker.load(specialistId: request.specialistId)
        Self.logger.debug(
            "Loaded \(response.children.count) children, \(response.assignments.count) assignments"
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - Create (specialist assigns → local + Firestore)

    func create(request: AssignedHomeworkModels.Create.Request) async {
        let assignment = await worker.create(request: request)
        let response = AssignedHomeworkModels.Create.Response(
            didSucceed: assignment != nil,
            assignment: assignment
        )
        if let assignment {
            hapticService.notification(.success)
            // Publish to Firestore so the family can read it.
            // familyId is '' when not explicitly set (specialist flow);
            // the document remains queryable by childId alone on the family side.
            await worker.publishToCloud(
                assignment: assignment,
                specialistId: specialistId,
                familyId: familyId
            )
        } else {
            hapticService.notification(.error)
        }
        await presenter?.presentCreate(response: response)
        // Reload the specialist's list after creation.
        await load(request: .init(specialistId: specialistId))
    }

    // MARK: - Update exercise status (child / parent context)

    func updateExerciseStatus(request: AssignedHomeworkModels.UpdateStatus.Request) async {
        let response = await worker.updateExerciseStatus(request: request)
        if response.didSucceed {
            hapticService.notification(.success)
        }
        await presenter?.presentUpdateStatus(response: response)
    }

    // MARK: - Delete (specialist removes assignment)

    func delete(request: AssignedHomeworkModels.Delete.Request) async {
        let didSucceed = await worker.delete(assignmentId: request.assignmentId)
        if didSucceed {
            hapticService.notification(.success)
        } else {
            hapticService.notification(.error)
        }
        let response = AssignedHomeworkModels.Delete.Response(
            didSucceed: didSucceed,
            deletedAssignmentId: request.assignmentId
        )
        await presenter?.presentDelete(response: response)
        // Reload the specialist's list after deletion.
        await load(request: .init(specialistId: specialistId))
    }

    // MARK: - Load for family (parent / child context)

    func loadForFamily(request: AssignedHomeworkModels.FamilyLoad.Request) async {
        familyId = request.familyId
        let remote = await worker.fetchAssignments(
            childId: request.childId,
            familyId: request.familyId
        )
        let response = AssignedHomeworkModels.FamilyLoad.Response(assignments: remote)
        Self.logger.debug(
            "FamilyLoad: \(remote.count) assignments for child \(request.childId, privacy: .private)"
        )
        await presenter?.presentFamilyLoad(response: response)
    }
}
