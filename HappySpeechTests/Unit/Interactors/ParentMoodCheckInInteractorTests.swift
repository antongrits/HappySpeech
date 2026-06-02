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

    /// Изолированный UserDefaults на каждый SUT — история чек-инов персистится,
    /// не должна протекать между тестами / на устройство.
    private func makeSUT() -> ParentMoodCheckInInteractor {
        let suite = UserDefaults(suiteName: "test.parentMood.\(UUID().uuidString)")!
        return ParentMoodCheckInInteractor(defaults: suite)
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

    // MARK: - Persistence

    func test_save_appendsToHistory() {
        let sut = makeSUT()
        sut.entry.mood = .tired
        sut.entry.note = "устал"
        sut.save()
        XCTAssertEqual(sut.history.count, 1)
        XCTAssertEqual(sut.history.first?.mood, ParentMoodCheckInModels.Mood.tired.rawValue)
        XCTAssertEqual(sut.history.first?.note, "устал")
    }

    func test_save_persistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "test.parentMood.persist.\(UUID().uuidString)")!
        let sut1 = ParentMoodCheckInInteractor(defaults: suite)
        sut1.entry.mood = .energised
        sut1.save()
        // Новый интерактор читает сохранённую историю.
        let sut2 = ParentMoodCheckInInteractor(defaults: suite)
        XCTAssertEqual(sut2.history.count, 1)
        XCTAssertEqual(sut2.history.first?.mood, ParentMoodCheckInModels.Mood.energised.rawValue)
        XCTAssertNotNil(sut2.lastSavedAt)
    }

    // MARK: - Mood model

    func test_mood_allCasesIdentifiable() {
        for mood in ParentMoodCheckInModels.Mood.allCases {
            XCTAssertEqual(mood.id, mood.rawValue)
        }
    }
}
