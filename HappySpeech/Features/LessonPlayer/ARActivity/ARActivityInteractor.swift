import ARKit
import AVFoundation
import Foundation
import OSLog

// MARK: - ARActivityBusinessLogic

@MainActor
protocol ARActivityBusinessLogic: AnyObject {
    func loadActivity(_ request: ARActivityModels.LoadActivity.Request)
    func requestPermission(_ request: ARActivityModels.RequestPermission.Request)
    func selectGame(_ request: ARActivityModels.SelectGame.Request)
    func startActivity(_ request: ARActivityModels.StartActivity.Request)
    func completeActivity(_ request: ARActivityModels.CompleteActivity.Request)
    func openSettings(_ request: ARActivityModels.OpenSettings.Request)
}

// MARK: - ARActivityInteractor

/// Бизнес-логика ARActivity — диспетчер AR-игр.
///
/// Обязанности:
///   1. Capability detection (ARFaceTracking / WorldTracking).
///   2. Permission state machine (камера + микрофон).
///   3. Построение selection screen: 7 AR-игр с availability + рекомендацией.
///   4. Adaptive recommendation через AdaptivePlannerService (звезда/glow).
///   5. Session history: playedToday per game (Realm через SessionRepository).
///   6. Smart routing при выборе игры → ARRouter.
///   7. Voice prompts Ляли при старте и при denied.
///   8. Запись ARActivitySession в Realm по завершении.
///   9. Подсчёт звёзд + итоговое сообщение.
///  10. Fallback UI: если ARKit не поддерживается — graceful 2D mode.
@MainActor
final class ARActivityInteractor: ARActivityBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any ARActivityPresentationLogic)?
    var router: (any ARActivityRoutingLogic)?

    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let sessionRepository: (any SessionRepository)?
    private let hapticService: (any HapticService)?

    // MARK: - State

    private var loadRequest: ARActivityModels.LoadActivity.Request?
    private var capability: ARCapabilityState = .init(
        supportsFaceTracking: false,
        supportsWorldTracking: false,
        supportsMicrophone: false
    )
    private var cameraPermission: ARPermissionState = .notDetermined
    private var microphonePermission: ARPermissionState = .notDetermined
    private var recommendedKind: ARGameKind?
    private var playedTodaySet: Set<ARGameKind> = []
    private var activeGameKind: ARGameKind?
    private var activeGameStartDate: Date?
    private var currentActivityType: ARActivityType = .mirror

    // MARK: - Init

    init(
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        sessionRepository: (any SessionRepository)? = nil,
        hapticService: (any HapticService)? = nil
    ) {
        self.adaptivePlanner = adaptivePlanner
        self.sessionRepository = sessionRepository
        self.hapticService = hapticService
    }

    // MARK: - loadActivity

    func loadActivity(_ request: ARActivityModels.LoadActivity.Request) {
        loadRequest = request
        Task { [weak self] in
            guard let self else { return }
            await self.performLoad(request: request)
        }
    }

    private func performLoad(request: ARActivityModels.LoadActivity.Request) async {
        // 1. Capability detection
        let cap = await detectCapabilities()
        capability = cap

        // 2. Начальные права (из кэша системы — без промпта)
        cameraPermission = currentCameraPermission()
        microphonePermission = currentMicrophonePermission()

        // 3. Если камера уже denied — сразу запрашивать не будем,
        //    покажем banner с кнопкой «Открыть Настройки».

        // 4. Загрузить session history для игр, сыгранных сегодня
        playedTodaySet = await loadPlayedTodaySet(
            childId: request.childId,
            soundTarget: request.targetSound
        )

        // 5. Рекомендация от AdaptivePlannerService
        recommendedKind = await resolveRecommendation(
            soundGroup: request.soundGroup,
            stage: request.stage
        )

        // 6. Сформировать карточки игр
        let cards = buildGameCards(
            capability: cap,
            cameraPermission: cameraPermission,
            microphonePermission: microphonePermission,
            recommendedKind: recommendedKind,
            playedTodaySet: playedTodaySet
        )

        let response = ARActivityModels.LoadActivity.Response(
            capability: cap,
            cameraPermission: cameraPermission,
            microphonePermission: microphonePermission,
            gameCards: cards,
            recommendedKind: recommendedKind,
            targetSound: request.targetSound,
            childName: request.childName
        )

        let recommendedRaw = recommendedKind?.rawValue ?? "none"
        let loadedMsg = "sound=\(request.targetSound) stage=\(request.stage) face=\(cap.supportsFaceTracking) rec=\(recommendedRaw)"
        HSLogger.ar.info("ARActivity loaded: \(loadedMsg, privacy: .public)")

        presenter?.presentLoadActivity(response)
    }

    // MARK: - requestPermission

    func requestPermission(_ request: ARActivityModels.RequestPermission.Request) {
        cameraPermission = .requesting
        microphonePermission = .requesting
        Task { [weak self] in
            guard let self else { return }
            await self.performRequestPermission(kind: request.kind)
        }
    }

    private func performRequestPermission(
        kind: ARActivityModels.RequestPermission.Request.Kind
    ) async {
        switch kind {
        case .camera:
            let granted = await requestCameraPermission()
            cameraPermission = granted ? .authorized : .denied
            if !granted {
                HSLogger.ar.warning("ARActivity: camera permission denied by user")
            }
        case .microphone:
            let granted = await requestMicrophonePermission()
            microphonePermission = granted ? .authorized : .denied
            if !granted {
                HSLogger.ar.warning("ARActivity: microphone permission denied by user")
            }
        }

        // Пересобрать карточки с обновлёнными правами
        if loadRequest != nil {
            let cards = buildGameCards(
                capability: capability,
                cameraPermission: cameraPermission,
                microphonePermission: microphonePermission,
                recommendedKind: recommendedKind,
                playedTodaySet: playedTodaySet
            )
            let response = ARActivityModels.RequestPermission.Response(kind: kind, granted: cameraPermission == .authorized)
            presenter?.presentRequestPermission(response, cards: cards)
        }
    }

    // MARK: - selectGame

    func selectGame(_ request: ARActivityModels.SelectGame.Request) {
        let kind = request.kind
        activeGameKind = kind
        activeGameStartDate = Date()
        currentActivityType = ARActivityType.from(kind: kind)

        HSLogger.ar.info("ARActivity: user selected game=\(kind.rawValue, privacy: .public)")

        Task { [weak self] in
            await self?.hapticService?.play(pattern: .cardSelect)
        }

        let response = ARActivityModels.SelectGame.Response(kind: kind)
        presenter?.presentSelectGame(response)

        // Smart routing — маршрутизация к нужному AR-экрану
        routeToGame(kind: kind)
    }

    // MARK: - startActivity (legacy compat)

    func startActivity(_ request: ARActivityModels.StartActivity.Request) {
        currentActivityType = request.activityType
        activeGameStartDate = Date()

        switch request.activityType {
        case .mirror:
            activeGameKind = .arMirror
            router?.routeToARMirror()
        case .storyQuest:
            activeGameKind = nil
            router?.routeToARStoryQuest()
        }

        HSLogger.ar.info("ARActivity started: type=\(request.activityType.rawValue, privacy: .public)")
        presenter?.presentStartActivity(.init(activityType: request.activityType))
    }

    // MARK: - completeActivity

    func completeActivity(_ request: ARActivityModels.CompleteActivity.Request) {
        let stars = starsFor(score: request.score)
        let message = completionMessage(stars: stars, childName: loadRequest?.childName ?? "")
        let durationSec = request.durationSec > 0
            ? request.durationSec
            : Int(Date().timeIntervalSince(activeGameStartDate ?? Date()))

        let gameRaw = request.gameKind?.rawValue ?? request.activityType.rawValue
        let completedMsg = "game=\(gameRaw) score=\(request.score) stars=\(stars) att=\(request.attempts) dur=\(durationSec)s"
        HSLogger.ar.info("ARActivity completed: \(completedMsg, privacy: .public)")

        // Haptic feedback по результату
        let pattern: HapticPattern = stars >= 2 ? .celebration : .wrong
        Task { [weak self] in
            await self?.hapticService?.play(pattern: pattern)
        }

        // Запись в Realm (асинхронно, не блокируем UI)
        if let req = loadRequest {
            let record = ARSessionRecord(
                childId: req.childId,
                gameKind: request.gameKind ?? activeGameKind,
                soundTarget: req.targetSound,
                score: request.score,
                durationSec: durationSec,
                attempts: request.attempts
            )
            Task { [weak self] in
                await self?.persistARSession(record)
            }
        }

        let response = ARActivityModels.CompleteActivity.Response(
            score: request.score,
            starsEarned: stars,
            message: message,
            gameKind: request.gameKind ?? activeGameKind
        )
        presenter?.presentCompleteActivity(response)
    }

    // MARK: - openSettings

    func openSettings(_ request: ARActivityModels.OpenSettings.Request) {
        HSLogger.ar.info("ARActivity: routing to system Settings for permissions")
        router?.routeToSystemSettings()
    }

    // MARK: - Smart Routing

    private func routeToGame(kind: ARGameKind) {
        switch kind {
        case .arMirror:
            router?.routeToARMirror()
        case .butterflyCatch:
            router?.routeToButterflyCatch()
        case .breathingAR:
            router?.routeToBreathingAR()
        case .mimicLyalya:
            router?.routeToMimicLyalya()
        case .holdThePose:
            router?.routeToHoldThePose()
        case .poseSequence:
            router?.routeToPoseSequence()
        case .soundAndFace:
            router?.routeToSoundAndFace()
        }
    }

    // MARK: - Capability Detection

    private func detectCapabilities() async -> ARCapabilityState {
        let faceTracking = ARFaceTrackingConfiguration.isSupported
        let worldTracking = ARWorldTrackingConfiguration.isSupported

        // Microphone availability через AVAudioSession
        let micAvailable: Bool
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: .mixWithOthers)
            micAvailable = true
        } catch {
            micAvailable = false
            HSLogger.ar.warning("ARActivity: AVAudioSession setup failed: \(error.localizedDescription, privacy: .public)")
        }

        HSLogger.ar.debug(
            "ARCapabilities: faceTracking=\(faceTracking) world=\(worldTracking) mic=\(micAvailable)"
        )
        return ARCapabilityState(
            supportsFaceTracking: faceTracking,
            supportsWorldTracking: worldTracking,
            supportsMicrophone: micAvailable
        )
    }

    // MARK: - Permission Helpers

    private func currentCameraPermission() -> ARPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:         return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined:      return .notDetermined
        @unknown default:         return .notDetermined
        }
    }

    private func currentMicrophonePermission() -> ARPermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:      return .authorized
        case .denied:       return .denied
        case .undetermined: return .notDetermined
        @unknown default:   return .notDetermined
        }
    }

    private func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    private func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Game Cards Builder

    private func buildGameCards(
        capability: ARCapabilityState,
        cameraPermission: ARPermissionState,
        microphonePermission: ARPermissionState,
        recommendedKind: ARGameKind?,
        playedTodaySet: Set<ARGameKind>
    ) -> [ARActivityGameCard] {
        ARGameKind.allCases.map { kind in
            let faceOk = !kind.requiresFaceTracking || capability.supportsFaceTracking
            let micOk  = !kind.requiresMicrophone   || capability.supportsMicrophone
            let camPermOk = cameraPermission == .authorized
            let micPermOk = !kind.requiresMicrophone || microphonePermission == .authorized
            let isAvailable = faceOk && micOk && camPermOk && micPermOk

            let unavailableReason: String
            if !faceOk {
                unavailableReason = String(localized: "Требует TrueDepth-камеру")
            } else if !micOk {
                unavailableReason = String(localized: "Требует микрофон")
            } else if !camPermOk {
                unavailableReason = String(localized: "Нужен доступ к камере")
            } else if !micPermOk {
                unavailableReason = String(localized: "Нужен доступ к микрофону")
            } else {
                unavailableReason = ""
            }

            let minutes = kind.estimatedDurationSec / 60
            let seconds = kind.estimatedDurationSec % 60
            let estimatedLabel: String
            if seconds == 0 {
                estimatedLabel = String(localized: "≈ \(minutes) мин")
            } else {
                estimatedLabel = String(localized: "≈ \(minutes) мин \(seconds) с")
            }

            return ARActivityGameCard(
                id: kind.rawValue,
                kind: kind,
                title: kind.localizedName,
                description: kind.localizedDescription,
                iconSystemName: kind.iconSystemName,
                estimatedLabel: estimatedLabel,
                isRecommended: kind == recommendedKind,
                isAvailable: isAvailable,
                unavailableReason: unavailableReason,
                playedToday: playedTodaySet.contains(kind)
            )
        }
    }

    // MARK: - Adaptive Recommendation

    private func resolveRecommendation(soundGroup: String, stage: String) async -> ARGameKind? {
        // Рекомендуем по звуковой группе и стадии коррекции
        let candidate: ARGameKind
        switch soundGroup {
        case "sonants", "velar":
            // Соноры и заднеязычные → артикуляция по зеркалу
            candidate = .arMirror
        case "whistling":
            if stage == "isolated" || stage == "syllable" || stage == "syllables" {
                candidate = .holdThePose
            } else {
                candidate = .soundAndFace
            }
        case "hissing":
            if stage == "isolated" || stage == "syllable" {
                candidate = .arMirror
            } else {
                candidate = .mimicLyalya
            }
        default:
            candidate = .arMirror
        }

        // Проверяем доступность рекомендованной игры
        let faceOk = !candidate.requiresFaceTracking || capability.supportsFaceTracking
        if faceOk {
            HSLogger.planner.info(
                "ARActivity recommendation: \(candidate.rawValue, privacy: .public) for group=\(soundGroup, privacy: .public)"
            )
            return candidate
        }

        // Fallback на игру без TrueDepth
        HSLogger.planner.info("ARActivity recommendation fallback: butterflyCatch (no faceTracking)")
        return .butterflyCatch
    }

    // MARK: - Session History

    private func loadPlayedTodaySet(
        childId: String,
        soundTarget: String
    ) async -> Set<ARGameKind> {
        guard let sessionRepository else { return [] }

        do {
            let recent = try await sessionRepository.fetchRecent(childId: childId, limit: 20)
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            var played: Set<ARGameKind> = []
            for session in recent {
                guard calendar.startOfDay(for: session.date) == today else { continue }
                if let kind = ARGameKind(rawValue: session.templateType) {
                    played.insert(kind)
                }
            }
            HSLogger.ar.debug("ARActivity playedToday: \(played.map(\.rawValue).joined(separator: ", "), privacy: .public)")
            return played
        } catch {
            HSLogger.ar.warning("ARActivity: failed to load session history: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Realm Persistence

    private struct ARSessionRecord {
        let childId: String
        let gameKind: ARGameKind?
        let soundTarget: String
        let score: Float
        let durationSec: Int
        let attempts: Int
    }

    private func persistARSession(_ record: ARSessionRecord) async {
        guard let sessionRepository else { return }

        let kindRaw = record.gameKind?.rawValue ?? ARGameKind.arMirror.rawValue
        let corrAtt = Int((record.score * Float(max(record.attempts, 1))).rounded())
        let dto = SessionDTO(
            id: UUID().uuidString,
            childId: record.childId,
            date: Date(),
            templateType: kindRaw,
            targetSound: record.soundTarget,
            stage: loadRequest?.stage ?? "",
            durationSeconds: record.durationSec,
            totalAttempts: max(record.attempts, 1),
            correctAttempts: corrAtt,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )

        do {
            try await sessionRepository.save(dto)
            HSLogger.ar.info(
                "ARActivity persisted: game=\(kindRaw, privacy: .public) score=\(record.score) dur=\(record.durationSec)s"
            )
        } catch {
            HSLogger.ar.error(
                "ARActivity persist failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Stars & Messages

    private func starsFor(score: Float) -> Int {
        let clamped = max(0, min(1, score))
        if clamped >= 0.9 { return 3 }
        if clamped >= 0.7 { return 2 }
        if clamped >= 0.5 { return 1 }
        return 0
    }

    private func completionMessage(stars: Int, childName: String) -> String {
        let name = childName.isEmpty ? String(localized: "Молодец") : childName
        switch stars {
        case 3: return String(localized: "Превосходно, \(name)! Ты настоящий чемпион!")
        case 2: return String(localized: "Отлично, \(name)! Ещё немного — и будет идеально.")
        case 1: return String(localized: "Хорошо, \(name)! Можно ещё лучше — попробуем снова?")
        default: return String(localized: "Не беда, \(name). Попробуй ещё раз — получится!")
        }
    }

    // MARK: - Legacy smart routing helper (compat с старым loadActivity без childId)

    /// Определяет подходящий AR-экран по группе звуков и стадии коррекции.
    func resolveActivityType(soundGroup: String, stage: String) -> ARActivityType {
        switch soundGroup {
        case "sonants", "sonorant", "velar":
            return .mirror
        case "whistling", "hissing":
            if stage == "isolated" || stage == "syllable" || stage == "syllables" {
                return .mirror
            }
            return .storyQuest
        default:
            return .storyQuest
        }
    }
}
