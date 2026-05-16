@testable import HappySpeech
import XCTest

// MARK: - FamilyCalendarPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие FamilyCalendarPresenter (60% → цель ≥90%).
// Тестируются все present* методы через DisplaySpy.

@MainActor
final class FamilyCalendarPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: FamilyCalendarDisplayLogic {
        var familyDataVM: FamilyCalendarViewModel?
        var dayDetailVM: DayDetailViewModel?
        var insights: [InsightItemViewModel]?
        var scheduledVoiceHint: String?
        var toastMessages: [String] = []
        var weekSummaryVM: WeekSummaryViewModel?
        var errorMessage: String?
        var loadingState: Bool?
        var insightsLoadingState: Bool?

        func displayFamilyData(viewModel: FamilyCalendarViewModel) { familyDataVM = viewModel }
        func displayDayDetail(viewModel: DayDetailViewModel) { dayDetailVM = viewModel }
        func displayInsights(insights: [InsightItemViewModel]) { self.insights = insights }
        func displayLessonScheduled(voiceHint: String) { scheduledVoiceHint = voiceHint }
        func displayToast(message: String) { toastMessages.append(message) }
        func displayWeekSummary(viewModel: WeekSummaryViewModel) { weekSummaryVM = viewModel }
        func displayError(message: String) { errorMessage = message }
        func displayLoadingState(isLoading: Bool) { loadingState = isLoading }
        func displayInsightsLoading(isLoading: Bool) { insightsLoadingState = isLoading }
        func displayClearToast() {}
    }

    // MARK: - SUT Factory

    private func makeSUT() -> (FamilyCalendarPresenter, DisplaySpy) {
        let presenter = FamilyCalendarPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    // MARK: - Helpers

    private func makeChild(id: String = "child-1", name: String = "Ваня") -> ChildProfileDTO {
        ChildProfileDTO(
            id: id,
            name: name,
            age: 6,
            targetSounds: ["С", "Р"],
            parentId: "parent-1",
            currentStreak: 3
        )
    }

    private func makeSession(childId: String = "child-1", date: Date = Date()) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: date,
            templateType: "listen-and-choose",
            targetSound: "С",
            stage: "word",
            durationSeconds: 600,
            totalAttempts: 10,
            correctAttempts: 8,
            fatigueDetected: false,
            isSynced: true,
            attempts: []
        )
    }

    private func baseDataLoaded(children: [ChildProfileDTO] = [], sessions: [SessionDTO] = []) -> FamilyCalendarResponse.DataLoaded {
        FamilyCalendarResponse.DataLoaded(
            children: children,
            sessions: sessions,
            selectedChildId: nil,
            currentMonth: Date(),
            weekOffset: 0,
            weeklyGoals: [:],
            plannedSessions: [],
            recurringPlans: [],
            specialistVisits: []
        )
    }

    // MARK: - presentDataLoaded

    func test_presentDataLoaded_noChildren_displaysEmptyVM() {
        let (sut, spy) = makeSUT()
        sut.presentDataLoaded(response: baseDataLoaded())
        XCTAssertNotNil(spy.familyDataVM)
        XCTAssertTrue(spy.familyDataVM?.isEmpty ?? false)
    }

    func test_presentDataLoaded_withChildren_childVMsContainAll() {
        let (sut, spy) = makeSUT()
        let children = [makeChild(id: "c1", name: "Ваня"), makeChild(id: "c2", name: "Маша")]
        sut.presentDataLoaded(response: baseDataLoaded(children: children))
        // +1 за «Все»
        XCTAssertEqual(spy.familyDataVM?.children.count, 3)
    }

    func test_presentDataLoaded_firstChildIsAll() {
        let (sut, spy) = makeSUT()
        sut.presentDataLoaded(response: baseDataLoaded(children: [makeChild()]))
        XCTAssertTrue(spy.familyDataVM?.children.first?.isAll ?? false)
    }

    func test_presentDataLoaded_isNotLoading() {
        let (sut, spy) = makeSUT()
        sut.presentDataLoaded(response: baseDataLoaded())
        XCTAssertFalse(spy.familyDataVM?.isLoading ?? true)
    }

    // MARK: - presentChildSelected

    func test_presentChildSelected_setsSelectedChildId() {
        let (sut, spy) = makeSUT()
        let child = makeChild(id: "c-selected")
        let response = FamilyCalendarResponse.ChildSelected(
            childId: "c-selected",
            children: [child],
            sessions: [],
            currentMonth: Date(),
            weekOffset: 0,
            weeklyGoals: [:],
            plannedSessions: [],
            recurringPlans: [],
            specialistVisits: []
        )
        sut.presentChildSelected(response: response)
        XCTAssertEqual(spy.familyDataVM?.selectedChildId, "c-selected")
    }

    // MARK: - presentMonthChanged

    func test_presentMonthChanged_weekOffsetIsZero() {
        let (sut, spy) = makeSUT()
        let response = FamilyCalendarResponse.MonthChanged(
            newMonth: Date(),
            sessions: [],
            selectedChildId: nil,
            children: []
        )
        sut.presentMonthChanged(response: response)
        XCTAssertEqual(spy.familyDataVM?.weekOffset, 0)
    }

    // MARK: - presentWeekChanged

    func test_presentWeekChanged_setsWeekOffset() {
        let (sut, spy) = makeSUT()
        let response = FamilyCalendarResponse.WeekChanged(
            weekStart: Date(),
            weekOffset: 2,
            sessions: [],
            selectedChildId: nil,
            children: [],
            weeklyGoals: [:],
            plannedSessions: [],
            specialistVisits: []
        )
        sut.presentWeekChanged(response: response)
        XCTAssertEqual(spy.familyDataVM?.weekOffset, 2)
    }

    // MARK: - presentDaySelected

    func test_presentDaySelected_emptyDay_isEmptyTrue() {
        let (sut, spy) = makeSUT()
        let response = FamilyCalendarResponse.DaySelected(
            date: Date(),
            sessions: [],
            children: [],
            dayPlans: [],
            specialistVisits: []
        )
        sut.presentDaySelected(response: response)
        XCTAssertTrue(spy.dayDetailVM?.isEmpty ?? false)
    }

    func test_presentDaySelected_withSession_aggregatesCorrectly() {
        let (sut, spy) = makeSUT()
        let today = Calendar.current.startOfDay(for: Date())
        let session = makeSession(childId: "c1", date: today.addingTimeInterval(3600))
        let child = makeChild(id: "c1", name: "Петя")
        let response = FamilyCalendarResponse.DaySelected(
            date: today,
            sessions: [session],
            children: [child],
            dayPlans: [],
            specialistVisits: []
        )
        sut.presentDaySelected(response: response)
        XCTAssertFalse(spy.dayDetailVM?.isEmpty ?? true)
        XCTAssertEqual(spy.dayDetailVM?.sessionItems.first?.childName, "Петя")
    }

    func test_presentDaySelected_dateTextNotEmpty() {
        let (sut, spy) = makeSUT()
        let response = FamilyCalendarResponse.DaySelected(
            date: Date(),
            sessions: [],
            children: [],
            dayPlans: [],
            specialistVisits: []
        )
        sut.presentDaySelected(response: response)
        XCTAssertFalse(spy.dayDetailVM?.dateText.isEmpty ?? true)
    }

    // MARK: - presentInsights

    func test_presentInsights_mapsAllInsights() {
        let (sut, spy) = makeSUT()
        let insights: [InsightItem] = [
            InsightItem(iconName: "flame", text: "Текст 1"),
            InsightItem(iconName: "star", text: "Текст 2")
        ]
        sut.presentInsights(response: .init(insights: insights))
        XCTAssertEqual(spy.insights?.count, 2)
    }

    func test_presentInsights_emptyList_displaysEmpty() {
        let (sut, spy) = makeSUT()
        let empty: [InsightItem] = []
        sut.presentInsights(response: .init(insights: empty))
        XCTAssertEqual(spy.insights?.count, 0)
    }

    // MARK: - presentLessonScheduled

    private func makePlannedSession(childId: String = "c1") -> PlannedSession {
        PlannedSession(id: UUID().uuidString, childId: childId, date: Date(), lessonTemplate: "listen-and-choose", notificationScheduled: false)
    }

    func test_presentLessonScheduled_callsDisplayWithToast() {
        let (sut, spy) = makeSUT()
        sut.presentLessonScheduled(response: .init(plan: makePlannedSession(), childName: "Ваня", voiceHint: "Молодец!"))
        XCTAssertFalse(spy.toastMessages.isEmpty)
    }

    func test_presentLessonScheduled_setsVoiceHint() {
        let (sut, spy) = makeSUT()
        sut.presentLessonScheduled(response: .init(plan: makePlannedSession(), childName: "Маша", voiceHint: "Отлично!"))
        XCTAssertEqual(spy.scheduledVoiceHint, "Отлично!")
    }

    // MARK: - Toast methods

    func test_presentRecurringPlanAdded_callsDisplayToast() {
        let (sut, spy) = makeSUT()
        let plan = RecurringPlan(id: "rp1", childId: "c1", weekday: 1, hour: 10, minute: 0, lessonTemplate: "breathing", isActive: true)
        sut.presentRecurringPlanAdded(response: .init(plan: plan))
        XCTAssertFalse(spy.toastMessages.isEmpty)
    }

    func test_presentRecurringPlanRemoved_callsDisplayToast() {
        let (sut, spy) = makeSUT()
        sut.presentRecurringPlanRemoved(response: .init(planId: "rp1"))
        XCTAssertFalse(spy.toastMessages.isEmpty)
    }

    func test_presentSpecialistVisitAdded_callsDisplayToast() {
        let (sut, spy) = makeSUT()
        let visit = SpecialistVisit(id: "v1", childId: "c1", date: Date(), specialistName: "Марина Ивановна", notes: "", reportRequested: false)
        sut.presentSpecialistVisitAdded(response: .init(visit: visit))
        XCTAssertFalse(spy.toastMessages.isEmpty)
    }

    // MARK: - presentWeekSummary

    func test_presentWeekSummary_singleChild_computesTotalCorrectly() {
        let (sut, spy) = makeSUT()
        let summary = WeekChildSummary(
            childId: "c1",
            childName: "Ваня",
            sessionsAchieved: 4,
            sessionsGoal: 5,
            goalReached: false,
            avgSuccessRate: 0.8,
            totalMinutes: 90,
            plannedCount: 1
        )
        let weekStart = Calendar.current.startOfDay(for: Date())
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)!
        sut.presentWeekSummary(response: .init(
            weekStart: weekStart,
            weekEnd: weekEnd,
            childSummaries: [summary]
        ))
        XCTAssertEqual(spy.weekSummaryVM?.familyTotalSessions, 4)
        XCTAssertEqual(spy.weekSummaryVM?.familyTotalMinutes, 90)
    }

    func test_presentWeekSummary_allGoalsReached_isTrue() {
        let (sut, spy) = makeSUT()
        let summary = WeekChildSummary(
            childId: "c1",
            childName: "Маша",
            sessionsAchieved: 5,
            sessionsGoal: 5,
            goalReached: true,
            avgSuccessRate: 0.9,
            totalMinutes: 120,
            plannedCount: 0
        )
        let weekStart = Date()
        sut.presentWeekSummary(response: .init(
            weekStart: weekStart,
            weekEnd: weekStart.addingTimeInterval(7 * 86400),
            childSummaries: [summary]
        ))
        XCTAssertTrue(spy.weekSummaryVM?.allGoalsReached ?? false)
    }

    func test_presentWeekSummary_hoursAndMinutes_durationTextNotEmpty() {
        let (sut, spy) = makeSUT()
        let summary = WeekChildSummary(
            childId: "c1",
            childName: "Петя",
            sessionsAchieved: 3,
            sessionsGoal: 4,
            goalReached: false,
            avgSuccessRate: 0.6,
            totalMinutes: 75,
            plannedCount: 1
        )
        let weekStart = Date()
        sut.presentWeekSummary(response: .init(
            weekStart: weekStart,
            weekEnd: weekStart.addingTimeInterval(7 * 86400),
            childSummaries: [summary]
        ))
        let row = spy.weekSummaryVM?.childRows.first
        XCTAssertFalse(row?.durationText.isEmpty ?? true)
    }

    // MARK: - presentError

    func test_presentError_callsDisplayError() {
        let (sut, spy) = makeSUT()
        sut.presentError(response: .init(message: "Что-то пошло не так"))
        XCTAssertEqual(spy.errorMessage, "Что-то пошло не так")
    }

    // MARK: - presentLoading

    func test_presentLoading_true() {
        let (sut, spy) = makeSUT()
        sut.presentLoading(isLoading: true)
        XCTAssertTrue(spy.loadingState ?? false)
    }

    func test_presentLoading_false() {
        let (sut, spy) = makeSUT()
        sut.presentLoading(isLoading: false)
        XCTAssertFalse(spy.loadingState ?? true)
    }

    // MARK: - presentInsightsLoading

    func test_presentInsightsLoading_true() {
        let (sut, spy) = makeSUT()
        sut.presentInsightsLoading(isLoading: true)
        XCTAssertTrue(spy.insightsLoadingState ?? false)
    }

    // MARK: - Comparison cards (selectedChildId = nil, 2+ children)

    func test_presentDataLoaded_twoChildren_comparisonCardsBuilt() {
        let (sut, spy) = makeSUT()
        let c1 = makeChild(id: "c1", name: "Ваня")
        let c2 = makeChild(id: "c2", name: "Маша")
        // Sessions: c1 correct 8/10, c2 correct 6/10
        let s1 = makeSession(childId: "c1")
        let s2 = makeSession(childId: "c2")
        sut.presentDataLoaded(response: FamilyCalendarResponse.DataLoaded(
            children: [c1, c2],
            sessions: [s1, s2],
            selectedChildId: nil,
            currentMonth: Date(),
            weekOffset: 0,
            weeklyGoals: [:],
            plannedSessions: [],
            recurringPlans: [],
            specialistVisits: []
        ))
        XCTAssertEqual(spy.familyDataVM?.comparisonCards.count, 2)
    }

    func test_presentDataLoaded_singleChild_noComparisonCards() {
        let (sut, spy) = makeSUT()
        sut.presentDataLoaded(response: baseDataLoaded(children: [makeChild()]))
        XCTAssertEqual(spy.familyDataVM?.comparisonCards.count, 0)
    }
}
