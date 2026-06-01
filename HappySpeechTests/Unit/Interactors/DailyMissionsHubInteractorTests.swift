@testable import HappySpeech
import XCTest

/// UTC-календарь для детерминированных дат (file-scope — нельзя `Self.` в
/// default-аргументе из-за covariant Self).
private let dailyMissionsTestCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC") ?? .current
    return c
}()

// MARK: - DailyMissionsHubInteractorTests
//
// DailyMissionsHubInteractor — thin VIP (@Observable). Выполнение миссий =
// авто-выполнение из сегодняшних сессий (по templateType) + ручные отметки,
// сохраняемые на текущий день в UserDefaults. Тесты используют изолированный
// suite UserDefaults, чтобы не загрязнять .standard и друг друга.

@MainActor
final class DailyMissionsHubInteractorTests: XCTestCase {

    private typealias Mission = DailyMissionsHubModels.Mission

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.dailyMissions.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeSUT(
        childId: String = "child-1",
        sessions: [SessionDTO] = [],
        calendar: Calendar = dailyMissionsTestCalendar
    ) -> DailyMissionsHubInteractor {
        DailyMissionsHubInteractor(
            childId: childId,
            sessionRepository: MockSessionRepository(sessions: sessions),
            defaults: defaults,
            calendar: calendar
        )
    }

    // MARK: - Init

    func test_init_storesChildId() {
        let sut = makeSUT(childId: "c-21")
        XCTAssertEqual(sut.childId, "c-21")
    }

    func test_initialState_nothingCompleted() {
        let sut = makeSUT()
        XCTAssertTrue(sut.state.completed.isEmpty)
        XCTAssertEqual(sut.state.progress, 0, accuracy: 0.0001)
    }

    // MARK: - markCompleted (manual)

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

    func test_markCompleted_persistsAcrossInstancesSameDay() {
        let sut1 = makeSUT(childId: "kid-persist")
        sut1.markCompleted(.breathing)
        // Новый экземпляр того же ребёнка/дня должен подтянуть отметку из defaults.
        let sut2 = makeSUT(childId: "kid-persist")
        XCTAssertTrue(sut2.state.completed.contains(.breathing))
    }

    func test_markCompleted_emptyChildId_doesNotPersist() {
        let sut = makeSUT(childId: "")
        sut.markCompleted(.warmup)
        // В состоянии есть (set), но в defaults не сохранилось.
        let sut2 = makeSUT(childId: "")
        XCTAssertTrue(sut2.state.completed.isEmpty)
    }

    // MARK: - autoCompleted from sessions

    func test_autoCompleted_matchesBingoFromTodaySession() {
        let cal = dailyMissionsTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [session(date: today, type: TemplateType.bingo.rawValue)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        XCTAssertTrue(sut.autoCompleted(from: sessions).contains(.bingo))
    }

    func test_autoCompleted_matchesStoryFromNarrativeQuest() {
        let cal = dailyMissionsTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [session(date: today, type: TemplateType.narrativeQuest.rawValue)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        XCTAssertTrue(sut.autoCompleted(from: sessions).contains(.story))
    }

    func test_autoCompleted_ignoresPastSessions() {
        let cal = dailyMissionsTestCalendar
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let sessions = [session(date: yesterday, type: TemplateType.bingo.rawValue)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        XCTAssertFalse(sut.autoCompleted(from: sessions).contains(.bingo))
    }

    func test_autoCompleted_unmatchedTemplate_isEmpty() {
        let cal = dailyMissionsTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [session(date: today, type: TemplateType.sorting.rawValue)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        XCTAssertTrue(sut.autoCompleted(from: sessions).isEmpty)
    }

    func test_autoCompleted_warmupFromArticulation() {
        let cal = dailyMissionsTestCalendar
        let today = cal.startOfDay(for: Date())
        let sessions = [session(date: today, type: TemplateType.articulationImitation.rawValue)]
        let sut = makeSUT(sessions: sessions, calendar: cal)
        XCTAssertTrue(sut.autoCompleted(from: sessions).contains(.warmup))
    }

    // MARK: - progress

    func test_progress_allCompleted_isOne() {
        let sut = makeSUT()
        for mission in Mission.allCases { sut.markCompleted(mission) }
        XCTAssertEqual(sut.state.progress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(sut.state.allDone)
    }

    func test_progress_singleMission() {
        let sut = makeSUT()
        sut.markCompleted(.soundOfDay)
        XCTAssertEqual(sut.state.progress,
                       1.0 / Double(Mission.allCases.count),
                       accuracy: 0.0001)
    }

    // MARK: - Helpers

    private func session(date: Date, type: String) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: "child-1",
            date: date,
            templateType: type,
            targetSound: "Р",
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 180,
            totalAttempts: 5,
            correctAttempts: 4,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }
}
