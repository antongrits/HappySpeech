@testable import HappySpeech
import XCTest

// MARK: - VoiceStrongmanInteractorTests
//
// Проверяет бизнес-логику «Силача-голоса» по двум фонопедическим режимам:
//   • громкость — попадание в зону комфортной громкости по RMS (антикрик);
//   • высота — пройденная доля лесенки + совпадение направления глиссандо;
// плюс переходы режим→режим, безоценочный скоринг и запись в планировщик.

@MainActor
final class VoiceStrongmanInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class SpyPresenter: VoiceStrongmanPresentationLogic {
        var starts: [VoiceStrongmanStartViewModel] = []
        var scores: [VoiceStrongmanModels.Score.Response] = []
        var completes: [VoiceStrongmanModels.Complete.Response] = []
        var recordingLog: [Bool] = []
        var playingLog: [Bool] = []
        var liveSamples: [VoiceStrongmanModels.LiveSample.Response] = []

        func presentStart(_ viewModel: VoiceStrongmanStartViewModel) { starts.append(viewModel) }
        func presentRecording(_ isRecording: Bool) { recordingLog.append(isRecording) }
        func presentPlaying(_ isPlaying: Bool) { playingLog.append(isPlaying) }
        func presentLiveSample(_ r: VoiceStrongmanModels.LiveSample.Response) { liveSamples.append(r) }
        func presentScore(_ r: VoiceStrongmanModels.Score.Response) { scores.append(r) }
        func presentComplete(_ r: VoiceStrongmanModels.Complete.Response) { completes.append(r) }
    }

    // MARK: - Planner spy

    private final class PlannerSpy: AdaptivePlannerService, @unchecked Sendable {
        private(set) var sessionResults: [(sound: String, quality: SM2Quality)] = []
        private(set) var itemOutcomes: [(itemId: String, correct: Bool)] = []

        func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
            AdaptiveRoute(steps: [], maxDurationSec: 0, fatigueLevel: .fresh, disorder: .dyslalia)
        }
        func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}
        func recordSessionResult(childId: String, soundTarget: String, qualityScore: SM2Quality) async throws {
            sessionResults.append((soundTarget, qualityScore))
        }
        func recordItemOutcome(childId: String, itemId: String, sound: String, correct: Bool) async {
            itemOutcomes.append((itemId, correct))
        }
        func shouldTakeBreak(consecutiveWrong: Int, sessionDurationSec: Int, childAge: Int) -> Bool { false }
    }

    // MARK: - Mock capture (детерминированный снимок)

    private final class MockCapture: VoiceStrongmanCapturing {
        var scripted: VoiceStrongmanSnapshot = .empty
        private(set) var started = false
        private(set) var stopped = false

        func start() async throws { started = true }
        func stop() { stopped = true }
        func liveSnapshot() async -> VoiceStrongmanSnapshot { scripted }
        func finalSnapshot() async -> VoiceStrongmanSnapshot { scripted }
    }

    // MARK: - Fixtures

    private func session(
        loudness: [LoudnessExercise] = [],
        pitch: [PitchExercise] = []
    ) -> VoiceStrongmanSession {
        VoiceStrongmanSession(loudness: loudness, pitch: pitch)
    }

    private func mediumLoudness() -> LoudnessExercise {
        LoudnessExercise(
            id: "loud-o-cat", vowel: "О", prompt: "Спой «о-о-о», как котик",
            level: .medium, animal: "🐱", hint: "Голос ровный — попади в полоску."
        )
    }

    private func quietLoudness() -> LoudnessExercise {
        LoudnessExercise(
            id: "loud-a-mouse", vowel: "А", prompt: "Тяни «а-а-а», как мышка",
            level: .quiet, animal: "🐭", hint: "Тихо, как мышка."
        )
    }

    private func upPitch() -> PitchExercise {
        PitchExercise(
            id: "pitch-u-up", vowel: "У", prompt: "Веди «у-у-у» вверх",
            direction: .up, steps: 5, hint: "Веди цыплёнка до верха."
        )
    }

    private func downPitch() -> PitchExercise {
        PitchExercise(
            id: "pitch-u-down", vowel: "У", prompt: "Спускай «у-у-у» вниз",
            direction: .down, steps: 5, hint: "Веди голос вниз."
        )
    }

    private func makeSUT(
        session sess: VoiceStrongmanSession
    ) -> (VoiceStrongmanInteractor, SpyPresenter, PlannerSpy, MockCapture) {
        let presenter = SpyPresenter()
        let planner = PlannerSpy()
        let capture = MockCapture()
        let interactor = VoiceStrongmanInteractor(
            childId: "child-1",
            childAge: 7,
            capture: capture,
            adaptivePlanner: planner,
            seededSession: sess
        )
        interactor.presenter = presenter
        return (interactor, presenter, planner, capture)
    }

    // MARK: - Snapshot builders

    /// Кадры громкости со средним значением вокруг центра зоны уровня.
    private func loudnessFrames(around center: Float, count: Int = 12) -> [Float] {
        (0..<count).map { idx in
            let jitter = Float(idx % 3) * 0.01
            return min(1, max(0, center + jitter))
        }
    }

    /// Восходящий питч-контур (низко → высоко) в детском диапазоне.
    private func risingContour() -> [PitchPoint] {
        (0...20).map { step in
            let t = Double(step) / 20.0
            return PitchPoint(time: t, frequencyHz: 180 + 220 * t) // 180 → 400 Hz
        }
    }

    /// Нисходящий питч-контур (высоко → низко).
    private func fallingContour() -> [PitchPoint] {
        (0...20).map { step in
            let t = Double(step) / 20.0
            return PitchPoint(time: t, frequencyHz: 400 - 220 * t) // 400 → 180 Hz
        }
    }

    /// Плоский контур на одной высоте (нет модуляции).
    private func flatContour() -> [PitchPoint] {
        (0...20).map { step in
            PitchPoint(time: Double(step) / 20.0, frequencyHz: 280)
        }
    }

    // MARK: - Start

    func test_start_loudnessFirst_presentsLoudnessPhase() async {
        let (sut, spy, _, _) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))

        XCTAssertEqual(spy.starts.count, 1)
        XCTAssertEqual(spy.starts.first?.mode, .loudness)
        XCTAssertEqual(spy.starts.first?.phase, .loudness)
        XCTAssertEqual(spy.starts.first?.vowel, "О")
        XCTAssertEqual(spy.starts.first?.loudnessLevel, .medium)
    }

    func test_start_emptySession_completesImmediately() async {
        let (sut, spy, _, _) = makeSUT(session: session())
        await sut.start(.init(childId: "child-1"))
        XCTAssertEqual(spy.completes.count, 1)
        XCTAssertTrue(spy.starts.isEmpty)
    }

    // MARK: - Loudness branch

    func test_loudness_inBand_isMatch() async {
        let (sut, spy, _, capture) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        // medium центр = 0.55, полуширина 0.16 → зона 0.39…0.71.
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: loudnessFrames(around: 0.55),
            loudness: 0.55, contour: [], pitchNorm: 0
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(spy.scores.count, 1)
        XCTAssertEqual(spy.scores.first?.mode, .loudness)
        XCTAssertTrue(spy.scores.first?.loudnessInBand ?? false)
        XCTAssertTrue(spy.scores.first?.isMatch ?? false,
                      "Громкость в зоне комфортной → попадание")
    }

    func test_loudness_tooLoud_notInBand() async {
        let (sut, spy, _, capture) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        // Крик (1.0) выше верхней границы medium-зоны → не попадание (антикрик).
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: loudnessFrames(around: 1.0),
            loudness: 1.0, contour: [], pitchNorm: 0
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertFalse(spy.scores.first?.loudnessInBand ?? true,
                       "Крик не должен засчитываться как попадание")
        XCTAssertFalse(spy.scores.first?.isMatch ?? true)
    }

    func test_loudness_tooQuiet_forLoudLevel_notInBand() async {
        // Уровень «громко» (центр 0.78), но ребёнок поёт тихо (0.2) → не зона.
        let loud = LoudnessExercise(
            id: "loud-u-bear", vowel: "У", prompt: "Громко, как мишка",
            level: .loud, animal: "🐻", hint: "Громко, но не криком."
        )
        let (sut, spy, _, capture) = makeSUT(session: session(loudness: [loud]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: loudnessFrames(around: 0.2),
            loudness: 0.2, contour: [], pitchNorm: 0
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertFalse(spy.scores.first?.isMatch ?? true)
    }

    func test_loudness_emptyFrames_notMatch() async {
        let (sut, spy, _, capture) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = .empty
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertFalse(spy.scores.first?.isMatch ?? true)
    }

    func test_selectLevel_updatesActiveLevel() async {
        let (sut, spy, _, _) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        sut.selectLevel(.init(level: .loud))
        XCTAssertEqual(spy.starts.last?.loudnessLevel, .loud)
    }

    // MARK: - Pitch branch

    func test_pitch_risingMatchesUpDirection() async {
        let (sut, spy, _, capture) = makeSUT(session: session(pitch: [upPitch()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: [], loudness: 0, contour: risingContour(), pitchNorm: 0.9
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(spy.scores.count, 1)
        XCTAssertEqual(spy.scores.first?.mode, .pitch)
        XCTAssertTrue(spy.scores.first?.directionMatched ?? false,
                      "Восходящий контур совпадает с направлением вверх")
        XCTAssertTrue(spy.scores.first?.isMatch ?? false)
        XCTAssertGreaterThanOrEqual(spy.scores.first?.ladderReached ?? 0,
                                    VoiceStrongmanScoring.ladderReachThreshold)
    }

    func test_pitch_fallingDoesNotMatchUpDirection() async {
        let (sut, spy, _, capture) = makeSUT(session: session(pitch: [upPitch()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: [], loudness: 0, contour: fallingContour(), pitchNorm: 0.2
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertFalse(spy.scores.first?.directionMatched ?? true,
                       "Нисходящий контур не совпадает с направлением вверх")
        XCTAssertFalse(spy.scores.first?.isMatch ?? true)
    }

    func test_pitch_fallingMatchesDownDirection() async {
        let (sut, spy, _, capture) = makeSUT(session: session(pitch: [downPitch()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: [], loudness: 0, contour: fallingContour(), pitchNorm: 0.2
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertTrue(spy.scores.first?.directionMatched ?? false)
        XCTAssertTrue(spy.scores.first?.isMatch ?? false)
    }

    func test_pitch_flatContour_notMatch() async {
        let (sut, spy, _, capture) = makeSUT(session: session(pitch: [upPitch()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: [], loudness: 0, contour: flatContour(), pitchNorm: 0.5
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertFalse(spy.scores.first?.isMatch ?? true,
                       "Плоский контур (нет модуляции) не проходит лесенку")
    }

    func test_selectDirection_updatesActiveDirection() async {
        let (sut, spy, _, _) = makeSUT(session: session(pitch: [upPitch()]))
        await sut.start(.init(childId: "child-1"))
        sut.selectDirection(.init(direction: .down))
        XCTAssertEqual(spy.starts.last?.pitchDirection, .down)
    }

    // MARK: - Mode transition + persistence

    func test_advance_movesFromLoudnessToPitch() async {
        let (sut, spy, _, capture) = makeSUT(
            session: session(loudness: [mediumLoudness()], pitch: [upPitch()])
        )
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: loudnessFrames(around: 0.55), loudness: 0.55, contour: [], pitchNorm: 0
        )
        await sut.startRecording()
        await sut.stopRecording()

        await sut.advance()
        XCTAssertEqual(spy.starts.last?.mode, .pitch)
        XCTAssertTrue(spy.completes.isEmpty)
    }

    func test_advance_secondTaskWithinMode() async {
        let (sut, spy, _, capture) = makeSUT(
            session: session(loudness: [mediumLoudness(), quietLoudness()])
        )
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: loudnessFrames(around: 0.55), loudness: 0.55, contour: [], pitchNorm: 0
        )
        await sut.startRecording()
        await sut.stopRecording()

        await sut.advance()
        XCTAssertTrue(spy.completes.isEmpty)
        XCTAssertEqual(spy.starts.last?.vowel, "А", "Второе задание — гласный А (мышка)")
        XCTAssertEqual(spy.starts.last?.loudnessLevel, .quiet)
    }

    func test_completeSession_recordsResultAndItemOutcome() async {
        let (sut, spy, planner, capture) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: loudnessFrames(around: 0.55), loudness: 0.55, contour: [], pitchNorm: 0
        )
        await sut.startRecording()
        await sut.stopRecording()

        await sut.advance() // единственное задание → complete

        XCTAssertEqual(spy.completes.count, 1)
        XCTAssertEqual(planner.sessionResults.count, 1)
        XCTAssertEqual(planner.sessionResults.first?.sound, "голос")
        XCTAssertEqual(planner.itemOutcomes.count, 1)
        XCTAssertTrue(planner.itemOutcomes.first?.correct ?? false,
                      "Попадание в зону → пословный outcome correct")
    }

    func test_matchRate_reflectsMatches() async {
        let (sut, _, _, capture) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceStrongmanSnapshot(
            loudnessFrames: loudnessFrames(around: 0.55), loudness: 0.55, contour: [], pitchNorm: 0
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(sut.matchFraction, 1.0, accuracy: 0.001)
    }

    // MARK: - Recording lifecycle

    func test_recording_emitsRecordingFlags() async {
        let (sut, spy, _, capture) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = .empty

        await sut.startRecording()
        XCTAssertTrue(capture.started)
        XCTAssertTrue(spy.recordingLog.contains(true))

        await sut.stopRecording()
        XCTAssertTrue(capture.stopped)
        XCTAssertTrue(spy.recordingLog.contains(false))
    }

    func test_cancel_stopsCapture() async {
        let (sut, _, _, capture) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        sut.cancel()
        XCTAssertTrue(capture.stopped)
    }

    func test_playPrompt_emitsPlayingFlag() async {
        let (sut, spy, _, _) = makeSUT(session: session(loudness: [mediumLoudness()]))
        await sut.start(.init(childId: "child-1"))
        sut.playPrompt()
        XCTAssertTrue(spy.playingLog.contains(true))
    }
}

// MARK: - VoiceStrongmanAnalyzerTests

final class VoiceStrongmanAnalyzerTests: XCTestCase {

    private let analyzer = VoiceStrongmanAnalyzer()

    // MARK: - Loudness band

    func test_inBandFraction_allInside_isOne() {
        let frames: [Float] = [0.5, 0.55, 0.6] // внутри medium 0.39…0.71
        XCTAssertEqual(analyzer.inBandFraction(frames: frames, level: .medium), 1.0, accuracy: 0.001)
    }

    func test_didHitBand_majorityInside_true() {
        let frames: [Float] = [0.55, 0.55, 0.55, 0.95] // 3/4 в зоне medium
        XCTAssertTrue(analyzer.didHitBand(frames: frames, level: .medium))
    }

    func test_didHitBand_shouting_false() {
        let frames: [Float] = [1.0, 1.0, 1.0] // крик
        XCTAssertFalse(analyzer.didHitBand(frames: frames, level: .medium),
                       "Постоянный крик не попадает в комфортную зону")
    }

    func test_isInBand_instant() {
        XCTAssertTrue(analyzer.isInBand(loudness: 0.30, level: .quiet))
        XCTAssertFalse(analyzer.isInBand(loudness: 0.90, level: .quiet))
    }

    func test_bands_doNotReachMaximum_antiYell() {
        // Даже верхняя граница «громко» не достигает 1.0 (защита от крика).
        XCTAssertLessThan(LoudnessLevel.loud.upperBound, 1.0)
    }

    // MARK: - Pitch

    func test_normalisedPitch_outsideRange_nil() {
        XCTAssertNil(analyzer.normalisedPitch(frequencyHz: nil))
        XCTAssertNil(analyzer.normalisedPitch(frequencyHz: 50))   // ниже floor
        XCTAssertNil(analyzer.normalisedPitch(frequencyHz: 900))  // выше ceil
    }

    func test_normalisedPitch_midRange_around_half() {
        // floor 160, ceil 440 → центр 300 Hz ≈ 0.5.
        let value = analyzer.normalisedPitch(frequencyHz: 300) ?? -1
        XCTAssertEqual(value, 0.5, accuracy: 0.05)
    }

    func test_ladderReached_wideModulation_high() {
        let contour = (0...20).map { step -> PitchPoint in
            let t = Double(step) / 20.0
            return PitchPoint(time: t, frequencyHz: 180 + 220 * t)
        }
        XCTAssertGreaterThan(analyzer.ladderReached(contour: contour, direction: .up), 0.6)
    }

    func test_ladderReached_flat_low() {
        let contour = (0...20).map { PitchPoint(time: Double($0) / 20.0, frequencyHz: 280) }
        XCTAssertLessThan(analyzer.ladderReached(contour: contour, direction: .up), 0.1)
    }

    func test_didMatchDirection_upForRising_true() {
        let contour = (0...20).map { step -> PitchPoint in
            PitchPoint(time: Double(step) / 20.0, frequencyHz: 180 + 220 * Double(step) / 20.0)
        }
        XCTAssertTrue(analyzer.didMatchDirection(contour: contour, direction: .up))
        XCTAssertFalse(analyzer.didMatchDirection(contour: contour, direction: .down))
    }

    func test_didMatchDirection_downForFalling_true() {
        let contour = (0...20).map { step -> PitchPoint in
            PitchPoint(time: Double(step) / 20.0, frequencyHz: 400 - 220 * Double(step) / 20.0)
        }
        XCTAssertTrue(analyzer.didMatchDirection(contour: contour, direction: .down))
    }

    func test_didMatchDirection_tooFewPoints_false() {
        let contour = [PitchPoint(time: 0, frequencyHz: 200), PitchPoint(time: 1, frequencyHz: 400)]
        XCTAssertFalse(analyzer.didMatchDirection(contour: contour, direction: .up))
    }

    func test_didClimbLadder_risingUp_true() {
        let contour = (0...20).map { step -> PitchPoint in
            PitchPoint(time: Double(step) / 20.0, frequencyHz: 180 + 220 * Double(step) / 20.0)
        }
        XCTAssertTrue(analyzer.didClimbLadder(contour: contour, direction: .up))
    }
}

// MARK: - VoiceStrongmanCorpusTests

final class VoiceStrongmanCorpusTests: XCTestCase {

    func test_buildSession_nonEmptyForFive() {
        let session = VoiceStrongmanCorpus.buildSession(age: 5)
        XCTAssertFalse(session.isEmpty, "Сессия для 5 лет не должна быть пустой")
        XCTAssertFalse(session.loudness.isEmpty)
        XCTAssertFalse(session.pitch.isEmpty)
    }

    func test_buildSession_olderGetsBothModes() {
        let session = VoiceStrongmanCorpus.buildSession(age: 8)
        XCTAssertFalse(session.loudness.isEmpty)
        XCTAssertFalse(session.pitch.isEmpty)
    }

    func test_loudnessLevels_haveOrderedBands() {
        XCTAssertLessThan(LoudnessLevel.quiet.bandCenter, LoudnessLevel.medium.bandCenter)
        XCTAssertLessThan(LoudnessLevel.medium.bandCenter, LoudnessLevel.loud.bandCenter)
    }

    func test_pitchDirections_distinctArrows() {
        XCTAssertNotEqual(PitchDirection.up.arrow, PitchDirection.down.arrow)
    }

    func test_scoring_stars_byMatchRate() {
        XCTAssertEqual(VoiceStrongmanScoring.stars(for: 0.9), 3)
        XCTAssertEqual(VoiceStrongmanScoring.stars(for: 0.6), 2)
        XCTAssertEqual(VoiceStrongmanScoring.stars(for: 0.1), 1)
    }
}
