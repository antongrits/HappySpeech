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
}

// MARK: - SessionReviewDisplayLogic

@MainActor
protocol SessionReviewDisplayLogic: AnyObject {
    func displayLoadSession(_ vm: SessionReviewModels.LoadSession.ViewModel)
    func displaySetManualScore(_ vm: SessionReviewModels.SetManualScore.ViewModel)
    func displayFinalizeReview(_ vm: SessionReviewModels.FinalizeReview.ViewModel)
    func displayLoadDetails(_ vm: SessionReviewModels.LoadDetails.ViewModel)
    func displayExportPDF(_ vm: SessionReviewModels.ExportPDF.ViewModel)
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
