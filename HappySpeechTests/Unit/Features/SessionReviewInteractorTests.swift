@testable import HappySpeech
import XCTest

// MARK: - SessionReviewInteractorTests

@MainActor
final class SessionReviewInteractorTests: XCTestCase {

    @MainActor
    private final class SpyPresenter: SessionReviewPresentationLogic {
        var loadCalls = 0
        var lastRows: [AttemptReviewRow] = []
        var lastSummary: SessionReviewSummary?
        var finalizedAt: Date?

        func presentLoadSession(_ response: SessionReviewModels.LoadSession.Response) async {
            loadCalls += 1
            lastRows = response.attemptRows
        }
        func presentSetManualScore(_ response: SessionReviewModels.SetManualScore.Response) async {
            lastRows = response.attemptRows
            lastSummary = response.summary
        }
        func presentFinalizeReview(_ response: SessionReviewModels.FinalizeReview.Response) async {
            finalizedAt = response.savedAt
        }
        func presentLoadDetails(_ response: SessionReviewModels.LoadDetails.Response) async {}
        func presentExportPDF(_ response: SessionReviewModels.ExportPDF.Response) async {}
        func presentAttemptBreakdown(_ response: SessionReviewModels.LoadAttemptBreakdown.Response) async {}
        func presentAnnotationUpdated(_ response: SessionReviewModels.AnnotationUpdated.Response) async {}
    }

    private final class StubSessionRepo: SessionRepository, @unchecked Sendable {
        var session: SessionDTO
        init(session: SessionDTO) { self.session = session }
        func fetchAll(childId: String) async throws -> [SessionDTO] { [session] }
        func fetch(id: String) async throws -> SessionDTO { session }
        func save(_ s: SessionDTO) async throws { session = s }
        func fetchRecent(childId: String, limit: Int) async throws -> [SessionDTO] { [session] }
    }

    private func makeAttempt(id: String, word: String = "рыба",
                             asr: Double = 0.6, pron: Double = 0.7,
                             manual: Double = 0) -> AttemptDTO {
        AttemptDTO(
            id: id, word: word, audioLocalPath: "/tmp/\(id).caf",
            audioStoragePath: "", asrTranscript: word,
            asrScore: asr, pronunciationScore: pron,
            manualScore: manual, isCorrect: manual > 0.5 || pron > 0.5,
            timestamp: Date()
        )
    }

    private func makeSUT(attempts: [AttemptDTO] = []) -> (SessionReviewInteractor, SpyPresenter) {
        let session = SessionDTO(
            id: "s1", childId: "c1", date: Date(), templateType: "test",
            targetSound: "Р", stage: "syllables",
            durationSeconds: 300, totalAttempts: attempts.count,
            correctAttempts: attempts.filter(\.isCorrect).count,
            fatigueDetected: false, isSynced: false, attempts: attempts
        )
        let repo = StubSessionRepo(session: session)
        let interactor = SessionReviewInteractor(sessionRepository: repo)
        let spy = SpyPresenter()
        interactor.presenter = spy
        return (interactor, spy)
    }

    // MARK: - Load

    func test_loadSession_buildsAttemptRows() async {
        let (sut, spy) = makeSUT(attempts: [
            makeAttempt(id: "a1", asr: 0.8, pron: 0.9),
            makeAttempt(id: "a2", asr: 0.3, pron: 0.4)
        ])
        await sut.loadSession(.init(sessionId: "s1"))
        XCTAssertEqual(spy.loadCalls, 1)
        XCTAssertEqual(spy.lastRows.count, 2)
        XCTAssertEqual(spy.lastRows[0].autoScore, 0.9)  // max(asr, pron)
    }

    // MARK: - setManualScore

    func test_setManualScore_updatesRow() async {
        let (sut, spy) = makeSUT(attempts: [makeAttempt(id: "a1")])
        await sut.loadSession(.init(sessionId: "s1"))

        await sut.setManualScore(.init(sessionId: "s1", attemptId: "a1", manualScore: 0.3))

        XCTAssertEqual(spy.lastRows.first?.manualScore, 0.3)
        XCTAssertFalse(spy.lastRows.first?.isMarkedCorrect ?? true)
    }

