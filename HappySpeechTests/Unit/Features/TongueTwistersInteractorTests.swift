@testable import HappySpeech
import XCTest

// MARK: - TongueTwistersInteractorTests
//
// Бизнес-логика «Чистоговорок-конструктора». Покрываем реальные ветки:
//   • start          — сборка сессии (seededPhrases), presentStart + первая фраза;
//   • chooseRhyme    — верный/неверный вариант, рифма «решена», errorless;
//   • enterTrain     — стартовые состояния вагонов (now/locked);
//   • speakWagon     — наращивание строки: completedIndex / nextIndex / allDone;
//   • recordAndCheck — мягкая ASR-проверка звука (inconclusive без микрофона,
//                       soundHeard при scripted ASR);
//   • metronome      — опционален и замедляем (toggle + slowDown через мок);
//   • advancePhrase  — переход/завершение, пословный outcome + сессионный SM-2;
//   • scoring        — доля «чистых» (рифма + услышан/incon.) → cleanFraction.
//
// Метроном инжектируется через мок (без реальных таймеров). Запись/ASR —
// контролируемые моки; без audioService запись недоступна (мягкий путь).
// `TongueTwistersScoring.stars` проверяется отдельно (чистая функция).

@MainActor
final class TongueTwistersInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class SpyPresenter: TongueTwistersPresentationLogic {
        var starts: [Int] = []
        var loadedPhrases: [TongueTwistersModels.LoadPhrase.Response] = []
        var playing: [Bool] = []
        var recording: [Bool] = []
        var beats: [Int] = []
        var metronomeStates: [(on: Bool, bpm: Int)] = []
        var rhymeResults: [TongueTwistersModels.ChooseRhyme.Response] = []
        var checkResults: [TongueTwistersModels.CheckRecording.Response] = []
        var enterTrains: [(states: [WagonState], currentIndex: Int?)] = []
        var speakWagons: [(response: TongueTwistersModels.SpeakWagon.Response, total: Int)] = []
        var completes: [TongueTwistersModels.Complete.Response] = []

