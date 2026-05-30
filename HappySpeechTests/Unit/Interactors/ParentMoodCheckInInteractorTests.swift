@testable import HappySpeech
import XCTest

// MARK: - ParentMoodCheckInInteractorTests
//
// ParentMoodCheckInInteractor is a thin VIP MVP variant (@Observable). It captures
// a parent's daily mood entry; save() only stamps lastSavedAt when a mood has been
// chosen (the note alone is not enough). Tests cover the guard branch, the happy
// path and that re-saving updates the timestamp.
// (Mood.emoji/.label maps are purely presentational — intentionally skipped.)

@MainActor
final class ParentMoodCheckInInteractorTests: XCTestCase {

    private func makeSUT() -> ParentMoodCheckInInteractor {
        ParentMoodCheckInInteractor()
    }

    // MARK: - Initial state

    func test_initialState_emptyEntry() {
        let sut = makeSUT()
        XCTAssertNil(sut.entry.mood)
        XCTAssertEqual(sut.entry.note, "")
    }

    func test_initialState_notSaved() {
        let sut = makeSUT()
        XCTAssertNil(sut.lastSavedAt)
    }

    // MARK: - save guard (no mood)

    func test_save_withoutMood_doesNotStamp() {
        let sut = makeSUT()
        sut.save()
        XCTAssertNil(sut.lastSavedAt)
    }

    func test_save_withNoteButNoMood_doesNotStamp() {
        let sut = makeSUT()
        sut.entry.note = "тяжёлый день"
        sut.save()
        XCTAssertNil(sut.lastSavedAt)
    }

    // MARK: - save happy path

    func test_save_withMood_stampsTimestamp() {
        let sut = makeSUT()
        sut.entry.mood = .tired
        sut.save()
        XCTAssertNotNil(sut.lastSavedAt)
    }

    func test_save_withMoodAndNote_stampsTimestamp() {
        let sut = makeSUT()
        sut.entry.mood = .okay
        sut.entry.note = "норм"
        sut.save()
        XCTAssertNotNil(sut.lastSavedAt)
    }

    func test_save_doesNotMutateEntry() {
        let sut = makeSUT()
        sut.entry.mood = .energised
        sut.entry.note = "отлично"
        sut.save()
        XCTAssertEqual(sut.entry.mood, .energised)
        XCTAssertEqual(sut.entry.note, "отлично")
    }

    func test_save_twice_updatesTimestamp() async {
        let sut = makeSUT()
        sut.entry.mood = .overwhelmed
        sut.save()
        let first = sut.lastSavedAt
        try? await Task.sleep(for: .milliseconds(20))
        sut.save()
        XCTAssertNotNil(sut.lastSavedAt)
        if let first, let second = sut.lastSavedAt {
            XCTAssertGreaterThanOrEqual(second, first)
        }
    }

    // MARK: - Mood model

    func test_mood_allCasesIdentifiable() {
        for mood in ParentMoodCheckInModels.Mood.allCases {
            XCTAssertEqual(mood.id, mood.rawValue)
        }
    }
}
