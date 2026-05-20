@testable import HappySpeech
import Foundation
import Testing

// MARK: - BeatScorer

@Suite("Logorhythmics — BeatScorer")
struct BeatScorerSuite {

    /// Идеальное совпадение: все expected beats имеют пару detected tap
    /// внутри окна толерантности — F1 = 1.0, 3★.
    @Test func perfectMatch_returns_F1_one_and_threeStars() {
        let expected = [
            ExpectedBeat(index: 0, timeSeconds: 0.0, isStrong: true),
            ExpectedBeat(index: 1, timeSeconds: 0.5, isStrong: false),
            ExpectedBeat(index: 2, timeSeconds: 1.0, isStrong: false),
            ExpectedBeat(index: 3, timeSeconds: 1.5, isStrong: true)
        ]
        let detected = [
            DetectedTap(timeSeconds: 0.02),
            DetectedTap(timeSeconds: 0.49),
            DetectedTap(timeSeconds: 1.01),
            DetectedTap(timeSeconds: 1.52)
        ]
        let scorer = BeatScorer(toleranceSeconds: 0.150)
        let score = scorer.score(expected: expected, detected: detected)

        #expect(score.hits == 4)
        #expect(score.misses == 0)
        #expect(score.extras == 0)
        #expect(score.f1 > 0.99)
        #expect(scorer.stars(forF1: score.f1) == 3)
    }

    /// Половина пропущена: ребёнок попал только на 2 из 4 ударов.
    /// Precision = 1.0, recall = 0.5, F1 ≈ 0.667 → 2★.
    @Test func halfMiss_returns_twoStars() {
        let expected = [
            ExpectedBeat(index: 0, timeSeconds: 0.0, isStrong: true),
            ExpectedBeat(index: 1, timeSeconds: 0.5, isStrong: false),
            ExpectedBeat(index: 2, timeSeconds: 1.0, isStrong: false),
            ExpectedBeat(index: 3, timeSeconds: 1.5, isStrong: true)
        ]
        let detected = [
            DetectedTap(timeSeconds: 0.02),
            DetectedTap(timeSeconds: 1.05)
        ]
        let scorer = BeatScorer()
        let score = scorer.score(expected: expected, detected: detected)

        #expect(score.hits == 2)
        #expect(score.misses == 2)
        #expect(score.extras == 0)
        #expect(abs(score.precision - 1.0) < 0.001)
        #expect(abs(score.recall - 0.5) < 0.001)
        #expect(abs(score.f1 - 0.667) < 0.01)
        #expect(scorer.stars(forF1: score.f1) == 2)
    }

    /// Все пропущены (нет тапов): F1 = 0, 0★.
    @Test func allMiss_returns_F1_zero_and_zeroStars() {
        let expected = [
            ExpectedBeat(index: 0, timeSeconds: 0.0, isStrong: true),
            ExpectedBeat(index: 1, timeSeconds: 0.5, isStrong: false)
        ]
        let scorer = BeatScorer()
        let score = scorer.score(expected: expected, detected: [])

        #expect(score.hits == 0)
        #expect(score.misses == 2)
        #expect(score.f1 == 0.0)
        #expect(scorer.stars(forF1: score.f1) == 0)
    }

    /// Лишние tap'ы (ребёнок тапал «не в попад»): F1 снижается через precision.
    @Test func extras_reduce_precision() {
        let expected = [
            ExpectedBeat(index: 0, timeSeconds: 0.0, isStrong: true),
            ExpectedBeat(index: 1, timeSeconds: 0.5, isStrong: false)
        ]
        let detected = [
            DetectedTap(timeSeconds: 0.02),
            DetectedTap(timeSeconds: 0.48),
            DetectedTap(timeSeconds: 0.20), // лишний — между beat'ами
            DetectedTap(timeSeconds: 0.70), // лишний
            DetectedTap(timeSeconds: 0.90)  // лишний
        ]
        let scorer = BeatScorer()
        let score = scorer.score(expected: expected, detected: detected)

        #expect(score.hits == 2)
        #expect(score.extras == 3)
        #expect(score.recall > 0.99)
        #expect(score.precision < 0.5)
    }

    /// Stars boundary: F1 ровно 0.85 = 3★, чуть ниже = 2★.
    @Test func starsBoundaries() {
        let scorer = BeatScorer()
        #expect(scorer.stars(forF1: 0.85) == 3)
        #expect(scorer.stars(forF1: 0.849) == 2)
        #expect(scorer.stars(forF1: 0.60) == 2)
        #expect(scorer.stars(forF1: 0.599) == 1)
        #expect(scorer.stars(forF1: 0.30) == 1)
        #expect(scorer.stars(forF1: 0.299) == 0)
        #expect(scorer.stars(forF1: 0.0) == 0)
    }

