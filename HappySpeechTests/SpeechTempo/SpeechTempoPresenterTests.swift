@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpyTempoDisplay: SpeechTempoDisplayLogic, @unchecked Sendable {
    var startVM: SpeechTempoModels.Start.ViewModel?
    var finishVM: SpeechTempoModels.Finish.ViewModel?

    func displayStart(viewModel: SpeechTempoModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayFinish(viewModel: SpeechTempoModels.Finish.ViewModel) async {
        finishVM = viewModel
    }
}

// MARK: - Helpers

private let rhymes: [TempoRhyme] = [
    .init(id: "rh1", text: "Са-са-са", syllables: ["са", "са", "са"]),
    .init(id: "rh2", text: "Ши-ши-ши", syllables: ["ши", "ши", "ши"])
]

// MARK: - Presenter Tests

@MainActor
final class SpeechTempoPresenterTests: XCTestCase {

    private func makeSUT() -> (SpeechTempoPresenter, SpyTempoDisplay) {
        let display = SpyTempoDisplay()
        let sut = SpeechTempoPresenter(displayLogic: display)
        return (sut, display)
    }

    func test_presentStart_buildsViewModelWithFirstRhyme() async {
        let (sut, display) = makeSUT()
        await sut.presentStart(response: .init(rhymes: rhymes))
        XCTAssertNotNil(display.startVM)
        XCTAssertEqual(display.startVM?.totalRhymes, 2)
        XCTAssertEqual(display.startVM?.firstRhyme.id, "rh1")
        XCTAssertEqual(display.startVM?.firstRhyme.syllables.count, 3)
        XCTAssertFalse(display.startVM?.instruction.isEmpty ?? true)
    }

    func test_presentFinish_smooth_setsRatingText() async {
        let (sut, display) = makeSUT()
        await sut.presentFinish(response: .init(
            rating: .smooth,
            variationCoefficient: 0.1,
            beatsCounted: 6,
            expectedSyllables: 6,
            isFinished: false,
            nextRhyme: rhymes[1],
            nextRhymeIndex: 1,
            smoothCount: 1,
            totalRhymes: 2
        ))
        XCTAssertEqual(display.finishVM?.rating, .smooth)
        XCTAssertFalse(display.finishVM?.ratingText.isEmpty ?? true)
        XCTAssertNotNil(display.finishVM?.nextRhyme)
        XCTAssertNil(display.finishVM?.summary)
    }

    func test_presentFinish_uneven_setsRatingText() async {
        let (sut, display) = makeSUT()
        await sut.presentFinish(response: .init(
            rating: .uneven,
            variationCoefficient: 0.9,
            beatsCounted: 4,
            expectedSyllables: 6,
            isFinished: false,
            nextRhyme: rhymes[1],
            nextRhymeIndex: 1,
            smoothCount: 0,
            totalRhymes: 2
        ))
        XCTAssertEqual(display.finishVM?.rating, .uneven)
        XCTAssertFalse(display.finishVM?.ratingText.isEmpty ?? true)
    }

    func test_presentFinish_finished_buildsSummary() async {
        let (sut, display) = makeSUT()
        await sut.presentFinish(response: .init(
            rating: .smooth,
            variationCoefficient: 0.1,
            beatsCounted: 6,
            expectedSyllables: 6,
            isFinished: true,
            nextRhyme: nil,
            nextRhymeIndex: nil,
            smoothCount: 2,
            totalRhymes: 2
        ))
        XCTAssertEqual(display.finishVM?.isFinished, true)
        XCTAssertNotNil(display.finishVM?.summary)
        XCTAssertEqual(display.finishVM?.summary?.smoothCount, 2)
        XCTAssertFalse(display.finishVM?.summary?.encouragement.isEmpty ?? true)
    }

    func test_presentFinish_finishedLowSmooth_stillEncourages() async {
        let (sut, display) = makeSUT()
        await sut.presentFinish(response: .init(
            rating: .uneven,
            variationCoefficient: 0.9,
            beatsCounted: 3,
            expectedSyllables: 9,
            isFinished: true,
            nextRhyme: nil,
            nextRhymeIndex: nil,
            smoothCount: 0,
            totalRhymes: 5
        ))
        XCTAssertFalse(display.finishVM?.summary?.encouragement.isEmpty ?? true)
    }

    func test_ratingText_isDistinctPerRating() {
        let smooth = SpeechTempoPresenter.ratingText(for: .smooth)
        let slight = SpeechTempoPresenter.ratingText(for: .slightlyUneven)
        let uneven = SpeechTempoPresenter.ratingText(for: .uneven)
        XCTAssertNotEqual(smooth, slight)
        XCTAssertNotEqual(slight, uneven)
    }
}
