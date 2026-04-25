import Foundation
import OSLog

// MARK: - PermissionsPresentationLogic

@MainActor
protocol PermissionsPresentationLogic: AnyObject {
    func presentStart(_ response: PermissionsModels.Start.Response)
    func presentRequestPermission(_ response: PermissionsModels.RequestPermission.Response)
    func presentSkip(_ response: PermissionsModels.Skip.Response)
    func presentOpenSettings(_ response: PermissionsModels.OpenSettings.Response)
    func presentFailure(_ response: PermissionsModels.Failure.Response)
}

// MARK: - PermissionsPresenter

@MainActor
final class PermissionsPresenter: PermissionsPresentationLogic {

    weak var display: (any PermissionsDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PermissionsPresenter")

    // MARK: - PresentationLogic

    func presentStart(_ response: PermissionsModels.Start.Response) {
        let cards = response.steps.map(makeCard)
        let progressLabel = makeProgressLabel(
            currentIndex: response.currentIndex,
            total: response.steps.count
        )
        display?.displayStart(.init(
            steps: cards,
            currentIndex: response.currentIndex,
            progressLabel: progressLabel,
            isSingleMode: response.isSingleMode
        ))
    }

    func presentRequestPermission(_ response: PermissionsModels.RequestPermission.Response) {
        let cards = response.updatedSteps.map(makeCard)

        let toast: String?
        switch response.resultState {
        case .granted:
            toast = String(localized: "permissions.toast.granted")
        case .denied:
            toast = String(localized: "permissions.toast.denied")
        case .restricted:
            toast = String(localized: "permissions.toast.restricted")
        case .notDetermined, .skipped:
            toast = nil
        }

        let nextIdx = response.nextIndex ?? response.updatedSteps.count - 1
        display?.displayRequestPermission(.init(
            steps: cards,
            currentIndex: nextIdx,
            toastMessage: toast,
            isFinished: response.isFinished
        ))
    }

    func presentSkip(_ response: PermissionsModels.Skip.Response) {
        let cards = response.updatedSteps.map(makeCard)
        let nextIdx = response.nextIndex ?? response.updatedSteps.count - 1
        display?.displaySkip(.init(
            steps: cards,
            currentIndex: nextIdx,
            isFinished: response.isFinished
        ))
    }

    func presentOpenSettings(_ response: PermissionsModels.OpenSettings.Response) {
        let toast: String? = response.url == nil
            ? String(localized: "permissions.toast.cannotOpenSettings")
            : nil
        display?.displayOpenSettings(.init(url: response.url, toastMessage: toast))
    }

    func presentFailure(_ response: PermissionsModels.Failure.Response) {
        logger.error("permissions failure: \(response.message, privacy: .public)")
        display?.displayFailure(.init(toastMessage: response.message))
    }

    // MARK: - Helpers

    private func makeCard(_ step: PermissionStep) -> PermissionStepCard {
        let showSettings = step.state == .denied || step.state == .restricted
        let isCompleted = step.state == .granted
            || step.state == .skipped
            || step.state == .denied
            || step.state == .restricted

        let stateLabel: String
        switch step.state {
        case .granted:       stateLabel = String(localized: "permissions.a11y.granted")
        case .denied:        stateLabel = String(localized: "permissions.a11y.denied")
        case .restricted:    stateLabel = String(localized: "permissions.a11y.restricted")
        case .notDetermined: stateLabel = String(localized: "permissions.a11y.notDetermined")
        case .skipped:       stateLabel = String(localized: "permissions.a11y.skipped")
        }

        let label = "\(step.title). \(step.description). \(stateLabel)"

        return PermissionStepCard(
            id: step.id,
            icon: step.icon,
            title: step.title,
            description: step.description,
            allowTitle: step.allowTitle,
            skipTitle: String(localized: "permissions.skip"),
            privacyNote: step.privacyNote,
            accentColor: step.accentColor.color,
            state: step.state,
            showSettingsButton: showSettings,
            isCompleted: isCompleted,
            accessibilityLabel: label
        )
    }

    private func makeProgressLabel(currentIndex: Int, total: Int) -> String {
        guard total > 0 else { return "" }
        return String(
            format: String(localized: "permissions.progressLabel"),
            currentIndex + 1, total
        )
    }
}
