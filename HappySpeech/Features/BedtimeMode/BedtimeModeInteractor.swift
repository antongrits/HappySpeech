import Foundation
import OSLog

// MARK: - BedtimeModeBusinessLogic

@MainActor
protocol BedtimeModeBusinessLogic: AnyObject {
    func start(request: BedtimeModeModels.Start.Request) async
    func advance(request: BedtimeModeModels.AdvanceStage.Request) async
    func pickNewStory(request: BedtimeModeModels.PickNewStory.Request) async
    func narrateStory() async
    func stopNarration()
}

// MARK: - BedtimeModeDataStore

@MainActor
protocol BedtimeModeDataStore: AnyObject {
    var childId: String { get set }
    var currentStory: BedtimeStory? { get set }
    var currentStage: BedtimeStage { get set }
}

// MARK: - BedtimeModeInteractor (Clean Swift: Interactor)
//
// v31 Волна B, Функция Ф.3 «Bedtime mode».

@MainActor
final class BedtimeModeInteractor: BedtimeModeBusinessLogic, BedtimeModeDataStore {

    var childId: String
    var currentStory: BedtimeStory?
    var currentStage: BedtimeStage = .intro

    var presenter: (any BedtimeModePresentationLogic)?

    private let worker: any BedtimeModeWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BedtimeMode.Interactor"
    )

    init(
        childId: String,
        worker: any BedtimeModeWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    func start(request: BedtimeModeModels.Start.Request) async {
        childId = request.childId
        currentStage = .intro
        guard let story = worker.pickStory(excluding: nil) else {
            Self.logger.warning("Bedtime corpus empty")
            return
        }
        currentStory = story
        let response = BedtimeModeModels.Start.Response(
            story: story,
            breathing: worker.breathingCycle(),
            storiesCountInLibrary: worker.libraryCount
        )
        await presenter?.presentStart(response: response)
    }

    func advance(request: BedtimeModeModels.AdvanceStage.Request) async {
        let next: BedtimeStage
        switch request.currentStage {
        case .intro:      next = .breathing
        case .breathing:  next = .story
        case .story:      next = .farewell
        case .farewell:   next = .farewell
        }
        currentStage = next
        // Маленькая тёплая «точка касания» — лёгкий haptic при переходе.
        hapticService.impact(.soft)
        await presenter?.presentAdvance(stage: next)
    }

    func pickNewStory(request: BedtimeModeModels.PickNewStory.Request) async {
        let excludeId = request.excludeId ?? currentStory?.id
        guard let story = worker.pickStory(excluding: excludeId) else { return }
        currentStory = story
        let response = BedtimeModeModels.Start.Response(
            story: story,
            breathing: worker.breathingCycle(),
            storiesCountInLibrary: worker.libraryCount
        )
        await presenter?.presentNewStory(response: response)
    }

    func narrateStory() async {
        guard let story = currentStory else { return }
        await worker.narrate(story.text)
    }

    func stopNarration() {
        worker.stopNarration()
    }
}
