import Foundation
import SwiftUI

// MARK: - SessionReviewPresentationLogic

@MainActor
protocol SessionReviewPresentationLogic: AnyObject {
    func presentLoadSession(_ response: SessionReviewModels.LoadSession.Response) async
    func presentSetManualScore(_ response: SessionReviewModels.SetManualScore.Response) async
    func presentFinalizeReview(_ response: SessionReviewModels.FinalizeReview.Response) async
    func presentLoadDetails(_ response: SessionReviewModels.LoadDetails.Response) async
    func presentExportPDF(_ response: SessionReviewModels.ExportPDF.Response) async
    /// M6.15: Breakdown по попыткам.
    func presentAttemptBreakdown(_ response: SessionReviewModels.LoadAttemptBreakdown.Response) async
    /// M6.15: Обновление аннотаций (после add/delete).
    func presentAnnotationUpdated(_ response: SessionReviewModels.AnnotationUpdated.Response) async
}

// MARK: - SessionReviewDisplayLogic

@MainActor
protocol SessionReviewDisplayLogic: AnyObject {
    func displayLoadSession(_ vm: SessionReviewModels.LoadSession.ViewModel)
    func displaySetManualScore(_ vm: SessionReviewModels.SetManualScore.ViewModel)
    func displayFinalizeReview(_ vm: SessionReviewModels.FinalizeReview.ViewModel)
    func displayLoadDetails(_ vm: SessionReviewModels.LoadDetails.ViewModel)
    func displayExportPDF(_ vm: SessionReviewModels.ExportPDF.ViewModel)
    /// M6.15: Breakdown по попыткам.
    func displayAttemptBreakdown(_ vm: SessionReviewModels.LoadAttemptBreakdown.ViewModel)
    /// M6.15: Обновление аннотаций.
    func displayAnnotationUpdated(_ vm: SessionReviewModels.AnnotationUpdated.ViewModel)
}

// MARK: - SessionReviewPresenter

@MainActor
final class SessionReviewPresenter: SessionReviewPresentationLogic {

    weak var display: (any SessionReviewDisplayLogic)?

    // MARK: - Per-attempt (existing)

    func presentLoadSession(_ response: SessionReviewModels.LoadSession.Response) async {
        let title = String(localized: "review.title.\(response.session.targetSound)")
        let summary = SessionReviewInteractor.makeSummary(rows: response.attemptRows)
        display?.displayLoadSession(.init(
            titleText: title,
            rows: response.attemptRows,
            summary: summary
        ))
    }

    func presentSetManualScore(_ response: SessionReviewModels.SetManualScore.Response) async {
        display?.displaySetManualScore(.init(rows: response.attemptRows, summary: response.summary))
    }

    func presentFinalizeReview(_ response: SessionReviewModels.FinalizeReview.Response) async {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        display?.displayFinalizeReview(.init(
            confirmationText: String(
                localized: "review.saved.at.\(formatter.string(from: response.savedAt))"
            )
        ))
    }

    // MARK: - Full session details (B1)

    func presentLoadDetails(_ response: SessionReviewModels.LoadDetails.Response) async {
        let summary = response.summary

        let title = String(format: String(localized: "review.details.title"), summary.childName)
        let dateText = Self.dateFormatter.string(from: summary.date)
        let durationText = Self.formatDuration(summary.duration)
        let totalAttemptsText = String(
            format: String(localized: "review.details.total_attempts"),
            summary.correctAttempts,
            summary.totalAttempts
        )
        let overallPercent = summary.totalAttempts > 0
            ? Int((Double(summary.correctAttempts) / Double(summary.totalAttempts) * 100).rounded())
            : 0

        let games = summary.games.map { Self.makeGameRow(from: $0) }
        let phonemeRows = summary.phonemeAccuracy
            .sorted(by: { $0.key < $1.key })
            .map { (phoneme, accuracy) -> PhonemeRowViewModel in
                let percent = Int((accuracy * 100).rounded())
                return PhonemeRowViewModel(
                    id: phoneme,
                    phoneme: phoneme,
                    accuracyPercent: percent,
                    tone: AccuracyTone.make(from: percent)
                )
            }
        let chartData = phonemeRows.map { row in
            SoundAccuracy(
                id: row.id,
                label: row.phoneme,
                value: Double(row.accuracyPercent) / 100.0,
                color: Self.color(for: row.tone)
            )
        }

        let viewModel = SessionReviewModels.LoadDetails.ViewModel(
            titleText: title,
            dateText: dateText,
            durationText: durationText,
            childNameText: summary.childName,
            games: games,
            phonemeChartData: chartData,
            phonemeRows: phonemeRows,
            llmRecommendation: summary.llmRecommendation,
            overallAccuracyPercent: overallPercent,
            totalAttemptsText: totalAttemptsText
        )
        display?.displayLoadDetails(viewModel)
    }

