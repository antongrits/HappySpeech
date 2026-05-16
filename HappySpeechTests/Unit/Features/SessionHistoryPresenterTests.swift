@testable import HappySpeech
import XCTest

// MARK: - SessionHistoryPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие SessionHistoryPresenter (35% → цель ≥90%).

@MainActor
final class SessionHistoryPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SessionHistoryDisplayLogic {
        var loadHistoryVM: SessionHistoryModels.LoadHistory.ViewModel?
        var applyFilterVM: SessionHistoryModels.ApplyFilter.ViewModel?
        var clearFilterVM: SessionHistoryModels.ClearFilter.ViewModel?
        var applySortVM: SessionHistoryModels.ApplySort.ViewModel?
        var loadNextPageVM: SessionHistoryModels.LoadNextPage.ViewModel?
        var openSessionVM: SessionHistoryModels.OpenSession.ViewModel?
        var addNoteVM: SessionHistoryModels.AddNote.ViewModel?
        var deleteNoteVM: SessionHistoryModels.DeleteNote.ViewModel?
        var exportPDFVM: SessionHistoryModels.ExportPDF.ViewModel?
        var exportCSVVM: SessionHistoryModels.ExportCSV.ViewModel?
        var exportJSONVM: SessionHistoryModels.ExportJSON.ViewModel?
        var audioStateVM: SessionHistoryModels.AudioState.ViewModel?
        var statsSummaryVM: SessionHistoryModels.LoadStatsSummary.ViewModel?
        var lyalyaCommentVM: SessionHistoryModels.LoadLyalyaComment.ViewModel?
        var searchVM: SessionHistoryModels.Search.ViewModel?
        var failureVM: SessionHistoryModels.Failure.ViewModel?

