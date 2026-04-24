import Foundation

// MARK: - ARActivityPresentationLogic

@MainActor
protocol ARActivityPresentationLogic: AnyObject {
    func presentLoadActivity(_ response: ARActivityModels.LoadActivity.Response)
    func presentStartActivity(_ response: ARActivityModels.StartActivity.Response)
    func presentCompleteActivity(_ response: ARActivityModels.CompleteActivity.Response)
}

// MARK: - ARActivityPresenter
//
// Форматирует строки на русском и готовит ViewModel для SwiftUI.
@MainActor
final class ARActivityPresenter: ARActivityPresentationLogic {

    weak var viewModel: (any ARActivityDisplayLogic)?

    // MARK: - LoadActivity

    func presentLoadActivity(_ response: ARActivityModels.LoadActivity.Response) {
        let title: String
        switch response.activityType {
        case .mirror:
            title = String(localized: "AR-зеркало")
        case .storyQuest:
            title = String(localized: "AR-квест")
        }

        let estimatedLabel = String(
            localized: "≈ \(response.estimatedMinutes) мин"
        )

        let vm = ARActivityModels.LoadActivity.ViewModel(
            title: title,
            description: response.description,
            iconSystemName: response.iconSystemName,
            estimatedLabel: estimatedLabel,
            activityType: response.activityType,
            previewReady: true
        )
        viewModel?.displayLoadActivity(vm)
    }

    // MARK: - StartActivity

    func presentStartActivity(_ response: ARActivityModels.StartActivity.Response) {
        let vm = ARActivityModels.StartActivity.ViewModel(activityType: response.activityType)
        viewModel?.displayStartActivity(vm)
    }

    // MARK: - CompleteActivity

    func presentCompleteActivity(_ response: ARActivityModels.CompleteActivity.Response) {
        let percentage = Int((response.score * 100).rounded())
        let scoreLabel = String(localized: "Результат: \(percentage)%")
        let vm = ARActivityModels.CompleteActivity.ViewModel(
            starsEarned: response.starsEarned,
            scoreLabel: scoreLabel,
            message: response.message,
            score: response.score
        )
        viewModel?.displayCompleteActivity(vm)
    }
}
