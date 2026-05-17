@testable import HappySpeech
import XCTest

// MARK: - Display Spy

@MainActor
private final class WSRDisplaySpy: WeeklySoundReportDisplayLogic {
    var loadVM: WeeklySoundReportModels.Load.ViewModel?
    var loadFailureCalled = false
    var selectVM: WeeklySoundReportModels.SelectSound.ViewModel?
    var shareVM: WeeklySoundReportModels.Share.ViewModel?

    func displayLoad(viewModel: WeeklySoundReportModels.Load.ViewModel) async { loadVM = viewModel }
    func displayLoadFailure() async { loadFailureCalled = true }
    func displaySelectSound(viewModel: WeeklySoundReportModels.SelectSound.ViewModel) async { selectVM = viewModel }
    func displayShare(viewModel: WeeklySoundReportModels.Share.ViewModel) async { shareVM = viewModel }
}

// MARK: - Builders

private func wsrAttempt(word: String, correct: Bool, score: Double = 0.8) -> AttemptDTO {
    AttemptDTO(
        id: UUID().uuidString, word: word, audioLocalPath: "", audioStoragePath: "",
        asrTranscript: word, asrScore: score, pronunciationScore: -1, manualScore: -1,
        isCorrect: correct, timestamp: Date()
    )
}

private func wsrSession(
    sound: String,
    date: Date = Date(),
    total: Int,
    correct: Int,
    attempts: [AttemptDTO] = []
) -> SessionDTO {
    SessionDTO(
        id: UUID().uuidString, childId: "child-1", date: date, templateType: "bingo",
        targetSound: sound, stage: "wordInit", durationSeconds: 300,
        totalAttempts: total, correctAttempts: correct,
        fatigueDetected: false, isSynced: false, attempts: attempts
    )
}

private func wsrResponse(
    week: [SessionDTO],
    previous: [SessionDTO] = [],
    sounds: [String],
    name: String = "Миша"
) -> WeeklySoundReportModels.Load.Response {
    WeeklySoundReportModels.Load.Response(
        childName: name,
        weekSessions: week,
        previousWeekSessions: previous,
        targetSounds: sounds,
        weekStart: Date(timeIntervalSince1970: 1_700_000_000),
        weekEnd: Date(timeIntervalSince1970: 1_700_000_000 + 7 * 86_400)
    )
}

// MARK: - Tests

@MainActor
final class WeeklySoundReportPresenterTests: XCTestCase {

    private func makeSUT() -> (WeeklySoundReportPresenter, WSRDisplaySpy) {
        let spy = WSRDisplaySpy()
        let presenter = WeeklySoundReportPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    // MARK: trendArrow

    func test_trendArrow_up_whenDeltaAboveFivePercent() {
        XCTAssertEqual(WeeklySoundReportPresenter.trendArrow(current: 0.8, previous: 0.7), .up)
    }

    func test_trendArrow_down_whenDeltaBelowMinusFive() {
        XCTAssertEqual(WeeklySoundReportPresenter.trendArrow(current: 0.62, previous: 0.7), .down)
    }

    func test_trendArrow_stable_whenSmallDelta() {
        XCTAssertEqual(WeeklySoundReportPresenter.trendArrow(current: 0.70, previous: 0.70), .stable)
        XCTAssertEqual(WeeklySoundReportPresenter.trendArrow(current: 0.73, previous: 0.70), .stable)
    }

    func test_trendArrow_justInsideStableBand_isStable() {
        // Δ = +0.049 — внутри полосы стабильности (|Δ| ≤ 0.05).
        XCTAssertEqual(WeeklySoundReportPresenter.trendArrow(current: 0.749, previous: 0.70), .stable)
        // Δ = -0.049 — также внутри полосы.
        XCTAssertEqual(WeeklySoundReportPresenter.trendArrow(current: 0.70, previous: 0.749), .stable)
    }

    // MARK: averageRate

    func test_averageRate_zeroSessions_isZero() {
        XCTAssertEqual(WeeklySoundReportPresenter.averageRate(of: []), 0)
    }

    func test_averageRate_computesWeightedByAttempts() {
        let sessions = [
            wsrSession(sound: "Ш", total: 10, correct: 8),
            wsrSession(sound: "Ш", total: 10, correct: 6)
        ]
        XCTAssertEqual(WeeklySoundReportPresenter.averageRate(of: sessions), 0.7, accuracy: 0.001)
    }

    // MARK: activeDays

    func test_activeDays_countsUniqueCalendarDays() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(2 * 86_400)
        let sessions = [
            wsrSession(sound: "Ш", date: day1, total: 5, correct: 5),
            wsrSession(sound: "Ш", date: day1.addingTimeInterval(3600), total: 5, correct: 5),
            wsrSession(sound: "Ш", date: day2, total: 5, correct: 5)
        ]
        XCTAssertEqual(WeeklySoundReportPresenter.activeDays(in: sessions), 2)
    }

    func test_activeDays_emptyIsZero() {
        XCTAssertEqual(WeeklySoundReportPresenter.activeDays(in: []), 0)
    }

    // MARK: summaryLine

    func test_summaryLine_zeroSessions_returnsEmptyMessage() {
        let line = WeeklySoundReportPresenter.summaryLine(childName: "Миша", totalSessions: 0)
        XCTAssertFalse(line.isEmpty)
    }

    func test_summaryLine_greatWhenFiveOrMore() {
        let line = WeeklySoundReportPresenter.summaryLine(childName: "Миша", totalSessions: 5)
        XCTAssertTrue(line.contains("Миша"))
    }

