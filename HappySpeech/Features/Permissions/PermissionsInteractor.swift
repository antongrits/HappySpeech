import Foundation
import OSLog
import AVFoundation
import UserNotifications
import UIKit

// MARK: - PermissionsBusinessLogic

@MainActor
protocol PermissionsBusinessLogic: AnyObject {
    func start(_ request: PermissionsModels.Start.Request)
    func requestPermission(_ request: PermissionsModels.RequestPermission.Request)
    func skipPermission(_ request: PermissionsModels.Skip.Request)
    func openSettings(_ request: PermissionsModels.OpenSettings.Request)
}

// MARK: - PermissionsInteractor

/// Бизнес-логика state-machine разрешений.
///
/// Вызывает реальные системные API (`AVCaptureDevice.requestAccess`,
/// `UNUserNotificationCenter.requestAuthorization`). Hands off `Response`
/// в Presenter для форматирования.
@MainActor
final class PermissionsInteractor: PermissionsBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any PermissionsPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Permissions")

    // MARK: - State

    private var steps: [PermissionStep] = []
    private var currentIndex: Int = 0
    private var isSingleMode: Bool = false

    // MARK: - BusinessLogic

    func start(_ request: PermissionsModels.Start.Request) {
        if let single = request.single {
            steps = [Self.makeStep(for: single, state: currentSystemState(for: single))]
            currentIndex = 0
            isSingleMode = true
        } else {
            steps = PermissionTypeRegistry.onboardingOrder.map {
                Self.makeStep(for: $0, state: currentSystemState(for: $0))
            }
            // Перематываем на первое не разрешённое.
            currentIndex = steps.firstIndex(where: { $0.state == .notDetermined })
                ?? max(0, steps.count - 1)
            isSingleMode = false
        }

        logger.info("permissions started single=\(self.isSingleMode, privacy: .public) idx=\(self.currentIndex, privacy: .public)")
        presenter?.presentStart(.init(
            steps: steps,
            currentIndex: currentIndex,
            isSingleMode: isSingleMode
        ))
    }

    func requestPermission(_ request: PermissionsModels.RequestPermission.Request) {
        guard let index = steps.firstIndex(where: { $0.id == request.type }) else {
            presenter?.presentFailure(.init(
                message: String(localized: "permissions.error.unknownType")
            ))
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.info("requesting permission=\(request.type.systemName, privacy: .public)")

            let granted = await self.askSystem(for: request.type)
            let resultState: PermissionState = granted ? .granted : .denied
            self.steps[index].state = resultState

            let nextIndex = self.advanceIndex(after: index)
            let isFinished = (nextIndex == nil) || self.isSingleMode

            self.presenter?.presentRequestPermission(.init(
                type: request.type,
                resultState: resultState,
                updatedSteps: self.steps,
                nextIndex: nextIndex,
                isFinished: isFinished
            ))

            if let next = nextIndex, !self.isSingleMode {
                self.currentIndex = next
            }
        }
    }

    func skipPermission(_ request: PermissionsModels.Skip.Request) {
        guard let index = steps.firstIndex(where: { $0.id == request.type }) else { return }

        // Не понижаем уже выданный grant — просто помечаем skipped.
        if steps[index].state == .notDetermined {
            steps[index].state = .skipped
        }

        let nextIndex = advanceIndex(after: index)
        let isFinished = (nextIndex == nil) || isSingleMode

        logger.info("skipped permission=\(request.type.systemName, privacy: .public) finished=\(isFinished, privacy: .public)")

        presenter?.presentSkip(.init(
            updatedSteps: steps,
            nextIndex: nextIndex,
            isFinished: isFinished
        ))

        if let next = nextIndex, !isSingleMode {
            currentIndex = next
        }
    }

    func openSettings(_ request: PermissionsModels.OpenSettings.Request) {
        let url = URL(string: UIApplication.openSettingsURLString)
        logger.info("openSettings requested")
        presenter?.presentOpenSettings(.init(url: url))
    }

    // MARK: - Helpers

    private func advanceIndex(after current: Int) -> Int? {
        let next = current + 1
        return steps.indices.contains(next) ? next : nil
    }

    private func currentSystemState(for type: PermissionType) -> PermissionState {
        switch type {
        case .microphone:
            switch AVAudioApplication.shared.recordPermission {
            case .granted:    return .granted
            case .denied:     return .denied
            case .undetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        case .camera:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return .granted
            case .denied:     return .denied
            case .restricted: return .restricted
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        case .notifications:
            // Уведомления — async API, поэтому в start считаем неопределённым;
            // реальный статус подтянется при requestPermission.
            return .notDetermined
        }
    }

    private func askSystem(for type: PermissionType) async -> Bool {
        switch type {
        case .microphone:
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        case .camera:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .notifications:
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                return granted
            } catch {
                logger.error("notifications request failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
    }
}

// MARK: - Step factory

private extension PermissionsInteractor {

    static func makeStep(for type: PermissionType, state: PermissionState) -> PermissionStep {
        switch type {
        case .microphone:
            return PermissionStep(
                id: .microphone,
                icon: "mic.fill",
                title: String(localized: "permissions.mic.title"),
                description: String(localized: "permissions.mic.desc"),
                allowTitle: String(localized: "permissions.mic.allow"),
                privacyNote: String(localized: "permissions.mic.privacy"),
                accentColor: .primary,
                state: state
            )
        case .camera:
            return PermissionStep(
                id: .camera,
                icon: "camera.fill",
                title: String(localized: "permissions.camera.title"),
                description: String(localized: "permissions.camera.desc"),
                allowTitle: String(localized: "permissions.camera.allow"),
                privacyNote: String(localized: "permissions.camera.privacy"),
                accentColor: .lilac,
                state: state
            )
        case .notifications:
            return PermissionStep(
                id: .notifications,
                icon: "bell.fill",
                title: String(localized: "permissions.notif.title"),
                description: String(localized: "permissions.notif.desc"),
                allowTitle: String(localized: "permissions.notif.allow"),
                privacyNote: nil,
                accentColor: .butter,
                state: state
            )
        }
    }
}

// MARK: - PermissionType helpers

extension PermissionType {
    /// Стабильный системный идентификатор для логирования.
    var systemName: String {
        switch self {
        case .microphone:    return "microphone"
        case .camera:        return "camera"
        case .notifications: return "notifications"
        }
    }
}
