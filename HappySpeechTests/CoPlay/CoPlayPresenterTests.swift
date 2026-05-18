@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyCoPlayDisplay: CoPlayDisplayLogic, @unchecked Sendable {
    var startVM: CoPlayModels.Start.ViewModel?
    var nextVM: CoPlayModels.NextTurn.ViewModel?

    func displayStart(viewModel: CoPlayModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayNextTurn(viewModel: CoPlayModels.NextTurn.ViewModel) async {
        nextVM = viewModel
    }
}

// MARK: - Helpers

@MainActor
private func makeActivity() -> CoPlayActivity {
    .init(
        id: "a1", title: "Тест", symbolName: "cat.fill",
        turns: [
            .init(id: "t1", role: .adult, line: "Образец.", instruction: "Скажите."),
            .init(id: "t2", role: .child, line: "Повтор.", instruction: "Повтори.")
        ],
        adultBriefing: "Инструктаж"
    )
}

// MARK: - Presenter Tests

@MainActor
final class CoPlayPresenterTests: XCTestCase {

    private func makeSUT() -> (CoPlayPresenter, SpyCoPlayDisplay) {
        let display = SpyCoPlayDisplay()
        let sut = CoPlayPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentStart_buildsViewModel() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(activity: makeActivity()))
        XCTAssertEqual(display.startVM?.totalTurns, 2)
        XCTAssertEqual(display.startVM?.firstTurn.role, .adult)
        XCTAssertFalse(display.startVM?.adultBriefing.isEmpty ?? true)
        XCTAssertFalse(display.startVM?.firstTurn.roleLabel.isEmpty ?? true)
    }

    func test_presentNextTurn_notFinished_hasNextTurn() async {
        let (sut, display) = makeSUT()
        let turn = CoPlayTurn(
            id: "t2", role: .child, line: "Повтор.", instruction: "Повтори."
        )
        await sut.presentNextTurn(response: .init(
            isFinished: false,
            nextTurn: turn,
            nextTurnIndex: 1,
            totalTurns: 2
        ))
        XCTAssertEqual(display.nextVM?.isFinished, false)
        XCTAssertNotNil(display.nextVM?.nextTurn)
        XCTAssertNil(display.nextVM?.summary)
    }

    func test_presentNextTurn_finished_buildsSummary() async {
        let (sut, display) = makeSUT()
        await sut.presentNextTurn(response: .init(
            isFinished: true,
            nextTurn: nil,
            nextTurnIndex: nil,
            totalTurns: 6
        ))
        XCTAssertEqual(display.nextVM?.isFinished, true)
        XCTAssertNotNil(display.nextVM?.summary)
        XCTAssertFalse(display.nextVM?.summary?.adultTip.isEmpty ?? true)
    }
}
