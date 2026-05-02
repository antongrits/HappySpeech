import Foundation

// MARK: - ARActivityDisplayLogic
//
// Контракт между `ARActivityPresenter` и SwiftUI-представлением.
// `ARActivityViewDisplay` реализует этот протокол и хранит состояние UI.

@MainActor
protocol ARActivityDisplayLogic: AnyObject {
    func displayLoadActivity(_ viewModel: ARActivityModels.LoadActivity.ViewModel)
    func displayRequestPermission(
        _ viewModel: ARActivityModels.RequestPermission.ViewModel,
        cards: [ARActivityGameCard]
    )
    func displaySelectGame(_ viewModel: ARActivityModels.SelectGame.ViewModel)
    func displayStartActivity(_ viewModel: ARActivityModels.StartActivity.ViewModel)
    func displayCompleteActivity(_ viewModel: ARActivityModels.CompleteActivity.ViewModel)
}

// MARK: - ARActivityViewDisplay + ARActivityDisplayLogic

extension ARActivityViewDisplay: ARActivityDisplayLogic {

    func displayLoadActivity(_ viewModel: ARActivityModels.LoadActivity.ViewModel) {
        screenTitle = viewModel.screenTitle
        subtitle = viewModel.subtitle
        gameCards = viewModel.gameCards
        cameraPermission = viewModel.cameraPermissionState
        microphonePermission = viewModel.microphonePermissionState
        showPermissionBanner = viewModel.showPermissionBanner
        permissionBannerMessage = viewModel.permissionBannerMessage
        hasAnyAvailableGame = viewModel.hasAnyAvailableGame
        // legacy compat
        title = viewModel.screenTitle
        phase = viewModel.previewReady ? .selection : .loading
    }

    func displayRequestPermission(
        _ viewModel: ARActivityModels.RequestPermission.ViewModel,
        cards: [ARActivityGameCard]
    ) {
        cameraPermission = viewModel.cameraPermission
        microphonePermission = viewModel.microphonePermission
        showPermissionBanner = viewModel.showPermissionBanner
        permissionBannerMessage = viewModel.permissionBannerMessage
        gameCards = cards
        hasAnyAvailableGame = cards.contains { $0.isAvailable }
        if viewModel.cameraPermission == .denied {
            phase = .permissionDenied
        } else if phase == .permissionDenied {
            phase = .selection
        }
    }

    func displaySelectGame(_ viewModel: ARActivityModels.SelectGame.ViewModel) {
        activeGameKind = viewModel.kind
        activityType = ARActivityType.from(kind: viewModel.kind)
        phase = .active
    }

    func displayStartActivity(_ viewModel: ARActivityModels.StartActivity.ViewModel) {
        activityType = viewModel.activityType
        phase = .active
    }

    func displayCompleteActivity(_ viewModel: ARActivityModels.CompleteActivity.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        lastScore = viewModel.score
        phase = .completed
    }
}
