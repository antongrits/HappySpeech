@testable import HappySpeech
import XCTest

/// UTC-календарь для детерминированных дат (file-scope — нельзя `Self.` в
/// default-аргументе из-за covariant Self).
private let soundJournalTestCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC") ?? .current
    return c
}()

// MARK: - SoundJournalKidInteractorTests
//
// SoundJournalKidInteractor — thin VIP (@Observable). Дневник строится из
// реальных сессий: группировка по звуку, число практик и последний балл.
// Тесты покрывают: пустой старт, select-toggle и агрегацию makeState.

@MainActor
final class SoundJournalKidInteractorTests: XCTestCase {

    private func makeSUT(
        childId: String = "child-1",
        sessions: [SessionDTO] = [],
        calendar: Calendar = soundJournalTestCalendar
    ) -> SoundJournalKidInteractor {
        SoundJournalKidInteractor(
            childId: childId,
            sessionRepository: MockSessionRepository(sessions: sessions),
            calendar: calendar
        )
    }

    // MARK: - Initial state

    func test_init_storesChildId() {
        let sut = SoundJournalKidInteractor(childId: "kid-7")
        XCTAssertEqual(sut.childId, "kid-7")
    }

    func test_initialState_isEmpty() {
        let sut = SoundJournalKidInteractor(childId: "c")
        XCTAssertEqual(sut.state, .initial)
        XCTAssertTrue(sut.state.isEmpty)
        XCTAssertTrue(sut.state.entries.isEmpty)
        XCTAssertNil(sut.state.selectedEntryId)
    }

    // MARK: - select

    func test_select_setsSelectedEntryId() {
        let sut = SoundJournalKidInteractor(childId: "c")
        sut.select("Р")
        XCTAssertEqual(sut.state.selectedEntryId, "Р")
    }

    func test_select_sameId_togglesOff() {
        let sut = SoundJournalKidInteractor(childId: "c")
        sut.select("Ш")
        sut.select("Ш")
        XCTAssertNil(sut.state.selectedEntryId)
    }

    func test_select_differentId_replacesSelection() {
        let sut = SoundJournalKidInteractor(childId: "c")
        sut.select("Р")
        sut.select("С")
        XCTAssertEqual(sut.state.selectedEntryId, "С")
    }

    // MARK: - makeState aggregation

    func test_makeState_emptySessions_isEmpty() {
        let sut = makeSUT()
        let state = sut.makeState(from: [])
        XCTAssertTrue(state.isEmpty)
    }

    func test_makeState_groupsBySound() {
        let cal = soundJournalTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [
            session(date: today.addingTimeInterval(3600), sound: "Р", total: 10, correct: 8),
            session(date: today.addingTimeInterval(4000), sound: "Р", total: 10, correct: 9),
            session(date: today.addingTimeInterval(5000), sound: "Ш", total: 10, correct: 5)
        ]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions)
        XCTAssertEqual(Set(state.entries.map(\.sound)), ["Р", "Ш"])
    }

    func test_makeState_timesPracticed_countsTodaySessions() {
        let cal = soundJournalTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [
            session(date: today.addingTimeInterval(3600), sound: "Р", total: 10, correct: 8),
            session(date: today.addingTimeInterval(4000), sound: "Р", total: 10, correct: 9)
        ]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions)
        XCTAssertEqual(state.entries.first { $0.sound == "Р" }?.timesPracticed, 2)
    }

    func test_makeState_lastScore_usesLatestSessionRate() {
        let cal = soundJournalTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [
            session(date: today.addingTimeInterval(1000), sound: "Р", total: 10, correct: 3),  // старее
            session(date: today.addingTimeInterval(9000), sound: "Р", total: 10, correct: 9)   // свежее → 90%
        ]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions)
        XCTAssertEqual(state.entries.first { $0.sound == "Р" }?.lastScore, 90)
    }

    func test_makeState_sortedByTimesPracticedDescending() {
        let cal = soundJournalTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [
            session(date: today.addingTimeInterval(1000), sound: "Ш", total: 10, correct: 9),
            session(date: today.addingTimeInterval(2000), sound: "Р", total: 10, correct: 5),
            session(date: today.addingTimeInterval(3000), sound: "Р", total: 10, correct: 6)
        ]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let state = sut.makeState(from: sessions)
        // Р практиковался 2 раза, Ш — 1 → Р первым.
        XCTAssertEqual(state.entries.first?.sound, "Р")
    }

    func test_makeState_ignoresEmptyTargetSound() {
        let cal = soundJournalTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [session(date: today, sound: "", total: 10, correct: 8)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        XCTAssertTrue(sut.makeState(from: sessions).isEmpty)
    }

    func test_makeState_assignsEmoji() {
        let cal = soundJournalTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [session(date: today, sound: "Р", total: 10, correct: 8)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        let entry = sut.makeState(from: sessions).entries.first
        XCTAssertEqual(entry?.emoji, SoundJournalKidModels.emoji(for: "Р"))
    }

    // MARK: - emoji mapping

    func test_emoji_knownSounds() {
        XCTAssertEqual(SoundJournalKidModels.emoji(for: "С"), "🐍")
        XCTAssertEqual(SoundJournalKidModels.emoji(for: "Ш"), "🌬")
    }

    func test_emoji_unknownSound_hasFallback() {
        XCTAssertEqual(SoundJournalKidModels.emoji(for: "Ъ"), "🎈")
    }

    // MARK: - Helpers

    private func session(date: Date, sound: String, total: Int, correct: Int) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: "child-1",
            date: date,
            templateType: TemplateType.repeatAfterModel.rawValue,
            targetSound: sound,
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 200,
            totalAttempts: total,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }
}
