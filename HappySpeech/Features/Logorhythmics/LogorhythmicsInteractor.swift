import Foundation
import OSLog

// MARK: - LogorhythmicsInteractor
//
// VIP-Interactor для «Логоритмики» (Ф.7).
//
// Поток:
//   1. `loadExercises()` — отдаёт корпус из 12 chants.
//   2. `selectExercise(id:)` — ребёнок выбрал chant.
//   3. `startPlayback()` — поднимает LogorhythmicsMetronomeWorker и MotionTapDetector,
//      слушает оба stream'а параллельно, копит detected-taps,
//      пушит каждый beat-tick через Presenter.
//   4. `stopPlayback()` — останов, BeatScorer.score(), Presenter.finish().
//
// Параллелизм: два child-task'а в `withTaskGroup` — один на metronome.beats,
// другой на motion.taps. По завершении metronome — детектор стопится.
//
// CTO-decision-default Wave F Ф.7: ExerciseScore не сохраняется в Realm.

@MainActor
final class LogorhythmicsInteractor {

    // MARK: - Dependencies

    private let presenter: LogorhythmicsPresenter
    private let metronomeFactory: @MainActor () -> LogorhythmicsMetronomeWorker
    private let tapDetectorFactory: @Sendable () -> MotionTapDetector
    private let scorer = BeatScorer()

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Logorhythmics.Interactor"
    )

    // MARK: - State

    private(set) var selectedExerciseId: String?
    private var metronome: LogorhythmicsMetronomeWorker?
    private var detector: MotionTapDetector?
    private var playbackTask: Task<Void, Never>?
    private var detectedTaps: [DetectedTap] = []
    private var sessionStartDate: Date?
    /// На какой beat сейчас «висит» View (для accessibility).
    private(set) var currentBeatIndex: Int = 0

    // MARK: - Init

    init(
        presenter: LogorhythmicsPresenter,
        metronomeFactory: @escaping @MainActor () -> LogorhythmicsMetronomeWorker = { LogorhythmicsMetronomeWorker() },
        tapDetectorFactory: @escaping @Sendable () -> MotionTapDetector = { MotionTapDetector() }
    ) {
        self.presenter = presenter
        self.metronomeFactory = metronomeFactory
        self.tapDetectorFactory = tapDetectorFactory
    }

    // MARK: - Load Exercises

    func loadExercises() async {
        let exercises = LogorhythmicsCorpus.exercises
        await presenter.presentLoadExercises(response: .init(exercises: exercises))
    }

    // MARK: - Select

    func selectExercise(id: String) async {
        guard LogorhythmicsCorpus.exercise(id: id) != nil else {
            logger.error("Unknown exercise id: \(id)")
            return
        }
        selectedExerciseId = id
        await presenter.presentSelectExercise(response: .init(exerciseId: id))
    }

    func clearSelection() {
        stopPlayback()
        selectedExerciseId = nil
        detectedTaps = []
    }

    // MARK: - Playback

    /// Запускает метроном и tap-детектор. Завершается, когда метроном
    /// дойдёт до последнего beat'а или будет вызван `stopPlayback`.
    func startPlayback() {
        guard let id = selectedExerciseId,
              let exercise = LogorhythmicsCorpus.exercise(id: id) else {
            logger.error("startPlayback: no selected exercise")
            return
        }
        // Чистый старт.
        stopPlayback()
        detectedTaps = []
        sessionStartDate = Date()
        currentBeatIndex = 0

        let metronome = metronomeFactory()
        let detector = tapDetectorFactory()
        self.metronome = metronome
        self.detector = detector

        let beatStream = metronome.beatEvents()
        let tapStream = detector.start()
        metronome.start(exercise: exercise)

        playbackTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    await self?.consumeBeatStream(beatStream, totalBeats: exercise.totalBeats)
                }
                group.addTask { [weak self] in
                    await self?.consumeTapStream(tapStream)
                }
                // Ждём, пока beat-стрим закончится; затем стопим детектор —
                // tap-стрим сам завершится и второй task закроется.
            }
            await self?.finishPlayback(exercise: exercise)
        }
    }

    /// Принудительный останов (кнопка Стоп / уход с экрана).
    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        metronome?.stop()
        detector?.stop()
        metronome = nil
        detector = nil
    }

    // MARK: - Public for tests

    /// Прямой расчёт скора (без записи). Полезно для unit-тестов Presenter+VIP.
    @discardableResult
    func scoreNow(expected: [ExpectedBeat], detected: [DetectedTap]) -> ExerciseScore {
        scorer.score(expected: expected, detected: detected)
    }

    /// Добавить tap-таймстамп (для тестов без CMMotionManager).
    func injectTap(at timeFromStart: Double) {
        detectedTaps.append(DetectedTap(timeSeconds: timeFromStart))
    }

    /// Завершить сессию принудительно (для тестов).
    func finishForTests(exercise: LogorhythmicsExercise) async {
        await finishPlayback(exercise: exercise)
    }

    // MARK: - Private

    private func consumeBeatStream(
        _ stream: AsyncStream<LogorhythmicsMetronomeWorker.BeatEvent>,
        totalBeats: Int
    ) async {
        for await event in stream {
            currentBeatIndex = event.beatIndex
            await presenter.presentBeatTick(
                response: .init(beatIndex: event.beatIndex, isStrong: event.isStrong),
                totalBeats: totalBeats
            )
        }
        // Beat-стрим закончился → стопим tap-детектор.
        detector?.stop()
    }

    private func consumeTapStream(_ stream: AsyncStream<Date>) async {
        guard let startDate = sessionStartDate else { return }
        for await tapDate in stream {
            let timeFromStart = tapDate.timeIntervalSince(startDate)
            detectedTaps.append(DetectedTap(timeSeconds: timeFromStart))
        }
    }

    private func finishPlayback(exercise: LogorhythmicsExercise) async {
        let expected = BeatScorer.buildExpectedBeats(for: exercise)
        let score = scorer.score(expected: expected, detected: detectedTaps)
        logger.info("Logorhythmics finished: hits=\(score.hits)/\(score.expectedBeats), F1=\(score.f1, format: .fixed(precision: 2))")
        metronome = nil
        detector = nil
        playbackTask = nil
        await presenter.presentFinishExercise(
            response: .init(exercise: exercise, score: score)
        )
    }
}
