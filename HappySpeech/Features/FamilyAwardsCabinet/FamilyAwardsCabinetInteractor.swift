import Foundation
import OSLog

// MARK: - FamilyAwardsCabinetBusinessLogic

@MainActor
protocol FamilyAwardsCabinetBusinessLogic: AnyObject {
    func load(request: FamilyAwardsCabinetModels.Load.Request) async
    func selectAward(request: FamilyAwardsCabinetModels.SelectAward.Request) async
}

// MARK: - FamilyAwardsCabinetDataStore

@MainActor
protocol FamilyAwardsCabinetDataStore: AnyObject {
    var currentShelves: [FamilyAwardsCabinetModels.Load.ShelfBucket] { get set }
    var totalChildren: Int { get set }
}

// MARK: - FamilyAwardsCabinetInteractor (Clean Swift: Interactor)
//
// Block AE batch 2 v21 — кабинет семейных наград.
//
// Ответственность:
//   • Собрать список наград всех детей семьи через ``AwardsCatalogWorker``.
//   • Подсчитать total awards / total children.
//   • Передать выбранную награду в Presenter (для модалки деталей).
//
// COPPA: read-only on-device.

@MainActor
final class FamilyAwardsCabinetInteractor: FamilyAwardsCabinetBusinessLogic,
    FamilyAwardsCabinetDataStore {

    // MARK: - DataStore

    var currentShelves: [FamilyAwardsCabinetModels.Load.ShelfBucket] = []
    var totalChildren: Int = 0

    // MARK: - VIP

    var presenter: (any FamilyAwardsCabinetPresentationLogic)?

    // MARK: - Workers

    private let catalogWorker: any AwardsCatalogWorkerProtocol
    private let childRepository: any ChildRepository
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyAwardsCabinet.Interactor"
    )

    init(
        catalogWorker: any AwardsCatalogWorkerProtocol,
        childRepository: any ChildRepository,
        hapticService: any HapticService
    ) {
        self.catalogWorker = catalogWorker
        self.childRepository = childRepository
        self.hapticService = hapticService
    }

    // MARK: - Load

    func load(request: FamilyAwardsCabinetModels.Load.Request) async {
        Self.logger.info("load parent=\(request.parentId, privacy: .private)")

        let totalChildrenCount: Int
        do {
            let all = try await childRepository.fetchAll()
            totalChildrenCount = all.filter {
                $0.parentId.isEmpty || $0.parentId == request.parentId
            }.count
        } catch {
            Self.logger.error("load: fetch children failed: \(error.localizedDescription, privacy: .public)")
            totalChildrenCount = 0
        }
        totalChildren = totalChildrenCount

        let shelves = await catalogWorker.fetchUnlocked(parentId: request.parentId)
        currentShelves = shelves

        let total = shelves.reduce(0) { $0 + $1.awards.count }
        Self.logger.debug("loaded \(total) awards across \(shelves.count) shelves")

        let response = FamilyAwardsCabinetModels.Load.Response(
            shelves: shelves,
            totalAwards: total,
            totalChildren: totalChildrenCount
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - SelectAward

    func selectAward(request: FamilyAwardsCabinetModels.SelectAward.Request) async {
        guard let award = currentShelves
            .flatMap({ $0.awards })
            .first(where: { $0.id == request.awardId }) else {
            Self.logger.warning("selectAward: unknown id \(request.awardId, privacy: .public)")
            return
        }
        hapticService.selection()
        let response = FamilyAwardsCabinetModels.SelectAward.Response(award: award)
        await presenter?.presentSelectAward(response: response)
    }
}
