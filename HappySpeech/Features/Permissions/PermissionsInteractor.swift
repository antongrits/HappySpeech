import AVFoundation
import Foundation
import OSLog
import UIKit
import UserNotifications

// MARK: - PermissionsBusinessLogic

@MainActor
protocol PermissionsBusinessLogic: AnyObject {
    func start(_ request: PermissionsModels.Start.Request)
    func requestPermission(_ request: PermissionsModels.RequestPermission.Request)
    func retryPermission(_ request: PermissionsModels.RetryPermission.Request)
    func skipPermission(_ request: PermissionsModels.Skip.Request)
    func openSettings(_ request: PermissionsModels.OpenSettings.Request)
    func checkAllPermissions(_ request: PermissionsModels.CheckAllPermissions.Request)
    func checkSinglePermission(_ request: PermissionsModels.CheckSingle.Request)
    func refreshOnForeground()
    func getLyalyaVoicePrompt(_ request: PermissionsModels.LyalyaPrompt.Request)
    func getDeniedGuidance(_ request: PermissionsModels.DeniedGuidance.Request)
}

// MARK: - PermissionsInteractor

/// Бизнес-логика state machine разрешений.
///
/// Вызывает реальные системные API (`AVCaptureDevice.requestAccess`,
/// `UNUserNotificationCenter.requestAuthorization`). Hands off `Response`
/// в Presenter для форматирования.
///
/// Расширенные возможности (v14):
/// - Persistence снапшота статусов в UserDefaults (ключ `permissions.snapshot.v1`)
/// - Auto-refresh при UIApplication.didBecomeActiveNotification (foreground re-check)
/// - Retry flow: mic/camera — redirect to Settings (iOS не допускает re-request),
///   notifications — единственный тип с реальным повторным запросом.
/// - Lyalya voice prompts per permission step (child-friendly тексты)
/// - Guidance messages для denied-case с пошаговыми инструкциями
/// - requiredPermissionDenied flag для блокировки mic-зависимых функций
/// - Sequential skip persistence (`permissions_skipped` в UserDefaults)
@MainActor
final class PermissionsInteractor: PermissionsBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any PermissionsPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Permissions")

    // MARK: - State

    private var steps: [PermissionStep] = []
    private var currentIndex: Int = 0
    private var isSingleMode: Bool = false

    // MARK: - Persistence keys

    private enum PersistenceKey {
        static let snapshot = "permissions.snapshot.v1"
        static let skipped  = "permissions.flow.skipped"
        static let seenAt   = "permissions.flow.seenAt"
    }

    // MARK: - Foreground observer
    //
    // Хранится как Optional<Any> чтобы обойти Swift 6 Sendable ограничение
    // на NSObjectProtocol в nonisolated deinit. Снятие наблюдателя
    // происходит через явный cancel() или при повторном вызове register.

    private var foregroundObserverToken: Any?

    // MARK: - BusinessLogic

    func start(_ request: PermissionsModels.Start.Request) {
        registerForegroundObserver()
        recordFirstSeen()

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

        persistStatusSnapshot()
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

        presenter?.presentLoading(true)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.info("requesting permission=\(request.type.systemName, privacy: .public)")

            let granted = await self.askSystem(for: request.type)
            let resultState: PermissionState = granted ? .granted : .denied
            self.steps[index].state = resultState

            self.persistStatusSnapshot()

            let nextIndex = self.advanceIndex(after: index)
            let isFinished = (nextIndex == nil) || self.isSingleMode

            // Если mic denied — логируем критический факт.
            if !granted && request.type == .microphone {
                self.logger.warning("microphone denied — pronunciation features will be degraded")
            }

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

    /// Попытка повторного запроса разрешения.
    ///
    /// iOS политика:
    /// - Notifications: возможен повторный запрос через UNUserNotificationCenter
    ///   (если статус undetermined или пользователь его сбросил в Settings).
    /// - Microphone / Camera / FaceTracking: iOS не допускает повторного диалога.
    ///   Единственный путь — открыть Settings.
    ///
    /// Interactor сам определяет, какой branch использовать.
    func retryPermission(_ request: PermissionsModels.RetryPermission.Request) {
        let currentState = currentSystemState(for: request.type)

        switch request.type {
        case .notifications:
            // Notifications могут быть повторно запрошены если статус undetermined.
            if currentState == .notDetermined {
                logger.info("retry notifications — re-requesting")
                requestPermission(.init(type: request.type))
            } else {
                // Уже denied — редирект в Settings.
                logger.info("retry notifications denied — opening Settings")
                presenter?.presentOpenSettings(.init(url: URL(string: UIApplication.openSettingsURLString)))
            }
        case .microphone, .camera, .faceTracking:
            // iOS не допускает повторный запрос — только Settings.
            logger.info("retry \(request.type.systemName, privacy: .public) — redirecting to Settings (iOS policy)")
            presenter?.presentOpenSettings(.init(url: URL(string: UIApplication.openSettingsURLString)))
        }
    }

    func skipPermission(_ request: PermissionsModels.Skip.Request) {
        guard let index = steps.firstIndex(where: { $0.id == request.type }) else { return }

        if steps[index].state == .notDetermined {
            steps[index].state = .skipped
        }

        let nextIndex = advanceIndex(after: index)
        let isFinished = (nextIndex == nil) || isSingleMode

        logger.info("skipped permission=\(request.type.systemName, privacy: .public) finished=\(isFinished, privacy: .public)")

        // Если завершили flow через skip — сохраняем флаг.
        if isFinished && !isSingleMode {
            UserDefaults.standard.set(true, forKey: PersistenceKey.skipped)
        }

        persistStatusSnapshot()

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

    func checkAllPermissions(_ request: PermissionsModels.CheckAllPermissions.Request) {
        logger.info("checkAllPermissions")
        var statuses: [PermissionType: PermissionState] = [:]
        for type in PermissionTypeRegistry.settingsOrder {
            statuses[type] = currentSystemState(for: type)
        }
        persistStatusSnapshot(from: statuses)
        presenter?.presentCheckAllPermissions(.init(statuses: statuses))
    }

    /// Проверяет статус одного разрешения без системного prompt.
    /// Используется при возврате из Settings (foreground re-check).
    func checkSinglePermission(_ request: PermissionsModels.CheckSingle.Request) {
        let state = currentSystemState(for: request.type)
        logger.debug("checkSingle \(request.type.systemName, privacy: .public) → \(String(describing: state), privacy: .public)")

        // Обновляем шаг если он присутствует в текущем flow.
        if let index = steps.firstIndex(where: { $0.id == request.type }) {
            steps[index].state = state
            persistStatusSnapshot()
            presenter?.presentRequestPermission(.init(
                type: request.type,
                resultState: state,
                updatedSteps: steps,
                nextIndex: nil,
                isFinished: false
            ))
        }

        presenter?.presentCheckAllPermissions(.init(statuses: [request.type: state]))
    }

    /// Вызывается при UIApplicationDidBecomeActive — перечитывает статусы
    /// (пользователь мог изменить их в iOS Settings пока приложение было в фоне).
    func refreshOnForeground() {
        logger.debug("refreshOnForeground — re-reading permission statuses")

        var updated = false
        for index in steps.indices {
            let freshState = currentSystemState(for: steps[index].id)
            if steps[index].state != freshState {
                let permName = self.steps[index].id.systemName
                let oldState = String(describing: self.steps[index].state)
                let newState = String(describing: freshState)
                logger.info("permission \(permName, privacy: .public) changed: \(oldState, privacy: .public) -> \(newState, privacy: .public)")
                steps[index].state = freshState
                updated = true
            }
        }

        if updated {
            persistStatusSnapshot()
            presenter?.presentStart(.init(
                steps: steps,
                currentIndex: currentIndex,
                isSingleMode: isSingleMode
            ))
        }

        // Также обновляем overview независимо от flow.
        checkAllPermissions(.init())
    }

    /// Возвращает голосовую реплику Ляли для текущего шага.
    /// Тексты child-friendly, подходят для TTS озвучки маскота.
    func getLyalyaVoicePrompt(_ request: PermissionsModels.LyalyaPrompt.Request) {
        let prompt = lyalyaPrompt(for: request.type, state: request.state)
        presenter?.presentLyalyaPrompt(.init(type: request.type, prompt: prompt))
    }

    /// Формирует детальное guidance-сообщение для denied-case.
    /// Содержит пошаговые инструкции «Как открыть Настройки».
    func getDeniedGuidance(_ request: PermissionsModels.DeniedGuidance.Request) {
        let guidance = buildGuidanceMessage(for: request.type)
        presenter?.presentDeniedGuidance(.init(type: request.type, guidanceMessage: guidance))
    }

    // MARK: - Foreground observer

    private func registerForegroundObserver() {
        guard foregroundObserverToken == nil else { return }
        foregroundObserverToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshOnForeground()
            }
        }
        logger.debug("foreground observer registered")
    }

    /// Явная отмена наблюдателя. Вызывается из View при disappear если нужно.
    func cancelForegroundObserver() {
        if let token = foregroundObserverToken {
            NotificationCenter.default.removeObserver(token)
            foregroundObserverToken = nil
            logger.debug("foreground observer cancelled")
        }
    }

    // MARK: - Persistence

    private func persistStatusSnapshot() {
        var statuses: [PermissionType: PermissionState] = [:]
        for step in steps {
            statuses[step.id] = step.state
        }
        persistStatusSnapshot(from: statuses)
    }

    private func persistStatusSnapshot(from statuses: [PermissionType: PermissionState]) {
        var dict: [String: String] = [:]
        for (type, state) in statuses {
            dict[type.systemName] = state.persistenceKey
        }
        UserDefaults.standard.set(dict, forKey: PersistenceKey.snapshot)
        logger.debug("status snapshot persisted: \(dict, privacy: .private)")
    }

    /// Восстанавливает последний сохранённый снапшот статусов из UserDefaults.
    /// Используется при cold-start чтобы показать актуальные statuses
    /// до первого системного запроса.
    func restoreStatusSnapshot() -> [PermissionType: PermissionState] {
        guard let dict = UserDefaults.standard.dictionary(forKey: PersistenceKey.snapshot)
                as? [String: String] else {
            return [:]
        }
        var result: [PermissionType: PermissionState] = [:]
        for (typeName, stateName) in dict {
            if let permType = PermissionType.fromSystemName(typeName),
               let permState = PermissionState.fromPersistenceKey(stateName) {
                result[permType] = permState
            }
        }
        return result
    }

    /// Записывает дату первого показа flow в UserDefaults.
    private func recordFirstSeen() {
        if UserDefaults.standard.object(forKey: PersistenceKey.seenAt) == nil {
            UserDefaults.standard.set(Date(), forKey: PersistenceKey.seenAt)
            logger.info("permissions flow: first seen recorded")
        }
    }

    // MARK: - Lyalya voice prompts

    /// Возвращает child-friendly реплику Ляли для конкретного типа/состояния.
    private func lyalyaPrompt(for type: PermissionType, state: PermissionState) -> String {
        switch state {
        case .granted:
            return lyalyaGrantedPrompt(for: type)
        case .denied, .restricted:
            return lyalyaDeniedPrompt(for: type)
        case .skipped:
            return String(localized: "permissions.lyalya.skipped")
        case .notDetermined:
            return lyalyaAskingPrompt(for: type)
        }
    }

    private func lyalyaAskingPrompt(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return String(localized: "permissions.lyalya.mic.asking")
        case .camera:
            return String(localized: "permissions.lyalya.camera.asking")
        case .notifications:
            return String(localized: "permissions.lyalya.notif.asking")
        case .faceTracking:
            return String(localized: "permissions.lyalya.faceTracking.asking")
        }
    }

    private func lyalyaGrantedPrompt(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return String(localized: "permissions.lyalya.mic.granted")
        case .camera:
            return String(localized: "permissions.lyalya.camera.granted")
        case .notifications:
            return String(localized: "permissions.lyalya.notif.granted")
        case .faceTracking:
            return String(localized: "permissions.lyalya.faceTracking.granted")
        }
    }

    private func lyalyaDeniedPrompt(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return String(localized: "permissions.lyalya.mic.denied")
        case .camera:
            return String(localized: "permissions.lyalya.camera.denied")
        case .notifications:
            return String(localized: "permissions.lyalya.notif.denied")
        case .faceTracking:
            return String(localized: "permissions.lyalya.faceTracking.denied")
        }
    }

    // MARK: - Denied guidance

    /// Возвращает пошаговую инструкцию как включить разрешение через iOS Settings.
    private func buildGuidanceMessage(for type: PermissionType) -> String {
        let appName = String(localized: "app.name")
        switch type {
        case .microphone:
            return String(
                format: String(localized: "permissions.guidance.mic"),
                appName
            )
        case .camera, .faceTracking:
            return String(
                format: String(localized: "permissions.guidance.camera"),
                appName
            )
        case .notifications:
            return String(
                format: String(localized: "permissions.guidance.notifications"),
                appName
            )
        }
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
            case .granted:      return .granted
            case .denied:       return .denied
            case .undetermined: return .notDetermined
            @unknown default:   return .notDetermined
            }
        case .camera, .faceTracking:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:    return .granted
            case .denied:        return .denied
            case .restricted:    return .restricted
            case .notDetermined: return .notDetermined
            @unknown default:    return .notDetermined
            }
        case .notifications:
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
        case .camera, .faceTracking:
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
        case .faceTracking:
            return PermissionStep(
                id: .faceTracking,
                icon: "face.dashed",
                title: String(localized: "permissions.faceTracking.title"),
                description: String(localized: "permissions.faceTracking.desc"),
                allowTitle: String(localized: "permissions.faceTracking.allow"),
                privacyNote: String(localized: "permissions.faceTracking.privacy"),
                accentColor: .primary,
                state: state
            )
        }
    }
}

// MARK: - PermissionType helpers

extension PermissionType {
    /// Стабильный системный идентификатор для логирования и persistence.
    var systemName: String {
        switch self {
        case .microphone:    return "microphone"
        case .camera:        return "camera"
        case .notifications: return "notifications"
        case .faceTracking:  return "faceTracking"
        }
    }

    /// Восстановление типа из строкового ключа persistence.
    static func fromSystemName(_ name: String) -> PermissionType? {
        switch name {
        case "microphone":    return .microphone
        case "camera":        return .camera
        case "notifications": return .notifications
        case "faceTracking":  return .faceTracking
        default:              return nil
        }
    }
}

// MARK: - PermissionState persistence helpers

extension PermissionState {
    var persistenceKey: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .granted:       return "granted"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .skipped:       return "skipped"
        }
    }

    static func fromPersistenceKey(_ key: String) -> PermissionState? {
        switch key {
        case "notDetermined": return .notDetermined
        case "granted":       return .granted
        case "denied":        return .denied
        case "restricted":    return .restricted
        case "skipped":       return .skipped
        default:              return nil
        }
    }
}
