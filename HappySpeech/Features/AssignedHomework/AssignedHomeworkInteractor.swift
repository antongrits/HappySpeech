import Foundation
import OSLog

// MARK: - AssignedHomeworkBusinessLogic

@MainActor
protocol AssignedHomeworkBusinessLogic: AnyObject {
    func load(request: AssignedHomeworkModels.Load.Request) async
    func create(request: AssignedHomeworkModels.Create.Request) async
}

// MARK: - AssignedHomeworkDataStore

@MainActor
protocol AssignedHomeworkDataStore: AnyObject {
    var specialistId: String { get set }
}

// MARK: - AssignedHomeworkInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 4 «Домашнее задание от логопеда».
//
// Бизнес-логика конструктора заданий: загрузка детей и заданий, создание
// нового задания, перезагрузка списка после создания.

@MainActor
final class AssignedHomeworkInteractor: AssignedHomeworkBusinessLogic, AssignedHomeworkDataStore {

    // MARK: - DataStore

    var specialistId: String

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
        worker: any AssignedHomeworkWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.specialistId = specialistId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Load

    func load(request: AssignedHomeworkModels.Load.Request) async {
        specialistId = request.specialistId
        let response = await worker.load(specialistId: request.specialistId)
        Self.logger.debug(
            "Loaded \(response.children.count) children, \(response.assignments.count) assignments"
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - Create

    func create(request: AssignedHomeworkModels.Create.Request) async {
        let assignment = await worker.create(request: request)
        let response = AssignedHomeworkModels.Create.Response(
            didSucceed: assignment != nil,
            assignment: assignment
        )
        if assignment != nil {
            hapticService.notification(.success)
        } else {
            hapticService.notification(.error)
        }
        await presenter?.presentCreate(response: response)
        // Перезагрузка списка заданий после создания.
        await load(request: .init(specialistId: specialistId))
    }
}
