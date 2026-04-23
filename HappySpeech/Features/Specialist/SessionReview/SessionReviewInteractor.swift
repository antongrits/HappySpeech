import Foundation
import OSLog

// MARK: - SessionReviewBusinessLogic

@MainActor
protocol SessionReviewBusinessLogic: AnyObject {
    func loadSession(_ request: SessionReviewModels.LoadSession.Request) async
    func setManualScore(_ request: SessionReviewModels.SetManualScore.Request) async
    func finalizeReview(_ request: SessionReviewModels.FinalizeReview.Request) async
}

// MARK: - SessionReviewInteractor

/// Per-attempt review flow. Loads the session via SessionRepository, turns
/// attempts into rows, holds per-row manual overrides in memory, and re-emits
/// an updated view model on each override. Finalization persists a
/// `ReviewedSession` back to the repo (method stubbed in MVP — writes
/// specialist notes locally; full Firestore persistence lives in
/// `LiveSessionRepository.attachSpecialistReview`).
@MainActor
final class SessionReviewInteractor: SessionReviewBusinessLogic {

    var presenter: (any SessionReviewPresentationLogic)?

    private let sessionRepository: any SessionRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionReview")

    private var currentSession: SessionDTO?
    private var rows: [AttemptReviewRow] = []
    private var specialistNotes: String = ""

    init(sessionRepository: any SessionRepository) {
        self.sessionRepository = sessionRepository
    }

    // MARK: - Load

    func loadSession(_ request: SessionReviewModels.LoadSession.Request) async {
        do {
            let session = try await sessionRepository.fetch(id: request.sessionId)
            currentSession = session
            rows = session.attempts.map { attempt in
                AttemptReviewRow(
                    id: attempt.id,
                    word: attempt.word,
                    asrTranscript: attempt.asrTranscript,
                    autoScore: max(attempt.asrScore, attempt.pronunciationScore),
                    manualScore: attempt.manualScore > 0 ? attempt.manualScore : nil,
                    audioPath: attempt.audioLocalPath,
                    isMarkedCorrect: attempt.isCorrect
                )
            }
            await presenter?.presentLoadSession(.init(
                session: session,
                attemptRows: rows
            ))
        } catch {
            logger.error("loadSession failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Manual override

    func setManualScore(_ request: SessionReviewModels.SetManualScore.Request) async {
        guard let index = rows.firstIndex(where: { $0.id == request.attemptId }) else { return }
        let clamped = max(0.0, min(1.0, request.manualScore))
        let current = rows[index]
        rows[index] = AttemptReviewRow(
            id: current.id,
            word: current.word,
            asrTranscript: current.asrTranscript,
            autoScore: current.autoScore,
            manualScore: clamped,
            audioPath: current.audioPath,
            isMarkedCorrect: clamped >= 0.5
        )
        let summary = Self.makeSummary(rows: rows)
        await presenter?.presentSetManualScore(.init(attemptRows: rows, summary: summary))
    }

    // MARK: - Finalize

    func finalizeReview(_ request: SessionReviewModels.FinalizeReview.Request) async {
        specialistNotes = request.specialistNotes
        let savedAt = Date()
        logger.info("review finalized session=\(request.sessionId, privacy: .public) notes=\(request.specialistNotes.count, privacy: .public)")
        await presenter?.presentFinalizeReview(.init(savedAt: savedAt))
    }

    // MARK: - Summary

    static func makeSummary(rows: [AttemptReviewRow]) -> SessionReviewSummary {
        guard !rows.isEmpty else {
            return SessionReviewSummary(
                totalAttempts: 0, markedCorrect: 0,
                averageEffectiveScore: 0, disagreementCount: 0
            )
        }
        let avg = rows.map(\.effectiveScore).reduce(0, +) / Double(rows.count)
        let correct = rows.filter(\.isMarkedCorrect).count
        let disagreements = rows.filter { row in
            guard let manual = row.manualScore else { return false }
            return abs(manual - row.autoScore) > 0.15
        }.count
        return SessionReviewSummary(
            totalAttempts: rows.count,
            markedCorrect: correct,
            averageEffectiveScore: avg,
            disagreementCount: disagreements
        )
    }

    // MARK: - Test hook

    func _rows() -> [AttemptReviewRow] { rows }
}
