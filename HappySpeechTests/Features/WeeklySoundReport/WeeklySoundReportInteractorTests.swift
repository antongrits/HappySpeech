@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Test Doubles

private final class WSRMockHapticService: HapticService, @unchecked Sendable {
    var impactCount = 0
    var selectionCount = 0
    var notificationCount = 0
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async {}
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { impactCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { notificationCount += 1 }
    func selection() { selectionCount += 1 }
    func playLevelUp() async {}
}

private struct WSRMockWorker: WeeklySoundReportWorkerProtocol {
    var response: WeeklySoundReportModels.Load.Response
    var shouldFail = false

    func fetchReportData(
        childId: String,
        weekOffset: Int
    ) async throws -> WeeklySoundReportModels.Load.Response {
        if shouldFail { throw AppError.entityNotFound(childId) }
        return response
    }
}

@MainActor
private final class WSRSpyPresenter: WeeklySoundReportPresentationLogic {
    var loadCalled = false
    var loadFailureCalled = false
    var selectSoundCalled = false
    var shareCalled = false

    var lastLoadResponse: WeeklySoundReportModels.Load.Response?
    var lastWeekOffset: Int?
    var lastSelectResponse: WeeklySoundReportModels.SelectSound.Response?

    func presentLoad(response: WeeklySoundReportModels.Load.Response, weekOffset: Int) async {
        loadCalled = true
        lastLoadResponse = response
        lastWeekOffset = weekOffset
    }
    func presentLoadFailure() async { loadFailureCalled = true }
    func presentSelectSound(response: WeeklySoundReportModels.SelectSound.Response) async {
        selectSoundCalled = true
        lastSelectResponse = response
    }
    func presentShare(response: WeeklySoundReportModels.Load.Response, weekOffset: Int) async {
        shareCalled = true
    }
}

// MARK: - Builders

private func makeAttempt(word: String, correct: Bool, score: Double = 0.8) -> AttemptDTO {
    AttemptDTO(
        id: UUID().uuidString,
        word: word,
        audioLocalPath: "",
        audioStoragePath: "",
        asrTranscript: word,
        asrScore: score,
        pronunciationScore: -1,
        manualScore: -1,
        isCorrect: correct,
        timestamp: Date()
    )
}

private func makeSession(
    sound: String,
    date: Date,
    attempts: [AttemptDTO],
    total: Int? = nil,
    correct: Int? = nil
) -> SessionDTO {
    let correctCount = correct ?? attempts.filter(\.isCorrect).count
    let totalCount = total ?? attempts.count
    return SessionDTO(
        id: UUID().uuidString,
        childId: "child-1",
        date: date,
        templateType: "bingo",
        targetSound: sound,
        stage: "wordInit",
        durationSeconds: 300,
        totalAttempts: totalCount,
        correctAttempts: correctCount,
        fatigueDetected: false,
        isSynced: false,
        attempts: attempts
    )
}

private func makeResponse(
    week: [SessionDTO] = [],
    previous: [SessionDTO] = [],
    sounds: [String] = ["Ш"],
    name: String = "Миша"
) -> WeeklySoundReportModels.Load.Response {
    WeeklySoundReportModels.Load.Response(
        childName: name,
        weekSessions: week,
        previousWeekSessions: previous,
        targetSounds: sounds,
        weekStart: Date(),
        weekEnd: Date().addingTimeInterval(7 * 86_400)
    )
}

// MARK: - Tests

@MainActor
final class WeeklySoundReportInteractorTests: XCTestCase {

    private func makeSUT(
        response: WeeklySoundReportModels.Load.Response,
        shouldFail: Bool = false
    ) -> (WeeklySoundReportInteractor, WSRSpyPresenter, MockAnalyticsService, WSRMockHapticService) {
        let worker = WSRMockWorker(response: response, shouldFail: shouldFail)
        let analytics = MockAnalyticsService()
        let haptic = WSRMockHapticService()
        let sut = WeeklySoundReportInteractor(
            childId: "child-1",
            worker: worker,
            analyticsService: analytics,
            hapticService: haptic
        )
        let spy = WSRSpyPresenter()
        sut.presenter = spy
        return (sut, spy, analytics, haptic)
    }

