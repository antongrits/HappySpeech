import Foundation
import Observation

// MARK: - PermissionsDisplayLogic

@MainActor
protocol PermissionsDisplayLogic: AnyObject {
    func displayStart(_ viewModel: PermissionsModels.Start.ViewModel)
    func displayRequestPermission(_ viewModel: PermissionsModels.RequestPermission.ViewModel)
    func displaySkip(_ viewModel: PermissionsModels.Skip.ViewModel)
    func displayOpenSettings(_ viewModel: PermissionsModels.OpenSettings.ViewModel)
    func displayFailure(_ viewModel: PermissionsModels.Failure.ViewModel)
    func displayLoading(_ isRequesting: Bool)
}

// MARK: - PermissionsDisplay

/// Источник истины SwiftUI-вью разрешений. Все поля — readonly для UI, изменяются
/// только через Display-методы (которые наполняет Presenter).
@Observable
@MainActor
final class PermissionsDisplay: PermissionsDisplayLogic {

    var steps: [PermissionStepCard] = []
    var currentIndex: Int = 0
    var progressLabel: String = ""
    var isSingleMode: Bool = false
    var isFinished: Bool = false
    var isRequesting: Bool = false
    var toastMessage: String?
    var pendingSettingsURL: URL?

    func displayStart(_ viewModel: PermissionsModels.Start.ViewModel) {
        steps = viewModel.steps
        currentIndex = viewModel.currentIndex
        progressLabel = viewModel.progressLabel
        isSingleMode = viewModel.isSingleMode
        isFinished = false
    }

    func displayRequestPermission(_ viewModel: PermissionsModels.RequestPermission.ViewModel) {
        steps = viewModel.steps
        currentIndex = viewModel.currentIndex
        toastMessage = viewModel.toastMessage
        isFinished = viewModel.isFinished
        isRequesting = false
    }

    func displaySkip(_ viewModel: PermissionsModels.Skip.ViewModel) {
        steps = viewModel.steps
        currentIndex = viewModel.currentIndex
        isFinished = viewModel.isFinished
    }

    func displayOpenSettings(_ viewModel: PermissionsModels.OpenSettings.ViewModel) {
        pendingSettingsURL = viewModel.url
        toastMessage = viewModel.toastMessage
    }

    func displayFailure(_ viewModel: PermissionsModels.Failure.ViewModel) {
        toastMessage = viewModel.toastMessage
        isRequesting = false
    }

    func displayLoading(_ isRequesting: Bool) {
        self.isRequesting = isRequesting
    }

    func clearToast() {
        toastMessage = nil
    }

    func clearPendingSettings() {
        pendingSettingsURL = nil
    }

    /// Текущий видимый шаг. nil если steps пустые.
    var currentStep: PermissionStepCard? {
        guard steps.indices.contains(currentIndex) else { return nil }
        return steps[currentIndex]
    }
}
