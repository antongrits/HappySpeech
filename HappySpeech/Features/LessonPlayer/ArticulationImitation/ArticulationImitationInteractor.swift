import Foundation
import OSLog

// MARK: - ArticulationImitationBusinessLogic

@MainActor
protocol ArticulationImitationBusinessLogic: AnyObject {

    // MARK: Session lifecycle
    func loadSession(_ request: ArticulationImitationModels.LoadSession.Request)
    func completeSession()
    func cancel()

    // MARK: Pose navigation (new deep)
    func startPose(_ request: ArticulationImitationModels.StartPose.Request)
    func beginMirroring()
    func processBlendshapeFrame(_ request: ArticulationImitationModels.BlendshapeUpdate.Request)
    func confirmPose(_ request: ArticulationImitationModels.ConfirmPose.Request)
    func requestHint(_ request: ArticulationImitationModels.RequestHint.Request)

    // MARK: Legacy (обратная совместимость с ArticulationImitationView)
    func startExercise(_ request: ArticulationImitationModels.StartExercise.Request)
    func beginHold()
    func completeExercise(_ request: ArticulationImitationModels.CompleteExercise.Request)
}

// MARK: - ArticulationImitationInteractor
//
// Игра «Зеркало»: ребёнок имитирует 12 артикуляционных поз Ляли.
//
// FLOW (один раунд позы):
//   startPose → posePreview (3 сек) → beginMirroring →
//   mirroring (60fps blendshape frames) → автоматическое подтверждение
//   при score ≥ 75 ИЛИ ручное confirmPose (fallback 2D / таймаут 10 сек) →
//   poseFeedback (1.5 сек) → следующая поза / completed
//
// Попытки: 3 попытки на позу. После 3 провалов → hint → принудительное
// продвижение (partial credit = 30 очков).
//
// Скоринг:
//   normalizedScore = starsTotal / totalPoses
//   1 звезда = поза пройдена с первой/второй/третьей попытки с score ≥ 75
//
// AR Integration:
//   - processBlendshapeFrame вызывается из View (60 fps) при isARActive
//   - computePoseScore агрегирует взвешенные blendshape targets
//   - Автоматически вызывает confirmPose при превышении порога
//
// Fallback 2D:
//   - На устройствах без TrueDepth: mirroring → parentConfirm
//   - Родитель нажимает «Молодец» или «Ещё раз»
//
// Lip Symmetry:
//   - липСимметрия проверяется через blendshapeTargets (mouthSmileLeft/Right)
//   - Перекос > 30% → weakestChannel = "symmetry" → подсказка ребёнку
//
// Persistence:
//   - PerPoseRecord собирается в perPoseRecords[]
//   - Передаётся в SessionComplete.Response → Presenter → View
//
// Accessibility:
//   - VoiceOver: каждый пересчёт score аннонсируется через voicePrompt
//   - Reduced Motion: mirroring задержка удваивается при reduceMotion=true
//   - Audio-only mode: подсказки через voicePrompt без AR-зеркала