    // MARK: load

    func test_load_callsPresenter() async {
        let (sut, spy, _, _) = makeSUT(response: makeResponse())
        await sut.load(request: .init(childId: "child-1", weekOffset: 0))
        XCTAssertTrue(spy.loadCalled)
        XCTAssertEqual(spy.lastWeekOffset, 0)
    }

    func test_load_storesResponseAndChildId() async {
        let (sut, _, _, _) = makeSUT(response: makeResponse(name: "Аня"))
        await sut.load(request: .init(childId: "child-99", weekOffset: -2))
        XCTAssertEqual(sut.childId, "child-99")
        XCTAssertEqual(sut.weekOffset, -2)
        XCTAssertEqual(sut.lastResponse?.childName, "Аня")
    }

    func test_load_tracksAnalyticsEvent() async {
        let (sut, _, analytics, _) = makeSUT(response: makeResponse())
        await sut.load(request: .init(childId: "child-1", weekOffset: -1))
        XCTAssertTrue(analytics.events.contains { $0.name == "weekly_report_viewed" })
        XCTAssertEqual(
            analytics.events.first { $0.name == "weekly_report_viewed" }?.parameters["weekOffset"],
            "-1"
        )
    }

    func test_load_failure_callsPresentLoadFailure() async {
        let (sut, spy, _, _) = makeSUT(response: makeResponse(), shouldFail: true)
        await sut.load(request: .init(childId: "child-1", weekOffset: 0))
        XCTAssertTrue(spy.loadFailureCalled)
        XCTAssertFalse(spy.loadCalled)
    }

    // MARK: selectSound

    func test_selectSound_withoutLoad_doesNothing() async {
        let (sut, spy, _, _) = makeSUT(response: makeResponse())
        await sut.selectSound(request: .init(soundTarget: "Ш"))
        XCTAssertFalse(spy.selectSoundCalled)
    }

    func test_selectSound_firesHaptic() async {
        let session = makeSession(
            sound: "Ш",
            date: Date(),
            attempts: [makeAttempt(word: "шапка", correct: true)]
        )
        let (sut, _, _, haptic) = makeSUT(response: makeResponse(week: [session]))
        await sut.load(request: .init(childId: "child-1", weekOffset: 0))
        await sut.selectSound(request: .init(soundTarget: "Ш"))
        XCTAssertEqual(haptic.impactCount, 1)
    }

    func test_selectSound_topWordsSortedByRate() async {
        let session = makeSession(
            sound: "Ш",
            date: Date(),
            attempts: [
                makeAttempt(word: "шапка", correct: true),
                makeAttempt(word: "шуба", correct: false),
                makeAttempt(word: "шуба", correct: false)
            ]
        )
        let (sut, spy, _, _) = makeSUT(response: makeResponse(week: [session]))
        await sut.load(request: .init(childId: "child-1", weekOffset: 0))
        await sut.selectSound(request: .init(soundTarget: "Ш"))
        let top = spy.lastSelectResponse?.topWords ?? []
        XCTAssertEqual(top.first?.word, "шапка")
        XCTAssertEqual(top.first?.successRate, 1.0)
    }

    func test_selectSound_weakWordsBelowThreshold() async {
        let session = makeSession(
            sound: "Ш",
            date: Date(),
            attempts: [
                makeAttempt(word: "шапка", correct: true),
                makeAttempt(word: "шуба", correct: false),
                makeAttempt(word: "шуба", correct: false)
            ]
        )
        let (sut, spy, _, _) = makeSUT(response: makeResponse(week: [session]))
        await sut.load(request: .init(childId: "child-1", weekOffset: 0))
        await sut.selectSound(request: .init(soundTarget: "Ш"))
        let weak = spy.lastSelectResponse?.weakWords ?? []
        XCTAssertEqual(weak.count, 1)
        XCTAssertEqual(weak.first?.word, "шуба")
        XCTAssertLessThan(weak.first?.successRate ?? 1, 0.8)
    }

    // MARK: share

    func test_shareReport_withoutLoad_doesNothing() async {
        let (sut, spy, _, _) = makeSUT(response: makeResponse())
        await sut.shareReport(request: .init())
        XCTAssertFalse(spy.shareCalled)
    }

