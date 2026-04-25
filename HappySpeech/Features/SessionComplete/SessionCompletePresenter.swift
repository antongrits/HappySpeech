import Foundation
import OSLog

// MARK: - SessionCompletePresentationLogic

@MainActor
protocol SessionCompletePresentationLogic: AnyObject {
    func presentLoadResult(_ response: SessionCompleteModels.LoadResult.Response)
    func presentAdvancePhase(_ response: SessionCompleteModels.AdvancePhase.Response)
    func presentShareResult(_ response: SessionCompleteModels.ShareResult.Response)
    func presentPlayAgain(_ response: SessionCompleteModels.PlayAgain.Response)
    func presentProceedToNext(_ response: SessionCompleteModels.ProceedToNext.Response)
    func presentFailure(_ response: SessionCompleteModels.Failure.Response)
}

// MARK: - SessionCompletePresenter

/// Преобразует Response → ViewModel: локализация, форматирование чисел,
/// accessibility-метки. Никаких вычислений и I/O.
@MainActor
final class SessionCompletePresenter: SessionCompletePresentationLogic {

    // MARK: - Collaborators

    weak var display: (any SessionCompleteDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionCompletePresenter")

    // MARK: - Formatters

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.unitsStyle = .abbreviated
        f.zeroFormattingBehavior = .pad
        return f
    }()

    // MARK: - Presentation

    func presentLoadResult(_ response: SessionCompleteModels.LoadResult.Response) {
        let result = response.result
        let scoreInt = Int((result.score * 100).rounded())
        let scoreLabel = "\(scoreInt)%"

        let attemptsTemplate = String(localized: "sessionComplete.summary.attemptsCount")
        let attemptsLabel = String(format: attemptsTemplate, result.attempts)

        let durationLabel = formatDuration(seconds: result.durationSec)

        let soundLabel = String(
            format: String(localized: "sessionComplete.summary.soundTarget"),
            result.soundTarget
        )

        let mascotTagline = makeMascotTagline(score: result.score)

        let summaryTemplate = String(localized: "sessionComplete.a11y.summary")
        let accessibilitySummary = String(
            format: summaryTemplate,
            scoreInt,
            result.starsEarned,
            result.attempts
        )

        let viewModel = SessionCompleteModels.LoadResult.ViewModel(
            scoreInt: scoreInt,
            scoreLabel: scoreLabel,
            starsEarned: result.starsEarned,
            starsTotal: 3,
            gameTitle: result.gameTitle,
            soundLabel: soundLabel,
            attemptsLabel: attemptsLabel,
            durationLabel: durationLabel,
            nextLessonTitle: result.nextLessonTitle,
            mascotTagline: mascotTagline,
            accessibilitySummary: accessibilitySummary
        )
        display?.displayLoadResult(viewModel)
    }

    func presentAdvancePhase(_ response: SessionCompleteModels.AdvancePhase.Response) {
        display?.displayAdvancePhase(.init(phase: response.phase))
    }

    func presentShareResult(_ response: SessionCompleteModels.ShareResult.Response) {
        display?.displayShareResult(.init(shareText: response.shareText))
    }

    func presentPlayAgain(_ response: SessionCompleteModels.PlayAgain.Response) {
        display?.displayPlayAgain(.init())
    }

    func presentProceedToNext(_ response: SessionCompleteModels.ProceedToNext.Response) {
        display?.displayProceedToNext(.init(hasNext: response.hasNext))
    }

    func presentFailure(_ response: SessionCompleteModels.Failure.Response) {
        logger.error("failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Private

    private func formatDuration(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes > 0 {
            return String(
                format: String(localized: "sessionComplete.summary.durationMinSec"),
                minutes,
                remainder
            )
        }
        return String(
            format: String(localized: "sessionComplete.summary.durationSec"),
            remainder
        )
    }

    private func makeMascotTagline(score: Float) -> String {
        switch score {
        case 0.9...:
            return String(localized: "sessionComplete.mascot.excellent")
        case 0.75..<0.9:
            return String(localized: "sessionComplete.mascot.good")
        case 0.5..<0.75:
            return String(localized: "sessionComplete.mascot.okay")
        default:
            return String(localized: "sessionComplete.mascot.encouraging")
        }
    }
}
