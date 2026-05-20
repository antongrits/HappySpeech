import Foundation
import OSLog

// MARK: - ComprehensionDetectiveBusinessLogic

@MainActor
protocol ComprehensionDetectiveBusinessLogic: AnyObject {
    func start(request: ComprehensionDetectiveModels.Start.Request) async
    func pick(request: ComprehensionDetectiveModels.Pick.Request) async
    func nextItem(request: ComprehensionDetectiveModels.NextItem.Request) async
}

// MARK: - ComprehensionDetectiveDataStore

@MainActor
protocol ComprehensionDetectiveDataStore: AnyObject {
    var childId: String { get set }
    var currentTier: GrammarTier { get set }
    var currentItem: DetectiveItem? { get set }
    var currentShuffle: [DetectivePicture] { get set }
    var playedIds: Set<String> { get set }
}

// MARK: - ComprehensionDetectiveInteractor (Clean Swift: Interactor)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив».

@MainActor
final class ComprehensionDetectiveInteractor:
    ComprehensionDetectiveBusinessLogic, ComprehensionDetectiveDataStore {

    var childId: String
    var currentTier: GrammarTier = .simple
    var currentItem: DetectiveItem?
    var currentShuffle: [DetectivePicture] = []
    var playedIds: Set<String> = []

    var presenter: (any ComprehensionDetectivePresentationLogic)?

    private let worker: any ComprehensionDetectiveWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.Interactor"
    )

    init(
        childId: String,
        worker: any ComprehensionDetectiveWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    func start(request: ComprehensionDetectiveModels.Start.Request) async {
        childId = request.childId
        let availableTiers = worker.availableTiers()
        let resolvedTier = request.preferredTier
            ?? availableTiers.first
            ?? .simple
        currentTier = resolvedTier

        guard let item = worker.nextItem(for: resolvedTier, exclude: playedIds) else {
            Self.logger.warning("No items for tier \(resolvedTier.rawValue, privacy: .public)")
            return
        }
        currentItem = item
        currentShuffle = worker.shuffle(item.pictures)
        playedIds.insert(item.id)

        let response = ComprehensionDetectiveModels.Start.Response(
            tier: resolvedTier,
            item: item,
            shuffledPictures: currentShuffle,
            availableTiers: availableTiers,
            totalItemsInTier: worker.count(for: resolvedTier),
            itemIndex: playedIds.intersection(
                Set(ComprehensionDetectiveCorpus.items(for: resolvedTier).map(\.id))
            ).count
        )
        await presenter?.presentStart(response: response)
        let instructionText = item.instruction
        Task { @MainActor [worker] in
            await worker.voiceInstruction(instructionText)
        }
    }

    func pick(request: ComprehensionDetectiveModels.Pick.Request) async {
        guard let item = currentItem else {
            Self.logger.warning("pick called without active item")
            return
        }
        let isCorrect = request.pictureId == item.correctPictureId
        if isCorrect {
            hapticService.notification(.success)
        } else {
            hapticService.notification(.error)
        }
        let response = ComprehensionDetectiveModels.Pick.Response(
            isCorrect: isCorrect,
            pickedPictureId: request.pictureId,
            correctPictureId: item.correctPictureId,
            instruction: item.instruction
        )
        await presenter?.presentPick(response: response)
    }

    func nextItem(request: ComprehensionDetectiveModels.NextItem.Request) async {
        let targetTier = request.nextTier ?? currentTier
        await start(request: .init(childId: childId, preferredTier: targetTier))
    }
}
