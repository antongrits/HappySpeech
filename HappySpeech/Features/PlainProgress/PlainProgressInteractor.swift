import Foundation
import OSLog

// MARK: - PlainProgressBusinessLogic

@MainActor
protocol PlainProgressBusinessLogic: AnyObject {
    func load(request: PlainProgressModels.Load.Request) async
    func share(request: PlainProgressModels.Share.Request) async
}

// MARK: - PlainProgressDataStore

@MainActor
protocol PlainProgressDataStore: AnyObject {
    var childId: String { get set }
    var lastResponse: PlainProgressModels.Load.Response? { get set }
}

// MARK: - PlainProgressInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 9 «Понятный прогресс».
//
// Бизнес-логика родительской аналитики: запрашивает агрегированные метрики
// у воркера, передаёт их пресентеру для сборки человекочитаемого нарратива.
// Действие «Поделиться» формирует текстовую сводку из той же модели.

@MainActor
final class PlainProgressInteractor: PlainProgressBusinessLogic, PlainProgressDataStore {

    // MARK: - DataStore

    var childId: String
    var lastResponse: PlainProgressModels.Load.Response?

    // MARK: - VIP

    var presenter: (any PlainProgressPresentationLogic)?

    // MARK: - Deps

    private let worker: any PlainProgressWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PlainProgress.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any PlainProgressWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Load

    func load(request: PlainProgressModels.Load.Request) async {
        childId = request.childId
        do {
            let response = try await worker.loadProgress(childId: request.childId)
            lastResponse = response
            await presenter?.presentLoad(response: response)
        } catch {
            Self.logger.error("Plain progress load failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentLoadFailure(error: error)
        }
    }

    // MARK: - Share

    func share(request: PlainProgressModels.Share.Request) async {
        _ = request
        guard let response = lastResponse else {
            Self.logger.warning("Share requested before data loaded")
            return
        }
        hapticService.selection()
        await presenter?.presentShare(response: response)
    }
}