    func test_setManualScore_clamps_outOfRange() async {
        let (sut, _) = makeSUT(attempts: [makeAttempt(id: "a1")])
        await sut.loadSession(.init(sessionId: "s1"))
        await sut.setManualScore(.init(sessionId: "s1", attemptId: "a1", manualScore: 1.7))
        XCTAssertEqual(sut._rows().first?.manualScore, 1.0)

        await sut.setManualScore(.init(sessionId: "s1", attemptId: "a1", manualScore: -0.2))
        XCTAssertEqual(sut._rows().first?.manualScore, 0.0)
    }

    // MARK: - Summary

    func test_summary_emptyRows_zeros() {
        let summary = SessionReviewInteractor.makeSummary(rows: [])
        XCTAssertEqual(summary.totalAttempts, 0)
        XCTAssertEqual(summary.averageEffectiveScore, 0)
    }

    func test_summary_manualOverride_wins_forEffectiveScore() {
        let rows: [AttemptReviewRow] = [
            AttemptReviewRow(id: "a1", word: "w", asrTranscript: "w",
                             autoScore: 0.9, manualScore: 0.2,
                             audioPath: "", isMarkedCorrect: false)
        ]
        let summary = SessionReviewInteractor.makeSummary(rows: rows)
        XCTAssertEqual(summary.averageEffectiveScore, 0.2, accuracy: 0.001)
        XCTAssertEqual(summary.disagreementCount, 1, "abs(0.9 - 0.2) > 0.15 → disagreement")
    }

    // MARK: - Finalize

    func test_finalizeReview_setsTimestamp() async {
        let (sut, spy) = makeSUT()
        await sut.loadSession(.init(sessionId: "s1"))
        let before = Date()
        await sut.finalizeReview(.init(sessionId: "s1", specialistNotes: "ok"))
        XCTAssertNotNil(spy.finalizedAt)
        XCTAssertGreaterThanOrEqual(spy.finalizedAt!.timeIntervalSince1970,
                                    before.timeIntervalSince1970 - 1)
    }

    // MARK: - loadDetails (статические агрегаторы)

    func test_loadDetails_callsPresenter() async {
        let captureSpy = CapturingSpy()
        let sut2 = makeSUTWithCapture(spy: captureSpy, attempts: [
            makeAttempt(id: "a1", asr: 0.8, pron: 0.9)
        ])
        await sut2.loadDetails(.init(sessionId: "s1"))
        XCTAssertTrue(captureSpy.loadDetailsCalled)
    }

    // MARK: - aggregateGames (pure static)