        func displayLoadHistory(_ viewModel: SessionHistoryModels.LoadHistory.ViewModel) { loadHistoryVM = viewModel }
        func displayApplyFilter(_ viewModel: SessionHistoryModels.ApplyFilter.ViewModel) { applyFilterVM = viewModel }
        func displayClearFilter(_ viewModel: SessionHistoryModels.ClearFilter.ViewModel) { clearFilterVM = viewModel }
        func displayApplySort(_ viewModel: SessionHistoryModels.ApplySort.ViewModel) { applySortVM = viewModel }
        func displayLoadNextPage(_ viewModel: SessionHistoryModels.LoadNextPage.ViewModel) { loadNextPageVM = viewModel }
        func displayOpenSession(_ viewModel: SessionHistoryModels.OpenSession.ViewModel) { openSessionVM = viewModel }
        func displayAddNote(_ viewModel: SessionHistoryModels.AddNote.ViewModel) { addNoteVM = viewModel }
        func displayDeleteNote(_ viewModel: SessionHistoryModels.DeleteNote.ViewModel) { deleteNoteVM = viewModel }
        func displayExportPDF(_ viewModel: SessionHistoryModels.ExportPDF.ViewModel) { exportPDFVM = viewModel }
        func displayExportCSV(_ viewModel: SessionHistoryModels.ExportCSV.ViewModel) { exportCSVVM = viewModel }
        func displayExportJSON(_ viewModel: SessionHistoryModels.ExportJSON.ViewModel) { exportJSONVM = viewModel }
        func displayAudioState(_ viewModel: SessionHistoryModels.AudioState.ViewModel) { audioStateVM = viewModel }
        func displayStatsSummary(_ viewModel: SessionHistoryModels.LoadStatsSummary.ViewModel) { statsSummaryVM = viewModel }
        func displayLyalyaComment(_ viewModel: SessionHistoryModels.LoadLyalyaComment.ViewModel) { lyalyaCommentVM = viewModel }
        func displaySearch(_ viewModel: SessionHistoryModels.Search.ViewModel) { searchVM = viewModel }
        func displayFailure(_ viewModel: SessionHistoryModels.Failure.ViewModel) { failureVM = viewModel }
        func displayLoading(_ isLoading: Bool) {}
    }

    private func makeSUT() -> (SessionHistoryPresenter, DisplaySpy) {
        let presenter = SessionHistoryPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeRecord(
        id: String = UUID().uuidString,
        date: Date = Date(),
        gameType: TemplateType = .listenAndChoose,
        soundTarget: String = "С",
        score: Float = 0.8,
        durationSec: Int = 300,
        attempts: Int = 10
    ) -> SessionRecord {
        SessionRecord(
            id: id,
            date: date,
            gameType: gameType,
            soundTarget: soundTarget,
            score: score,
            durationSec: durationSec,
            attempts: attempts,
            isPassed: score >= 0.7
        )
    }

    private func makeAttempt(score: Float = 0.9, isCorrect: Bool = true) -> SessionAttemptRecord {
        SessionAttemptRecord(id: UUID().uuidString, word: "сапог", score: score, isCorrect: isCorrect, durationMs: 1500)
    }

    private func baseListContext(
        sessions: [SessionRecord] = [],
        allSessions: [SessionRecord] = [],
        filter: SessionHistoryFilter = .empty,
        sort: SessionHistorySort = .byDate
    ) -> SessionHistoryModels.LoadHistory.Response {
        SessionHistoryModels.LoadHistory.Response(
            sessions: sessions,
            allSessions: allSessions,
            activeFilter: filter,
            activeSort: sort,
            currentPage: 0,
            isLastPage: true,
            isFromCache: false
        )
    }

    // MARK: - presentLoadHistory

    func test_presentLoadHistory_noSessions_isEmptyTrue() {
        let (sut, spy) = makeSUT()
        sut.presentLoadHistory(baseListContext())
        XCTAssertTrue(spy.loadHistoryVM?.isEmpty ?? false)
    }

    func test_presentLoadHistory_noSessions_emptyKindIsNoSessions() {
        let (sut, spy) = makeSUT()
        sut.presentLoadHistory(baseListContext(sessions: [], allSessions: []))
        XCTAssertEqual(spy.loadHistoryVM?.emptyKind, .noSessions)
    }

    func test_presentLoadHistory_withSessions_groupsNotEmpty() {
        let (sut, spy) = makeSUT()
        let session = makeRecord()
        sut.presentLoadHistory(baseListContext(sessions: [session], allSessions: [session]))
        XCTAssertFalse(spy.loadHistoryVM?.groups.isEmpty ?? true)
    }

    func test_presentLoadHistory_totalCountMatchesAllSessions() {
        let (sut, spy) = makeSUT()
        let all = [makeRecord(), makeRecord()]
        sut.presentLoadHistory(baseListContext(sessions: all, allSessions: all))
        XCTAssertEqual(spy.loadHistoryVM?.totalCount, 2)
    }

    func test_presentLoadHistory_filteredResults_emptyKindIsNoResultsForFilter() {
        let (sut, spy) = makeSUT()
        let all = [makeRecord()]
        sut.presentLoadHistory(baseListContext(sessions: [], allSessions: all))
        XCTAssertEqual(spy.loadHistoryVM?.emptyKind, .noResultsForFilter)
    }

    func test_presentLoadHistory_soundChipsFromFilter() {
        let (sut, spy) = makeSUT()
        var filter = SessionHistoryFilter.empty
        filter.sounds = ["С", "Р"]
        sut.presentLoadHistory(baseListContext(filter: filter))
        XCTAssertEqual(spy.loadHistoryVM?.activeSoundChips.count, 2)
    }

    // MARK: - presentApplyFilter

    func test_presentApplyFilter_callsDisplay() {
        let (sut, spy) = makeSUT()
        let response = SessionHistoryModels.ApplyFilter.Response(
            sessions: [], allSessions: [], activeFilter: .empty, activeSort: .byDate,
            currentPage: 0, isLastPage: true
        )
        sut.presentApplyFilter(response)
        XCTAssertNotNil(spy.applyFilterVM)
    }

    // MARK: - presentClearFilter

    func test_presentClearFilter_callsDisplay() {
        let (sut, spy) = makeSUT()
        let response = SessionHistoryModels.ClearFilter.Response(
            sessions: [], allSessions: [], activeFilter: .empty, activeSort: .byDate,
            currentPage: 0, isLastPage: true
        )
        sut.presentClearFilter(response)
        XCTAssertNotNil(spy.clearFilterVM)
    }

    // MARK: - presentApplySort

    func test_presentApplySort_callsDisplay() {
        let (sut, spy) = makeSUT()
        let response = SessionHistoryModels.ApplySort.Response(
            sessions: [], allSessions: [], activeFilter: .empty, activeSort: .byScore,
            currentPage: 0, isLastPage: true
        )
        sut.presentApplySort(response)
        XCTAssertEqual(spy.applySortVM?.activeSort, .byScore)
    }

    // MARK: - presentLoadNextPage

    func test_presentLoadNextPage_callsDisplay() {
        let (sut, spy) = makeSUT()
        let session = makeRecord()
        let response = SessionHistoryModels.LoadNextPage.Response(
            sessions: [session],
            currentPage: 1,
            isLastPage: false,
            activeFilter: .empty,
            activeSort: .byDate
        )
        sut.presentLoadNextPage(response)
        XCTAssertNotNil(spy.loadNextPageVM)
    }

    // MARK: - presentOpenSession

    func test_presentOpenSession_buildsTitleAndDate() {
        let (sut, spy) = makeSUT()
        let session = makeRecord(score: 0.8)
        let attempt = makeAttempt()
        let response = SessionHistoryModels.OpenSession.Response(
            session: session,
            attempts: [attempt],
            parentNote: "Хорошо работал",
            hasAudioRecording: false
        )
        sut.presentOpenSession(response)
        XCTAssertFalse(spy.openSessionVM?.detail.titleLine.isEmpty ?? true)
        XCTAssertFalse(spy.openSessionVM?.detail.dateLine.isEmpty ?? true)
    }

    func test_presentOpenSession_highScore_tierIsExcellent() {
        let (sut, spy) = makeSUT()
        let session = makeRecord(score: 0.85)
        sut.presentOpenSession(.init(session: session, attempts: [], parentNote: nil, hasAudioRecording: false))
        XCTAssertEqual(spy.openSessionVM?.detail.scoreTier, .excellent)
    }

    func test_presentOpenSession_lowScore_tierIsLow() {
        let (sut, spy) = makeSUT()
        let session = makeRecord(score: 0.3)
        sut.presentOpenSession(.init(session: session, attempts: [], parentNote: nil, hasAudioRecording: false))
        XCTAssertEqual(spy.openSessionVM?.detail.scoreTier, .low)
    }

    func test_presentOpenSession_withAttempts_attemptRowsBuilt() {
        let (sut, spy) = makeSUT()
        let session = makeRecord()
        let attempts = [makeAttempt(score: 0.9, isCorrect: true), makeAttempt(score: 0.4, isCorrect: false)]
        sut.presentOpenSession(.init(session: session, attempts: attempts, parentNote: nil, hasAudioRecording: true))
        XCTAssertEqual(spy.openSessionVM?.detail.attemptRows.count, 2)
    }

    // MARK: - presentAddNote

    func test_presentAddNote_callsDisplayWithToast() {
        let (sut, spy) = makeSUT()
        sut.presentAddNote(.init(sessionId: "s-1", noteText: "Отлично"))
        XCTAssertFalse(spy.addNoteVM?.toastMessage.isEmpty ?? true)
        XCTAssertEqual(spy.addNoteVM?.sessionId, "s-1")
    }

    // MARK: - presentDeleteNote

    func test_presentDeleteNote_callsDisplayWithSessionId() {
        let (sut, spy) = makeSUT()
        sut.presentDeleteNote(.init(sessionId: "s-2"))
        XCTAssertEqual(spy.deleteNoteVM?.sessionId, "s-2")
    }

    // MARK: - Export methods

    func test_presentExportPDF_hasURLAndToast() {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        sut.presentExportPDF(.init(fileURL: url, exportFormat: .pdf, childId: "c-1"))
        XCTAssertEqual(spy.exportPDFVM?.shareURL, url)
        XCTAssertFalse(spy.exportPDFVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentExportCSV_hasURLAndToast() {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.csv")
        sut.presentExportCSV(.init(fileURL: url, exportFormat: .csv, childId: "c-1"))
        XCTAssertNotNil(spy.exportCSVVM?.shareURL)
        XCTAssertFalse(spy.exportCSVVM?.toastMessage.isEmpty ?? true)
    }

    func test_presentExportJSON_hasURLAndToast() {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.json")
        sut.presentExportJSON(.init(fileURL: url, exportFormat: .json, childId: "c-1"))
        XCTAssertNotNil(spy.exportJSONVM?.shareURL)
        XCTAssertFalse(spy.exportJSONVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentAudioState

    func test_presentAudioState_playing_progressTextNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentAudioState(.init(sessionId: "s-3", isPlaying: true, progress: 0.5, durationSeconds: 120))
        XCTAssertFalse(spy.audioStateVM?.progressText.isEmpty ?? true)
        XCTAssertTrue(spy.audioStateVM?.isPlaying ?? false)
    }

    func test_presentAudioState_stopped_progressTextEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentAudioState(.init(sessionId: "s-4", isPlaying: false, progress: 0, durationSeconds: 0))
        XCTAssertEqual(spy.audioStateVM?.progressText, "")
    }

    // MARK: - presentStatsSummary

    func test_presentStatsSummary_noData_soundsAreDefault() {
        let (sut, spy) = makeSUT()
        sut.presentStatsSummary(.init(
            totalSessions: 0,
            totalMinutes: 0,
            averageScorePercent: 0,
            bestSound: "—",
            hardestSound: "—",
            weekSessions: 0,
            prevWeekSessions: 0,
            soundBreakdown: []
        ))
        XCTAssertFalse(spy.statsSummaryVM?.bestSoundText.isEmpty ?? true)
        XCTAssertFalse(spy.statsSummaryVM?.hardestSoundText.isEmpty ?? true)
    }

    func test_presentStatsSummary_weekImproved_weekComparisonNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStatsSummary(.init(
            totalSessions: 10,
            totalMinutes: 120,
            averageScorePercent: 75,
            bestSound: "С",
            hardestSound: "Р",
            weekSessions: 5,
            prevWeekSessions: 3,
            soundBreakdown: []
        ))
        XCTAssertFalse(spy.statsSummaryVM?.weekComparisonText.isEmpty ?? true)
        XCTAssertEqual(spy.statsSummaryVM?.totalSessionsText, "10")
    }

    func test_presentStatsSummary_weekDeclined_weekComparisonNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStatsSummary(.init(
            totalSessions: 5,
            totalMinutes: 60,
            averageScorePercent: 60,
            bestSound: "Ш",
            hardestSound: "Р",
            weekSessions: 2,
            prevWeekSessions: 4,
            soundBreakdown: []
        ))
        XCTAssertFalse(spy.statsSummaryVM?.weekComparisonText.isEmpty ?? true)
    }

    func test_presentStatsSummary_firstWeek_prevIsZero_weekComparisonNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStatsSummary(.init(
            totalSessions: 3,
            totalMinutes: 30,
            averageScorePercent: 50,
            bestSound: "Л",
            hardestSound: "Р",
            weekSessions: 3,
            prevWeekSessions: 0,
            soundBreakdown: []
        ))
        XCTAssertFalse(spy.statsSummaryVM?.weekComparisonText.isEmpty ?? true)
    }

    func test_presentStatsSummary_minutesOver60_timeTextNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentStatsSummary(.init(
            totalSessions: 20,
            totalMinutes: 130,
            averageScorePercent: 80,
            bestSound: "С",
            hardestSound: "Ж",
            weekSessions: 5,
            prevWeekSessions: 5,
            soundBreakdown: []
        ))
        XCTAssertFalse(spy.statsSummaryVM?.totalTimeText.isEmpty ?? true)
    }

    // MARK: - presentLyalyaComment

    func test_presentLyalyaComment_passesThrough() {
        let (sut, spy) = makeSUT()
        sut.presentLyalyaComment(.init(commentText: "Ты молодец, продолжай!"))
        XCTAssertEqual(spy.lyalyaCommentVM?.commentText, "Ты молодец, продолжай!")
    }

    // MARK: - presentSearch

    func test_presentSearch_emptyQuery_emptyKindNoSessions() {
        let (sut, spy) = makeSUT()
        sut.presentSearch(.init(sessions: [], allSessions: [], query: "", activeFilter: .empty, activeSort: .byDate, currentPage: 0, isLastPage: true))
        XCTAssertEqual(spy.searchVM?.emptyKind, .noSessions)
    }

    func test_presentSearch_queryWithNoResults_emptyKindIsNoResultsForSearch() {
        let (sut, spy) = makeSUT()
        sut.presentSearch(.init(sessions: [], allSessions: [makeRecord()], query: "дракон", activeFilter: .empty, activeSort: .byDate, currentPage: 0, isLastPage: true))
        XCTAssertEqual(spy.searchVM?.emptyKind, .noResultsForSearch)
    }

    func test_presentSearch_withResults_isEmptyFalse() {
        let (sut, spy) = makeSUT()
        let session = makeRecord()
        sut.presentSearch(.init(sessions: [session], allSessions: [session], query: "С", activeFilter: .empty, activeSort: .byDate, currentPage: 0, isLastPage: true))
        XCTAssertFalse(spy.searchVM?.isEmpty ?? true)
    }

    // MARK: - presentFailure

    func test_presentFailure_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentFailure(.init(message: "Сетевая ошибка"))
        XCTAssertEqual(spy.failureVM?.toastMessage, "Сетевая ошибка")
    }
}