        func presentStart(_ response: TongueTwistersModels.Start.Response) { starts.append(response.phrases.count) }
        func presentLoadPhrase(_ response: TongueTwistersModels.LoadPhrase.Response) { loadedPhrases.append(response) }
        func presentPlaying(_ isPlaying: Bool) { playing.append(isPlaying) }
        func presentRecording(_ isRecording: Bool) { recording.append(isRecording) }
        func presentBeat(_ beat: Int) { beats.append(beat) }
        func presentMetronome(on: Bool, bpm: Int) { metronomeStates.append((on, bpm)) }
        func presentChooseRhyme(_ response: TongueTwistersModels.ChooseRhyme.Response) { rhymeResults.append(response) }
        func presentCheckRecording(_ response: TongueTwistersModels.CheckRecording.Response) { checkResults.append(response) }
        func presentEnterTrain(states: [WagonState], currentIndex: Int?) { enterTrains.append((states, currentIndex)) }
        func presentSpeakWagon(_ response: TongueTwistersModels.SpeakWagon.Response, total: Int) {
            speakWagons.append((response, total))
        }
        func presentComplete(_ response: TongueTwistersModels.Complete.Response) { completes.append(response) }
    }

    // MARK: - Controllable metronome (no real timer)

    private final class StubMetronome: MetronomeWorkerProtocol {
        private(set) var startCount = 0
        private(set) var stopCount = 0
        private(set) var lastBPM: Int?
        func start(bpm: Int, onTick: @escaping @Sendable () -> Void) {
            startCount += 1
            lastBPM = bpm
        }
        func stop() { stopCount += 1 }
    }

    // MARK: - Controllable ASR (scripted transcript)

    private final class ScriptedASR: ASRService, @unchecked Sendable {
        var isReady = true
        var transcript: String
        var confidence: Double
        init(transcript: String, confidence: Double = 0.9) {
            self.transcript = transcript
            self.confidence = confidence
        }
        func transcribe(url: URL) async throws -> ASRResult {
            ASRResult(transcript: transcript, confidence: confidence, wordTimestamps: [])
        }
        func transcribe(url: URL, expectedWord: String?, childAge: Int?) async throws -> ASRResult {
            ASRResult(transcript: transcript, confidence: confidence, wordTimestamps: [])
        }
        func loadModel() async throws {}
        func loadModel(tier: ASRTier) async throws {}
    }

    // MARK: - Controllable audio (no real recording)

    private final class StubAudio: AudioService, @unchecked Sendable {
        var isPermissionGranted = true
        var amplitude: Float = 0.4
        var isRecording = false
        func requestPermission() async -> Bool { true }
        func startRecording() async throws { isRecording = true }
        func stopRecording() async throws -> URL {
            isRecording = false
            return URL(fileURLWithPath: "/tmp/tongue_test.m4a")
        }
        func playAudio(url: URL) async throws {}
        func stopPlayback() {}
        func amplitudeBuffer() -> [Float] { [] }
    }

    // MARK: - Fixtures

    /// Чистоговорка на звук «С»: рифма «оса», 3 варианта, 4 вагона.
    private func sPhrase(id: String = "s-osa") -> TonguePhrase {
        TonguePhrase(
            id: id, targetSound: "С", group: "свистящие", minAge: 5,
            warmupSyllable: "Са", warmupBeats: 3,
            linePrefix: "Са-са-са —", lineSuffix: "вот летит",
            answerWord: "оса", answerAsset: "word_wasp",
            answers: [
                RhymeAnswer(id: "\(id)-correct", word: "оса", imageAsset: "word_wasp", isCorrect: true),
                RhymeAnswer(id: "\(id)-d0", word: "лиса", imageAsset: "word_fox", isCorrect: false),
                RhymeAnswer(id: "\(id)-d1", word: "коса", imageAsset: "word_kosa", isCorrect: false)
            ],
            wagons: [
                WagonStep(id: 0, text: "Са", isSyllable: true),
                WagonStep(id: 1, text: "Са-са-са", isSyllable: true),
                WagonStep(id: 2, text: "вот летит оса", isSyllable: false),
                WagonStep(id: 3, text: "Са-са-са — вот летит оса", isSyllable: false)
            ]
        )
    }

    /// Чистоговорка на звук «Л»: рифма «пила».
    private func lPhrase(id: String = "l-pila") -> TonguePhrase {
        TonguePhrase(
            id: id, targetSound: "Л", group: "соноры", minAge: 5,
            warmupSyllable: "Ла", warmupBeats: 3,
            linePrefix: "Ла-ла-ла —", lineSuffix: "острая",
            answerWord: "пила", answerAsset: "word_pila",
            answers: [
                RhymeAnswer(id: "\(id)-correct", word: "пила", imageAsset: "word_pila", isCorrect: true),
                RhymeAnswer(id: "\(id)-d0", word: "юла", imageAsset: "word_yula", isCorrect: false)
            ],
            wagons: [
                WagonStep(id: 0, text: "Ла", isSyllable: true),
                WagonStep(id: 1, text: "острая пила", isSyllable: false)
            ]
        )
    }

    private struct SUT {
        let interactor: TongueTwistersInteractor
        let presenter: SpyPresenter
        let planner: MockAdaptivePlannerService
        let metronome: StubMetronome
    }

    private func makeSUT(
        phrases: [TonguePhrase],
        audio: (any AudioService)? = nil,
        asr: (any ASRService)? = nil,
        childAge: Int = 6
    ) -> SUT {
        let presenter = SpyPresenter()
        let planner = MockAdaptivePlannerService()
        let metronome = StubMetronome()
        let rhythm = TongueTwistersRhythmWorker(metronome: metronome)
        let speech = TongueTwistersSpeechWorker(audioService: audio, asrService: asr)
        let interactor = TongueTwistersInteractor(
            childId: "kid-1",
            childAge: childAge,
            rhythm: rhythm,
            speech: speech,
            adaptivePlanner: planner,
            seededPhrases: phrases
        )
        interactor.presenter = presenter
        return SUT(interactor: interactor, presenter: presenter, planner: planner, metronome: metronome)
    }

    // MARK: - start

    func test_start_presentsSessionAndFirstPhrase() async {
        let sut = makeSUT(phrases: [sPhrase(), lPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        XCTAssertEqual(sut.presenter.starts, [2])
        XCTAssertEqual(sut.presenter.loadedPhrases.count, 1)
        XCTAssertEqual(sut.presenter.loadedPhrases.first?.phrase.id, "s-osa")
        XCTAssertEqual(sut.presenter.loadedPhrases.first?.phraseIndex, 0)
        XCTAssertEqual(sut.presenter.loadedPhrases.first?.totalPhrases, 2)
    }

    func test_start_emptySession_noPhraseLoaded() async {
        let sut = makeSUT(phrases: [])
        await sut.interactor.start(.init(childId: "kid-1"))
        XCTAssertEqual(sut.presenter.starts, [0])
        XCTAssertTrue(sut.presenter.loadedPhrases.isEmpty)
    }

    // MARK: - chooseRhyme

    func test_chooseRhyme_correct_marksSolvedAndAdvances() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.chooseRhyme(.init(answerId: "s-osa-correct"))
        XCTAssertEqual(sut.presenter.rhymeResults.last?.isCorrect, true)
        XCTAssertEqual(sut.presenter.rhymeResults.last?.chosenWord, "оса")
        XCTAssertEqual(sut.presenter.rhymeResults.last?.correctWord, "оса")
    }

    func test_chooseRhyme_wrong_isCorrectFalse_errorless() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.chooseRhyme(.init(answerId: "s-osa-d0")) // «лиса» — не рифма
        XCTAssertEqual(sut.presenter.rhymeResults.last?.isCorrect, false)
        XCTAssertEqual(sut.presenter.rhymeResults.last?.chosenWord, "лиса")
        XCTAssertEqual(sut.presenter.rhymeResults.last?.correctWord, "оса")
    }

    func test_chooseRhyme_unknownAnswerId_isNoOp() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))
        sut.interactor.chooseRhyme(.init(answerId: "does-not-exist"))
        XCTAssertTrue(sut.presenter.rhymeResults.isEmpty)
    }

    // MARK: - enterTrain

    func test_enterTrain_firstWagonNow_restLocked() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.enterTrain()
        let entered = sut.presenter.enterTrains.last
        XCTAssertEqual(entered?.currentIndex, 0)
        XCTAssertEqual(entered?.states.count, 4)
        XCTAssertEqual(entered?.states.first, .now)
        XCTAssertEqual(entered?.states.dropFirst().allSatisfy { $0 == .locked }, true)
    }

    // MARK: - speakWagon (наращивание)

    func test_speakWagon_middleStep_reportsNextIndex() async {
        let sut = makeSUT(phrases: [sPhrase()]) // 4 вагона
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.speakWagon(index: 1)
        let r = sut.presenter.speakWagons.last
        XCTAssertEqual(r?.response.completedIndex, 1)
        XCTAssertEqual(r?.response.nextIndex, 2)
        XCTAssertEqual(r?.response.allDone, false)
        XCTAssertEqual(r?.total, 4)
    }

    func test_speakWagon_lastStep_allDoneNoNext() async {
        let sut = makeSUT(phrases: [sPhrase()]) // последний индекс — 3
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.speakWagon(index: 3)
        let r = sut.presenter.speakWagons.last
        XCTAssertEqual(r?.response.completedIndex, 3)
        XCTAssertNil(r?.response.nextIndex)
        XCTAssertEqual(r?.response.allDone, true)
    }

    func test_speakWagon_outOfRange_isNoOp() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))
        sut.interactor.speakWagon(index: 99)
        XCTAssertTrue(sut.presenter.speakWagons.isEmpty)
    }

    // MARK: - recordAndCheck (мягкая ASR-проверка)

    func test_recordAndCheck_noAudioService_inconclusive() async {
        // Без audioService запись недоступна → мягкий путь (inconclusive, без штрафа).
        let sut = makeSUT(phrases: [sPhrase()], audio: nil, asr: nil)
        await sut.interactor.start(.init(childId: "kid-1"))

        await sut.interactor.recordAndCheck()
        XCTAssertEqual(sut.presenter.checkResults.count, 1)
        XCTAssertTrue(sut.presenter.checkResults.last?.inconclusive ?? false)
        XCTAssertEqual(sut.presenter.checkResults.last?.soundHeard, false)
        XCTAssertEqual(sut.presenter.checkResults.last?.targetSound, "С")
        // Запись окружена presentRecording(true)…(false).
        XCTAssertEqual(sut.presenter.recording.first, true)
        XCTAssertEqual(sut.presenter.recording.last, false)
    }

    func test_recordAndCheck_scriptedASRWithSound_soundHeard() async {
        // Транскрипт содержит звук «с» → soundHeard, не inconclusive.
        let sut = makeSUT(phrases: [sPhrase()], audio: StubAudio(), asr: ScriptedASR(transcript: "вот летит оса"))
        await sut.interactor.start(.init(childId: "kid-1"))

        await sut.interactor.recordAndCheck()
        XCTAssertEqual(sut.presenter.checkResults.last?.soundHeard, true)
        XCTAssertEqual(sut.presenter.checkResults.last?.inconclusive, false)
    }

    func test_recordAndCheck_scriptedASRWithoutSound_notHeard() async {
        // Транскрипт без «с» → soundHeard=false, но это не inconclusive (ASR сработал).
        let sut = makeSUT(phrases: [sPhrase()], audio: StubAudio(), asr: ScriptedASR(transcript: "тут много дыма"))
        await sut.interactor.start(.init(childId: "kid-1"))

        await sut.interactor.recordAndCheck()
        XCTAssertEqual(sut.presenter.checkResults.last?.soundHeard, false)
        XCTAssertEqual(sut.presenter.checkResults.last?.inconclusive, false)
    }

    func test_recordAndCheck_lowConfidenceASR_inconclusive() async {
        // Низкая уверенность ASR (< 0.2) → не выносим суждение (поддержка).
        let sut = makeSUT(phrases: [sPhrase()], audio: StubAudio(),
                          asr: ScriptedASR(transcript: "оса", confidence: 0.1))
        await sut.interactor.start(.init(childId: "kid-1"))

        await sut.interactor.recordAndCheck()
        XCTAssertTrue(sut.presenter.checkResults.last?.inconclusive ?? false)
    }

    // MARK: - Metronome (опционален, замедляем)

    func test_toggleMetronome_startsThenStops() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.toggleMetronome()
        XCTAssertEqual(sut.metronome.startCount, 1)
        XCTAssertEqual(sut.presenter.metronomeStates.last?.on, true)
        XCTAssertEqual(sut.presenter.metronomeStates.last?.bpm, TongueTwistersRhythmWorker.defaultBPM)

        sut.interactor.toggleMetronome()
        XCTAssertEqual(sut.metronome.stopCount, 1)
        XCTAssertEqual(sut.presenter.metronomeStates.last?.on, false)
    }

    func test_slowDownMetronome_whileStopped_reportsSlowBPM() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.slowDownMetronome()
        XCTAssertEqual(sut.interactor.metronomeBPMForTests, TongueTwistersRhythmWorker.slowBPM)
        XCTAssertEqual(sut.presenter.metronomeStates.last?.on, false)
        XCTAssertEqual(sut.presenter.metronomeStates.last?.bpm, TongueTwistersRhythmWorker.slowBPM)
    }

    func test_slowDownMetronome_whileRunning_restartsAtSlowBPM() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.toggleMetronome()                 // старт на defaultBPM
        sut.interactor.slowDownMetronome()               // рестарт на slowBPM
        XCTAssertEqual(sut.interactor.metronomeBPMForTests, TongueTwistersRhythmWorker.slowBPM)
        XCTAssertEqual(sut.metronome.lastBPM, TongueTwistersRhythmWorker.slowBPM)
        XCTAssertEqual(sut.presenter.metronomeStates.last?.on, true)
        XCTAssertEqual(sut.presenter.metronomeStates.last?.bpm, TongueTwistersRhythmWorker.slowBPM)
    }

    // MARK: - advancePhrase + scoring

    func test_advancePhrase_movesToNextPhrase() async {
        let sut = makeSUT(phrases: [sPhrase(), lPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        await sut.interactor.advancePhrase()
        XCTAssertTrue(sut.presenter.completes.isEmpty, "После первой из двух фраз сессия не завершена")
        XCTAssertEqual(sut.presenter.loadedPhrases.last?.phrase.id, "l-pila")
        XCTAssertEqual(sut.presenter.loadedPhrases.last?.phraseIndex, 1)
    }

    func test_advancePhrase_lastPhrase_completes() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        await sut.interactor.advancePhrase()
        XCTAssertEqual(sut.presenter.completes.count, 1)
        XCTAssertEqual(sut.presenter.completes.last?.totalPhrases, 1)
        XCTAssertEqual(sut.presenter.completes.last?.phrasesCompleted, 1)
    }

    func test_advancePhrase_recordsPerPhraseItemOutcome() async {
        let sut = makeSUT(phrases: [sPhrase(), lPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))

        await sut.interactor.advancePhrase()
        XCTAssertEqual(sut.planner.recordedItemOutcomes.count, 1)
        XCTAssertEqual(sut.planner.recordedItemOutcomes.first?.itemId, "s-osa")
        XCTAssertEqual(sut.planner.recordedItemOutcomes.first?.sound, "С")
        // Без решённой рифмы/записи фраза не «чистая».
        XCTAssertEqual(sut.planner.recordedItemOutcomes.first?.correct, false)
    }

    func test_cleanPhrase_rhymeSolvedPlusRecord_marksOutcomeCorrect() async {
        // Полный «чистый» проход одной фразы: верная рифма + запись (incon. → засчитано).
        let sut = makeSUT(phrases: [sPhrase()], audio: nil, asr: nil)
        await sut.interactor.start(.init(childId: "kid-1"))

        sut.interactor.chooseRhyme(.init(answerId: "s-osa-correct")) // rhymeSolved = true
        await sut.interactor.recordAndCheck()                        // inconclusive → phraseWasClean
        await sut.interactor.advancePhrase()                         // последняя → complete

        XCTAssertEqual(sut.planner.recordedItemOutcomes.first?.correct, true,
                       "Рифма решена + запись (incon.) → чистая фраза")
        // Чистая 1 из 1 → cleanFraction 1.0 → SM-2 perfect.
        XCTAssertEqual(sut.interactor.cleanFraction, 1.0, accuracy: 0.001)
        XCTAssertEqual(sut.presenter.completes.last?.cleanFraction ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(sut.planner.recordedQualities.last?.quality, .perfect)
    }

    func test_complete_recordsSessionResultWithSoundOfFirstPhrase() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))
        await sut.interactor.advancePhrase() // 0 чистых → score 0 → blackout

        XCTAssertEqual(sut.planner.recordedQualities.count, 1)
        XCTAssertEqual(sut.planner.recordedQualities.last?.soundTarget, "С")
        XCTAssertEqual(sut.planner.recordedQualities.last?.quality, .blackout)
    }

    func test_advancePhrase_afterComplete_isNoOp() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))
        await sut.interactor.advancePhrase() // complete
        await sut.interactor.advancePhrase() // finished → no-op

        XCTAssertEqual(sut.presenter.completes.count, 1, "Повторный advance после финала ничего не делает")
    }

    func test_cleanFraction_partial_twoPhrasesOneClean() async {
        let sut = makeSUT(phrases: [sPhrase(), lPhrase()], audio: nil, asr: nil)
        await sut.interactor.start(.init(childId: "kid-1"))

        // Фраза 1 — чистая.
        sut.interactor.chooseRhyme(.init(answerId: "s-osa-correct"))
        await sut.interactor.recordAndCheck()
        await sut.interactor.advancePhrase()

        // Фраза 2 — без рифмы/записи (не чистая) → завершение.
        await sut.interactor.advancePhrase()

        XCTAssertEqual(sut.interactor.cleanFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(sut.presenter.completes.last?.cleanFraction ?? 0, 0.5, accuracy: 0.001)
    }

    // MARK: - cancel

    func test_cancel_stopsMetronomeAndFinishes() async {
        let sut = makeSUT(phrases: [sPhrase()])
        await sut.interactor.start(.init(childId: "kid-1"))
        sut.interactor.toggleMetronome()
        sut.interactor.cancel()
        XCTAssertGreaterThanOrEqual(sut.metronome.stopCount, 1)

        // После cancel интерактор «finished» — advance не завершает повторно.
        await sut.interactor.advancePhrase()
        XCTAssertTrue(sut.presenter.completes.isEmpty)
    }
}

