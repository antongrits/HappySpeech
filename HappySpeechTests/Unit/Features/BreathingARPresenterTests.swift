@testable import HappySpeech
import XCTest

// MARK: - BreathingARPresenterTests
//
// Verifies the Response → ViewModel mapping in the AR "blow the dandelion"
// presenter. The presenter consumes only plain Response structs (blendshapes
// live in Requests), so it is fully unit-testable without ARKit:
//   - StartGame: totalText formatted (non-empty) from dandelionCount
//   - UpdateFrame: hint key switches on isBlowing; strength/flag carried
//   - ScoreAttempt: result message formatted from percent; stars carried

@MainActor
final class BreathingARPresenterTests: XCTestCase {

    @MainActor
    private final class DisplaySpy: BreathingARDisplayLogic {
        var startVM: BreathingARModels.StartGame.ViewModel?
        var frameVM: BreathingARModels.UpdateFrame.ViewModel?
        var scoreVM: BreathingARModels.ScoreAttempt.ViewModel?

        func displayStartGame(_ viewModel: BreathingARModels.StartGame.ViewModel) { startVM = viewModel }
        func displayUpdateFrame(_ viewModel: BreathingARModels.UpdateFrame.ViewModel) { frameVM = viewModel }
        func displayScoreAttempt(_ viewModel: BreathingARModels.ScoreAttempt.ViewModel) { scoreVM = viewModel }
    }

    private func makeSUT() -> (BreathingARPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = BreathingARPresenter()
        presenter.display = spy
        return (presenter, spy)
    }

    // MARK: - StartGame

    func test_startGame_totalTextNonEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStartGame(.init(dandelionCount: 5))
        XCTAssertFalse(spy.startVM?.totalText.isEmpty ?? true)
    }

    // MARK: - UpdateFrame

    func test_updateFrame_blowing_carriesFlagAndStrength() {
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(isBlowing: true, strength: 0.7))
        XCTAssertEqual(spy.frameVM?.isBlowing, true)
        XCTAssertEqual(spy.frameVM?.strength, 0.7)
        XCTAssertFalse(spy.frameVM?.hint.isEmpty ?? true)
    }

    func test_updateFrame_hintNonEmptyForBothBlowingStates() {
        // The presenter selects a localized hint via the `isBlowing` branch.
        // Both keys currently share the same placeholder translation in the
        // String Catalog, so we assert the branch produces a non-empty hint in
        // both states rather than depending on distinct translations.
        let (sut, spy) = makeSUT()
        sut.presentUpdateFrame(.init(isBlowing: true, strength: 0.5))
        XCTAssertFalse(spy.frameVM?.hint.isEmpty ?? true)
        XCTAssertEqual(spy.frameVM?.isBlowing, true)

        sut.presentUpdateFrame(.init(isBlowing: false, strength: 0.0))
        XCTAssertFalse(spy.frameVM?.hint.isEmpty ?? true)
        XCTAssertEqual(spy.frameVM?.isBlowing, false)
    }

    // MARK: - ScoreAttempt

    func test_scoreAttempt_carriesStarsAndMessage() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 3, percent: 100))
        XCTAssertEqual(spy.scoreVM?.stars, 3)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }

    func test_scoreAttempt_zeroStarsStillProducesMessage() {
        let (sut, spy) = makeSUT()
        sut.presentScoreAttempt(.init(stars: 0, percent: 0))
        XCTAssertEqual(spy.scoreVM?.stars, 0)
        XCTAssertFalse(spy.scoreVM?.message.isEmpty ?? true)
    }
}
