import Foundation
import OSLog
import SwiftUI

// MARK: - PermissionsPresentationLogic

@MainActor
protocol PermissionsPresentationLogic: AnyObject {
    func presentStart(_ response: PermissionsModels.Start.Response)
    func presentRequestPermission(_ response: PermissionsModels.RequestPermission.Response)
    func presentSkip(_ response: PermissionsModels.Skip.Response)
    func presentOpenSettings(_ response: PermissionsModels.OpenSettings.Response)
    func presentCheckAllPermissions(_ response: PermissionsModels.CheckAllPermissions.Response)
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

    func presentCheckAllPermissions(_ response: PermissionsModels.CheckAllPermissions.Response) {
        let cards = PermissionTypeRegistry.settingsOrder.map { type -> PermissionOverviewCard in
            let state = response.statuses[type] ?? .notDetermined
            return makeOverviewCard(for: type, state: state)
        }

        let granted = cards.filter { $0.state == .granted }.count
        let total = cards.count
        let allGranted = granted == total

        let summaryLabel: String
        if allGranted {
            summaryLabel = String(localized: "permissions.overview.allGranted")
        } else {
            summaryLabel = String(
                format: String(localized: "permissions.overview.partialGranted"),
                granted, total
            )
        }

        display?.displayCheckAllPermissions(.init(
            cards: cards,
            allGranted: allGranted,
            grantedCount: granted,
            totalCount: total,
            summaryLabel: summaryLabel
        ))
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
            accessibilityLabel: label,
            lyalyaState: makeLyalyaState(for: step.state)
        )
    }

    /// Маппинг состояния шага → состояние маскота:
    /// - granted → celebrating (праздник),
    /// - denied/restricted → encouraging (поддержка, "ничего страшного"),
    /// - skipped → idle,
    /// - notDetermined → explaining (Ляля объясняет, зачем нужно).
    private func makeLyalyaState(for permissionState: PermissionState) -> LyalyaState {
        switch permissionState {
        case .granted:       return .celebrating
        case .denied:        return .encouraging
        case .restricted:    return .encouraging
        case .skipped:       return .idle
        case .notDetermined: return .explaining
        }
    }

    private func makeProgressLabel(currentIndex: Int, total: Int) -> String {
        guard total > 0 else { return "" }
        return String(
            format: String(localized: "permissions.progressLabel"),
            currentIndex + 1, total
        )
    }

    private func makeOverviewCard(
        for type: PermissionType,
        state: PermissionState
    ) -> PermissionOverviewCard {
        let icon: String
        let title: String
        let description: String
        let accentColor: Color
        switch type {
        case .microphone:
            icon = "mic.fill"
            title = String(localized: "permissions.mic.title")
            description = String(localized: "permissions.mic.desc")
            accentColor = ColorTokens.Brand.primary
        case .camera:
            icon = "camera.fill"
            title = String(localized: "permissions.camera.title")
            description = String(localized: "permissions.camera.desc")
            accentColor = ColorTokens.Brand.lilac
        case .notifications:
            icon = "bell.fill"
            title = String(localized: "permissions.notif.title")
            description = String(localized: "permissions.notif.desc")
            accentColor = ColorTokens.Brand.butter
        case .faceTracking:
            icon = "face.dashed"
            title = String(localized: "permissions.faceTracking.title")
            description = String(localized: "permissions.faceTracking.desc")
            accentColor = ColorTokens.Brand.mint
        }

        let statusLabel: String
        switch state {
        case .granted:       statusLabel = String(localized: "permissions.overview.status.granted")
        case .denied:        statusLabel = String(localized: "permissions.overview.status.denied")
        case .restricted:    statusLabel = String(localized: "permissions.overview.status.restricted")
        case .notDetermined: statusLabel = String(localized: "permissions.overview.status.notDetermined")
        case .skipped:       statusLabel = String(localized: "permissions.overview.status.skipped")
        }

        let a11yLabel = "\(title). \(statusLabel)"
        let a11yHint: String
        switch state {
        case .granted:
            a11yHint = String(localized: "permissions.a11y.granted")
        case .denied, .restricted:
            a11yHint = String(localized: "permissions.a11y.denied")
        default:
            a11yHint = String(localized: "permissions.a11y.notDetermined")
        }

        return PermissionOverviewCard(
            id: type,
            icon: icon,
            title: title,
            description: description,
            state: state,
            accentColor: accentColor,
            statusLabel: statusLabel,
            canRequest: state == .notDetermined,
            showSettingsButton: state == .denied || state == .restricted,
            accessibilityLabel: a11yLabel,
            accessibilityHint: a11yHint
        )
    }
}

// MARK: - All-done card factory

extension PermissionsPresenter {

    /// Формирует ViewModel финального праздничного шага.
    /// View использует этот метод напрямую через `presenter` для
    /// получения локализованных строк (без отдельного VIP-цикла).
    static func makeAllDoneCard(steps: [PermissionStepCard]) -> PermissionsAllDoneCard {
        let granted = steps.filter { $0.state == .granted }.count
        let total = steps.count
        return PermissionsAllDoneCard(
            title: String(localized: "permissions.allDone.title"),
            subtitle: String(localized: "permissions.allDone.subtitle"),
            ctaTitle: String(localized: "permissions.allDone.cta"),
            lyalyaState: .celebrating,
            grantedCount: granted,
            totalCount: total
        )
    }
}
