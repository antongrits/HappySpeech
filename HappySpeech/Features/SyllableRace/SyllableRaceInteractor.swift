import Foundation
import OSLog

// MARK: - SyllableRaceBusinessLogic

@MainActor
protocol SyllableRaceBusinessLogic: AnyObject {
    /// Запуск сессии: резолв возраста из профиля, первый ряд каталога.
    func startSession(_ request: SyllableRaceModels.Start.Request) async
    /// Одна попытка: запись `attemptDuration` сек → анализ → результат раунда.
    func performAttempt(_ request: SyllableRaceModels.Attempt.Request) async
    /// Отмена активной записи/анализа (выход с экрана).
    func cancel()
}

// MARK: - SyllableRaceInteractor

/// Бизнес-логика «Скороговорки-ракеты» (Clean Swift VIP).
///
/// Владеет жизненным циклом записи (audioService) и анализа (raceService) —
/// View только рисует state и шлёт интенты. Результаты честные: при
/// нераспознанном ряде раунд получает 0 звёзд и подсказку, никакой фабрикации.
///
/// Персистентность по завершении сессии:
///   • `SessionDTO` через `SessionPersistenceCoordinating` (реальные минуты/стрик/
///     агрегаты профиля; stage = prep — артикуляционно-моторная разминка);
///   • исход каждого раунда — в FSRS-лестницу через `AdaptivePlannerService`.
@MainActor
final class SyllableRaceInteractor: SyllableRaceBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any SyllableRacePresentationLogic)?

    private let childId: String
    private let audioService: any AudioService
    private let raceService: any SyllableRaceServicing
    private let childRepository: (any ChildRepository)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let sessionPersistence: (any SessionPersistenceCoordinating)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SyllableRace")

    /// Источник sleep — инъектируется для детерминированных тестов.
    private let sleeper: @Sendable (TimeInterval) async -> Void

    // MARK: - Session state

    private(set) var roundNumber: Int = 0
    private(set) var earnedStars: [Int] = []
    private(set) var bestRate: Double = 0
    private var childAge = SyllableRaceModels.defaultChildAge
    private var sessionStart = Date()
    private var attemptTask: Task<Void, Never>?
    private var didPersistSession = false
    private let sessionId = UUID().uuidString

    /// Ряды сессии (по одному на раунд, ротация каталога).
    private let sequences: [DDKSequence]

    // MARK: - Init

    init(
        childId: String,
        audioService: any AudioService,
        raceService: any SyllableRaceServicing,
        childRepository: (any ChildRepository)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        sessionPersistence: (any SessionPersistenceCoordinating)? = nil,
        sequences: [DDKSequence] = DDKCatalog.sequences,
        sleeper: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(for: .seconds(seconds))
        }
    ) {
        self.childId = childId
        self.audioService = audioService
        self.raceService = raceService
        self.childRepository = childRepository
        self.adaptivePlanner = adaptivePlanner
        self.sessionPersistence = sessionPersistence
        self.sequences = sequences.isEmpty ? DDKCatalog.sequences : sequences
        self.sleeper = sleeper
    }

    // MARK: - Business logic

    func startSession(_ request: SyllableRaceModels.Start.Request) async {
        sessionStart = Date()
        roundNumber = 0
        earnedStars = []
        bestRate = 0
        didPersistSession = false
        childAge = await resolveChildAge()

        logger.info("SyllableRace start: age=\(self.childAge, privacy: .private) seq=\(self.sequences.count, privacy: .public)")
        presentCurrentRound()
    }

    func performAttempt(_ request: SyllableRaceModels.Attempt.Request) async {
        guard roundNumber < SyllableRaceModels.roundsPerSession else { return }
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

    func cancel() {
        attemptTask?.cancel()
        attemptTask = nil
        if audioService.isRecording {
            Task { _ = try? await audioService.stopRecording() }
        }
    }

    // MARK: - Round presentation

    /// Ряд текущего раунда (ротация каталога по индексу раунда).
    private func currentSequence() -> DDKSequence {
        sequences[roundNumber % sequences.count]
    }

    private func presentCurrentRound() {
        presenter?.presentStart(
            SyllableRaceModels.Start.Response(
                sequence: currentSequence(),
                roundNumber: roundNumber,
                totalRounds: SyllableRaceModels.roundsPerSession,
                childAge: childAge
            )
        )
    }

    // MARK: - Attempt pipeline

    private func recordAndAnalyze() async {
        let sequence = currentSequence()
        presenter?.presentRecording()

        let url: URL
        do {
            try await audioService.startRecording()
            await sleeper(SyllableRaceModels.attemptDuration)
            url = try await audioService.stopRecording()
        } catch {
            if audioService.isRecording {
                _ = try? await audioService.stopRecording()
            }
            logger.error("SyllableRace record failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentFailure(permissionDenied: false)
            return
        }

        guard !Task.isCancelled else { return }
        presenter?.presentAnalyzing()

        let evaluation: DDKEvaluation
        do {
            evaluation = try await raceService.analyzeAttempt(
                url: url,
                sequence: sequence,
                childAge: childAge
            )
        } catch {
            logger.error("SyllableRace analyze failed: \(error.localizedDescription, privacy: .public)")
            presenter?.presentFailure(permissionDenied: false)
            cleanupTempFile(url)
            return
        }
        cleanupTempFile(url)
        guard !Task.isCancelled else { return }

        roundNumber += 1
        earnedStars.append(evaluation.stars)
        if evaluation.verdict != .notDetected {
            bestRate = max(bestRate, evaluation.syllablesPerSecond)
        }

        // FSRS: исход раунда (ряд «зачтён» при ≥2 звёзд) — кормит планировщик.
        await adaptivePlanner?.recordItemOutcome(
            childId: childId,
            itemId: "syllable-race-\(sequence.id)",
            sound: sequence.displayString,
            correct: evaluation.stars >= 2
        )

        let isComplete = roundNumber >= SyllableRaceModels.roundsPerSession
        presenter?.presentAttempt(
            SyllableRaceModels.Attempt.Response(
                evaluation: evaluation,
                roundNumber: roundNumber,
                totalRounds: SyllableRaceModels.roundsPerSession,
                isSessionComplete: isComplete
            )
        )

        if isComplete {
            await completeSession()
        } else {
            presentCurrentRound()
        }
    }

    private func completeSession() async {
        let total = earnedStars.reduce(0, +)
        presenter?.presentComplete(
            SyllableRaceModels.Complete.Response(
                totalStars: total,
                maxStars: SyllableRaceModels.roundsPerSession * 3,
                bestRate: bestRate
            )
        )
        await persistSessionIfNeeded(totalStars: total)
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
            templateType: TemplateType.rhythm.rawValue,
            targetSound: "ДДК",
            stage: CorrectionStage.prep.rawValue,
            durationSeconds: Int(Date().timeIntervalSince(sessionStart)),
            totalAttempts: earnedStars.count,
            correctAttempts: correctRounds,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
        await sessionPersistence.persistAndSync(dto)
        logger.info("SyllableRace session persisted: stars=\(totalStars) correct=\(correctRounds)/\(self.earnedStars.count)")
    }

    // MARK: - Child age resolution

    /// Возраст из профиля ребёнка; иначе дефолт.
    private func resolveChildAge() async -> Int {
        if let childRepository, !childId.isEmpty,
           let profile = try? await childRepository.fetch(id: childId) {
            return profile.age
        }
        return SyllableRaceModels.defaultChildAge
    }

    // MARK: - Cleanup

    /// Удаляет временный файл попытки (аудио не храним — COPPA-минимизация).
    private func cleanupTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
