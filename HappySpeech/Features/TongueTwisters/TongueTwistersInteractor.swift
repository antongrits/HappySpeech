import Foundation
import OSLog

// MARK: - TongueTwistersBusinessLogic

@MainActor
protocol TongueTwistersBusinessLogic: AnyObject {
    func start(_ request: TongueTwistersModels.Start.Request) async
    func playModel()
    func playWarmupSound()
    func chooseRhyme(_ request: TongueTwistersModels.ChooseRhyme.Request)
    func enterTrain()
    func recordAndCheck() async
    func playWagon(index: Int)
    func speakWagon(index: Int)
    func toggleMetronome()
    func slowDownMetronome()
    func advancePhrase() async
    func cancel()
}

// MARK: - TongueTwistersInteractor
//
// Бизнес-логика «Чистоговорок-конструктора».
//   • start         — собирает сессию чистоговорок (`TongueTwistersBuilder`) по
//                      возрасту; шлёт первую.
//   • playModel     — образец чистоговорки голосом Ляли (SpeechWorker).
//   • playWarmupSound — изолированный целевой звук разминки (TTS-фоллбэк).
//   • chooseRhyme   — проверка выбранной картинки-рифмы; верно → вписать и перейти
//                      к «скажи целиком»; неверно → мягкая подсказка (errorless).
//   • enterTrain    — переход к наращиванию строки (вагончики).
//   • recordAndCheck — запись проговаривания (AudioService) + мягкая ASR-проверка
//                      целевого звука (статус-пилл, не штраф).
//   • playWagon / speakWagon — прослушать/подтвердить ступень наращивания.
//   • toggleMetronome / slowDownMetronome — ритм опционален и замедляем.
//   • advancePhrase — следующая чистоговорка или завершение.
//
// Скоринг: доля «чистых» чистоговорок (рифма выбрана верно + услышан звук, либо
// рифма верна и ASR inconclusive — не наказываем за отсутствие микрофона).
// Результат сохраняется в AdaptivePlannerService (SM-2 + пословный outcome).

@MainActor
final class TongueTwistersInteractor: TongueTwistersBusinessLogic {

    // MARK: - VIP

    var presenter: (any TongueTwistersPresentationLogic)?

    // MARK: - Deps

