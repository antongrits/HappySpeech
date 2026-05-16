@testable import HappySpeech
import XCTest

// MARK: - SessionHistoryInteractorTests
//
// M10.1 — базовое покрытие (6 тестов).
// Plan v25 2.8.2 — расширено до 90%+: applySort, loadNextPage, addNote/deleteNote,
// exportPDF/CSV/JSON, playAudio/stopAudio, loadStatsSummary, loadLyalyaComment,
// performSearch + edge cases и ошибочные пути.

@MainActor
final class SessionHistoryInteractorTests: XCTestCase {

    // MARK: - Spy

    @MainActor
    private final class SpyPresenter: SessionHistoryPresentationLogic {
        var loadHistoryCalled = false
        var applyFilterCalled = false
        var clearFilterCalled = false
        var applySortCalled = false
        var loadNextPageCalled = false
        var openSessionCalled = false
        var addNoteCalled = false
        var deleteNoteCalled = false
        var exportPDFCalled = false
        var exportCSVCalled = false
        var exportJSONCalled = false
        var audioStateCalled = false
        var statsSummaryCalled = false
        var lyalyaCommentCalled = false
        var searchCalled = false
        var failureCalled = false

        var lastLoadHistoryResponse: SessionHistoryModels.LoadHistory.Response?
        var lastApplyFilterResponse: SessionHistoryModels.ApplyFilter.Response?
        var lastApplySortResponse: SessionHistoryModels.ApplySort.Response?
        var lastLoadNextPageResponse: SessionHistoryModels.LoadNextPage.Response?
        var lastOpenSessionResponse: SessionHistoryModels.OpenSession.Response?
        var lastAddNoteResponse: SessionHistoryModels.AddNote.Response?
        var lastDeleteNoteResponse: SessionHistoryModels.DeleteNote.Response?
        var lastExportPDFResponse: SessionHistoryModels.ExportPDF.Response?
        var lastExportCSVResponse: SessionHistoryModels.ExportCSV.Response?
        var lastExportJSONResponse: SessionHistoryModels.ExportJSON.Response?
        var lastAudioStateResponse: SessionHistoryModels.AudioState.Response?
        var lastStatsResponse: SessionHistoryModels.LoadStatsSummary.Response?
        var lastLyalyaResponse: SessionHistoryModels.LoadLyalyaComment.Response?
        var lastSearchResponse: SessionHistoryModels.Search.Response?
        var lastFailureResponse: SessionHistoryModels.Failure.Response?

        var exportExpectation: XCTestExpectation?

        func presentLoadHistory(_ response: SessionHistoryModels.LoadHistory.Response) {
            loadHistoryCalled = true
            lastLoadHistoryResponse = response
        }
        func presentApplyFilter(_ response: SessionHistoryModels.ApplyFilter.Response) {
            applyFilterCalled = true
            lastApplyFilterResponse = response
        }
        func presentClearFilter(_ response: SessionHistoryModels.ClearFilter.Response) {
            clearFilterCalled = true
        }
        func presentApplySort(_ response: SessionHistoryModels.ApplySort.Response) {
            applySortCalled = true
            lastApplySortResponse = response
        }
        func presentLoadNextPage(_ response: SessionHistoryModels.LoadNextPage.Response) {
            loadNextPageCalled = true
            lastLoadNextPageResponse = response
        }
        func presentOpenSession(_ response: SessionHistoryModels.OpenSession.Response) {
            openSessionCalled = true
            lastOpenSessionResponse = response
        }
        func presentAddNote(_ response: SessionHistoryModels.AddNote.Response) {
            addNoteCalled = true
            lastAddNoteResponse = response
        }
        func presentDeleteNote(_ response: SessionHistoryModels.DeleteNote.Response) {
            deleteNoteCalled = true
            lastDeleteNoteResponse = response
        }
        func presentExportPDF(_ response: SessionHistoryModels.ExportPDF.Response) {
            exportPDFCalled = true
            lastExportPDFResponse = response
            exportExpectation?.fulfill()
        }
        func presentExportCSV(_ response: SessionHistoryModels.ExportCSV.Response) {
            exportCSVCalled = true
            lastExportCSVResponse = response
            exportExpectation?.fulfill()
        }
        func presentExportJSON(_ response: SessionHistoryModels.ExportJSON.Response) {
            exportJSONCalled = true
            lastExportJSONResponse = response
            exportExpectation?.fulfill()
        }
        func presentAudioState(_ response: SessionHistoryModels.AudioState.Response) {
            audioStateCalled = true
            lastAudioStateResponse = response
        }
        func presentStatsSummary(_ response: SessionHistoryModels.LoadStatsSummary.Response) {
            statsSummaryCalled = true
            lastStatsResponse = response
        }
        func presentLyalyaComment(_ response: SessionHistoryModels.LoadLyalyaComment.Response) {
            lyalyaCommentCalled = true
            lastLyalyaResponse = response
        }
        func presentSearch(_ response: SessionHistoryModels.Search.Response) {
            searchCalled = true
            lastSearchResponse = response
        }
        func presentFailure(_ response: SessionHistoryModels.Failure.Response) {
            failureCalled = true
            lastFailureResponse = response
        }
    }