    /// Outside tolerance window: tap слишком далеко от beat'а — не засчитан.
    @Test func tapOutsideTolerance_isMiss() {
        let expected = [
            ExpectedBeat(index: 0, timeSeconds: 1.0, isStrong: false)
        ]
        let detected = [
            DetectedTap(timeSeconds: 1.20) // 200 ms — за окном 150 ms
        ]
        let scorer = BeatScorer(toleranceSeconds: 0.150)
        let score = scorer.score(expected: expected, detected: detected)
        #expect(score.hits == 0)
        #expect(score.misses == 1)
        #expect(score.extras == 1)
    }

    /// Build expected beats — кумулятивная сумма pattern по beatDuration.
    @Test func buildExpectedBeats_cumulative() {
        let exercise = LogorhythmicsExercise(
            id: "t",
            title: "T",
            ageMin: 5,
            category: "топот",
            bpm: 60, // beatDuration = 1.0 s
            patternSource: "test",
            syllables: ["а", "б", "в"],
            pattern: [1, 2, 1],
            strongBeats: [0, 2],
            rhymeText: "А Б В"
        )
        let beats = BeatScorer.buildExpectedBeats(for: exercise)
        #expect(beats.count == 3)
        #expect(beats[0].timeSeconds == 0.0)
        #expect(beats[0].isStrong)
        #expect(beats[1].timeSeconds == 1.0)
        #expect(!beats[1].isStrong)
        #expect(beats[2].timeSeconds == 3.0) // 1 + 2 = 3 quarter-notes
        #expect(beats[2].isStrong)
    }
}

// MARK: - Metronome timing (deterministic via MockClock)

/// Детерминированный clock: возвращает заранее заданные значения now() и
/// конечный список «sleep»-длительностей в виде логов.
/// Реализован как actor — Swift 6 запрещает NSLock в async-контексте.
private actor MockClockStorage {
    var current: Double = 0
    var sleepCalls: [Double] = []

    func now() -> Double { current }

    func sleep(seconds: Double) async {
        sleepCalls.append(seconds)
        current += seconds
    }
}

private final class MockClock: LogorhythmicsClock {
    let storage = MockClockStorage()
    /// Кэшированный snapshot текущего времени — обновляется после каждого sleep().
    /// Это допустимо для тестов: тест работает sequentially, snapshot consistent.
    private nonisolated(unsafe) var cachedNow: Double = 0

    func now() -> Double { cachedNow }

    func sleep(seconds: Double) async throws {
        await storage.sleep(seconds: seconds)
        cachedNow = await storage.now()
        await Task.yield()
    }
}

@Suite("Logorhythmics — Metronome timing")
struct MetronomeTimingSuite {

    /// MetronomeWorker должен попросить clock «спать» по beat-длительности
    /// для каждого beat'а из паттерна.
    @Test @MainActor func metronome_sleepIntervals_matchPattern() async throws {
        // BPM 60 → beatDuration = 1.0 s; pattern [1, 2, 1] →
        // sleeps = [1.0, 2.0, 1.0].
        let exercise = LogorhythmicsExercise(
            id: "t",
            title: "T",
            ageMin: 5,
            category: "топот",
            bpm: 60,
            patternSource: "test",
            syllables: ["а", "б", "в"],
            pattern: [1, 2, 1],
            strongBeats: [0],
            rhymeText: ""
        )
        let clock = MockClock()
        let worker = LogorhythmicsMetronomeWorker(clock: clock)
        let stream = worker.beatEvents()
        worker.start(exercise: exercise)

        let collectorTask = Task<[Int], Never> {
            var out: [Int] = []
            for await event in stream {
                out.append(event.beatIndex)
            }
            return out
        }

        // Даём async-task'у поработать — он выходит сам по завершении
        // паттерна (sleeps консервативно завершаются за yield-итерации).
        for _ in 0..<400 {
            await Task.yield()
            let calls = await clock.storage.sleepCalls
            if calls.count >= 3 { break }
        }
        worker.stop() // закроет stream

        let receivedBeats = await collectorTask.value
        let sleeps = await clock.storage.sleepCalls
        #expect(receivedBeats == [0, 1, 2])
        #expect(sleeps == [1.0, 2.0, 1.0])
    }
}

// MARK: - Presenter