    private let childId: String
    private let childAge: Int
    private let builder: TongueTwistersBuilder
    private let rhythm: TongueTwistersRhythmWorker
    private let speech: TongueTwistersSpeechWorker
    private let voice: LessonVoiceWorker
    private let adaptivePlanner: (any AdaptivePlannerService)?
    /// Тестовый seam: если задано — используется вместо загрузки пака.
    private let seededPhrases: [TonguePhrase]?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "TongueTwistersInteractor")

    // MARK: - Tunables

    private static let phrasesPerSession = 5

    // MARK: - State

    private var phrases: [TonguePhrase] = []
    private var phraseIndex = 0
    /// Текущая чистоговорка пройдена «чисто» (рифма верна + услышан звук/incon.).
    private var phraseWasClean = false
    /// Рифма выбрана верно (для скоринга).
    private var rhymeSolved = false
    private var cleanCount = 0
    private var completedCount = 0
    private var isFinished = false

    private var speakTask: Task<Void, Never>?
    private var recordTask: Task<Void, Never>?

    // MARK: - Init

    init(
        childId: String,
        childAge: Int,
        builder: TongueTwistersBuilder = TongueTwistersBuilder(),
        rhythm: TongueTwistersRhythmWorker = TongueTwistersRhythmWorker(),
        speech: TongueTwistersSpeechWorker,
        voice: LessonVoiceWorker = .shared,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        seededPhrases: [TonguePhrase]? = nil
    ) {
        self.childId = childId
        self.childAge = max(5, min(childAge, 8))
        self.builder = builder
        self.rhythm = rhythm
        self.speech = speech
        self.voice = voice
        self.adaptivePlanner = adaptivePlanner
        self.seededPhrases = seededPhrases
    }

    deinit {
        speakTask?.cancel()
        recordTask?.cancel()
    }

    // MARK: - start

    func start(_ request: TongueTwistersModels.Start.Request) async {
        if let seededPhrases {
            phrases = seededPhrases
        } else {
            let all = builder.loadPhrases()
            phrases = builder.buildSession(
                from: all, age: childAge, count: Self.phrasesPerSession, childId: childId
            )
        }
        phraseIndex = 0
        cleanCount = 0
        completedCount = 0
        rhymeSolved = false
        phraseWasClean = false
        isFinished = false
        logger.info("start child=\(self.childId, privacy: .public) phrases=\(self.phrases.count, privacy: .public)")
        presenter?.presentStart(.init(phrases: phrases))
        if let first = currentPhrase {
            presenter?.presentLoadPhrase(.init(phrase: first, phraseIndex: 0, totalPhrases: phrases.count))
        }
    }

    // MARK: - playModel (образец чистоговорки)

    func playModel() {
        guard let phrase = currentPhrase else { return }
        speakTask?.cancel()
        speech.stopPlayback()
        presenter?.presentPlaying(true)
        let line = phrase.fullLine
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.speech.playModel(line)
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    // MARK: - playWarmupSound (изолированный целевой звук)

    func playWarmupSound() {
        guard let phrase = currentPhrase else { return }
        speakTask?.cancel()
        speech.stopPlayback()
        presenter?.presentPlaying(true)
        let sound = phrase.targetSound
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voice.speakIsolatedSound(sound, lessonType: "tongue_twisters")
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    // MARK: - chooseRhyme

    func chooseRhyme(_ request: TongueTwistersModels.ChooseRhyme.Request) {
        guard !isFinished, let phrase = currentPhrase,
              let answer = phrase.answers.first(where: { $0.id == request.answerId }) else { return }
        let isCorrect = answer.isCorrect
        if isCorrect { rhymeSolved = true }
        presenter?.presentChooseRhyme(.init(
            isCorrect: isCorrect,
            chosenWord: answer.word,
            correctWord: phrase.answerWord
        ))
        if isCorrect {
            // Озвучим собранную строку как поддержку.
            playModel()
        }
        logger.info("chooseRhyme correct=\(isCorrect, privacy: .public)")
    }

    // MARK: - enterTrain (наращивание строки)

    func enterTrain() {
        guard let phrase = currentPhrase, !phrase.wagons.isEmpty else { return }
        var states = Array(repeating: WagonState.locked, count: phrase.wagons.count)
        states[0] = .now
        presenter?.presentEnterTrain(states: states, currentIndex: 0)
    }

    // MARK: - recordAndCheck (запись + мягкая ASR-проверка)

    func recordAndCheck() async {
        guard !isFinished, let phrase = currentPhrase else { return }
        recordTask?.cancel()
        presenter?.presentRecording(true)
        let sound = phrase.targetSound
        let line = phrase.fullLine
        recordTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.presenter?.presentRecording(false) }
            do {
                let url = try await self.speech.recordPhrase()
                guard !Task.isCancelled, !self.isFinished else { return }
                let result = await self.speech.detectTargetSound(
                    in: url, targetSound: sound, expectedLine: line
                )
                guard !Task.isCancelled, !self.isFinished else { return }
                // «Чисто», если рифма решена И (звук услышан ИЛИ ASR молчит —
                // не наказываем за отсутствие микрофона/тихую запись).
                if self.rhymeSolved, result.soundHeard || result.inconclusive {
                    self.phraseWasClean = true
                }
                self.presenter?.presentCheckRecording(.init(
                    soundHeard: result.soundHeard,
                    targetSound: sound,
                    inconclusive: result.inconclusive
                ))
            } catch is CancellationError {
                return
            } catch {
                // Микрофон недоступен — мягко, без штрафа: трактуем как
                // inconclusive (ровно как тихую/неразборчивую запись). Ребёнок не
                // теряет «чистоту» из-за отсутствия микрофона, если рифма решена.
                if self.rhymeSolved { self.phraseWasClean = true }
                self.presenter?.presentCheckRecording(.init(
                    soundHeard: false, targetSound: sound, inconclusive: true
                ))
            }
            self.recordTask = nil
        }
        await recordTask?.value
    }

    // MARK: - Wagons

    func playWagon(index: Int) {
        guard let phrase = currentPhrase, phrase.wagons.indices.contains(index) else { return }
        speakTask?.cancel()
        speech.stopPlayback()
        presenter?.presentPlaying(true)
        let text = phrase.wagons[index].text
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.speech.playModel(text)
            guard !Task.isCancelled, !self.isFinished else { return }
            self.presenter?.presentPlaying(false)
            self.speakTask = nil
        }
    }

    func speakWagon(index: Int) {
        guard let phrase = currentPhrase, phrase.wagons.indices.contains(index) else { return }
        let total = phrase.wagons.count
        let next = index + 1
        let allDone = next >= total
        presenter?.presentSpeakWagon(.init(
            completedIndex: index,
            nextIndex: allDone ? nil : next,
            allDone: allDone
        ), total: total)
        logger.info("speakWagon idx=\(index, privacy: .public) allDone=\(allDone, privacy: .public)")
    }

    // MARK: - Metronome (опционален, замедляем)

    func toggleMetronome() {
        if rhythm.isRunning {
            rhythm.stop()
            presenter?.presentMetronome(on: false, bpm: currentBPM)
        } else {
            startMetronome(bpm: currentBPM)
        }
    }

    func slowDownMetronome() {
        let slow = TongueTwistersRhythmWorker.slowBPM
        currentBPM = slow
        if rhythm.isRunning {
            rhythm.stop()
            startMetronome(bpm: slow)
        } else {
            presenter?.presentMetronome(on: false, bpm: slow)
        }
    }

    private var currentBPM = TongueTwistersRhythmWorker.defaultBPM

    private func startMetronome(bpm: Int) {
        let beats = currentPhrase?.warmupBeats ?? 3
        rhythm.start(bpm: bpm, beatsPerCycle: beats) { [weak self] beat in
            self?.presenter?.presentBeat(beat)
        }
        presenter?.presentMetronome(on: true, bpm: bpm)
    }

    // MARK: - advancePhrase

    func advancePhrase() async {
        guard !isFinished else { return }
        await recordPhraseOutcome()
        rhythm.stop()
        completedCount += 1
        if phraseWasClean { cleanCount += 1 }

        let next = phraseIndex + 1
        if next >= phrases.count {
            await complete()
            return
        }
        phraseIndex = next
        rhymeSolved = false
        phraseWasClean = false
        let phrase = phrases[phraseIndex]
        presenter?.presentLoadPhrase(.init(
            phrase: phrase, phraseIndex: phraseIndex, totalPhrases: phrases.count
        ))
    }

    // MARK: - complete

    private func complete() async {
        guard !isFinished else { return }
        isFinished = true
        rhythm.stop()
        speech.stopPlayback()
        speakTask?.cancel()
        recordTask?.cancel()
        let total = max(phrases.count, 1)
        let score = min(max(Float(cleanCount) / Float(total), 0), 1)
        logger.info("complete clean=\(self.cleanCount, privacy: .public)/\(total, privacy: .public) score=\(score, privacy: .public)")
        await recordSession(score: score)
        presenter?.presentComplete(.init(
            phrasesCompleted: completedCount,
            totalPhrases: phrases.count,
            cleanFraction: score
        ))
    }

    // MARK: - cancel

    func cancel() {
        isFinished = true
        speakTask?.cancel(); speakTask = nil
        recordTask?.cancel(); recordTask = nil
        rhythm.stop()
        speech.stopPlayback()
        logger.info("TongueTwisters cancelled")
    }

    // MARK: - Persistence

    private func recordPhraseOutcome() async {
        guard let phrase = currentPhrase, let planner = adaptivePlanner else { return }
        await planner.recordItemOutcome(
            childId: childId,
            itemId: phrase.id,
            sound: phrase.targetSound,
            correct: phraseWasClean
        )
    }

    private func recordSession(score: Float) async {
        guard let planner = adaptivePlanner else { return }
        let quality = SM2Quality.fromSuccessRate(Double(score))
        let sound = phrases.first?.targetSound ?? "автоматизация"
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: sound,
                qualityScore: quality
            )
        } catch {
            logger.error("recordSessionResult failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private var currentPhrase: TonguePhrase? {
        phrases.indices.contains(phraseIndex) ? phrases[phraseIndex] : nil
    }

    // MARK: - Test seams

    /// Доля «чистых» чистоговорок (для тестов и расчётов).
    var cleanFraction: Double {
        phrases.isEmpty ? 0 : Double(cleanCount) / Double(phrases.count)
    }

    /// Текущий BPM (для тестов).
    var metronomeBPMForTests: Int { currentBPM }
}
