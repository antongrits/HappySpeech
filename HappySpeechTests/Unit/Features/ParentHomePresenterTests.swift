@testable import HappySpeech
import XCTest

// MARK: - ParentHomePresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие ParentHomePresenter (71% → цель ≥90%).

@MainActor
final class ParentHomePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ParentHomeDisplayLogic {
        var fetchVM: ParentHomeModels.Fetch.ViewModel?
        var isLoading: Bool?
        var emptyStateCalled = false
        var weeklyInsight: ParentHomeModels.WeeklyInsightResponse?
        var errorMessage: String?
        var addChildCalled = false
        var exportSpecialistChildId: String?
        var startLessonChildId: String?

        func displayFetch(_ viewModel: ParentHomeModels.Fetch.ViewModel) { fetchVM = viewModel }
        func displayLoading(_ isLoading: Bool) { self.isLoading = isLoading }
        func displayEmptyState() { emptyStateCalled = true }
        func displayWeeklyInsight(_ response: ParentHomeModels.WeeklyInsightResponse) { weeklyInsight = response }
        func displayError(_ message: String) { errorMessage = message }
        func displayNavigateToAddChild() { addChildCalled = true }
        func displayNavigateToSpecialistExport(childId: String) { exportSpecialistChildId = childId }
        func displayNavigateToStartLesson(childId: String) { startLessonChildId = childId }
    }

    private func makeSUT() -> (ParentHomePresenter, DisplaySpy) {
        let presenter = ParentHomePresenter()
        let spy = DisplaySpy()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    // MARK: - Helpers

    private func makeSessionData(
        targetSound: String = "С",
        templateType: String = "listen-and-choose",
        durationSeconds: Int = 600,
        totalAttempts: Int = 10,
        correctAttempts: Int = 8
    ) -> ParentHomeModels.SessionData {
        ParentHomeModels.SessionData(
            id: UUID().uuidString,
            date: Date(),
            templateType: templateType,
            targetSound: targetSound,
            durationSeconds: durationSeconds,
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts
        )
    }

    private func makeResponse(
        childId: String = "c-1",
        childName: String = "Ваня",
        childAge: Int = 6,
        targetSounds: [String] = ["С", "Р"],
        currentStreak: Int = 5,
        recentSessions: [ParentHomeModels.SessionData] = [],
        weekSessions: [SessionDTO] = [],
        progressSummary: [String: Double] = [:],
        screeningOutcome: ScreeningOutcomeDTO? = nil
    ) -> ParentHomeModels.Fetch.Response {
        ParentHomeModels.Fetch.Response(
            childId: childId,
            childName: childName,
            childAge: childAge,
            targetSounds: targetSounds,
            currentStreak: currentStreak,
            totalSessionMinutes: 120,
            overallRate: 0.75,
            recentSessions: recentSessions,
            progressSummary: progressSummary,
            homeTask: nil,
            screeningOutcome: screeningOutcome,
            allChildren: [],
            weekSessions: weekSessions,
            achievements: [],
            notifications: []
        )
    }

    private func makeSessionDTO(targetSound: String = "С", date: Date = Date()) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: "c-1",
            date: date,
            templateType: "listen-and-choose",
            targetSound: targetSound,
            stage: "word",
            durationSeconds: 600,
            totalAttempts: 10,
            correctAttempts: 8,
            fatigueDetected: false,
            isSynced: true,
            attempts: []
        )
    }

    // MARK: - presentFetch

    func test_presentFetch_setsChildNameAndId() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(childId: "c-1", childName: "Петя"))
        XCTAssertEqual(spy.fetchVM?.childId, "c-1")
        XCTAssertEqual(spy.fetchVM?.childName, "Петя")
    }

    func test_presentFetch_greetingNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse())
        XCTAssertFalse(spy.fetchVM?.greeting.isEmpty ?? true)
    }

    func test_presentFetch_targetSoundsText_joinedWithComma() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["С", "Р", "Л"]))
        XCTAssertTrue(spy.fetchVM?.targetSoundsText.contains(",") ?? false)
    }

    func test_presentFetch_soundProgress_countMatchesTargetSounds() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["С", "Ш"]))
        XCTAssertEqual(spy.fetchVM?.soundProgress.count, 2)
    }

    func test_presentFetch_highRate_stageIsStory() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["С"], progressSummary: ["С": 0.95]))
        let progress = spy.fetchVM?.soundProgress.first
        XCTAssertFalse(progress?.currentStage.isEmpty ?? true)
    }

    func test_presentFetch_lowRate_stageIsIsolated() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["Р"], progressSummary: ["Р": 0.1]))
        let progress = spy.fetchVM?.soundProgress.first
        XCTAssertFalse(progress?.currentStage.isEmpty ?? true)
    }

    func test_presentFetch_noRecentSessions_lastSessionIsNil() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(recentSessions: []))
        XCTAssertNil(spy.fetchVM?.lastSession)
    }

    func test_presentFetch_withRecentSession_lastSessionNotNil() {
        let (sut, spy) = makeSUT()
        let session = makeSessionData()
        sut.presentFetch(makeResponse(recentSessions: [session]))
        XCTAssertNotNil(spy.fetchVM?.lastSession)
    }

    func test_presentFetch_sessionSuccessRate_calculatedCorrectly() {
        let (sut, spy) = makeSUT()
        let session = makeSessionData(totalAttempts: 10, correctAttempts: 8)
        sut.presentFetch(makeResponse(recentSessions: [session]))
        XCTAssertEqual(spy.fetchVM?.lastSession?.successRate ?? 0, 0.8, accuracy: 0.001)
    }

    func test_presentFetch_zeroAttempts_successRateIsZero() {
        let (sut, spy) = makeSUT()
        let session = makeSessionData(totalAttempts: 0, correctAttempts: 0)
        sut.presentFetch(makeResponse(recentSessions: [session]))
        XCTAssertEqual(spy.fetchVM?.lastSession?.successRate ?? 1, 0.0, accuracy: 0.001)
    }

    func test_presentFetch_quickActionsHasFourItems() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse())
        XCTAssertEqual(spy.fetchVM?.quickActions.count, 4)
    }

    func test_presentFetch_noScreeningOutcome_screeningCardIsNil() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(screeningOutcome: nil))
        XCTAssertNil(spy.fetchVM?.screeningCard)
    }

    func test_presentFetch_mildScreeningOutcome_screeningCardNotNil() {
        let (sut, spy) = makeSUT()
        let outcome = ScreeningOutcomeDTO(
            childId: "c-1",
            completedAt: Date(timeIntervalSinceNow: -86400),
            overallSeverity: "mild",
            problematicSounds: []
        )
        sut.presentFetch(makeResponse(screeningOutcome: outcome))
        XCTAssertNotNil(spy.fetchVM?.screeningCard)
    }

    func test_presentFetch_moderateScreeningOutcome_recommendationNotEmpty() {
        let (sut, spy) = makeSUT()
        let outcome = ScreeningOutcomeDTO(
            childId: "c-1",
            completedAt: Date(timeIntervalSinceNow: -86400),
            overallSeverity: "moderate",
            problematicSounds: ["Р", "Л"]
        )
        sut.presentFetch(makeResponse(screeningOutcome: outcome))
        XCTAssertFalse(spy.fetchVM?.screeningCard?.recommendationText.isEmpty ?? true)
    }

    func test_presentFetch_severeScreeningOutcome_recommendationNotEmpty() {
        let (sut, spy) = makeSUT()
        let outcome = ScreeningOutcomeDTO(
            childId: "c-1",
            completedAt: Date(timeIntervalSinceNow: -86400),
            overallSeverity: "severe",
            problematicSounds: ["Р"]
        )
        sut.presentFetch(makeResponse(screeningOutcome: outcome))
        XCTAssertFalse(spy.fetchVM?.screeningCard?.recommendationText.isEmpty ?? true)
    }

    func test_presentFetch_screeningOlderThan14Days_canRetakeIsTrue() {
        let (sut, spy) = makeSUT()
        let outcome = ScreeningOutcomeDTO(
            childId: "c-1",
            completedAt: Date(timeIntervalSinceNow: -15 * 86400),
            overallSeverity: "mild"
        )
        sut.presentFetch(makeResponse(screeningOutcome: outcome))
        XCTAssertTrue(spy.fetchVM?.screeningCard?.canRetake ?? false)
    }

    func test_presentFetch_screeningRecent_canRetakeIsFalse() {
        let (sut, spy) = makeSUT()
        let outcome = ScreeningOutcomeDTO(
            childId: "c-1",
            completedAt: Date(timeIntervalSinceNow: -86400),
            overallSeverity: "mild"
        )
        sut.presentFetch(makeResponse(screeningOutcome: outcome))
        XCTAssertFalse(spy.fetchVM?.screeningCard?.canRetake ?? true)
    }

    func test_presentFetch_recommendationsBuilt_forLowRate() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["С"], progressSummary: ["С": 0.2]))
        XCTAssertFalse(spy.fetchVM?.recommendations.isEmpty ?? true)
    }

    func test_presentFetch_recommendationsBuilt_forMidRate() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["Р"], progressSummary: ["Р": 0.5]))
        XCTAssertFalse(spy.fetchVM?.recommendations.isEmpty ?? true)
    }

    func test_presentFetch_highRate_defaultRecommendation() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["С"], progressSummary: ["С": 0.97]))
        XCTAssertFalse(spy.fetchVM?.recommendations.isEmpty ?? true)
    }

    func test_presentFetch_needsSpecialistReview_trueWhenLowRate3Sessions() {
        let (sut, spy) = makeSUT()
        let sessions = [makeSessionDTO(targetSound: "Р"), makeSessionDTO(targetSound: "Р"), makeSessionDTO(targetSound: "Р")]
        sut.presentFetch(makeResponse(targetSounds: ["Р"], weekSessions: sessions, progressSummary: ["Р": 0.2]))
        XCTAssertTrue(spy.fetchVM?.needsSpecialistReview ?? false)
    }

    // MARK: - presentLoading

    func test_presentLoading_true() {
        let (sut, spy) = makeSUT()
        sut.presentLoading(true)
        XCTAssertTrue(spy.isLoading ?? false)
    }

    func test_presentLoading_false() {
        let (sut, spy) = makeSUT()
        sut.presentLoading(false)
        XCTAssertFalse(spy.isLoading ?? true)
    }

    // MARK: - presentEmpty

    func test_presentEmpty_callsDisplayEmptyState() {
        let (sut, spy) = makeSUT()
        sut.presentEmpty()
        XCTAssertTrue(spy.emptyStateCalled)
    }

    // MARK: - presentWeeklyInsight

    func test_presentWeeklyInsight_passesThrough() {
        let (sut, spy) = makeSUT()
        let insight = ParentHomeModels.WeeklyInsight(
            summaryText: "Хорошая неделя",
            highlights: ["Регулярные занятия"],
            recommendations: ["Продолжайте в том же духе"],
            source: .ruleBased
        )
        let response = ParentHomeModels.WeeklyInsightResponse(dayStat: [], insight: insight)
        sut.presentWeeklyInsight(response)
        XCTAssertNotNil(spy.weeklyInsight)
    }

    // MARK: - presentError

    func test_presentError_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentError("Не удалось загрузить данные")
        XCTAssertEqual(spy.errorMessage, "Не удалось загрузить данные")
    }

    // MARK: - Navigation

    func test_presentAddChild_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentAddChild()
        XCTAssertTrue(spy.addChildCalled)
    }

    func test_presentExportSpecialist_passesChildId() {
        let (sut, spy) = makeSUT()
        sut.presentExportSpecialist(childId: "child-xyz")
        XCTAssertEqual(spy.exportSpecialistChildId, "child-xyz")
    }

    func test_presentStartLesson_passesChildId() {
        let (sut, spy) = makeSUT()
        sut.presentStartLesson(childId: "child-abc")
        XCTAssertEqual(spy.startLessonChildId, "child-abc")
    }

    // MARK: - Sound family name helpers (indirect via soundProgress)

    func test_presentFetch_whistlingSoundFamily_notEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["С"]))
        XCTAssertFalse(spy.fetchVM?.soundProgress.first?.familyName.isEmpty ?? true)
    }

    func test_presentFetch_hissingSoundFamily_notEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(targetSounds: ["Ш"]))
        XCTAssertFalse(spy.fetchVM?.soundProgress.first?.familyName.isEmpty ?? true)
    }
}
