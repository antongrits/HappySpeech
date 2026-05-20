@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubDetectiveWorker: ComprehensionDetectiveWorkerProtocol {

    var itemsByTier: [GrammarTier: [DetectiveItem]]
    private(set) var voiceCallCount = 0

    init(itemsByTier: [GrammarTier: [DetectiveItem]]) {
        self.itemsByTier = itemsByTier
    }

    func nextItem(for tier: GrammarTier, exclude playedIds: Set<String>) -> DetectiveItem? {
        let pool = itemsByTier[tier] ?? []
        if let remaining = pool.first(where: { !playedIds.contains($0.id) }) {
            return remaining
        }
        return pool.first
    }

    func availableTiers() -> [GrammarTier] {
        itemsByTier.keys.sorted(by: { $0.rawValue < $1.rawValue })
    }

    func count(for tier: GrammarTier) -> Int {
        itemsByTier[tier]?.count ?? 0
    }

    func shuffle(_ pictures: [DetectivePicture]) -> [DetectivePicture] {
        // Stub: возвращаем без перетасовки (определённый порядок для тестов).
        pictures
    }

    func voiceInstruction(_ text: String) async {
        voiceCallCount += 1
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyDetectivePresenter:
    ComprehensionDetectivePresentationLogic, @unchecked Sendable {
    var startCount = 0
    var pickCount = 0
    var lastPick: ComprehensionDetectiveModels.Pick.Response?

    func presentStart(response: ComprehensionDetectiveModels.Start.Response) async {
        startCount += 1
    }
    func presentPick(response: ComprehensionDetectiveModels.Pick.Response) async {
        pickCount += 1
        lastPick = response
    }
}

// MARK: - Fixtures

private func makeItem(
    id: String,
    correctSymbol: String = "soccerball",
    tier: GrammarTier = .simple
) -> DetectiveItem {
    let pictures = [
        DetectivePicture(id: "\(id)-\(correctSymbol)", symbolName: correctSymbol, label: "правильный"),
        DetectivePicture(id: "\(id)-car.fill", symbolName: "car.fill", label: "машина"),
        DetectivePicture(id: "\(id)-leaf.fill", symbolName: "leaf.fill", label: "лист"),
        DetectivePicture(id: "\(id)-house.fill", symbolName: "house.fill", label: "дом")
    ]
    return DetectiveItem(
        id: id,
        tier: tier,
        instruction: "Покажи мяч",
        pictures: pictures,
        correctPictureId: pictures[0].id
    )
}

// MARK: - Interactor Tests

@MainActor
final class ComprehensionDetectiveInteractorTests: XCTestCase {

    private func makeSUT(
        items: [GrammarTier: [DetectiveItem]] = [.simple: [makeItem(id: "i1")]]
    ) -> (ComprehensionDetectiveInteractor, SpyDetectivePresenter, StubDetectiveWorker, SpyHapticService) {
        let worker = StubDetectiveWorker(itemsByTier: items)
        let haptic = SpyHapticService()
        let interactor = ComprehensionDetectiveInteractor(
            childId: "child-1",
            worker: worker,
            hapticService: haptic
        )
        let spy = SpyDetectivePresenter()
        interactor.presenter = spy
        return (interactor, spy, worker, haptic)
    }

    func test_start_loadsItem() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .simple))
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.currentItem?.id, "i1")
    }

    func test_start_recordsPlayedId() async {
        let (sut, _, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .simple))
        XCTAssertTrue(sut.playedIds.contains("i1"))
    }

    func test_pick_correct_returnsTrue_andHaptic() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .simple))
        guard let correctId = sut.currentItem?.correctPictureId else {
            XCTFail("no current item"); return
        }
        await sut.pick(request: .init(pictureId: correctId))
        XCTAssertEqual(spy.lastPick?.isCorrect, true)
        XCTAssertGreaterThan(haptic.notificationCount, 0)
    }

    func test_pick_wrong_returnsFalse() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .simple))
        await sut.pick(request: .init(pictureId: "bogus-id"))
        XCTAssertEqual(spy.lastPick?.isCorrect, false)
    }

    func test_pick_includesInstructionInResponse() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .simple))
        await sut.pick(request: .init(pictureId: "x"))
        XCTAssertEqual(spy.lastPick?.instruction, "Покажи мяч")
    }

    func test_pick_beforeStart_isIgnored() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.pick(request: .init(pictureId: "any"))
        XCTAssertEqual(spy.pickCount, 0)
    }

    func test_nextItem_advances() async {
        let (sut, spy, _, _) = makeSUT(items: [
            .simple: [
                makeItem(id: "i1"),
                makeItem(id: "i2")
            ]
        ])
        await sut.start(request: .init(childId: "child-1", preferredTier: .simple))
        await sut.nextItem(request: .init(nextTier: nil))
        XCTAssertEqual(spy.startCount, 2)
        XCTAssertEqual(sut.playedIds.count, 2)
    }

    func test_nextItem_switchesTier() async {
        let (sut, _, _, _) = makeSUT(items: [
            .simple: [makeItem(id: "i1", tier: .simple)],
            .doubleInstruction: [makeItem(id: "j1", tier: .doubleInstruction)]
        ])
        await sut.start(request: .init(childId: "child-1", preferredTier: .simple))
        await sut.nextItem(request: .init(nextTier: .doubleInstruction))
        XCTAssertEqual(sut.currentTier, .doubleInstruction)
        XCTAssertEqual(sut.currentItem?.id, "j1")
    }

    func test_start_emptyCorpus_noPresenterCall() async {
        let (sut, spy, _, _) = makeSUT(items: [:])
        await sut.start(request: .init(childId: "child-1", preferredTier: nil))
        XCTAssertEqual(spy.startCount, 0)
    }

    func test_pick_correct_haptic_distinct_from_wrong() async {
        let (sut, _, _, haptic1) = makeSUT()
        await sut.start(request: .init(childId: "child-1", preferredTier: .simple))
        guard let correctId = sut.currentItem?.correctPictureId else {
            XCTFail("no current item"); return
        }
        await sut.pick(request: .init(pictureId: correctId))
        XCTAssertEqual(haptic1.notificationCount, 1)
        // wrong tick:
        await sut.pick(request: .init(pictureId: "bogus"))
        XCTAssertEqual(haptic1.notificationCount, 2)
    }
}

