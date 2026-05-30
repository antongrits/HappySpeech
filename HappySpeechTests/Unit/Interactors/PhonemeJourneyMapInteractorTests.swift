@testable import HappySpeech
import XCTest

// MARK: - PhonemeJourneyMapInteractorTests
//
// Thin VIP (@Observable). Tests toggle (flips isComplete) plus the two
// computed properties on ViewState: currentIndex (first incomplete) and
// progress (fraction complete).

@MainActor
final class PhonemeJourneyMapInteractorTests: XCTestCase {

    private func makeSUT() -> PhonemeJourneyMapInteractor {
        PhonemeJourneyMapInteractor(childId: "child-1")
    }

    // MARK: - Initial state

    func test_initialState_targetSoundIsR() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.targetSound, "Р")
    }

    func test_initialState_fiveStages() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.stages.count, PhonemeJourneyMapModels.Stage.allCases.count)
    }

    func test_initialState_progressMatchesSeed() {
        let sut = makeSUT()
        // 2 of 5 complete in seed → 0.4.
        XCTAssertEqual(sut.state.progress, 0.4, accuracy: 0.0001)
    }

    func test_initialState_currentIndexIsFirstIncomplete() {
        let sut = makeSUT()
        // isolated + syllables done → first incomplete is .words (index 2).
        XCTAssertEqual(sut.state.currentIndex, 2)
    }

    // MARK: - toggle

    func test_toggle_flipsCompletion() {
        let sut = makeSUT()
        sut.toggle(.words) // false → true
        let words = sut.state.stages.first { $0.id == .words }
        XCTAssertEqual(words?.isComplete, true)
    }

    func test_toggle_completingThird_advancesCurrentIndex() {
        let sut = makeSUT()
        sut.toggle(.words) // now isolated/syllables/words done → next is .phrases (3)
        XCTAssertEqual(sut.state.currentIndex, 3)
    }

    func test_toggle_completingAll_currentIndexClampsToLast() {
        let sut = makeSUT()
        sut.toggle(.words)
        sut.toggle(.phrases)
        sut.toggle(.freeSpeech)
        // No incomplete left → falls back to stages.count - 1 == 4.
        XCTAssertEqual(sut.state.currentIndex, sut.state.stages.count - 1)
    }

    func test_toggle_completingAll_progressIsOne() {
        let sut = makeSUT()
        sut.toggle(.words)
        sut.toggle(.phrases)
        sut.toggle(.freeSpeech)
        XCTAssertEqual(sut.state.progress, 1.0, accuracy: 0.0001)
    }

    func test_toggle_uncompleting_reducesProgress() {
        let sut = makeSUT()
        let before = sut.state.progress
        sut.toggle(.isolated) // true → false
        XCTAssertLessThan(sut.state.progress, before)
    }

    // MARK: - Stage model

    func test_stage_titleCaptionIcon_nonEmpty() {
        for stage in PhonemeJourneyMapModels.Stage.allCases {
            XCTAssertFalse(stage.title.isEmpty)
            XCTAssertFalse(stage.caption.isEmpty)
            XCTAssertFalse(stage.iconSystemName.isEmpty)
        }
    }
}
