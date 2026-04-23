import XCTest
@testable import HappySpeech

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
            makeAttempt(id: "a2", asr: 0.3, pron: 0.4),
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
                             audioPath: "", isMarkedCorrect: false),
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
}