    private func makeSUT(
        audioPlayer: MockAudioFilePlayer = MockAudioFilePlayer(stubbedDuration: 3.0)
    ) -> (SessionHistoryInteractor, SpyPresenter, MockAudioFilePlayer) {
        let sut = SessionHistoryInteractor(audioPlayer: audioPlayer)
        let spy = SpyPresenter()
        sut.presenter = spy
        return (sut, spy, audioPlayer)
    }

    // MARK: - 1. loadHistory заполняет сессии из seed

    func test_loadHistory_populatesSessions() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        XCTAssertTrue(spy.loadHistoryCalled)
        XCTAssertFalse(spy.lastLoadHistoryResponse?.allSessions.isEmpty ?? true)
        XCTAssertTrue(spy.lastLoadHistoryResponse?.isFromCache ?? false)
    }

    // MARK: - 2. loadHistory с forceReload пересоздаёт данные

    func test_loadHistory_forceReload_resetsData() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: true))
        XCTAssertTrue(spy.loadHistoryCalled)
        let count = spy.lastLoadHistoryResponse?.allSessions.count ?? 0
        XCTAssertGreaterThan(count, 0)
        XCTAssertFalse(spy.lastLoadHistoryResponse?.isFromCache ?? true)
        XCTAssertEqual(spy.lastLoadHistoryResponse?.currentPage, 0)
    }

    // MARK: - 3. applyFilter вызывает presentApplyFilter

    func test_applyFilter_callsPresenter() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let filter = SessionHistoryFilter(fromDate: nil, toDate: nil, sounds: ["Р"], gameTypes: [], scoreRange: .all)
        sut.applyFilter(.init(filter: filter))
        XCTAssertTrue(spy.applyFilterCalled)
        XCTAssertEqual(spy.lastApplyFilterResponse?.activeFilter.sounds, ["Р"])
    }

    // MARK: - 4. clearFilter вызывает presentClearFilter

    func test_clearFilter_callsPresenter() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let filter = SessionHistoryFilter(fromDate: nil, toDate: nil, sounds: ["Р"], gameTypes: [], scoreRange: .all)
        sut.applyFilter(.init(filter: filter))
        sut.clearFilter(.init())
        XCTAssertTrue(spy.clearFilterCalled)
    }

    // MARK: - 5. openSession с существующим ID → presentOpenSession

    func test_openSession_existingId_callsPresenter() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        guard let firstId = spy.lastLoadHistoryResponse?.allSessions.first?.id else {
            return XCTFail("Нет сессий в seed")
        }
        sut.openSession(.init(id: firstId))
        XCTAssertTrue(spy.openSessionCalled)
        XCTAssertEqual(spy.lastOpenSessionResponse?.session.id, firstId)
    }

    // MARK: - 6. openSession с несуществующим ID → presentFailure

    func test_openSession_notFound_callsFailure() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.openSession(.init(id: "nonexistent-session-99"))
        XCTAssertFalse(spy.openSessionCalled)
        XCTAssertTrue(spy.failureCalled)
        XCTAssertFalse(spy.lastFailureResponse?.message.isEmpty ?? true)
    }

    // MARK: - 7. Фильтр по диапазону score (.high / .medium / .low)

    func test_applyFilter_scoreRangeHigh_filtersOnlyHighScores() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let filter = SessionHistoryFilter(fromDate: nil, toDate: nil, sounds: [], gameTypes: [], scoreRange: .high)
        sut.applyFilter(.init(filter: filter))
        let all = spy.lastApplyFilterResponse?.allSessions ?? []
        let visible = spy.lastApplyFilterResponse?.sessions ?? []
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(visible.allSatisfy { $0.score >= 0.80 })
    }

    func test_applyFilter_scoreRangeMedium_filtersMidScores() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let filter = SessionHistoryFilter(fromDate: nil, toDate: nil, sounds: [], gameTypes: [], scoreRange: .medium)
        sut.applyFilter(.init(filter: filter))
        let visible = spy.lastApplyFilterResponse?.sessions ?? []
        XCTAssertTrue(visible.allSatisfy { $0.score >= 0.50 && $0.score < 0.80 })
    }

    func test_applyFilter_scoreRangeLow_filtersLowScores() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let filter = SessionHistoryFilter(fromDate: nil, toDate: nil, sounds: [], gameTypes: [], scoreRange: .low)
        sut.applyFilter(.init(filter: filter))
        let visible = spy.lastApplyFilterResponse?.sessions ?? []
        XCTAssertTrue(visible.allSatisfy { $0.score < 0.50 })
    }

    // MARK: - 8. Фильтр по типу игры

    func test_applyFilter_gameTypeFilter_restrictsResults() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let filter = SessionHistoryFilter(
            fromDate: nil, toDate: nil, sounds: [],
            gameTypes: [.listenAndChoose], scoreRange: .all
        )
        sut.applyFilter(.init(filter: filter))
        let visible = spy.lastApplyFilterResponse?.sessions ?? []
        XCTAssertTrue(visible.allSatisfy { $0.gameType == .listenAndChoose })
    }

    // MARK: - 9. Фильтр по диапазону дат

    func test_applyFilter_dateRange_restrictsResults() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let from = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        let filter = SessionHistoryFilter(fromDate: from, toDate: Date(), sounds: [], gameTypes: [], scoreRange: .all)
        sut.applyFilter(.init(filter: filter))
        let visible = spy.lastApplyFilterResponse?.sessions ?? []
        let fromStart = Calendar.current.startOfDay(for: from ?? Date())
        XCTAssertTrue(visible.allSatisfy { Calendar.current.startOfDay(for: $0.date) >= fromStart })
    }

    // MARK: - 10. applySort по каждой стратегии

    func test_applySort_byScore_sortsDescending() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.applySort(.init(sort: .byScore))
        XCTAssertTrue(spy.applySortCalled)
        let sessions = spy.lastApplySortResponse?.sessions ?? []
        let scores = sessions.map(\.score)
        XCTAssertEqual(scores, scores.sorted(by: >))
    }

    func test_applySort_byDuration_sortsDescending() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.applySort(.init(sort: .byDuration))
        let sessions = spy.lastApplySortResponse?.sessions ?? []
        let durations = sessions.map(\.durationSec)
        XCTAssertEqual(durations, durations.sorted(by: >))
    }

    func test_applySort_bySound_sortsAscending() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.applySort(.init(sort: .bySound))
        let sessions = spy.lastApplySortResponse?.sessions ?? []
        let sounds = sessions.map(\.soundTarget)
        XCTAssertEqual(sounds, sounds.sorted())
    }

    func test_applySort_byDate_sortsDescending() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.applySort(.init(sort: .byDate))
        let sessions = spy.lastApplySortResponse?.sessions ?? []
        let dates = sessions.map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    // MARK: - 11. loadNextPage на последней странице игнорируется

    func test_loadNextPage_atLastPage_doesNothing() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        // 17 сессий < pageSize 20 → первая страница уже последняя
        sut.loadNextPage(.init())
        XCTAssertFalse(spy.loadNextPageCalled)
    }

    // MARK: - 12. addNote сохраняет заметку

    func test_addNote_validText_callsPresenter() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        guard let id = spy.lastLoadHistoryResponse?.allSessions.first?.id else {
            return XCTFail("Нет сессий")
        }
        sut.addNote(.init(sessionId: id, noteText: "  Хорошая работа  "))
        XCTAssertTrue(spy.addNoteCalled)
        XCTAssertEqual(spy.lastAddNoteResponse?.noteText, "Хорошая работа")
    }

    func test_addNote_emptySessionId_ignored() {
        let (sut, spy, _) = makeSUT()
        sut.addNote(.init(sessionId: "", noteText: "текст"))
        XCTAssertFalse(spy.addNoteCalled)
    }

    func test_addNote_emptyText_ignored() {
        let (sut, spy, _) = makeSUT()
        sut.addNote(.init(sessionId: "sess-1", noteText: "   \n  "))
        XCTAssertFalse(spy.addNoteCalled)
    }

    // MARK: - 13. note виден в openSession после addNote

    func test_addNote_thenOpenSession_reflectsNote() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        guard let id = spy.lastLoadHistoryResponse?.allSessions.first?.id else {
            return XCTFail("Нет сессий")
        }
        sut.addNote(.init(sessionId: id, noteText: "Заметка родителя"))
        sut.openSession(.init(id: id))
        XCTAssertEqual(spy.lastOpenSessionResponse?.parentNote, "Заметка родителя")
    }

    // MARK: - 14. deleteNote удаляет заметку

    func test_deleteNote_removesNote() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        guard let id = spy.lastLoadHistoryResponse?.allSessions.first?.id else {
            return XCTFail("Нет сессий")
        }
        sut.addNote(.init(sessionId: id, noteText: "Заметка"))
        sut.deleteNote(.init(sessionId: id))
        XCTAssertTrue(spy.deleteNoteCalled)
        XCTAssertEqual(spy.lastDeleteNoteResponse?.sessionId, id)
        sut.openSession(.init(id: id))
        XCTAssertNil(spy.lastOpenSessionResponse?.parentNote)
    }

    // MARK: - 15. performSearch фильтрует по звуку

    func test_performSearch_bySound_filtersResults() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.performSearch(.init(query: "Р"))
        XCTAssertTrue(spy.searchCalled)
        XCTAssertEqual(spy.lastSearchResponse?.query, "Р")
    }

    func test_performSearch_emptyQuery_returnsAll() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.performSearch(.init(query: "   "))
        let count = spy.lastSearchResponse?.sessions.count ?? 0
        XCTAssertGreaterThan(count, 0)
    }

    func test_performSearch_noMatch_emptyResult() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.performSearch(.init(query: "zzzнесуществующийzzz"))
        XCTAssertEqual(spy.lastSearchResponse?.sessions.count, 0)
    }

    // MARK: - 16. clearFilter сбрасывает поиск

    func test_clearFilter_resetsSearch() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.performSearch(.init(query: "Р"))
        sut.clearFilter(.init())
        let count = spy.lastLoadHistoryResponse?.allSessions.count ?? 0
        // После clearFilter новый search вернёт всё
        sut.performSearch(.init(query: ""))
        XCTAssertEqual(spy.lastSearchResponse?.sessions.count, count)
    }

    // MARK: - 17. playAudio happy path

    func test_playAudio_existingFile_startsPlayback() {
        let (sut, spy, player) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        // Seed: sess-1..sess-5 имеют аудио "/dev/null"
        sut.playAudio(.init(sessionId: "sess-1"))
        XCTAssertTrue(spy.audioStateCalled)
        XCTAssertEqual(spy.lastAudioStateResponse?.isPlaying, true)
        XCTAssertEqual(player.playCallCount, 1)
    }

    func test_playAudio_noFile_callsFailure() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.playAudio(.init(sessionId: "sess-99"))
        XCTAssertTrue(spy.failureCalled)
        XCTAssertFalse(spy.audioStateCalled)
    }

    func test_playAudio_playerThrows_callsFailure() {
        let player = MockAudioFilePlayer()
        player.shouldFailPlayback = true
        let (sut, spy, _) = makeSUT(audioPlayer: player)
        sut.loadHistory(.init(forceReload: false))
        sut.playAudio(.init(sessionId: "sess-2"))
        XCTAssertTrue(spy.failureCalled)
    }

    // MARK: - 18. stopAudio

    func test_stopAudio_afterPlay_stopsPlayback() {
        let (sut, spy, player) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.playAudio(.init(sessionId: "sess-1"))
        sut.stopAudio(.init(sessionId: "sess-1"))
        XCTAssertEqual(spy.lastAudioStateResponse?.isPlaying, false)
        XCTAssertGreaterThanOrEqual(player.stopCallCount, 1)
    }

    func test_stopAudio_withoutPlay_doesNothing() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        spy.audioStateCalled = false
        sut.stopAudio(.init())
        XCTAssertFalse(spy.audioStateCalled)
    }

    func test_playAudio_secondPlay_stopsPrevious() {
        let (sut, _, player) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.playAudio(.init(sessionId: "sess-1"))
        sut.playAudio(.init(sessionId: "sess-2"))
        XCTAssertGreaterThanOrEqual(player.stopCallCount, 1)
        XCTAssertEqual(player.playCallCount, 2)
    }

    // MARK: - 19. loadStatsSummary

    func test_loadStatsSummary_buildsStats() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.loadStatsSummary(.init(childId: "child-1"))
        XCTAssertTrue(spy.statsSummaryCalled)
        XCTAssertGreaterThan(spy.lastStatsResponse?.totalSessions ?? 0, 0)
        XCTAssertGreaterThan(spy.lastStatsResponse?.totalMinutes ?? 0, 0)
        XCTAssertFalse(spy.lastStatsResponse?.soundBreakdown.isEmpty ?? true)
        XCTAssertNotEqual(spy.lastStatsResponse?.bestSound, "—")
    }

    func test_loadStatsSummary_averageScoreInRange() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.loadStatsSummary(.init())
        let avg = spy.lastStatsResponse?.averageScorePercent ?? -1
        XCTAssertGreaterThanOrEqual(avg, 0)
        XCTAssertLessThanOrEqual(avg, 100)
    }

    // MARK: - 20. loadLyalyaComment

    func test_loadLyalyaComment_withName_returnsComment() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.loadLyalyaComment(.init(childName: "Маша"))
        XCTAssertTrue(spy.lyalyaCommentCalled)
        XCTAssertFalse(spy.lastLyalyaResponse?.commentText.isEmpty ?? true)
    }

    func test_loadLyalyaComment_emptyName_usesDefault() {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        sut.loadLyalyaComment(.init())
        XCTAssertFalse(spy.lastLyalyaResponse?.commentText.isEmpty ?? true)
    }

    // MARK: - 21. exportPDF / CSV / JSON (async)

    func test_exportPDF_generatesFile() async {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let exp = expectation(description: "exportPDF")
        spy.exportExpectation = exp
        sut.exportPDF(.init(childId: "child-1"))
        await fulfillment(of: [exp], timeout: 10)
        XCTAssertTrue(spy.exportPDFCalled)
        XCTAssertEqual(spy.lastExportPDFResponse?.exportFormat, .pdf)
    }

    func test_exportCSV_generatesFile() async {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let exp = expectation(description: "exportCSV")
        spy.exportExpectation = exp
        sut.exportCSV(.init(childId: ""))
        await fulfillment(of: [exp], timeout: 10)
        XCTAssertTrue(spy.exportCSVCalled)
        XCTAssertEqual(spy.lastExportCSVResponse?.exportFormat, .csv)
        XCTAssertEqual(spy.lastExportCSVResponse?.childId, "child")
    }

    func test_exportJSON_generatesFile() async {
        let (sut, spy, _) = makeSUT()
        sut.loadHistory(.init(forceReload: false))
        let exp = expectation(description: "exportJSON")
        spy.exportExpectation = exp
        sut.exportJSON(.init(childId: "child-1"))
        await fulfillment(of: [exp], timeout: 10)
        XCTAssertTrue(spy.exportJSONCalled)
        XCTAssertEqual(spy.lastExportJSONResponse?.exportFormat, .json)
        if let url = spy.lastExportJSONResponse?.fileURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }
}
