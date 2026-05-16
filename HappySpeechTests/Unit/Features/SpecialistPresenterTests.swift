@testable import HappySpeech
import XCTest

// MARK: - SpecialistPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие SpecialistPresenter (0% → цель ≥90%).

@MainActor
final class SpecialistPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SpecialistDisplayLogic {
        var fetchVM: SpecialistModels.Fetch.ViewModel?
        var updateVM: SpecialistModels.Update.ViewModel?
        var childDashboardVM: SpecialistModels.FetchChildDashboard.ViewModel?
        var saveNoteVM: SpecialistModels.SaveNote.ViewModel?
        var fetchNotesVM: SpecialistModels.FetchNotes.ViewModel?
        var exportVM: SpecialistModels.RequestExport.ViewModel?
        var sendMessageVM: SpecialistModels.SendParentMessage.ViewModel?
        var deleteNoteVM: SpecialistModels.DeleteNote.ViewModel?
        var errorMessage: String?

        func displayFetch(_ viewModel: SpecialistModels.Fetch.ViewModel) { fetchVM = viewModel }
        func displayUpdate(_ viewModel: SpecialistModels.Update.ViewModel) { updateVM = viewModel }
        func displayChildDashboard(_ viewModel: SpecialistModels.FetchChildDashboard.ViewModel) { childDashboardVM = viewModel }
        func displaySaveNote(_ viewModel: SpecialistModels.SaveNote.ViewModel) { saveNoteVM = viewModel }
        func displayFetchNotes(_ viewModel: SpecialistModels.FetchNotes.ViewModel) { fetchNotesVM = viewModel }
        func displayExport(_ viewModel: SpecialistModels.RequestExport.ViewModel) { exportVM = viewModel }
        func displaySendMessage(_ viewModel: SpecialistModels.SendParentMessage.ViewModel) { sendMessageVM = viewModel }
        func displayDeleteNote(_ viewModel: SpecialistModels.DeleteNote.ViewModel) { deleteNoteVM = viewModel }
        func displayError(_ message: String) { errorMessage = message }
    }

    private func makeSUT() -> (SpecialistPresenter, DisplaySpy) {
        let presenter = SpecialistPresenter()
        let spy = DisplaySpy()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    // MARK: - Helpers

    private func makeEntry(id: String = "c1", name: String = "Ваня", age: Int = 6, rate: Double = 0.7) -> ChildCaseEntry {
        ChildCaseEntry(id: id, name: name, age: age, targetSounds: ["С", "Р"], lastSessionAt: Date(), overallSuccessRate: rate, parentId: "p1")
    }

    private func makeChild(id: String = "c1", name: String = "Ваня", age: Int = 6) -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: name, age: age, targetSounds: ["С"], parentId: "p1")
    }

    private func makeNote(text: String = "Хорошо работал") -> SpecialistNote {
        SpecialistNote(id: UUID().uuidString, childId: "c1", specialistId: "sp1", text: text, createdAt: Date())
    }

    // MARK: - presentFetch

    func test_presentFetch_noChildren_emptyRows() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(children: []))
        XCTAssertEqual(spy.fetchVM?.rows.count, 0)
    }

    func test_presentFetch_withChildren_rowsBuilt() {
        let (sut, spy) = makeSUT()
        let entries = [makeEntry(id: "c1"), makeEntry(id: "c2")]
        sut.presentFetch(.init(children: entries))
        XCTAssertEqual(spy.fetchVM?.rows.count, 2)
    }

    func test_presentFetch_rowHasAgeLine() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(children: [makeEntry(age: 7)]))
        let row = spy.fetchVM?.rows.first
        XCTAssertFalse(row?.ageLine.isEmpty ?? true)
    }

    func test_presentFetch_age1_suffix_god() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(children: [makeEntry(age: 1)]))
        XCTAssertTrue(spy.fetchVM?.rows.first?.ageLine.contains("год") ?? false)
    }

    func test_presentFetch_age5_suffix_let() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(children: [makeEntry(age: 5)]))
        XCTAssertTrue(spy.fetchVM?.rows.first?.ageLine.contains("лет") ?? false)
    }

    func test_presentFetch_age3_suffix_goda() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(children: [makeEntry(age: 3)]))
        XCTAssertTrue(spy.fetchVM?.rows.first?.ageLine.contains("года") ?? false)
    }

    func test_presentFetch_progressPercentCalculated() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(children: [makeEntry(rate: 0.75)]))
        XCTAssertEqual(spy.fetchVM?.rows.first?.overallProgressPercent, 75)
    }

    func test_presentFetch_sortLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(.init(children: []))
        XCTAssertFalse(spy.fetchVM?.sortLabel.isEmpty ?? true)
    }

    // MARK: - presentUpdate

    func test_presentUpdate_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentUpdate(.init())
        XCTAssertNotNil(spy.updateVM)
    }

    // MARK: - presentChildDashboard

    func test_presentChildDashboard_overallPercentCalculated() {
        let (sut, spy) = makeSUT()
        let summary = ReportSummary(totalSessions: 20, totalMinutes: 200, overallSuccessRate: 0.8, improvedSounds: [], strugglingSounds: [])
        let response = SpecialistModels.FetchChildDashboard.Response(
            child: makeChild(),
            recentSessions: [],
            soundBreakdown: [],
            summary: summary,
            llmReport: nil
        )
        sut.presentChildDashboard(response)
        XCTAssertEqual(spy.childDashboardVM?.overallPercentText, "80%")
    }

    func test_presentChildDashboard_noLlmReport_usesNoDataHeadline() {
        let (sut, spy) = makeSUT()
        let summary = ReportSummary(totalSessions: 5, totalMinutes: 50, overallSuccessRate: 0.6, improvedSounds: [], strugglingSounds: [])
        let response = SpecialistModels.FetchChildDashboard.Response(
            child: makeChild(),
            recentSessions: [],
            soundBreakdown: [],
            summary: summary,
            llmReport: nil
        )
        sut.presentChildDashboard(response)
        XCTAssertFalse(spy.childDashboardVM?.llmHeadline.isEmpty ?? true)
    }

    func test_presentChildDashboard_soundBreakdown_rowsBuilt() {
        let (sut, spy) = makeSUT()
        let summary = ReportSummary(totalSessions: 10, totalMinutes: 100, overallSuccessRate: 0.7, improvedSounds: [], strugglingSounds: [])
        let soundRow = SoundBreakdownRow(sound: "С", attempts: 5, successes: 4, averageConfidence: 0.8, currentStageTitle: "Слова", weekOverWeekDelta: 0.1)
        let response = SpecialistModels.FetchChildDashboard.Response(
            child: makeChild(),
            recentSessions: [],
            soundBreakdown: [soundRow],
            summary: summary,
            llmReport: nil
        )
        sut.presentChildDashboard(response)
        XCTAssertEqual(spy.childDashboardVM?.soundRows.count, 1)
    }

    func test_presentChildDashboard_positiveDelta_prefixedWithPlus() {
        let (sut, spy) = makeSUT()
        let summary = ReportSummary(totalSessions: 5, totalMinutes: 50, overallSuccessRate: 0.6, improvedSounds: [], strugglingSounds: [])
        let soundRow = SoundBreakdownRow(sound: "Р", attempts: 3, successes: 2, averageConfidence: 0.7, currentStageTitle: "Слоги", weekOverWeekDelta: 0.05)
        let response = SpecialistModels.FetchChildDashboard.Response(
            child: makeChild(),
            recentSessions: [],
            soundBreakdown: [soundRow],
            summary: summary,
            llmReport: nil
        )
        sut.presentChildDashboard(response)
        XCTAssertTrue(spy.childDashboardVM?.soundRows.first?.deltaText.hasPrefix("+") ?? false)
    }

    // MARK: - presentSaveNote

    func test_presentSaveNote_confirmationNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentSaveNote(.init(success: true, note: makeNote()))
        XCTAssertFalse(spy.saveNoteVM?.confirmationText.isEmpty ?? true)
    }

    func test_presentSaveNote_previewTruncatedAt60() {
        let (sut, spy) = makeSUT()
        let longText = String(repeating: "А", count: 80)
        sut.presentSaveNote(.init(success: true, note: makeNote(text: longText)))
        XCTAssertLessThanOrEqual(spy.saveNoteVM?.notePreview.count ?? 0, 60)
    }

    // MARK: - presentFetchNotes

    func test_presentFetchNotes_emptyNotes_emptyStateTextNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetchNotes(.init(notes: []))
        XCTAssertFalse(spy.fetchNotesVM?.emptyStateText.isEmpty ?? true)
    }

    func test_presentFetchNotes_withNotes_rowsBuilt() {
        let (sut, spy) = makeSUT()
        sut.presentFetchNotes(.init(notes: [makeNote(), makeNote()]))
        XCTAssertEqual(spy.fetchNotesVM?.rows.count, 2)
    }

    func test_presentFetchNotes_previewTruncatedAt80() {
        let (sut, spy) = makeSUT()
        let longNote = makeNote(text: String(repeating: "Б", count: 100))
        sut.presentFetchNotes(.init(notes: [longNote]))
        XCTAssertLessThanOrEqual(spy.fetchNotesVM?.rows.first?.preview.count ?? 0, 80)
    }

    // MARK: - presentDeleteNote

    func test_presentDeleteNote_success_feedbackNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentDeleteNote(.init(success: true))
        XCTAssertFalse(spy.deleteNoteVM?.feedbackText.isEmpty ?? true)
    }

    func test_presentDeleteNote_failure_feedbackNotEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentDeleteNote(.init(success: false))
        XCTAssertFalse(spy.deleteNoteVM?.feedbackText.isEmpty ?? true)
    }

    // MARK: - presentExport

    func test_presentExport_sizeLabelFormatted() {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        sut.presentExport(.init(fileURL: url, sizeBytes: 2048, format: .pdf))
        XCTAssertFalse(spy.exportVM?.sizeLabel.isEmpty ?? true)
    }

    func test_presentExport_successMessageNotEmpty() {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/report.csv")
        sut.presentExport(.init(fileURL: url, sizeBytes: 512, format: .csv))
        XCTAssertFalse(spy.exportVM?.successMessage.isEmpty ?? true)
    }

    // MARK: - presentSendMessage

    func test_presentSendMessage_delivered_isNotError() {
        let (sut, spy) = makeSUT()
        sut.presentSendMessage(.init(delivered: true, timestamp: Date()))
        XCTAssertFalse(spy.sendMessageVM?.isError ?? true)
    }

    func test_presentSendMessage_failed_isError() {
        let (sut, spy) = makeSUT()
        sut.presentSendMessage(.init(delivered: false, timestamp: Date()))
        XCTAssertTrue(spy.sendMessageVM?.isError ?? false)
    }

    // MARK: - presentError

    func test_presentError_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentError("Ошибка подключения")
        XCTAssertEqual(spy.errorMessage, "Ошибка подключения")
    }
}