@MainActor
private final class SpyPresenterDisplay: LogorhythmicsDisplayLogic {
    var loadVM: LogorhythmicsModels.LoadExercises.ViewModel?
    var selectVM: LogorhythmicsModels.SelectExercise.ViewModel?
    var beatVM: LogorhythmicsModels.BeatTick.ViewModel?
    var finishVM: LogorhythmicsModels.FinishExercise.ViewModel?

    func displayLoadExercises(viewModel: LogorhythmicsModels.LoadExercises.ViewModel) async {
        loadVM = viewModel
    }
    func displaySelectExercise(viewModel: LogorhythmicsModels.SelectExercise.ViewModel) async {
        selectVM = viewModel
    }
    func displayBeatTick(viewModel: LogorhythmicsModels.BeatTick.ViewModel) async {
        beatVM = viewModel
    }
    func displayFinishExercise(viewModel: LogorhythmicsModels.FinishExercise.ViewModel) async {
        finishVM = viewModel
    }
}

@Suite("Logorhythmics — Presenter")
struct PresenterSuite {

    @Test @MainActor func presenter_stars_threshold_threeStars_atF1_085() async {
        let spy = SpyPresenterDisplay()
        let presenter = LogorhythmicsPresenter(displayLogic: spy)
        let exercise = LogorhythmicsExercise(
            id: "p",
            title: "P",
            ageMin: 5,
            category: "топот",
            bpm: 60,
            patternSource: "test",
            syllables: ["а"],
            pattern: [1],
            strongBeats: [0],
            rhymeText: ""
        )
        let score = ExerciseScore(
            expectedBeats: 10, detectedTaps: 10,
            hits: 9, misses: 1, extras: 1,
            precision: 0.9, recall: 0.9, f1: 0.9
        )
        await presenter.presentFinishExercise(
            response: .init(exercise: exercise, score: score)
        )
        #expect(spy.finishVM?.stars == 3)
        #expect(spy.finishVM?.f1Percent == 90)
    }

    @Test @MainActor func presenter_stars_twoStars_atF1_065() async {
        let spy = SpyPresenterDisplay()
        let presenter = LogorhythmicsPresenter(displayLogic: spy)
        let exercise = LogorhythmicsExercise(
            id: "p", title: "P", ageMin: 5,
            category: "хлопок", bpm: 60,
            patternSource: "test",
            syllables: ["а"], pattern: [1], strongBeats: [],
            rhymeText: ""
        )
        let score = ExerciseScore(
            expectedBeats: 10, detectedTaps: 8,
            hits: 6, misses: 4, extras: 2,
            precision: 0.75, recall: 0.6, f1: 0.65
        )
        await presenter.presentFinishExercise(
            response: .init(exercise: exercise, score: score)
        )
        #expect(spy.finishVM?.stars == 2)
    }

    @Test @MainActor func presenter_stars_oneStar_atF1_040() async {
        let spy = SpyPresenterDisplay()
        let presenter = LogorhythmicsPresenter(displayLogic: spy)
        let exercise = LogorhythmicsExercise(
            id: "p", title: "P", ageMin: 5,
            category: "качание", bpm: 60,
            patternSource: "test",
            syllables: ["а"], pattern: [1], strongBeats: [],
            rhymeText: ""
        )
        let score = ExerciseScore(
            expectedBeats: 10, detectedTaps: 4,
            hits: 3, misses: 7, extras: 1,
            precision: 0.75, recall: 0.3, f1: 0.40
        )
        await presenter.presentFinishExercise(
            response: .init(exercise: exercise, score: score)
        )
        #expect(spy.finishVM?.stars == 1)
    }

    @Test @MainActor func presenter_stars_zeroStars_atF1_010() async {
        let spy = SpyPresenterDisplay()
        let presenter = LogorhythmicsPresenter(displayLogic: spy)
        let exercise = LogorhythmicsExercise(
            id: "p", title: "P", ageMin: 5,
            category: "хлопок", bpm: 60,
            patternSource: "test",
            syllables: ["а"], pattern: [1], strongBeats: [],
            rhymeText: ""
        )
        let score = ExerciseScore(
            expectedBeats: 10, detectedTaps: 1,
            hits: 1, misses: 9, extras: 0,
            precision: 1.0, recall: 0.1, f1: 0.18
        )
        await presenter.presentFinishExercise(
            response: .init(exercise: exercise, score: score)
        )
        #expect(spy.finishVM?.stars == 0)
    }

