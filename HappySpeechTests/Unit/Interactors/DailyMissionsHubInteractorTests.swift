@testable import HappySpeech
import XCTest

// MARK: - DailyMissionsHubInteractorTests
//
// DailyMissionsHubInteractor is a thin VIP MVP variant (@Observable). It tracks the
// set of completed daily missions; markCompleted(_:) inserts into that set (set
// semantics → idempotent). The derived `progress` is completed/total. Tests cover
// the empty start, completion (incl. idempotency and full-completion), and progress.
// (Mission.title/.subtitle/.icon maps are purely presentational — intentionally skipped.)

@MainActor
final class DailyMissionsHubInteractorTests: XCTestCase {

    private typealias Mission = DailyMissionsHubModels.Mission

    private func makeSUT() -> DailyMissionsHubInteractor {
        DailyMissionsHubInteractor(childId: "child-1")
    }

    // MARK: - Init

    func test_init_storesChildId() {
        let sut = DailyMissionsHubInteractor(childId: "c-21")
        XCTAssertEqual(sut.childId, "c-21")
    }

    func test_initialState_nothingCompleted() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.completed.isEmpty)
        XCTAssertEqual(sut.state.progress, 0, accuracy: 0.0001)
    }

    // MARK: - markCompleted

    func test_markCompleted_insertsMission() {
        let sut = makeSUT()
        sut.markCompleted(.warmup)
        XCTAssertTrue(sut.state.completed.contains(.warmup))
    }

    func test_markCompleted_isIdempotent() {
        let sut = makeSUT()
        sut.markCompleted(.bingo)
        sut.markCompleted(.bingo)
        XCTAssertEqual(sut.state.completed.count, 1)
    }

    func test_markCompleted_distinctMissionsAccumulate() {
        let sut = makeSUT()
        sut.markCompleted(.warmup)
        sut.markCompleted(.story)
        XCTAssertEqual(sut.state.completed, [.warmup, .story])
    }

    func test_markCompleted_onlyAddsTarget() {
        let sut = makeSUT()
        sut.markCompleted(.breathing)
        XCTAssertEqual(sut.state.completed, [.breathing])
    }

    // MARK: - progress

    func test_progress_halfWay() {
        let sut = makeSUT()
        let half = Mission.allCases.count / 2
        for mission in Mission.allCases.prefix(half) {
            sut.markCompleted(mission)
        }
        XCTAssertEqual(sut.state.progress,
                       Double(half) / Double(Mission.allCases.count),
                       accuracy: 0.0001)
    }

    func test_progress_allCompleted_isOne() {
        let sut = makeSUT()
        for mission in Mission.allCases {
            sut.markCompleted(mission)
        }
        XCTAssertEqual(sut.state.progress, 1.0, accuracy: 0.0001)
    }

    func test_progress_singleMission() {
        let sut = makeSUT()
        sut.markCompleted(.soundOfDay)
        XCTAssertEqual(sut.state.progress,
                       1.0 / Double(Mission.allCases.count),
                       accuracy: 0.0001)
    }
}