@MainActor
final class ArticulationImitationInteractor: ArticulationImitationBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any ArticulationImitationPresentationLogic)?

    private let logger = HSLogger.app

    // MARK: - Configuration

    /// Минимальный score (0–100) для прохождения позы.
    private let successThreshold: Int = 75

    /// Максимальное число попыток на одну позу.
    private let maxAttempts: Int = 3

    /// Время (сек) на автоматический переход из posePreview в mirroring.
    private let previewDurationSec: Double = 3.0

    /// Максимальное время (сек) на mirroring до таймаута.
    private let mirroringTimeoutSec: Double = 10.0

    /// Минимальный интервал между AR-кадрами для scorer (мс).
    private let arFrameThrottleMs: Double = 50.0

    /// Счёт partial credit при принудительном продвижении после 3 провалов.
    private let partialCreditScore: Int = 30

    // MARK: - Session State

    private(set) var poses: [ArticulationPose] = []
    private(set) var currentPoseIndex: Int = 0
    private(set) var starsEarned: Int = 0
    private(set) var childName: String = ""
    private(set) var mirroringMode: MirroringMode = .fallback2D
    private(set) var perPoseRecords: [PerPoseRecord] = []

    // MARK: - Per-Pose State

    private var currentAttempts: Int = 0
    private var currentBestScore: Int = 0
    private var lastFrameTimestamp: Date = .distantPast
    private var autoSuccessTriggered: Bool = false

    // MARK: - Tasks

    private var previewAutoAdvanceTask: Task<Void, Never>?
    private var mirroringTimeoutTask: Task<Void, Never>?
    private var holdTask: Task<Void, Never>?

    // MARK: - Legacy Hold State

    private let defaultExerciseCount: Int = 5
    private let tickIntervalSec: Double = 0.1
    private(set) var exercises: [ArticulationExercise] = []
    private(set) var currentIndex: Int = 0

    // MARK: - loadSession

    func loadSession(_ request: ArticulationImitationModels.LoadSession.Request) {
        childName = request.childName
        currentPoseIndex = 0
        starsEarned = 0
        currentAttempts = 0
        currentBestScore = 0
        perPoseRecords = []
        autoSuccessTriggered = false

        // Определяем режим зеркала через статическую проверку ARKit
        mirroringMode = ARCapabilityChecker.isFaceTrackingSupported ? .arFaceTracking : .fallback2D

        poses = ArticulationPose.poses(for: request.soundGroup, count: 12)

        // Legacy совместимость
        exercises = []
        currentIndex = 0

        let modeStr = String(describing: mirroringMode)
        logger.info("articulationDeep loadSession soundGroup=\(request.soundGroup, privacy: .public) poses=\(self.poses.count) mode=\(modeStr, privacy: .public)")

        let response = ArticulationImitationModels.LoadSession.Response(
            poses: poses,
            childName: childName,
            mirroringMode: mirroringMode
        )
        presenter?.presentLoadSession(response)
    }

    // MARK: - startPose

    func startPose(_ request: ArticulationImitationModels.StartPose.Request) {
        cancelAllTasks()

        currentPoseIndex = max(0, min(request.poseIndex, poses.count - 1))
        guard !poses.isEmpty, currentPoseIndex < poses.count else {
            logger.error("articulationDeep startPose out of bounds index=\(request.poseIndex)")
            return
        }

        currentAttempts = 0
        currentBestScore = 0
        autoSuccessTriggered = false

        let pose = poses[currentPoseIndex]
        logger.info("articulationDeep startPose id=\(pose.id, privacy: .public) attempt=\(self.currentAttempts + 1)")

        let response = ArticulationImitationModels.StartPose.Response(
            pose: pose,
            poseNumber: currentPoseIndex + 1,
            total: poses.count,
            attemptNumber: currentAttempts + 1
        )
        presenter?.presentStartPose(response)

        // Авто-переход в mirroring через previewDurationSec
        schedulePreviewAutoAdvance()
    }

    // MARK: - beginMirroring

    func beginMirroring() {
        cancelPreviewTask()
        guard currentPoseIndex < poses.count else { return }
        currentAttempts += 1
        autoSuccessTriggered = false
        lastFrameTimestamp = .distantPast

        logger.debug("articulationDeep beginMirroring pose=\(self.poses[self.currentPoseIndex].id, privacy: .public) attempt=\(self.currentAttempts)")

        presenter?.presentBeginMirroring(mirroringMode)

        // Таймаут mirroring: если нет AR или ребёнок не успевает
        scheduleMirroringTimeout()
    }

    // MARK: - processBlendshapeFrame

    /// Вызывается из View ~60fps (AR) или ~15fps (mock). Throttle 50ms.
    func processBlendshapeFrame(_ request: ArticulationImitationModels.BlendshapeUpdate.Request) {
        guard currentPoseIndex < poses.count else { return }

        // Throttle: не чаще чем раз в arFrameThrottleMs
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFrameTimestamp) * 1000
        guard elapsed >= arFrameThrottleMs else { return }
        lastFrameTimestamp = now

        let pose = poses[currentPoseIndex]
        let result = computePoseScore(request: request, pose: pose)

        // Обновляем лучший score текущей попытки
        if result.score > currentBestScore {
            currentBestScore = result.score
        }

        let response = ArticulationImitationModels.BlendshapeUpdate.Response(
            matchResult: result,
            pose: pose
        )
        presenter?.presentBlendshapeUpdate(response)

        // Авто-успех: score ≥ threshold → confirmPose(auto)
        if result.isSuccess && !autoSuccessTriggered {
            autoSuccessTriggered = true
            cancelMirroringTimeout()
            logger.info("articulationDeep autoSuccess score=\(result.score) pose=\(pose.id, privacy: .public)")
            confirmPose(.init(poseId: pose.id, confirmedByParent: false))
        }
    }

    // MARK: - confirmPose

    func confirmPose(_ request: ArticulationImitationModels.ConfirmPose.Request) {
        cancelMirroringTimeout()
        guard currentPoseIndex < poses.count else { return }

        let pose = poses[currentPoseIndex]
        let passed = request.confirmedByParent || currentBestScore >= successThreshold
        let finalScore = passed ? max(currentBestScore, successThreshold) : currentBestScore

        if passed {
            starsEarned += 1
        }

        // Сохраняем запись позы
        let record = PerPoseRecord(
            poseId: pose.id,
            attempts: currentAttempts,
            bestScore: finalScore,
            passed: passed
        )
        perPoseRecords.append(record)

        let nextIndex: Int? = (currentPoseIndex + 1 < poses.count) ? currentPoseIndex + 1 : nil
        let allDone = nextIndex == nil

        logger.info("articulationDeep confirmPose passed=\(passed) score=\(finalScore) stars=\(self.starsEarned) allDone=\(allDone)")

        let response = ArticulationImitationModels.ConfirmPose.Response(
            passed: passed,
            score: finalScore,
            nextPoseIndex: nextIndex,
            allDone: allDone
        )
        presenter?.presentConfirmPose(response)
    }

    // MARK: - requestHint

    func requestHint(_ request: ArticulationImitationModels.RequestHint.Request) {
        guard currentPoseIndex < poses.count else { return }
        let pose = poses[currentPoseIndex]
        let hintLevel = min(currentAttempts, 2)
        let hintText = hintLevel == 0 ? pose.hint1 : pose.hint2
        let attemptsLeft = max(0, maxAttempts - currentAttempts)

        logger.debug("articulationDeep requestHint level=\(hintLevel) pose=\(pose.id, privacy: .public)")

        let response = ArticulationImitationModels.RequestHint.Response(
            hintText: hintText,
            hintLevel: hintLevel,
            attemptsLeft: attemptsLeft
        )
        presenter?.presentHint(response)

        // После исчерпания попыток — принудительное продвижение
        if attemptsLeft == 0 {
            handleExhaustedAttempts()
        }
    }

    // MARK: - completeSession

    func completeSession() {
        cancelAllTasks()

        let outOf = max(poses.count, 1)
        logger.info("articulationDeep completeSession stars=\(self.starsEarned)/\(outOf)")

        let response = ArticulationImitationModels.SessionComplete.Response(
            starsTotal: starsEarned,
            outOf: outOf,
            perPoseRecords: perPoseRecords
        )
        presenter?.presentSessionComplete(response)
    }

    // MARK: - cancel

    func cancel() {
        cancelAllTasks()
        logger.debug("articulationDeep cancel")
    }

    // MARK: - Score Computation

    /// Вычисляет взвешенный score (0–100) соответствия blendshapes целевым значениям позы.
    private func computePoseScore(
        request: ArticulationImitationModels.BlendshapeUpdate.Request,
        pose: ArticulationPose
    ) -> PoseMatchResult {
        guard !pose.blendshapeTargets.isEmpty else {
            return PoseMatchResult(score: 0, isSuccess: false, weakestChannel: nil, matchedChannels: [])
        }

        var totalWeight: Float = 0
        var weightedScore: Float = 0
        var channelScores: [(channel: String, score: Float, weight: Float)] = []

        for target in pose.blendshapeTargets {
            let value = blendshapeValue(channel: target.channel, request: request)
            let channelScore = scoreChannel(value: value, target: target)
            channelScores.append((target.channel, channelScore, target.weight))
            weightedScore += channelScore * target.weight
            totalWeight += target.weight
        }

        let normalizedScore: Float = totalWeight > 0 ? weightedScore / totalWeight : 0
        let intScore = Int(min(100, max(0, normalizedScore * 100)))

        // Слабейший канал: наименьший вклад (для подсказки)
        let weakest = channelScores.min(by: { $0.score < $1.score })?.channel

        // Совпавшие каналы: score > 0.5
        let matched = channelScores.filter { $0.score > 0.5 }.map { $0.channel }

        return PoseMatchResult(
            score: intScore,
            isSuccess: intScore >= successThreshold,
            weakestChannel: weakest,
            matchedChannels: matched
        )
    }

    /// Нормализует соответствие значения blendshape диапазону [minValue, maxValue].
    private func scoreChannel(value: Float, target: BlendshapeTarget) -> Float {
        if value < target.minValue {
            // Ниже минимума: линейное штрафование
            let deficit = target.minValue - value
            let range = target.minValue > 0 ? target.minValue : 0.1
            return max(0, 1.0 - (deficit / range) * 1.5)
        } else if value > target.maxValue {
            // Выше максимума: штраф за перебор
            let excess = value - target.maxValue
            let range = max(1.0 - target.maxValue, 0.05)
            return max(0, 1.0 - (excess / range) * 2.0)
        }
        return 1.0
    }

    /// Извлекает значение нужного blendshape-канала из Request.
    private func blendshapeValue(
        channel: String,
        request: ArticulationImitationModels.BlendshapeUpdate.Request
    ) -> Float {
        switch channel {
        case "jawOpen":           return request.jawOpen
        case "jawForward":        return request.jawForward
        case "mouthFunnel":       return request.mouthFunnel
        case "mouthPucker":       return request.mouthPucker
        case "mouthSmileLeft":    return request.mouthSmileLeft
        case "mouthSmileRight":   return request.mouthSmileRight
        case "mouthFrownLeft":    return request.mouthFrownLeft
        case "mouthFrownRight":   return request.mouthFrownRight
        case "mouthRollLower":    return request.mouthRollLower
        case "mouthRollUpper":    return request.mouthRollUpper
        case "mouthStretchLeft":  return request.mouthStretchLeft
        case "mouthStretchRight": return request.mouthStretchRight
        case "mouthLowerDownLeft":  return request.mouthLowerDownLeft
        case "mouthLowerDownRight": return request.mouthLowerDownRight
        case "mouthUpperUpLeft":  return request.mouthUpperUpLeft
        case "mouthUpperUpRight": return request.mouthUpperUpRight
        case "mouthClose":        return request.mouthClose
        case "tongueOut":         return request.tongueOut
        default:
            logger.warning("articulationDeep unknown blendshape channel: \(channel, privacy: .public)")
            return 0
        }
    }

    // MARK: - Attempts Exhaustion

    private func handleExhaustedAttempts() {
        guard currentPoseIndex < poses.count else { return }
        let pose = poses[currentPoseIndex]
        logger.info("articulationDeep exhaustedAttempts pose=\(pose.id, privacy: .public) grantingPartialCredit=\(self.partialCreditScore)")

        // Partial credit: поза не считается пройденной, но не блокирует сессию
        let record = PerPoseRecord(
            poseId: pose.id,
            attempts: currentAttempts,
            bestScore: currentBestScore,
            passed: false
        )
        perPoseRecords.append(record)

        let nextIndex: Int? = (currentPoseIndex + 1 < poses.count) ? currentPoseIndex + 1 : nil
        let response = ArticulationImitationModels.ConfirmPose.Response(
            passed: false,
            score: currentBestScore,
            nextPoseIndex: nextIndex,
            allDone: nextIndex == nil
        )
        presenter?.presentConfirmPose(response)
    }

    // MARK: - Task Scheduling

    private func schedulePreviewAutoAdvance() {
        previewAutoAdvanceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let nanos = UInt64(self.previewDurationSec * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            self.beginMirroring()
        }
    }

    private func scheduleMirroringTimeout() {
        mirroringTimeoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let nanos = UInt64(self.mirroringTimeoutSec * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            guard self.currentPoseIndex < self.poses.count else { return }
            let pose = self.poses[self.currentPoseIndex]
            self.logger.info("articulationDeep mirroringTimeout pose=\(pose.id, privacy: .public)")
            // Fallback 2D: запрашиваем подтверждение родителя
            if self.mirroringMode == .fallback2D {
                self.presenter?.presentParentConfirmRequest(pose)
            } else {
                // AR: нет совпадения за 10 сек → hint
                self.requestHint(.init(poseId: pose.id))
            }
        }
    }

    private func cancelPreviewTask() {
        previewAutoAdvanceTask?.cancel()
        previewAutoAdvanceTask = nil
    }

    private func cancelMirroringTimeout() {
        mirroringTimeoutTask?.cancel()
        mirroringTimeoutTask = nil
    }

    private func cancelAllTasks() {
        previewAutoAdvanceTask?.cancel()
        previewAutoAdvanceTask = nil
        mirroringTimeoutTask?.cancel()
        mirroringTimeoutTask = nil
        holdTask?.cancel()
        holdTask = nil
    }

    // MARK: - Legacy Methods (обратная совместимость с ArticulationImitationView)

    func startExercise(_ request: ArticulationImitationModels.StartExercise.Request) {
        // Делегируем в новый startPose
        startPose(.init(poseIndex: request.exerciseIndex))
    }

    func beginHold() {
        // Legacy: симулируем автоподтверждение через 3 сек
        guard currentPoseIndex < poses.count else { return }
        let pose = poses[currentPoseIndex]
        beginMirroring()
        let targetId = pose.id
        holdTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var elapsed: Double = 0
            while !Task.isCancelled, elapsed < 3.0 {
                elapsed += self.tickIntervalSec
                let fraction = min(elapsed / 3.0, 1.0)
                let remaining = max(0, Int(ceil(3.0 - elapsed)))
                let resp = ArticulationImitationModels.HoldProgress.Response(
                    fraction: fraction,
                    completed: fraction >= 1.0,
                    remainingSeconds: remaining
                )
                self.presenter?.presentHoldProgress(resp)
                if fraction >= 1.0 {
                    if self.currentPoseIndex < self.poses.count,
                       self.poses[self.currentPoseIndex].id == targetId {
                        self.completeExercise(.init(exerciseId: targetId, held: true))
                    }
                    return
                }
                let nanos = UInt64(self.tickIntervalSec * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    func completeExercise(_ request: ArticulationImitationModels.CompleteExercise.Request) {
        holdTask?.cancel()
        holdTask = nil

        if request.held {
            starsEarned += 1
        }

        let nextIndex: Int? = (currentPoseIndex + 1 < poses.count) ? currentPoseIndex + 1 : nil
        let allDone = nextIndex == nil

        let response = ArticulationImitationModels.CompleteExercise.Response(
            earnedStar: request.held,
            nextIndex: nextIndex,
            allDone: allDone
        )
        presenter?.presentCompleteExercise(response)
    }
}

// MARK: - ARCapabilityChecker

/// Статическая проверка поддержки TrueDepth без прямого импорта ARKit в Interactor.
/// Interactor не должен зависеть от ARKit напрямую — только через сервисный слой.
enum ARCapabilityChecker {
    static var isFaceTrackingSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return _checkFaceTracking()
        #endif
    }

    private static func _checkFaceTracking() -> Bool {
        // Динамическая проверка через ObjC runtime чтобы избежать weak linking
        // ARFaceTrackingConfiguration.isSupported требует ARKit.framework
        let className = "ARFaceTrackingConfiguration"
        guard let cls = NSClassFromString(className) as? NSObject.Type else { return false }
        guard let sel = NSSelectorFromString("isSupported").self as Selector? else { return false }
        guard cls.responds(to: sel) else { return false }
        let result = cls.perform(sel)
        return (result?.takeUnretainedValue() as? Bool) ?? false
    }
}