    @Test @MainActor func presenter_loadGroupsByCategory() async {
        let spy = SpyPresenterDisplay()
        let presenter = LogorhythmicsPresenter(displayLogic: spy)
        let one = LogorhythmicsExercise(
            id: "a", title: "A", ageMin: 5,
            category: "топот", bpm: 80,
            patternSource: "test",
            syllables: ["а"], pattern: [1], strongBeats: [],
            rhymeText: ""
        )
        let two = LogorhythmicsExercise(
            id: "b", title: "B", ageMin: 5,
            category: "хлопок", bpm: 80,
            patternSource: "test",
            syllables: ["а"], pattern: [1], strongBeats: [],
            rhymeText: ""
        )
        await presenter.presentLoadExercises(response: .init(exercises: [one, two]))
        #expect(spy.loadVM?.grouped["топот"]?.count == 1)
        #expect(spy.loadVM?.grouped["хлопок"]?.count == 1)
    }
}

// MARK: - Corpus

@Suite("Logorhythmics — Corpus")
struct CorpusSuite {

    /// Корпус загружается из бандла (или fallback). В любом случае
    /// должен быть >= 3 chants.
    @Test func corpus_loads_atLeastThreeExercises() {
        let exercises = LogorhythmicsCorpus.exercises
        #expect(exercises.count >= 3)
    }

    /// Для каждого chant — pattern.count == syllables.count.
    @Test func corpus_eachExercise_hasMatchingPatternAndSyllables() {
        for exercise in LogorhythmicsCorpus.exercises {
            #expect(
                exercise.pattern.count == exercise.syllables.count,
                "Mismatch in exercise \(exercise.id)"
            )
        }
    }

    /// Для каждого chant — BPM в разумном диапазоне 40…160.
    @Test func corpus_eachExercise_hasReasonableBpm() {
        for exercise in LogorhythmicsCorpus.exercises {
            #expect(exercise.bpm >= 40 && exercise.bpm <= 160,
                    "Bad BPM in exercise \(exercise.id): \(exercise.bpm)")
        }
    }

    /// Сильные доли (strongBeats) — индексы в пределах паттерна.
    @Test func corpus_strongBeats_areWithinPattern() {
        for exercise in LogorhythmicsCorpus.exercises {
            for index in exercise.strongBeats {
                #expect(
                    index >= 0 && index < exercise.pattern.count,
                    "strongBeat \(index) out of bounds in \(exercise.id)"
                )
            }
        }
    }

    /// totalBeats — кумулятивная сумма pattern.
    @Test func corpus_totalBeats_equalsPatternSum() {
        for exercise in LogorhythmicsCorpus.exercises {
            #expect(exercise.totalBeats == exercise.pattern.reduce(0, +))
        }
    }

    /// beatDurationSeconds = 60 / BPM.
    @Test func corpus_beatDuration_isCorrect() {
        for exercise in LogorhythmicsCorpus.exercises {
            let expected = 60.0 / Double(exercise.bpm)
            #expect(abs(exercise.beatDurationSeconds - expected) < 0.0001)
        }
    }
}

// MARK: - Interactor (end-to-end via injected taps, no CMMotionManager)

@Suite("Logorhythmics — Interactor")
struct InteractorSuite {

    @Test @MainActor func interactor_scoreNow_returnsExpectedF1() {
        let spy = SpyPresenterDisplay()
        let presenter = LogorhythmicsPresenter(displayLogic: spy)
        let interactor = LogorhythmicsInteractor(presenter: presenter)
        let expected = [
            ExpectedBeat(index: 0, timeSeconds: 0.0, isStrong: true),
            ExpectedBeat(index: 1, timeSeconds: 0.5, isStrong: false)
        ]
        let detected = [
            DetectedTap(timeSeconds: 0.04),
            DetectedTap(timeSeconds: 0.52)
        ]
        let score = interactor.scoreNow(expected: expected, detected: detected)
        #expect(score.hits == 2)
        #expect(score.f1 > 0.99)
    }

    /// finishForTests прокидывает VM в Presenter и стопает воркеры.
    @Test @MainActor func interactor_finishForTests_pushesViewModel() async {
        let spy = SpyPresenterDisplay()
        let presenter = LogorhythmicsPresenter(displayLogic: spy)
        let interactor = LogorhythmicsInteractor(presenter: presenter)
        let exercise = LogorhythmicsExercise(
            id: "x", title: "X", ageMin: 5,
            category: "топот", bpm: 60,
            patternSource: "test",
            syllables: ["а"], pattern: [1], strongBeats: [0],
            rhymeText: "X"
        )
        await interactor.finishForTests(exercise: exercise)
        #expect(spy.finishVM != nil)
        #expect(spy.finishVM?.exercise.id == "x")
    }
}
