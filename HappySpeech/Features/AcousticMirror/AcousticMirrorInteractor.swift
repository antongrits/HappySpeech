import Foundation
import OSLog

// MARK: - AcousticMirrorBusinessLogic

@MainActor
protocol AcousticMirrorBusinessLogic: AnyObject {
    /// Запуск сессии: резолв целевого звука (профиль ребёнка → первый сибилянт).
    func startSession(_ request: AcousticMirrorModels.Start.Request) async
    /// Одна попытка: запись `attemptDuration` сек → анализ → результат раунда.
    func performAttempt(_ request: AcousticMirrorModels.Attempt.Request) async
    /// Переключение целевого звука вручную (С ↔ Ш и т.п.) — сбрасывает раунды.
    func switchTargetSound(to sound: String) async
    /// Отмена активной записи/анализа (выход с экрана).
    func cancel()
}

// MARK: - AcousticMirrorInteractor

/// Бизнес-логика «Акустического зеркала» (Clean Swift VIP).
///
/// Владеет жизненным циклом записи (audioService) и анализа (mirrorService) —
/// View только рисует state и шлёт интенты. Результаты честные: при отсутствии
/// фрикативного звука раунд получает 0 звёзд и подсказку «потяни звук»,
/// никакой фабрикации оценок.
///
/// Персистентность по завершении сессии:
///   • `SessionDTO` через `SessionPersistenceCoordinating` (реальные минуты/стрик/
///     агрегаты профиля; stage = isolated — честная стадия изолированного звука);
///   • исход каждого раунда — в FSRS-лестницу через `AdaptivePlannerService`.
@MainActor
final class AcousticMirrorInteractor: AcousticMirrorBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any AcousticMirrorPresentationLogic)?

    private let childId: String
    private let audioService: any AudioService
    private let mirrorService: any AcousticMirrorServicing
    private let childRepository: (any ChildRepository)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let sessionPersistence: (any SessionPersistenceCoordinating)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "AcousticMirror")

    /// Источник «сейчас»/sleep — инъектируется для детерминированных тестов.
    private let sleeper: @Sendable (TimeInterval) async -> Void

    // MARK: - Session state

    private(set) var targetSound: String = "С"
    private(set) var roundNumber: Int = 0
    private(set) var earnedStars: [Int] = []
    private(set) var positions: [Double] = []
    private var sessionStart = Date()
    private var attemptTask: Task<Void, Never>?
    private var didPersistSession = false
    private let sessionId = UUID().uuidString

    // MARK: - Init

    init(
        childId: String,
        audioService: any AudioService,
        mirrorService: any AcousticMirrorServicing,
        childRepository: (any ChildRepository)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        sessionPersistence: (any SessionPersistenceCoordinating)? = nil,
        sleeper: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(for: .seconds(seconds))
        }
    ) {
        self.childId = childId
        self.audioService = audioService
        self.mirrorService = mirrorService
        self.childRepository = childRepository
        self.adaptivePlanner = adaptivePlanner
        self.sessionPersistence = sessionPersistence
        self.sleeper = sleeper
    }

    // MARK: - Business logic

    func startSession(_ request: AcousticMirrorModels.Start.Request) async {
        sessionStart = Date()
        roundNumber = 0
        earnedStars = []
        positions = []
        didPersistSession = false

        targetSound = await resolveTargetSound(preferred: request.preferredSound)
        logger.info("AcousticMirror start: sound=\(self.targetSound, privacy: .public)")

        presenter?.presentStart(
            AcousticMirrorModels.Start.Response(
                targetSound: targetSound,
                totalRounds: AcousticMirrorModels.roundsPerSession
            )
        )
    }

    func performAttempt(_ request: AcousticMirrorModels.Attempt.Request) async {
        guard roundNumber < AcousticMirrorModels.roundsPerSession else { return }
        guard attemptTask == nil else { return } // запись уже идёт

        // Разрешение микрофона — честный отказ без фейковой оценки.
        if !audioService.isPermissionGranted {
            let granted = await audioService.requestPermission()
            guard granted else {
                presenter?.presentFailure(permissionDenied: true)
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            await self?.recordAndAnalyze()
            self?.attemptTask = nil
        }
        attemptTask = task
        await task.value
    }

    func switchTargetSound(to sound: String) async {
        guard AcousticMirrorModels.supportedSounds.contains(sound) else { return }
        cancel()
        targetSound = sound
        roundNumber = 0
        earnedStars = []
        positions = []
        didPersistSession = false
        presenter?.presentStart(
            AcousticMirrorModels.Start.Response(
                targetSound: targetSound,
                totalRounds: AcousticMirrorModels.roundsPerSession
            )
        )
    }

    func cancel() {
        attemptTask?.cancel()
        attemptTask = nil
        if audioService.isRecording {
            Task { _ = try? await audioService.stopRecording() }
        }
    }

    // MARK: - Attempt pipeline

    private func recordAndAnalyze() async {
        presenter?.presentRecording()

        let url: URL
        do {
            try await audioService.startRecording()
            await sleeper(AcousticMirrorModels.attemptDuration)
            url = try await audioService.stopRecording()
        } catch {
            // Прерванная запись: останавливаем без зачёта раунда.
            if audioService.isRecording {
                _ = try? await audioService.stopRecording()
            }
            logger.error("AcousticMirror record failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentFailure(permissionDenied: false)
            return
        }

        guard !Task.isCancelled else { return }
        presenter?.presentAnalyzing()

        let evaluation: SibilantEvaluation
        do {
            evaluation = try await mirrorService.analyzeAttempt(url: url, targetSound: targetSound)
        } catch {
            logger.error("AcousticMirror analyze failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentFailure(permissionDenied: false)
            cleanupTempFile(url)
            return
        }
        cleanupTempFile(url)
        guard !Task.isCancelled else { return }

        roundNumber += 1
        earnedStars.append(evaluation.stars)
        if evaluation.verdict != .noFrication {
            positions.append(evaluation.continuumPosition)
        }

        // FSRS: исход раунда (звук «зачтён» при ≥2 звёзд) — кормит планировщик.
        await adaptivePlanner?.recordItemOutcome(
            childId: childId,
            itemId: "acoustic-mirror-\(targetSound)",
            sound: targetSound,
            correct: evaluation.stars >= 2
        )

        let isComplete = roundNumber >= AcousticMirrorModels.roundsPerSession
        presenter?.presentAttempt(
            AcousticMirrorModels.Attempt.Response(
                evaluation: evaluation,
                roundNumber: roundNumber,
                totalRounds: AcousticMirrorModels.roundsPerSession,
                isSessionComplete: isComplete
            )
        )

        if isComplete {
            await completeSession()
        }
    }

    private func completeSession() async {
        let total = earnedStars.reduce(0, +)
        let best = bestPosition()
        presenter?.presentComplete(
            AcousticMirrorModels.Complete.Response(
                totalStars: total,
                maxStars: AcousticMirrorModels.roundsPerSession * 3,
                bestPosition: best,
                targetSound: targetSound
            )
        )
        await persistSessionIfNeeded(totalStars: total)
    }

    /// Лучшая (ближайшая к цели) позиция сессии — для итогового экрана.
    private func bestPosition() -> Double? {
        guard !positions.isEmpty else { return nil }
        if SibilantPole.pole(forTargetSound: targetSound) == .whistling {
            return positions.max()
        }
        return positions.min()
    }

    /// Сохраняет сессию в Realm + очередь синка (реальные минуты/стрик/агрегаты).
    /// Идемпотентно: ровно один раз на сессию. correct = раунды с ≥2 звёздами.
    private func persistSessionIfNeeded(totalStars: Int) async {
        guard !didPersistSession, let sessionPersistence, !childId.isEmpty else { return }
        didPersistSession = true

        let correctRounds = earnedStars.filter { $0 >= 2 }.count
        let dto = SessionDTO(
            id: sessionId,
            childId: childId,
            date: Date(),
            templateType: TemplateType.visualAcoustic.rawValue,
            targetSound: targetSound,
            stage: CorrectionStage.isolated.rawValue,
            durationSeconds: Int(Date().timeIntervalSince(sessionStart)),
            totalAttempts: earnedStars.count,
            correctAttempts: correctRounds,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
        await sessionPersistence.persistAndSync(dto)
        logger.info("AcousticMirror session persisted: stars=\(totalStars) correct=\(correctRounds)/\(self.earnedStars.count)")
    }

    // MARK: - Target sound resolution

    /// Первый сибилянт из целевых звуков ребёнка; иначе предпочтённый; иначе «С».
    private func resolveTargetSound(preferred: String) async -> String {
        if AcousticMirrorModels.supportedSounds.contains(preferred) {
            return preferred
        }
        if let childRepository, !childId.isEmpty,
           let profile = try? await childRepository.fetch(id: childId) {
            for sound in profile.targetSounds {
                let normalized = String(sound.prefix(1)).uppercased()
                if AcousticMirrorModels.supportedSounds.contains(normalized) {
                    return normalized
                }
            }
        }
        return "С"
    }

    // MARK: - Cleanup

    /// Удаляет временный файл попытки (аудио не храним — COPPA-минимизация).
    private func cleanupTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
