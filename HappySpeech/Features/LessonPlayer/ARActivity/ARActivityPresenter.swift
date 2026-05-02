import Foundation

// MARK: - ARActivityPresentationLogic

@MainActor
protocol ARActivityPresentationLogic: AnyObject {
    func presentLoadActivity(_ response: ARActivityModels.LoadActivity.Response)
    func presentRequestPermission(
        _ response: ARActivityModels.RequestPermission.Response,
        cards: [ARActivityGameCard]
    )
    func presentSelectGame(_ response: ARActivityModels.SelectGame.Response)
    func presentStartActivity(_ response: ARActivityModels.StartActivity.Response)
    func presentCompleteActivity(_ response: ARActivityModels.CompleteActivity.Response)
}

// MARK: - ARActivityPresenter

/// Форматирует строки на русском и готовит ViewModel для SwiftUI.
@MainActor
final class ARActivityPresenter: ARActivityPresentationLogic {

    weak var viewModel: (any ARActivityDisplayLogic)?

    // MARK: - LoadActivity

    func presentLoadActivity(_ response: ARActivityModels.LoadActivity.Response) {
        let screenTitle = String(localized: "AR-игры")
        let subtitle: String
        if response.targetSound.isEmpty {
            subtitle = String(localized: "Выбери AR-упражнение")
        } else {
            subtitle = String(localized: "Звук «\(response.targetSound)» — выбери упражнение")
        }

        let showBanner: Bool
        let bannerMessage: String
        if response.cameraPermission == .denied {
            showBanner = true
            bannerMessage = String(
                localized: "Разреши доступ к камере в Настройках — без неё AR не работает"
            )
        } else if response.cameraPermission == .notDetermined {
            showBanner = true
            bannerMessage = String(localized: "Камера нужна для AR. Нажми «Разрешить»")
        } else {
            showBanner = false
            bannerMessage = ""
        }

        let hasAnyAvailable = response.gameCards.contains { $0.isAvailable }

        let vm = ARActivityModels.LoadActivity.ViewModel(
            screenTitle: screenTitle,
            subtitle: subtitle,
            gameCards: response.gameCards,
            cameraPermissionState: response.cameraPermission,
            microphonePermissionState: response.microphonePermission,
            showPermissionBanner: showBanner,
            permissionBannerMessage: bannerMessage,
            hasAnyAvailableGame: hasAnyAvailable,
            previewReady: true
        )
        viewModel?.displayLoadActivity(vm)
    }

    // MARK: - RequestPermission

    func presentRequestPermission(
        _ response: ARActivityModels.RequestPermission.Response,
        cards: [ARActivityGameCard]
    ) {
        let camPermission: ARPermissionState
        let micPermission: ARPermissionState

        switch response.kind {
        case .camera:
            camPermission = response.granted ? .authorized : .denied
            micPermission = .notDetermined
        case .microphone:
            camPermission = .authorized
            micPermission = response.granted ? .authorized : .denied
        }

        let showBanner = camPermission == .denied
        let bannerMessage: String
        if camPermission == .denied {
            bannerMessage = String(
                localized: "Доступ к камере запрещён. Открой Настройки и разреши HappySpeech"
            )
        } else if micPermission == .denied {
            bannerMessage = String(
                localized: "Доступ к микрофону запрещён. Открой Настройки и разреши HappySpeech"
            )
        } else {
            bannerMessage = ""
        }

        let vm = ARActivityModels.RequestPermission.ViewModel(
            cameraPermission: camPermission,
            microphonePermission: micPermission,
            showPermissionBanner: showBanner,
            permissionBannerMessage: bannerMessage
        )
        viewModel?.displayRequestPermission(vm, cards: cards)
    }

    // MARK: - SelectGame

    func presentSelectGame(_ response: ARActivityModels.SelectGame.Response) {
        let vm = ARActivityModels.SelectGame.ViewModel(kind: response.kind)
        viewModel?.displaySelectGame(vm)
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
