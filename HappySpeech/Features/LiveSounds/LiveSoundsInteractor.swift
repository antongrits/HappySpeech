import Foundation
import OSLog

// MARK: - LiveSoundsBusinessLogic

@MainActor
protocol LiveSoundsBusinessLogic: AnyObject {
    func start(_ request: LiveSoundsModels.Start.Request) async
    /// Проигрывает слово ПО ЗВУКАМ с управляемой паузой (живой синтез).
    func playSoundsSequence()
    /// Меняет темп пофонемной озвучки (длина паузы).
    func setPace(_ request: LiveSoundsModels.Speed.Request)
    /// collect-режим: ребёнок выбрал картинку из сетки 2×2.
    func choosePicture(_ request: LiveSoundsModels.ChoosePicture.Request)
    /// bench-режим: ребёнок выбрал человечка-звук со «скамейки».
    func placeCharacter(_ request: LiveSoundsModels.PlaceCharacter.Request)
    /// Переход к следующему раунду или завершение сессии.
    func advanceRound() async
    func cancel()
}

// MARK: - LiveSoundsInteractor
//
// Бизнес-логика «Живых звуков» — устного фонематического синтеза.
//   • start             — собирает сессию раундов через `LiveSoundsBuilder`
//                          по возрасту ребёнка; шлёт первый раунд + первую озвучку.
//   • playSoundsSequence — Ляля произносит слово ПО ЗВУКАМ: каждый звук —
//                          изолированная фонема (LessonVoiceWorker.speakIsolatedSound),
//                          между звуками — пауза `pace.gapSeconds`. Активный звук
//                          подсвечивается (nowSoundIndex). БЕЗ ASR.
//   • choosePicture     — collect: верно → слияние (картинка подсвечена, слово
//                          целиком озвучено); неверно → мягкая подсказка + повтор.
//   • placeCharacter    — bench: верный человечек встаёт в ряд; полный ряд →
//                          слово целиком (слияние).
//   • advanceRound      — следующий раунд или завершение.
//
// Скоринг: доля раундов, решённых С ПЕРВОЙ попытки (errorless, без штрафов).
// Результат сохраняется через SessionPersistenceCoordinating + AdaptivePlanner.

@MainActor
final class LiveSoundsInteractor: LiveSoundsBusinessLogic {

    // MARK: - VIP

    var presenter: (any LiveSoundsPresentationLogic)?

    // MARK: - Deps

