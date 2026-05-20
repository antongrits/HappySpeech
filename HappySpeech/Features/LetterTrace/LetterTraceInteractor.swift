import Foundation
import OSLog

// MARK: - LetterTraceBusinessLogic

@MainActor
protocol LetterTraceBusinessLogic: AnyObject {
    func load(request: LetterTraceModels.Load.Request) async
    func advance(request: LetterTraceModels.Advance.Request) async
    func score(request: LetterTraceModels.Score.Request) async
}

// MARK: - LetterTraceDataStore

@MainActor
protocol LetterTraceDataStore: AnyObject {
    var childId: String { get set }
    var items: [TraceItem] { get }
    var currentItemId: String? { get }
}

// MARK: - LetterTraceInteractor (Clean Swift: Interactor)
//
// v31 Волна C Ф.2 «Пиши пальчиком/пером».

@MainActor
final class LetterTraceInteractor: LetterTraceBusinessLogic, LetterTraceDataStore {

    var childId: String
    private(set) var items: [TraceItem] = []
    private(set) var currentItemId: String?

    var presenter: (any LetterTracePresentationLogic)?

    private let worker: any LetterTraceWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LetterTrace.Interactor"
    )

    init(
        childId: String,
        worker: any LetterTraceWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    func load(request: LetterTraceModels.Load.Request) async {
        childId = request.childId
        items = worker.loadItems()
        currentItemId = items.first?.id
        await presenter?.presentLoad(response: .init(items: items))
    }

    func advance(request: LetterTraceModels.Advance.Request) async {
        guard !items.isEmpty else { return }
        let currentIndex: Int
        if let currentId = request.currentItemId,
           let idx = items.firstIndex(where: { $0.id == currentId }) {
            currentIndex = idx
        } else {
            currentIndex = -1
        }
        let nextIndex = currentIndex + 1
        let next: TraceItem?
        let position: Int
        if nextIndex < items.count {
            next = items[nextIndex]
            position = nextIndex + 1
        } else {
            // Цикл — возвращаемся к первой букве.
            next = items.first
            position = 1
        }
        currentItemId = next?.id
        hapticService.impact(.soft)
        await presenter?.presentAdvance(response: .init(
            nextItem: next,
            position: position,
            totalCount: items.count
        ))
    }

    func score(request: LetterTraceModels.Score.Request) async {
        let result = worker.score(itemId: request.itemId, userStrokes: request.userStrokes)
        switch result.band {
        case .excellent: hapticService.notification(.success)
        case .good:      hapticService.impact(.light)
        case .tryAgain:  hapticService.notification(.warning)
        }
        await presenter?.presentScore(response: .init(
            itemId: request.itemId,
            score: result
        ))
    }
}