    func test_aggregateGames_emptyAttempts_returnsOneResult() {
        let session = makeSession(attempts: [])
        let games = SessionReviewInteractor.aggregateGames(from: session)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].total, session.totalAttempts)
        XCTAssertEqual(games[0].correct, session.correctAttempts)
    }

    func test_aggregateGames_withAttempts_countsCorrectly() {
        let attempts = [
            makeAttempt(id: "a1", asr: 0.8, pron: 0.9),
            makeAttempt(id: "a2", asr: 0.2, pron: 0.3)
        ]
        let session = makeSession(attempts: attempts)
        let games = SessionReviewInteractor.aggregateGames(from: session)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].total, 2)
        // a1 correct (pron 0.9 > 0.5), a2 not
        XCTAssertEqual(games[0].correct, 1)
    }

    // MARK: - aggregatePhonemeAccuracy (pure static)

    func test_aggregatePhonemeAccuracy_emptyAttempts_returnsEmpty() {
        let session = makeSession(attempts: [])
        let result = SessionReviewInteractor.aggregatePhonemeAccuracy(from: session)
        XCTAssertTrue(result.isEmpty)
    }

    func test_aggregatePhonemeAccuracy_usesManualScoreWhenPresent() {
        let attempts = [
            AttemptDTO(id: "a1", word: "рыба", audioLocalPath: "/tmp/a1.caf",
                       audioStoragePath: "", asrTranscript: "рыба",
                       asrScore: 0.3, pronunciationScore: 0.3,
                       manualScore: 0.9, isCorrect: true, timestamp: Date()),
            AttemptDTO(id: "a2", word: "рак", audioLocalPath: "/tmp/a2.caf",
                       audioStoragePath: "", asrTranscript: "рак",
                       asrScore: 0.5, pronunciationScore: 0.5,
                       manualScore: 0.0, isCorrect: true, timestamp: Date())
        ]
        let session = makeSession(attempts: attempts)
        let result = SessionReviewInteractor.aggregatePhonemeAccuracy(from: session)
        XCTAssertFalse(result.isEmpty)
        // Первая попытка manual=0.9, вторая uses max(asr=0.5, pron=0.5)=0.5 → avg=(0.9+0.5)/2=0.7
        let accuracy = result["Р"] ?? 0
        XCTAssertEqual(accuracy, 0.7, accuracy: 0.001)
    }

    // MARK: - makeRecommendation (pure static)

    func test_makeRecommendation_fatigue_returnsFatigueMessage() {
        let result = SessionReviewInteractor.makeRecommendation(
            accuracy: [:], fatigueDetected: true, successRate: 0.6, targetSound: "Р"
        )
        XCTAssertNotNil(result)
    }

    func test_makeRecommendation_highSuccess_returnsAdvance() {
        let result = SessionReviewInteractor.makeRecommendation(
            accuracy: [:], fatigueDetected: false, successRate: 0.9, targetSound: "Л"
        )
        XCTAssertNotNil(result)
    }

    func test_makeRecommendation_lowSuccess_returnsRegress() {
        let result = SessionReviewInteractor.makeRecommendation(
            accuracy: [:], fatigueDetected: false, successRate: 0.3, targetSound: "С"
        )
        XCTAssertNotNil(result)
    }

    func test_makeRecommendation_midSuccess_returnsNil() {
        let result = SessionReviewInteractor.makeRecommendation(
            accuracy: [:], fatigueDetected: false, successRate: 0.65, targetSound: "Ш"
        )
        XCTAssertNil(result)
    }

    // MARK: - gameName (pure static)

    func test_gameName_knownTemplate_returnsLocalizedName() {
        let name = SessionReviewInteractor.gameName(for: "listenAndChoose")
        XCTAssertFalse(name.isEmpty)
    }

    func test_gameName_unknownTemplate_returnsTemplateType() {
        let name = SessionReviewInteractor.gameName(for: "unknownTemplate")
        XCTAssertEqual(name, "unknownTemplate")
    }

    // MARK: - buildBreakdown (pure static)

    func test_buildBreakdown_emptyAttempts_returnsEmpty() {
        let session = makeSession(attempts: [])
        let rows = SessionReviewInteractor.buildBreakdown(from: session)
        XCTAssertTrue(rows.isEmpty)
    }

    func test_buildBreakdown_setsCorrectIndex() {
        let attempts = [
            makeAttempt(id: "a1"), makeAttempt(id: "a2"), makeAttempt(id: "a3")
        ]
        let session = makeSession(attempts: attempts)
        let rows = SessionReviewInteractor.buildBreakdown(from: session)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0].index, 1)
        XCTAssertEqual(rows[1].index, 2)
        XCTAssertEqual(rows[2].index, 3)
    }

    func test_buildBreakdown_manualScoreOverridesEffective() {
        let attempt = AttemptDTO(
            id: "a1", word: "рыба", audioLocalPath: "", audioStoragePath: "",
            asrTranscript: "рыба", asrScore: 0.3, pronunciationScore: 0.3,
            manualScore: 0.9, isCorrect: true, timestamp: Date()
        )
        let session = makeSession(attempts: [attempt])
        let rows = SessionReviewInteractor.buildBreakdown(from: session)
        XCTAssertEqual(rows[0].effectiveScore, 0.9, accuracy: 0.001)
        XCTAssertNotNil(rows[0].manualScore)
    }

    func test_buildBreakdown_negativePronunciation_setsNilPronunciation() {
        let attempt = AttemptDTO(
            id: "a1", word: "рыба", audioLocalPath: "", audioStoragePath: "",
            asrTranscript: "рыба", asrScore: 0.5, pronunciationScore: -1.0,
            manualScore: 0.0, isCorrect: true, timestamp: Date()
        )
        let session = makeSession(attempts: [attempt])
        let rows = SessionReviewInteractor.buildBreakdown(from: session)
        XCTAssertNil(rows[0].pronunciationScore)
    }

    // MARK: - breakdownStats (pure static)

    func test_breakdownStats_emptyRows_returnsZeros() {
        let stats = SessionReviewInteractor.breakdownStats(from: [])
        XCTAssertEqual(stats.averageASR, 0)
        XCTAssertNil(stats.averagePronunciation)
        XCTAssertEqual(stats.averageEffective, 0)
    }

    func test_breakdownStats_calculatesCorrectly() {
        let rows = [
            makeBreakdownRow(asr: 0.8, pron: 0.9, isCorrect: true),
            makeBreakdownRow(asr: 0.4, pron: 0.7, isCorrect: false)
        ]
        let stats = SessionReviewInteractor.breakdownStats(from: rows)
        XCTAssertEqual(stats.averageASR, 0.6, accuracy: 0.001)
        XCTAssertNotNil(stats.averagePronunciation)
        XCTAssertEqual(stats.averagePronunciation ?? 0, 0.8, accuracy: 0.001)
        XCTAssertEqual(stats.totalCorrect, 1)
    }

    func test_breakdownStats_allRowsWithoutPronunciation_returnsNilAvg() {
        let rows = [
            makeBreakdownRow(asr: 0.8, pron: nil, isCorrect: true),
            makeBreakdownRow(asr: 0.4, pron: nil, isCorrect: false)
        ]
        let stats = SessionReviewInteractor.breakdownStats(from: rows)
        XCTAssertNil(stats.averagePronunciation, "Все строки без pronunciation → среднее nil")
    }

    func test_breakdownStats_manualOverrideCount() {
        let rows = [
            makeBreakdownRow(asr: 0.8, pron: 0.9, isCorrect: true, hasManual: true),
            makeBreakdownRow(asr: 0.4, pron: 0.5, isCorrect: false, hasManual: false)
        ]
        let stats = SessionReviewInteractor.breakdownStats(from: rows)
        XCTAssertEqual(stats.manualOverrideCount, 1)
    }

    // MARK: - Annotations (M6.15)

    func test_addAnnotation_nonEmptyText_addsToList() async {
        let (sut, _) = makeSUT()
        await sut.loadSession(.init(sessionId: "s1"))
        await sut.addAnnotation(.init(sessionId: "s1", targetAttemptId: nil, text: "Хорошая сессия"))
        XCTAssertEqual(sut._annotations().count, 1)
        XCTAssertEqual(sut._annotations().first?.text, "Хорошая сессия")
    }

    func test_addAnnotation_emptyText_isIgnored() async {
        let (sut, _) = makeSUT()
        await sut.loadSession(.init(sessionId: "s1"))
        await sut.addAnnotation(.init(sessionId: "s1", targetAttemptId: nil, text: "   "))
        XCTAssertTrue(sut._annotations().isEmpty)
    }

    func test_addAnnotation_withAttemptId_storesAttemptId() async {
        let (sut, _) = makeSUT()
        await sut.loadSession(.init(sessionId: "s1"))
        await sut.addAnnotation(.init(sessionId: "s1", targetAttemptId: "a1", text: "Слог пропущен"))
        XCTAssertEqual(sut._annotations().first?.targetAttemptId, "a1")
    }

    func test_deleteAnnotation_removesById() async {
        let (sut, _) = makeSUT()
        await sut.loadSession(.init(sessionId: "s1"))
        await sut.addAnnotation(.init(sessionId: "s1", targetAttemptId: nil, text: "Первая"))
        await sut.addAnnotation(.init(sessionId: "s1", targetAttemptId: nil, text: "Вторая"))
        let firstId = sut._annotations().first!.id
        await sut.deleteAnnotation(.init(sessionId: "s1", annotationId: firstId))
        XCTAssertEqual(sut._annotations().count, 1)
        XCTAssertEqual(sut._annotations().first?.text, "Вторая")
    }

    // MARK: - loadAttemptBreakdown

    func test_loadAttemptBreakdown_fillsBreakdown() async {
        let (sut, _) = makeSUT(attempts: [makeAttempt(id: "a1"), makeAttempt(id: "a2")])
        await sut.loadAttemptBreakdown(.init(sessionId: "s1"))
        XCTAssertEqual(sut._attemptBreakdown().count, 2)
    }

    func test_loadAttemptBreakdown_usesCachedSession() async {
        let (sut, _) = makeSUT(attempts: [makeAttempt(id: "a1")])
        await sut.loadSession(.init(sessionId: "s1"))   // кэшируем
        await sut.loadAttemptBreakdown(.init(sessionId: "s1"))  // должен взять из кэша
        XCTAssertEqual(sut._attemptBreakdown().count, 1)
    }

    // MARK: - Helpers

    private func makeSession(attempts: [AttemptDTO]) -> SessionDTO {
        SessionDTO(
            id: "s1", childId: "c1", date: Date(), templateType: "listenAndChoose",
            targetSound: "Р", stage: "syllables",
            durationSeconds: 300,
            totalAttempts: attempts.count,
            correctAttempts: attempts.filter(\.isCorrect).count,
            fatigueDetected: false, isSynced: false, attempts: attempts
        )
    }

    @MainActor
    private final class CapturingSpy: SessionReviewPresentationLogic {
        var loadDetailsCalled = false
        func presentLoadSession(_ r: SessionReviewModels.LoadSession.Response) async {}
        func presentSetManualScore(_ r: SessionReviewModels.SetManualScore.Response) async {}
        func presentFinalizeReview(_ r: SessionReviewModels.FinalizeReview.Response) async {}
        func presentLoadDetails(_ r: SessionReviewModels.LoadDetails.Response) async { loadDetailsCalled = true }
        func presentExportPDF(_ r: SessionReviewModels.ExportPDF.Response) async {}
        func presentAttemptBreakdown(_ r: SessionReviewModels.LoadAttemptBreakdown.Response) async {}
        func presentAnnotationUpdated(_ r: SessionReviewModels.AnnotationUpdated.Response) async {}
    }

    private func makeSUTWithCapture(spy: CapturingSpy, attempts: [AttemptDTO]) -> SessionReviewInteractor {
        let session = SessionDTO(
            id: "s1", childId: "c1", date: Date(), templateType: "test",
            targetSound: "Р", stage: "syllables",
            durationSeconds: 300, totalAttempts: attempts.count,
            correctAttempts: attempts.filter(\.isCorrect).count,
            fatigueDetected: false, isSynced: false, attempts: attempts
        )
        let repo = StubSessionRepo(session: session)
        let interactor = SessionReviewInteractor(sessionRepository: repo)
        interactor.presenter = spy
        return interactor
    }

    private func makeBreakdownRow(
        asr: Double,
        pron: Double?,
        isCorrect: Bool,
        hasManual: Bool = false
    ) -> AttemptBreakdownRow {
        AttemptBreakdownRow(
            index: 1,
            id: UUID().uuidString,
            word: "тест",
            asrTranscript: "тест",
            asrScore: asr,
            pronunciationScore: pron,
            manualScore: hasManual ? 0.8 : nil,
            effectiveScore: hasManual ? 0.8 : (pron ?? asr),
            isCorrect: isCorrect,
            audioPath: "",
            confidence: .high,
            timestamp: Date()
        )
    }
}