    private let childId: String
    private let childAge: Int
    private let builder: LiveSoundsBuilder
    private let voice: LessonVoiceWorker
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let sessionPersistence: (any SessionPersistenceCoordinating)?
    /// Тестовый seam: если задано — используется вместо загрузки пака.
    private let seededRounds: [LiveSoundsRound]?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "LiveSoundsInteractor")

    // MARK: - Tunables

    private static let roundsPerSession = 8

    // MARK: - State

    private var rounds: [LiveSoundsRound] = []
    private var roundIndex: Int = 0
    private var pace: LiveSoundsPace = .medium

    /// Раунд уже решён без единой ошибки (для скоринга «с первой попытки»).
    private var roundHadError: Bool = false
    private var firstTrySolvedCount: Int = 0
    private var solvedRoundCount: Int = 0

    /// bench-режим: индекс следующего пустого места в ряду.
    private var benchActiveSlot: Int = 0
    private var benchUsedIndices: Set<Int> = []

    private var isFinished: Bool = false
    private var didPersist: Bool = false

    private let sessionId = UUID().uuidString
    private let sessionStart = Date()

    private var speakTask: Task<Void, Never>?

    // MARK: - Init

    init(
        childId: String,
        childAge: Int,
        builder: LiveSoundsBuilder,
        voice: LessonVoiceWorker = .shared,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        sessionPersistence: (any SessionPersistenceCoordinating)? = nil,
        seededRounds: [LiveSoundsRound]? = nil
    ) {
        self.childId = childId
        self.childAge = max(5, min(childAge, 8))
        self.builder = builder
        self.voice = voice
        self.adaptivePlanner = adaptivePlanner
        self.sessionPersistence = sessionPersistence
        self.seededRounds = seededRounds
    }

    deinit {
        speakTask?.cancel()
    }

    // MARK: - start

    func start(_ request: LiveSoundsModels.Start.Request) async {
        if let seededRounds {
            rounds = seededRounds
        } else {
            let all = builder.loadRounds()
            rounds = builder.buildSession(from: all, age: childAge, count: Self.roundsPerSession)
        }
        roundIndex = 0
        roundHadError = false
        firstTrySolvedCount = 0
        solvedRoundCount = 0
        benchActiveSlot = 0
        benchUsedIndices = []
        isFinished = false
        logger.info("start child=\(self.childId, privacy: .private) rounds=\(self.rounds.count, privacy: .public)")
        presenter?.presentStart(LiveSoundsModels.Start.Response(rounds: rounds))
        // Автопроигрывание первого слова по звукам — ребёнок сразу слышит синтез.
        playSoundsSequence()
    }

    // MARK: - playSoundsSequence (живой синтез: звук-пауза-звук)

    func playSoundsSequence() {
        guard let round = currentRound, !round.sounds.isEmpty else { return }
        speakTask?.cancel()
        voice.stop()
        presenter?.presentPlaying(true)
        let gap = pace.gapSeconds
        let sounds = round.sounds
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for (idx, sound) in sounds.enumerated() {
                if Task.isCancelled || self.isFinished { break }
                self.presenter?.presentNowSound(idx)
                await self.voice.speakIsolatedSound(sound.letter, lessonType: "live_sounds")
                if Task.isCancelled || self.isFinished { break }
                // Пауза между звуками (управляемая) — кроме последнего звука.
                if idx < sounds.count - 1 {
                    self.presenter?.presentNowSound(nil)
                    try? await Task.sleep(for: .seconds(gap))
                }
            }
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentNowSound(nil)
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    /// Слово ЦЕЛИКОМ — финальное слияние после верного ответа (озвучка слова Лялей).
    private func playMergedWord() {
        guard let round = currentRound else { return }
        speakTask?.cancel()
        voice.stop()
        presenter?.presentPlaying(true)
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voice.speak(round.word, lessonType: "live_sounds")
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    // MARK: - setPace

    func setPace(_ request: LiveSoundsModels.Speed.Request) {
        pace = request.pace
        presenter?.presentPace(pace)
        // Перепроигрываем текущее слово с новым темпом — выбор сразу слышен.
        playSoundsSequence()
    }

    // MARK: - choosePicture (collect-режим)

    func choosePicture(_ request: LiveSoundsModels.ChoosePicture.Request) {
        guard !isFinished, let round = currentRound,
              round.options.indices.contains(request.optionIndex) else { return }
        let chosen = round.options[request.optionIndex]
        let correctIndex = round.options.firstIndex(where: { $0.isCorrect }) ?? 0

        if chosen.isCorrect {
            if !roundHadError {
                firstTrySolvedCount += 1
            }
            solvedRoundCount += 1
            presenter?.presentChoosePicture(LiveSoundsModels.ChoosePicture.Response(
                optionIndex: request.optionIndex,
                isCorrect: true,
                correctIndex: correctIndex,
                word: round.word
            ))
            playMergedWord()
            logger.info("choosePicture OK round=\(self.roundIndex, privacy: .public) firstTry=\(!self.roundHadError, privacy: .public)")
        } else {
            roundHadError = true
            presenter?.presentChoosePicture(LiveSoundsModels.ChoosePicture.Response(
                optionIndex: request.optionIndex,
                isCorrect: false,
                correctIndex: correctIndex,
                word: round.word
            ))
            // Мягкая подсказка: повторяем слово по звукам ещё раз.
            playSoundsSequence()
            logger.info("choosePicture soft-hint round=\(self.roundIndex, privacy: .public)")
        }
    }

    // MARK: - placeCharacter (bench-режим)

    func placeCharacter(_ request: LiveSoundsModels.PlaceCharacter.Request) {
        guard !isFinished, let round = currentRound,
              round.benchLetters.indices.contains(request.benchIndex),
              round.sounds.indices.contains(benchActiveSlot),
              !benchUsedIndices.contains(request.benchIndex) else { return }

        let picked = round.benchLetters[request.benchIndex]
        let expected = round.sounds[benchActiveSlot]
        let isCorrect = picked.letter == expected.letter

        if isCorrect {
            let slot = benchActiveSlot
            benchUsedIndices.insert(request.benchIndex)
            benchActiveSlot += 1
            let complete = benchActiveSlot >= round.sounds.count
            if complete {
                if !roundHadError { firstTrySolvedCount += 1 }
                solvedRoundCount += 1
            }
            presenter?.presentPlaceCharacter(
                LiveSoundsModels.PlaceCharacter.Response(
                    benchIndex: request.benchIndex,
                    isCorrect: true,
                    slotIndex: slot,
                    letter: picked.letter,
                    rowComplete: complete
                ),
                placedLetters: Array(round.sounds.prefix(benchActiveSlot).map { $0.letter }),
                usedBenchIndices: benchUsedIndices
            )
            if complete {
                playMergedWord()
            } else {
                // Озвучиваем следующий ожидаемый звук как подсказку.
                playActiveSlotSound()
            }
            logger.info("placeCharacter OK slot=\(slot, privacy: .public) complete=\(complete, privacy: .public)")
        } else {
            roundHadError = true
            presenter?.presentPlaceCharacter(
                LiveSoundsModels.PlaceCharacter.Response(
                    benchIndex: request.benchIndex,
                    isCorrect: false,
                    slotIndex: benchActiveSlot,
                    letter: picked.letter,
                    rowComplete: false
                ),
                placedLetters: Array(round.sounds.prefix(benchActiveSlot).map { $0.letter }),
                usedBenchIndices: benchUsedIndices
            )
            // Мягкая подсказка: проигрываем слово по звукам ещё раз.
            playSoundsSequence()
            logger.info("placeCharacter soft-hint slot=\(self.benchActiveSlot, privacy: .public)")
        }
    }

    /// Изолированно озвучивает звук текущего активного места ряда (подсказка bench).
    private func playActiveSlotSound() {
        guard let round = currentRound, round.sounds.indices.contains(benchActiveSlot) else { return }
        let letter = round.sounds[benchActiveSlot].letter
        speakTask?.cancel()
        voice.stop()
        presenter?.presentPlaying(true)
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voice.speakIsolatedSound(letter, lessonType: "live_sounds")
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    // MARK: - advanceRound

    func advanceRound() async {
        guard !isFinished else { return }
        await recordRoundOutcome()
        let next = roundIndex + 1
        if next >= rounds.count {
            await complete()
            return
        }
        roundIndex = next
        roundHadError = false
        benchActiveSlot = 0
        benchUsedIndices = []
        let round = rounds[roundIndex]
        presenter?.presentLoadRound(LiveSoundsModels.LoadRound.Response(
            round: round,
            roundIndex: roundIndex,
            totalRounds: rounds.count
        ))
        // Автопроигрывание нового слова по звукам.
        playSoundsSequence()
    }

    // MARK: - complete

    private func complete() async {
        guard !isFinished else { return }
        isFinished = true
        voice.stop()
        let total = max(rounds.count, 1)
        let score = min(max(Float(firstTrySolvedCount) / Float(total), 0), 1)
        logger.info("complete firstTry=\(self.firstTrySolvedCount, privacy: .public)/\(total, privacy: .public) score=\(score, privacy: .public)")
        await recordSession(score: score)
        presenter?.presentComplete(LiveSoundsModels.Complete.Response(
            roundsSolved: solvedRoundCount,
            totalRounds: rounds.count,
            score: score
        ))
    }

    // MARK: - cancel

    func cancel() {
        isFinished = true
        speakTask?.cancel()
        speakTask = nil
        voice.stop()
        logger.info("LiveSounds cancelled")
    }

    // MARK: - Persistence

    private func recordRoundOutcome() async {
        guard let round = currentRound, let planner = adaptivePlanner else { return }
        await planner.recordItemOutcome(
            childId: childId,
            itemId: round.id,
            sound: round.sounds.first?.letter ?? "",
            correct: !roundHadError
        )
    }

    private func recordSession(score: Float) async {
        // 1. SM-2 в планировщике.
        if let planner = adaptivePlanner {
            let quality = SM2Quality.fromSuccessRate(Double(score))
            do {
                try await planner.recordSessionResult(
                    childId: childId,
                    soundTarget: "фонематический-синтез",
                    qualityScore: quality
                )
            } catch {
                logger.error("recordSessionResult failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        // 2. Персистентность сессии (offline-first + sync для аутентиф. родителя).
        await persistSessionIfNeeded(score: score)
    }

    private func persistSessionIfNeeded(score: Float) async {
        guard !didPersist, let sessionPersistence, !childId.isEmpty else { return }
        didPersist = true
        let dto = SessionDTO(
            id: sessionId,
            childId: childId,
            date: Date(),
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: "фонематический-синтез",
            stage: CorrectionStage.syllable.rawValue,
            durationSeconds: Int(Date().timeIntervalSince(sessionStart)),
            totalAttempts: rounds.count,
            correctAttempts: firstTrySolvedCount,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
        await sessionPersistence.persistAndSync(dto)
        logger.info("LiveSounds session persisted score=\(score, privacy: .public) solved=\(self.firstTrySolvedCount, privacy: .public)/\(self.rounds.count, privacy: .public)")
    }

    // MARK: - Helpers

    private var currentRound: LiveSoundsRound? {
        rounds.indices.contains(roundIndex) ? rounds[roundIndex] : nil
    }

    // MARK: - Test seams

    /// Доля решённых с первой попытки (для тестов и расчётов).
    var firstTryFraction: Double {
        rounds.isEmpty ? 0 : Double(firstTrySolvedCount) / Double(rounds.count)
    }

    /// Текущий темп озвучки (для тестов).
    var currentPace: LiveSoundsPace { pace }
}
