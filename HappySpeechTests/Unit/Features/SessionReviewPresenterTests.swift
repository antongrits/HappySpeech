@testable import HappySpeech
import XCTest

// MARK: - SessionReviewPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие SessionReviewPresenter (0% → цель ≥90%).

@MainActor
final class SessionReviewPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SessionReviewDisplayLogic {
        var loadSessionVM: SessionReviewModels.LoadSession.ViewModel?
        var setManualScoreVM: SessionReviewModels.SetManualScore.ViewModel?
        var finalizeVM: SessionReviewModels.FinalizeReview.ViewModel?
        var loadDetailsVM: SessionReviewModels.LoadDetails.ViewModel?
        var exportPDFVM: SessionReviewModels.ExportPDF.ViewModel?
        var attemptBreakdownVM: SessionReviewModels.LoadAttemptBreakdown.ViewModel?
        var annotationUpdatedVM: SessionReviewModels.AnnotationUpdated.ViewModel?

        func displayLoadSession(_ vm: SessionReviewModels.LoadSession.ViewModel) { loadSessionVM = vm }
        func displaySetManualScore(_ vm: SessionReviewModels.SetManualScore.ViewModel) { setManualScoreVM = vm }
        func displayFinalizeReview(_ vm: SessionReviewModels.FinalizeReview.ViewModel) { finalizeVM = vm }
        func displayLoadDetails(_ vm: SessionReviewModels.LoadDetails.ViewModel) { loadDetailsVM = vm }
        func displayExportPDF(_ vm: SessionReviewModels.ExportPDF.ViewModel) { exportPDFVM = vm }
        func displayAttemptBreakdown(_ vm: SessionReviewModels.LoadAttemptBreakdown.ViewModel) { attemptBreakdownVM = vm }
        func displayAnnotationUpdated(_ vm: SessionReviewModels.AnnotationUpdated.ViewModel) { annotationUpdatedVM = vm }
    }

    private func makeSUT() -> (SessionReviewPresenter, DisplaySpy) {
        let presenter = SessionReviewPresenter()
        let spy = DisplaySpy()
        presenter.display = spy
        return (presenter, spy)
    }

    private func makeAttemptReviewRow(
        id: String = UUID().uuidString,
        word: String = "сапог",
        autoScore: Double = 0.8,
        isMarkedCorrect: Bool = true
    ) -> AttemptReviewRow {
        AttemptReviewRow(
            id: id,
            word: word,
            asrTranscript: word,
            autoScore: autoScore,
            manualScore: nil,
            audioPath: "/tmp/\(id).m4a",
            isMarkedCorrect: isMarkedCorrect
        )
    }

    private func makeAttemptBreakdownRow(
        id: String = UUID().uuidString,
        word: String = "кот",
        asrScore: Double = 0.8,
        effectiveScore: Double = 0.8,
        isCorrect: Bool = true
    ) -> AttemptBreakdownRow {
        AttemptBreakdownRow(
            index: 1,
            id: id,
            word: word,
            asrTranscript: word,
            asrScore: asrScore,
            pronunciationScore: nil,
            manualScore: nil,
            effectiveScore: effectiveScore,
            isCorrect: isCorrect,
            audioPath: "/tmp/\(id).m4a",
            confidence: .high,
            timestamp: Date()
        )
    }

    private func makeReviewSummary(
        totalAttempts: Int = 10,
        markedCorrect: Int = 8
    ) -> SessionReviewSummary {
        SessionReviewSummary(
            totalAttempts: totalAttempts,
            markedCorrect: markedCorrect,
            averageEffectiveScore: 0.8,
            disagreementCount: 0
        )
    }

    private func makeSessionDTO() -> SessionDTO {
        SessionDTO(
            id: "s-1",
            childId: "c-1",
            date: Date(),
            templateType: "listen-and-choose",
            targetSound: "С",
            stage: "words",
            durationSeconds: 300,
            totalAttempts: 10,
            correctAttempts: 8,
            fatigueDetected: false,
            isSynced: true,
            attempts: []
        )
    }

    private func makeSessionSummary(
        childName: String = "Ваня",
        totalAttempts: Int = 10,
        correctAttempts: Int = 8
    ) -> SessionSummary {
        SessionSummary(
            sessionId: "s-1",
            date: Date(),
            duration: 300,
            childName: childName,
            targetSound: "С",
            games: [],
            phonemeAccuracy: ["С": 0.8, "Р": 0.6],
            llmRecommendation: "Продолжайте занятия",
            totalAttempts: totalAttempts,
            correctAttempts: correctAttempts,
            fatigueDetected: false
        )
    }

    // MARK: - presentLoadSession

    func test_presentLoadSession_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadSession(.init(session: makeSessionDTO(), attemptRows: []))
        XCTAssertNotNil(spy.loadSessionVM)
    }

    func test_presentLoadSession_rowsPassedThrough() async {
        let (sut, spy) = makeSUT()
        let rows = [makeAttemptReviewRow(), makeAttemptReviewRow()]
        await sut.presentLoadSession(.init(session: makeSessionDTO(), attemptRows: rows))
        XCTAssertEqual(spy.loadSessionVM?.rows.count, 2)
    }

    // MARK: - presentSetManualScore

    func test_presentSetManualScore_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let summary = makeReviewSummary()
        await sut.presentSetManualScore(.init(attemptRows: [], summary: summary))
        XCTAssertNotNil(spy.setManualScoreVM)
    }

    // MARK: - presentFinalizeReview

    func test_presentFinalizeReview_confirmationNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentFinalizeReview(.init(savedAt: Date()))
        XCTAssertFalse(spy.finalizeVM?.confirmationText.isEmpty ?? true)
    }

    // MARK: - presentLoadDetails

    func test_presentLoadDetails_titleContainsChildName() async {
        let (sut, spy) = makeSUT()
        let summary = makeSessionSummary(childName: "Ваня")
        await sut.presentLoadDetails(.init(summary: summary))
        XCTAssertTrue(spy.loadDetailsVM?.titleText.contains("Ваня") ?? false)
    }

    func test_presentLoadDetails_dateTextNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadDetails(.init(summary: makeSessionSummary()))
        XCTAssertFalse(spy.loadDetailsVM?.dateText.isEmpty ?? true)
    }

    func test_presentLoadDetails_overallPercentCalculated() async {
        let (sut, spy) = makeSUT()
        // 8 correct / 10 total = 80%
        await sut.presentLoadDetails(.init(summary: makeSessionSummary(totalAttempts: 10, correctAttempts: 8)))
        XCTAssertEqual(spy.loadDetailsVM?.overallAccuracyPercent, 80)
    }

    func test_presentLoadDetails_phonemeRowsBuilt() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadDetails(.init(summary: makeSessionSummary()))
        XCTAssertEqual(spy.loadDetailsVM?.phonemeRows.count, 2)
    }

    func test_presentLoadDetails_durationTextNotEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadDetails(.init(summary: makeSessionSummary()))
        XCTAssertFalse(spy.loadDetailsVM?.durationText.isEmpty ?? true)
    }

    func test_presentLoadDetails_zeroDuration_textNotEmpty() async {
        let (sut, spy) = makeSUT()
        let summary = SessionSummary(
            sessionId: "s-1",
            date: Date(),
            duration: 30,
            childName: "Маша",
            targetSound: "С",
            games: [],
            phonemeAccuracy: [:],
            llmRecommendation: nil,
            totalAttempts: 0,
            correctAttempts: 0,
            fatigueDetected: false
        )
        await sut.presentLoadDetails(.init(summary: summary))
        XCTAssertFalse(spy.loadDetailsVM?.durationText.isEmpty ?? true)
    }

    // MARK: - presentExportPDF

    func test_presentExportPDF_confirmationNotEmpty() async {
        let (sut, spy) = makeSUT()
        let url = URL(fileURLWithPath: "/tmp/review.pdf")
        await sut.presentExportPDF(.init(url: url))
        XCTAssertFalse(spy.exportPDFVM?.confirmationText.isEmpty ?? true)
    }

    // MARK: - presentAttemptBreakdown

    func test_presentAttemptBreakdown_rowsBuilt() async {
        let (sut, spy) = makeSUT()
        let rows = [makeAttemptBreakdownRow(effectiveScore: 0.9), makeAttemptBreakdownRow(effectiveScore: 0.4)]
        await sut.presentAttemptBreakdown(.init(sessionId: "s-1", rows: rows))
        XCTAssertEqual(spy.attemptBreakdownVM?.rows.count, 2)
    }

    func test_presentAttemptBreakdown_statsBuilt() async {
        let (sut, spy) = makeSUT()
        let rows = [makeAttemptBreakdownRow(isCorrect: true), makeAttemptBreakdownRow(isCorrect: false)]
        await sut.presentAttemptBreakdown(.init(sessionId: "s-1", rows: rows))
        XCTAssertFalse(spy.attemptBreakdownVM?.stats.totalCorrectText.isEmpty ?? true)
    }

    func test_presentAttemptBreakdown_emptyTranscript_usesPlaceholder() async {
        let (sut, spy) = makeSUT()
        let rowWithEmptyTranscript = AttemptBreakdownRow(
            index: 1,
            id: "a1",
            word: "кот",
            asrTranscript: "",
            asrScore: 0.5,
            pronunciationScore: nil,
            manualScore: nil,
            effectiveScore: 0.5,
            isCorrect: false,
            audioPath: "/tmp/a1.m4a",
            confidence: .low,
            timestamp: Date()
        )
        await sut.presentAttemptBreakdown(.init(sessionId: "s-2", rows: [rowWithEmptyTranscript]))
        XCTAssertFalse(spy.attemptBreakdownVM?.rows.first?.asrTranscript.isEmpty ?? true)
    }

    // MARK: - presentAnnotationUpdated

    func test_presentAnnotationUpdated_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentAnnotationUpdated(.init(sessionId: "s-1", annotations: []))
        XCTAssertNotNil(spy.annotationUpdatedVM)
    }

    func test_presentAnnotationUpdated_annotationsPassedThrough() async {
        let (sut, spy) = makeSUT()
        let ann = SessionAnnotation(id: "a1", sessionId: "s-1", targetAttemptId: nil, text: "Заметка", createdAt: Date())
        await sut.presentAnnotationUpdated(.init(sessionId: "s-1", annotations: [ann]))
        XCTAssertEqual(spy.annotationUpdatedVM?.annotations.count, 1)
    }
}