// MARK: - TongueTwistersScoringTests (чистая функция звёзд)

final class TongueTwistersScoringTests: XCTestCase {

    func test_stars_thresholds() {
        XCTAssertEqual(TongueTwistersScoring.stars(for: 1.0), 3)
        XCTAssertEqual(TongueTwistersScoring.stars(for: 0.9), 3)
        XCTAssertEqual(TongueTwistersScoring.stars(for: 0.75), 2)
        XCTAssertEqual(TongueTwistersScoring.stars(for: 0.6), 2)
        XCTAssertEqual(TongueTwistersScoring.stars(for: 0.45), 1)
        XCTAssertEqual(TongueTwistersScoring.stars(for: 0.3), 1)
        XCTAssertEqual(TongueTwistersScoring.stars(for: 0.2), 0)
        XCTAssertEqual(TongueTwistersScoring.stars(for: 0.0), 0)
    }
}

// MARK: - TongueTwistersBuilderTests (детерминизм + отбор по возрасту)

@MainActor
final class TongueTwistersBuilderTests: XCTestCase {

    private let builder = TongueTwistersBuilder()

    private func phrase(_ id: String, sound: String, group: String, minAge: Int) -> TonguePhrase {
        TonguePhrase(
            id: id, targetSound: sound, group: group, minAge: minAge,
            warmupSyllable: "Х", warmupBeats: 3,
            linePrefix: "пре", lineSuffix: "суф", answerWord: "сл", answerAsset: "word_x",
            answers: [RhymeAnswer(id: "\(id)-c", word: "сл", imageAsset: "word_x", isCorrect: true)],
            wagons: [WagonStep(id: 0, text: "Х", isSyllable: true)]
        )
    }

