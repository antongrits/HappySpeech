@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubCoPlayWorker: CoPlayWorkerProtocol {
    var response: CoPlayModels.Start.Response
    private(set) var pickCount = 0

    init(response: CoPlayModels.Start.Response) {
        self.response = response
    }

    func pickActivity(childId: String) async -> CoPlayModels.Start.Response {
        pickCount += 1
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyCoPlayPresenter: CoPlayPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var nextCount = 0
    var lastNext: CoPlayModels.NextTurn.Response?

    func presentStart(response: CoPlayModels.Start.Response) async {
        startCount += 1
    }
    func presentNextTurn(response: CoPlayModels.NextTurn.Response) async {
        nextCount += 1
        lastNext = response
    }
}

// MARK: - Helpers

@MainActor
private func makeActivity() -> CoPlayActivity {
    .init(
        id: "a1", title: "Тест", symbolName: "cat.fill",
        turns: [
            .init(id: "t1", role: .adult, line: "Образец.", instruction: "Скажите."),
            .init(id: "t2", role: .child, line: "Повтор.", instruction: "Повтори."),
            .init(id: "t3", role: .adult, line: "Ещё.", instruction: "Скажите.")
        ],
        adultBriefing: "Инструктаж"
    )
}

// MARK: - Interactor Tests

@MainActor
final class CoPlayInteractorTests: XCTestCase {

    private func makeSUT() -> (CoPlayInteractor, SpyCoPlayPresenter, StubCoPlayWorker, SpyHapticService) {
        let worker = StubCoPlayWorker(response: .init(activity: makeActivity()))
        let haptic = SpyHapticService()
        let sut = CoPlayInteractor(childId: "child-1", worker: worker, hapticService: haptic)
        let spy = SpyCoPlayPresenter()
        sut.presenter = spy
        return (sut, spy, worker, haptic)
    }

    func test_start_picksActivityAndPresents() async {
        let (sut, spy, worker, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        XCTAssertEqual(worker.pickCount, 1)
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.activity?.turns.count, 3)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func test_nextTurn_advances() async {
        let (sut, spy, _, haptic) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.nextTurn(request: .init(voiceConfirmed: true))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastNext?.isFinished, false)
        XCTAssertNotNil(spy.lastNext?.nextTurn)
        XCTAssertEqual(haptic.notificationCount, 1)
    }

    func test_nextTurn_lastTurn_finishes() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        await sut.nextTurn(request: .init(voiceConfirmed: true))
        await sut.nextTurn(request: .init(voiceConfirmed: true))
        await sut.nextTurn(request: .init(voiceConfirmed: true))
        XCTAssertEqual(spy.lastNext?.isFinished, true)
        XCTAssertNil(spy.lastNext?.nextTurn)
    }

    func test_nextTurn_afterFinish_isIgnored() async {
        let (sut, spy, _, _) = makeSUT()
        await sut.start(request: .init(childId: "child-1"))
        for _ in 0..<3 {
            await sut.nextTurn(request: .init(voiceConfirmed: true))
        }
        let afterFinish = spy.nextCount
        await sut.nextTurn(request: .init(voiceConfirmed: true))
        XCTAssertEqual(spy.nextCount, afterFinish)
    }
}

// MARK: - Corpus Tests

final class CoPlayCorpusTests: XCTestCase {

    func test_corpus_isNotEmpty() {
        XCTAssertFalse(CoPlayCorpus.activities.isEmpty)
    }

    func test_activityIdsAreUnique() {
        let ids = CoPlayCorpus.activities.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_everyActivityHasTurnsAndBriefing() {
        for activity in CoPlayCorpus.activities {
            XCTAssertGreaterThanOrEqual(activity.turns.count, 4)
            XCTAssertFalse(activity.adultBriefing.isEmpty)
            for turn in activity.turns {
                XCTAssertFalse(turn.line.isEmpty)
                XCTAssertFalse(turn.instruction.isEmpty)
            }
        }
    }

    func test_everyActivityAlternatesRoles() {
        for activity in CoPlayCorpus.activities {
            let roles = Set(activity.turns.map(\.role))
            XCTAssertEqual(roles, Set(CoPlayRole.allCases))
        }
    }
}