    func test_summaryLine_usesDefaultNameWhenEmpty() {
        let line = WeeklySoundReportPresenter.summaryLine(childName: "", totalSessions: 3)
        XCTAssertFalse(line.isEmpty)
    }

    // MARK: buildSoundCards

    func test_buildSoundCards_skipsSoundsWithoutWeekSessions() {
        let response = wsrResponse(
            week: [wsrSession(sound: "Ш", total: 10, correct: 9)],
            sounds: ["Ш", "Р"]
        )
        let cards = WeeklySoundReportPresenter.buildSoundCards(from: response)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.id, "Ш")
    }

    func test_buildSoundCards_computesTrendFromPreviousWeek() {
        let response = wsrResponse(
            week: [wsrSession(sound: "Ш", total: 10, correct: 9)],
            previous: [wsrSession(sound: "Ш", total: 10, correct: 5)],
            sounds: ["Ш"]
        )
        let cards = WeeklySoundReportPresenter.buildSoundCards(from: response)
        XCTAssertEqual(cards.first?.trendArrow, .up)
        XCTAssertEqual(cards.first?.successRate ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(cards.first?.previousRate ?? 0, 0.5, accuracy: 0.001)
    }

    func test_buildSoundCards_sessionCountMatches() {
        let response = wsrResponse(
            week: [
                wsrSession(sound: "Ш", total: 10, correct: 9),
                wsrSession(sound: "Ш", total: 10, correct: 8)
            ],
            sounds: ["Ш"]
        )
        let cards = WeeklySoundReportPresenter.buildSoundCards(from: response)
        XCTAssertEqual(cards.first?.sessionCount, 2)
    }

    // MARK: presentLoad

    func test_presentLoad_buildsViewModel() async {
        let (sut, spy) = makeSUT()
        let response = wsrResponse(
            week: [wsrSession(sound: "Ш", total: 10, correct: 9)],
            sounds: ["Ш"]
        )
        await sut.presentLoad(response: response, weekOffset: 0)
        XCTAssertNotNil(spy.loadVM)
        XCTAssertEqual(spy.loadVM?.totalSessions, 1)
        XCTAssertEqual(spy.loadVM?.sounds.count, 1)
    }

    func test_presentLoad_canGoNextFalseForCurrentWeek() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: wsrResponse(week: [], sounds: []), weekOffset: 0)
        XCTAssertEqual(spy.loadVM?.canGoNext, false)
    }

    func test_presentLoad_canGoNextTrueForPastWeek() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: wsrResponse(week: [], sounds: []), weekOffset: -1)
        XCTAssertEqual(spy.loadVM?.canGoNext, true)
    }

    func test_presentLoadFailure_setsFlag() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadFailure()
        XCTAssertTrue(spy.loadFailureCalled)
    }

    // MARK: presentSelectSound

    func test_presentSelectSound_formatsWords() async {
        let (sut, spy) = makeSUT()
        let response = WeeklySoundReportModels.SelectSound.Response(
            topWords: [WeeklyWordStat(id: "шапка", word: "шапка", successRate: 0.95, attemptCount: 4)],
            weakWords: [WeeklyWordStat(id: "шуба", word: "шуба", successRate: 0.3, attemptCount: 3)],
            recommendationKey: "weeklyReport.recommendation.keepGoing",
            recommendationArgument: "Ш"
        )
        await sut.presentSelectSound(response: response)
        XCTAssertEqual(spy.selectVM?.topWordsFormatted.count, 1)
        XCTAssertEqual(spy.selectVM?.weakWordsFormatted.count, 1)
        XCTAssertEqual(spy.selectVM?.hasWords, true)
        XCTAssertTrue(spy.selectVM?.topWordsFormatted.first?.contains("шапка") ?? false)
    }

    func test_presentSelectSound_emptyWords_hasWordsFalse() async {
        let (sut, spy) = makeSUT()
        let response = WeeklySoundReportModels.SelectSound.Response(
            topWords: [], weakWords: [],
            recommendationKey: "weeklyReport.recommendation.keepGoing",
            recommendationArgument: "Р"
        )
        await sut.presentSelectSound(response: response)
        XCTAssertEqual(spy.selectVM?.hasWords, false)
    }

    // MARK: presentShare

    func test_presentShare_buildsNonEmptyText() async {
        let (sut, spy) = makeSUT()
        let response = wsrResponse(
            week: [wsrSession(sound: "Ш", total: 10, correct: 9)],
            sounds: ["Ш"]
        )
        await sut.presentShare(response: response, weekOffset: 0)
        XCTAssertNotNil(spy.shareVM)
        XCTAssertFalse(spy.shareVM?.shareText.isEmpty ?? true)
    }

    func test_presentShare_includesSoundLine() async {
        let (sut, spy) = makeSUT()
        let response = wsrResponse(
            week: [wsrSession(sound: "Р", total: 10, correct: 7)],
            sounds: ["Р"]
        )
        await sut.presentShare(response: response, weekOffset: 0)
        let text = spy.shareVM?.shareText ?? ""
        XCTAssertTrue(text.contains("Р"))
    }

    // MARK: formatWord / dateRangeLabel

    func test_formatWord_containsWordAndPercent() {
        let stat = WeeklyWordStat(id: "роза", word: "роза", successRate: 0.85, attemptCount: 5)
        let text = WeeklySoundReportPresenter.formatWord(stat)
        XCTAssertTrue(text.contains("роза"))
        XCTAssertTrue(text.contains("85"))
    }

    func test_dateRangeLabel_nonEmpty() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(7 * 86_400)
        let label = WeeklySoundReportPresenter.dateRangeLabel(start: start, end: end)
        XCTAssertFalse(label.isEmpty)
        XCTAssertTrue(label.contains("–"))
    }
}