    func test_loadPhrases_returnsNonEmptyCorpus() {
        // Пак из бандла или fallback — в любом случае корпус не пуст и валиден.
        let all = builder.loadPhrases()
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(all.allSatisfy { $0.answers.contains(where: { $0.isCorrect }) },
                      "В каждой чистоговорке есть ровно один верный вариант")
    }

    func test_buildSession_filtersByAge() {
        let pool = [
            phrase("a", sound: "С", group: "свистящие", minAge: 5),
            phrase("b", sound: "Ш", group: "шипящие", minAge: 8)
        ]
        let session = builder.buildSession(from: pool, age: 5, count: 5, childId: "kid-1")
        XCTAssertEqual(session.map(\.id), ["a"], "Фраза с minAge 8 недоступна 5-летке")
    }

    func test_buildSession_isDeterministicPerChild() {
        let pool = (0..<6).map { phrase("p\($0)", sound: "С", group: "свистящие", minAge: 5) }
        let a = builder.buildSession(from: pool, age: 7, count: 4, childId: "kid-1").map(\.id)
        let b = builder.buildSession(from: pool, age: 7, count: 4, childId: "kid-1").map(\.id)
        XCTAssertEqual(a, b, "Одинаковый ребёнок → одинаковая сессия")
        XCTAssertEqual(a.count, 4)
    }