    // MARK: - Export PDF

    func presentExportPDF(_ response: SessionReviewModels.ExportPDF.Response) async {
        let confirmation = String(
            format: String(localized: "review.export.ready"),
            response.url.lastPathComponent
        )
        display?.displayExportPDF(.init(
            shareableURL: response.url,
            confirmationText: confirmation
        ))
    }

    // MARK: - M6.15: Attempt breakdown

    func presentAttemptBreakdown(_ response: SessionReviewModels.LoadAttemptBreakdown.Response) async {
        let rowVMs = response.rows.map { row -> AttemptBreakdownViewModel in
            let scorePct = Int((row.effectiveScore * 100).rounded())
            let tone = AccuracyTone.make(from: scorePct)
            return AttemptBreakdownViewModel(
                id: row.id,
                index: row.index,
                word: row.word,
                asrTranscript: row.asrTranscript.isEmpty
                    ? String(localized: "review.breakdown.no_transcript")
                    : row.asrTranscript,
                asrScoreText: "\(Int((row.asrScore * 100).rounded()))%",
                pronunciationScoreText: row.pronunciationScore.map { "\(Int(($0 * 100).rounded()))%" },
                effectiveScoreText: "\(scorePct)%",
                isCorrect: row.isCorrect,
                audioPath: row.audioPath,
                confidenceIconName: row.confidence.iconName,
                tone: tone,
                hasManualScore: row.manualScore != nil,
                timestampText: Self.timeFormatter.string(from: row.timestamp)
            )
        }

        let allRows = response.rows
        let stats = SessionReviewInteractor.breakdownStats(from: allRows)
        let statsVM = BreakdownStatsViewModel(
            averageASRText: "\(Int((stats.averageASR * 100).rounded()))%",
            averagePronunciationText: stats.averagePronunciation.map { "\(Int(($0 * 100).rounded()))%" },
            averageEffectiveText: "\(Int((stats.averageEffective * 100).rounded()))%",
            totalCorrectText: String(
                format: String(localized: "review.breakdown.correct_of"),
                stats.totalCorrect,
                allRows.count
            ),
            manualOverrideText: stats.manualOverrideCount > 0
                ? String(format: String(localized: "review.breakdown.manual_count"), stats.manualOverrideCount)
                : nil
        )

        display?.displayAttemptBreakdown(.init(
            sessionId: response.sessionId,
            rows: rowVMs,
            stats: statsVM
        ))
    }

    // MARK: - M6.15: Annotations

    func presentAnnotationUpdated(_ response: SessionReviewModels.AnnotationUpdated.Response) async {
        let annotationVMs = response.annotations.map { ann -> AnnotationViewModel in
            AnnotationViewModel(
                id: ann.id,
                text: ann.text,
                dateText: Self.annotationDateFormatter.string(from: ann.createdAt),
                targetAttemptWord: nil,  // word lookup требует доступа к попыткам; в MVP опускаем
                isSessionLevel: ann.targetAttemptId == nil
            )
        }
        display?.displayAnnotationUpdated(.init(annotations: annotationVMs))
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        if minutes > 0 {
            return String(format: String(localized: "review.duration.minutes_seconds"), minutes, secs)
        }
        return String(format: String(localized: "review.duration.seconds"), secs)
    }

    private static func makeGameRow(from result: GameResult) -> GameResultViewModel {
        let percent = Int((result.accuracy * 100).rounded())
        let detail = String(
            format: String(localized: "review.game.detail"),
            result.correct,
            result.total
        )
        return GameResultViewModel(
            id: result.id,
            title: result.gameName,
            detailText: detail,
            accuracyPercent: percent,
            tone: AccuracyTone.make(from: percent)
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let annotationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static func color(for tone: AccuracyTone) -> Color {
        switch tone {
        case .good:
            return ColorTokens.Semantic.success
        case .medium:
            return ColorTokens.Brand.gold
        case .poor:
            return ColorTokens.Semantic.error
        }
    }
}
