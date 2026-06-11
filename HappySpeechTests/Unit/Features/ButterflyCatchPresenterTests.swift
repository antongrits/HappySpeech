@testable import HappySpeech
import CoreGraphics
import XCTest

// MARK: - ButterflyCatchPresenterTests
//
// Verifies the Response → ViewModel mapping in the AR "catch the butterfly"
// presenter. The presenter consumes plain Response structs (blendshapes live
// in the ScoreAttempt Request), so it is unit-testable without ARKit:
//   - StartGame: timeLeftText formatted from durationSec; totalButterflies carried
//   - SpawnButterfly: butterfly forwarded verbatim
//   - ScoreAttempt: scoreText formatted from totalCaught; caught flag carried

@MainActor
final class ButterflyCatchPresenterTests: XCTestCase {

    @MainActor
    private final class DisplaySpy: ButterflyCatchDisplayLogic {
        var startVM: ButterflyCatchModels.StartGame.ViewModel?
        var spawnVM: ButterflyCatchModels.SpawnButterfly.ViewModel?
        var scoreVM: ButterflyCatchModels.ScoreAttempt.ViewModel?

        func displayStartGame(_ viewModel: ButterflyCatchModels.StartGame.ViewModel) { startVM = viewModel }
        func displaySpawnButterfly(_ viewModel: ButterflyCatchModels.SpawnButterfly.ViewModel) { spawnVM = viewModel }
        func displayScoreAttempt(_ viewModel: ButterflyCatchModels.ScoreAttempt.ViewModel) { scoreVM = viewModel }
    }

    private func makeSUT() -> (ButterflyCatchPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ButterflyCatchPresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    private func butterfly(id: UUID = UUID(),
                           posture: ArticulationPosture = .tongueUp) -> ButterflyCatchModels.Butterfly {
        .init(
            id: id,
            position: CGPoint(x: 0.5, y: 0.5),
            direction: .left,
            targetPosture: posture
        )
    }

    // MARK: - StartGame

    func test_startGame_carriesTotalAndFormatsTime() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(totalButterflies: 8, durationSec: 30))
        XCTAssertEqual(spy.startVM?.totalButterflies, 8)
        XCTAssertTrue(spy.startVM?.timeLeftText.contains("30") ?? false)
    }

    // MARK: - SpawnButterfly

    func test_spawn_forwardsButterfly() {
        let (sut, spy) = makeSUT()
        let id = UUID()
        sut.presentSpawnButterfly(.init(butterfly: butterfly(id: id)))
        XCTAssertEqual(spy.spawnVM?.butterfly.id, id)
        XCTAssertEqual(spy.spawnVM?.butterfly.direction, .left)
        XCTAssertEqual(spy.spawnVM?.butterfly.targetPosture, .tongueUp)
    }

    func test_spawn_providesTongueInstruction() {
        let (sut, spy) = makeSUT()
        sut.presentSpawnButterfly(.init(butterfly: butterfly(posture: .tongueUp)))
        XCTAssertFalse(spy.spawnVM?.instruction.isEmpty ?? true,
                       "Ребёнок получает подсказку, как ловить бабочку языком")
        let upCue = spy.spawnVM?.instruction
        sut.presentSpawnButterfly(.init(butterfly: butterfly(posture: .shoveling)))
        XCTAssertFalse(spy.spawnVM?.instruction.isEmpty ?? true)
        XCTAssertNotEqual(upCue, spy.spawnVM?.instruction,
                          "Подсказка отличается для разных поз языка")
    }

    // MARK: - ScoreAttempt

    func test_score_caughtTrue_scoreTextNonEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(caught: true, totalCaught: 3))
        XCTAssertEqual(spy.scoreVM?.caught, true)
        XCTAssertFalse(spy.scoreVM?.scoreText.isEmpty ?? true)
    }

    func test_score_caughtFalse_carriesFlag() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(caught: false, totalCaught: 0))
        XCTAssertEqual(spy.scoreVM?.caught, false)
        XCTAssertFalse(spy.scoreVM?.scoreText.isEmpty ?? true)
    }
}