    func test_shareReport_afterLoad_callsPresenterAndTracks() async {
        let (sut, spy, analytics, _) = makeSUT(response: makeResponse())
        await sut.load(request: .init(childId: "child-1", weekOffset: 0))
        await sut.shareReport(request: .init())
        XCTAssertTrue(spy.shareCalled)
        XCTAssertTrue(analytics.events.contains { $0.name == "weekly_report_shared" })
    }

    // MARK: wordStats aggregation (static)

    func test_wordStats_aggregatesByWord() {
        let session = makeSession(
            sound: "Р",
            date: Date(),
            attempts: [
                makeAttempt(word: "рыба", correct: true),
                makeAttempt(word: "рыба", correct: false),
                makeAttempt(word: "роза", correct: true)
            ]
        )
        let stats = WeeklySoundReportInteractor.wordStats(for: "Р", in: [session])
        XCTAssertEqual(stats.count, 2)
        let ryba = stats.first { $0.word == "рыба" }
        XCTAssertEqual(ryba?.attemptCount, 2)
        XCTAssertEqual(ryba?.successRate, 0.5)
    }

    func test_wordStats_ignoresOtherSounds() {
        let session = makeSession(
            sound: "С",
            date: Date(),
            attempts: [makeAttempt(word: "сок", correct: true)]
        )
        let stats = WeeklySoundReportInteractor.wordStats(for: "Ш", in: [session])
        XCTAssertTrue(stats.isEmpty)
    }

    func test_wordStats_ignoresEmptyWords() {
        let session = makeSession(
            sound: "Ш",
            date: Date(),
            attempts: [makeAttempt(word: "", correct: true)]
        )
        let stats = WeeklySoundReportInteractor.wordStats(for: "Ш", in: [session])
        XCTAssertTrue(stats.isEmpty)
    }

    // MARK: recommendation (static)

    func test_recommendation_emptyWeakWords_keepGoing() {
        let (key, arg) = WeeklySoundReportInteractor.recommendation(for: "Ш", weakWords: [])
        XCTAssertEqual(key, "weeklyReport.recommendation.keepGoing")
        XCTAssertEqual(arg, "Ш")
    }

    func test_recommendation_initialPosition() {
        let weak = [
            WeeklyWordStat(id: "шапка", word: "шапка", successRate: 0.3, attemptCount: 3),
            WeeklyWordStat(id: "шуба", word: "шуба", successRate: 0.2, attemptCount: 3)
        ]
        let (key, _) = WeeklySoundReportInteractor.recommendation(for: "Ш", weakWords: weak)
        XCTAssertEqual(key, "weeklyReport.recommendation.positionInitial")
    }

    func test_recommendation_finalPosition() {
        let weak = [
            WeeklyWordStat(id: "душ", word: "душ", successRate: 0.3, attemptCount: 3),
            WeeklyWordStat(id: "ёрш", word: "ёрш", successRate: 0.2, attemptCount: 3)
        ]
        let (key, _) = WeeklySoundReportInteractor.recommendation(for: "ш", weakWords: weak)
        XCTAssertEqual(key, "weeklyReport.recommendation.positionFinal")
    }

    func test_recommendation_middlePosition_fallback() {
        let weak = [
            WeeklyWordStat(id: "крыша", word: "крыша", successRate: 0.3, attemptCount: 3)
        ]
        let (key, _) = WeeklySoundReportInteractor.recommendation(for: "ш", weakWords: weak)
        XCTAssertEqual(key, "weeklyReport.recommendation.positionMiddle")
    }

    // MARK: weekBounds (static)

    func test_weekBounds_offsetZeroAndMinusOneDiffer() {
        let current = WeeklySoundReportWorker.weekBounds(offset: 0)
        let previous = WeeklySoundReportWorker.weekBounds(offset: -1)
        XCTAssertLessThan(previous.start, current.start)
        XCTAssertEqual(previous.end, current.start)
    }

    func test_weekBounds_durationIsSevenDays() {
        let bounds = WeeklySoundReportWorker.weekBounds(offset: 0)
        let days = bounds.end.timeIntervalSince(bounds.start) / 86_400
        XCTAssertEqual(days, 7, accuracy: 0.1)
    }
}