    func test_buildSession_differsBetweenChildren() {
        let pool = (0..<8).map { phrase("p\($0)", sound: "С", group: "свистящие", minAge: 5) }
        let a = builder.buildSession(from: pool, age: 7, count: 6, childId: "child-A").map(\.id)
        let b = builder.buildSession(from: pool, age: 7, count: 6, childId: "child-B").map(\.id)
        XCTAssertNotEqual(a, b, "Разные дети → разный порядок (стабильный seed на childId)")
    }

    func test_buildSession_limitsToCount() {
        let pool = (0..<10).map { phrase("p\($0)", sound: "С", group: "свистящие", minAge: 5) }
        let session = builder.buildSession(from: pool, age: 7, count: 3, childId: "kid-1")
        XCTAssertEqual(session.count, 3)
    }

    func test_deterministicShuffle_stableForSeed() {
        let input = Array(0..<12)
        let s1 = TongueTwistersBuilder.deterministicShuffle(input, seed: 42)
        let s2 = TongueTwistersBuilder.deterministicShuffle(input, seed: 42)
        XCTAssertEqual(s1, s2)
        XCTAssertEqual(Set(s1), Set(input), "Перестановка сохраняет все элементы")
        XCTAssertNotEqual(TongueTwistersBuilder.deterministicShuffle(input, seed: 7), s1)
    }

