import Foundation

// MARK: - SessionReviewPresentationLogic

@MainActor
protocol SessionReviewPresentationLogic: AnyObject {
    func presentLoadSession(_ response: SessionReviewModels.LoadSession.Response) async
    func presentSetManualScore(_ response: SessionReviewModels.SetManualScore.Response) async
    func presentFinalizeReview(_ response: SessionReviewModels.FinalizeReview.Response) async
}

// MARK: - SessionReviewDisplayLogic

@MainActor
protocol SessionReviewDisplayLogic: AnyObject {
    func displayLoadSession(_ vm: SessionReviewModels.LoadSession.ViewModel)
    func displaySetManualScore(_ vm: SessionReviewModels.SetManualScore.ViewModel)
    func displayFinalizeReview(_ vm: SessionReviewModels.FinalizeReview.ViewModel)
}

// MARK: - SessionReviewPresenter

@MainActor
final class SessionReviewPresenter: SessionReviewPresentationLogic {

    weak var display: (any SessionReviewDisplayLogic)?

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
}