// MARK: - Worker Tests

@MainActor
final class ComprehensionDetectiveWorkerTests: XCTestCase {

    func test_shuffle_seededWithZero_preservesOrAlmostPreserves() {
        let worker = ComprehensionDetectiveWorker(randomSource: { 0.0 })
        let pictures = [
            DetectivePicture(id: "p1", symbolName: "a", label: "a"),
            DetectivePicture(id: "p2", symbolName: "b", label: "b"),
            DetectivePicture(id: "p3", symbolName: "c", label: "c"),
            DetectivePicture(id: "p4", symbolName: "d", label: "d")
        ]
        let shuffled = worker.shuffle(pictures)
        XCTAssertEqual(shuffled.count, 4)
        XCTAssertEqual(Set(shuffled.map(\.id)), Set(pictures.map(\.id)))
    }

    func test_count_returnsCorpusSize() {
        let worker = ComprehensionDetectiveWorker()
        for tier in GrammarTier.allCases {
            XCTAssertGreaterThan(worker.count(for: tier), 0,
                                 "Tier \(tier.rawValue) пуст")
        }
    }
}

// MARK: - Corpus Tests

final class ComprehensionDetectiveCorpusTests: XCTestCase {

    func test_corpus_loads120Items() {
        XCTAssertGreaterThanOrEqual(ComprehensionDetectiveCorpus.allItems.count, 100,
                                    "Корпус должен содержать ≥100 пунктов")
    }

    func test_corpus_hasAllFourTiers() {
        let tiers = Set(ComprehensionDetectiveCorpus.allItems.map(\.tier))
        XCTAssertEqual(tiers, Set(GrammarTier.allCases))
    }

    func test_everyItem_hasFourPictures() {
        for item in ComprehensionDetectiveCorpus.allItems {
            XCTAssertEqual(item.pictures.count, 4,
                           "Пункт \(item.id) должен иметь 4 картинки")
        }
    }

    func test_correctPictureId_belongsToItemPictures() {
        for item in ComprehensionDetectiveCorpus.allItems {
            let ids = Set(item.pictures.map(\.id))
            XCTAssertTrue(ids.contains(item.correctPictureId),
                          "Пункт \(item.id): правильный id вне списка картинок")
        }
    }

    func test_idsAreUnique() {
        let ids = ComprehensionDetectiveCorpus.allItems.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_instructions_nonEmpty() {
        for item in ComprehensionDetectiveCorpus.allItems {
            XCTAssertFalse(item.instruction.isEmpty,
                           "Пункт \(item.id) без инструкции")
        }
    }
}