    func test_seed_stableAndChildSpecific() {
        XCTAssertEqual(TongueTwistersBuilder.seed(for: "kid-1"), TongueTwistersBuilder.seed(for: "kid-1"))
        XCTAssertNotEqual(TongueTwistersBuilder.seed(for: "kid-1"), TongueTwistersBuilder.seed(for: "kid-2"))
    }
}

// MARK: - TongueTwistersSpeechWorkerTests (containsSound — мягкая пара)

@MainActor
final class TongueTwistersSpeechWorkerSoundTests: XCTestCase {

    func test_containsSound_matchesHardAndSoftPair() {
        XCTAssertTrue(TongueTwistersSpeechWorker.containsSound("рыба", sound: "Р"))
        XCTAssertTrue(TongueTwistersSpeechWorker.containsSound("река", sound: "Рь"),
                      "Мягкая пара матчит базовую букву")
        XCTAssertTrue(TongueTwistersSpeechWorker.containsSound("СОВА", sound: "с"),
                      "Регистр не важен")
    }

    func test_containsSound_absent_returnsFalse() {
        XCTAssertFalse(TongueTwistersSpeechWorker.containsSound("дом", sound: "Р"))
        XCTAssertFalse(TongueTwistersSpeechWorker.containsSound("кот", sound: "С"))
    }
}
