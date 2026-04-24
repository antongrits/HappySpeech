import Foundation

// MARK: - ARActivityDisplayLogic
//
// Контракт между `ARActivityPresenter` и SwiftUI-представлением.
// `ARActivityViewDisplay` реализует этот протокол и хранит состояние UI.

@MainActor
protocol ARActivityDisplayLogic: AnyObject {
    func displayLoadActivity(_ viewModel: ARActivityModels.LoadActivity.ViewModel)
    func displayStartActivity(_ viewModel: ARActivityModels.StartActivity.ViewModel)
    func displayCompleteActivity(_ viewModel: ARActivityModels.CompleteActivity.ViewModel)
}

// MARK: - ARActivityViewDisplay + ARActivityDisplayLogic

extension ARActivityViewDisplay: ARActivityDisplayLogic {
    func displayLoadActivity(_ viewModel: ARActivityModels.LoadActivity.ViewModel) {
        self.title = viewModel.title
        self.description = viewModel.description
        self.iconSystemName = viewModel.iconSystemName
        self.estimatedLabel = viewModel.estimatedLabel
        self.activityType = viewModel.activityType
        self.phase = viewModel.previewReady ? .preview : .loading
    }

    func displayStartActivity(_ viewModel: ARActivityModels.StartActivity.ViewModel) {
        self.activityType = viewModel.activityType
        self.phase = .active
    }

    func displayCompleteActivity(_ viewModel: ARActivityModels.CompleteActivity.ViewModel) {
        self.starsEarned = viewModel.starsEarned
        self.scoreLabel = viewModel.scoreLabel
        self.completionMessage = viewModel.message
        self.lastScore = viewModel.score
        self.phase = .completed
    }
}
