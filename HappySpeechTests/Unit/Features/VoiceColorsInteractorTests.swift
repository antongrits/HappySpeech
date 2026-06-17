@testable import HappySpeech
import XCTest

// MARK: - VoiceColorsInteractorTests
//
// Проверяет бизнес-логику «Голосовых красок» по трём режимам:
//   • интонация — сравнение pitch-контура (ContourComparator);
//   • логическое ударение — пословный RMS (WordStressAnalyzer);
//   • эмоция — маппинг распознанной окраски (EmotionDetection) в зеркало Ляли;
// плюс переходы режим→режим, безоценочный скоринг и запись в планировщик.

@MainActor
final class VoiceColorsInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class SpyPresenter: VoiceColorsPresentationLogic {
        var starts: [VoiceColorsStartViewModel] = []
        var selectIntonations: [VoiceColorsModels.SelectIntonation.Response] = []
        var selectStress: [VoiceColorsModels.SelectStressWord.Response] = []
        var selectEmotions: [VoiceColorsModels.SelectEmotion.Response] = []
        var scores: [VoiceColorsModels.Score.Response] = []
        var completes: [VoiceColorsModels.Complete.Response] = []
        var recordingLog: [Bool] = []
        var playingLog: [Bool] = []
        var liveSamples: [VoiceColorsModels.LiveSample.Response] = []

        func presentStart(_ viewModel: VoiceColorsStartViewModel) { starts.append(viewModel) }
        func presentSelectIntonation(_ r: VoiceColorsModels.SelectIntonation.Response) { selectIntonations.append(r) }
        func presentSelectStressWord(_ r: VoiceColorsModels.SelectStressWord.Response) { selectStress.append(r) }
        func presentSelectEmotion(_ r: VoiceColorsModels.SelectEmotion.Response) { selectEmotions.append(r) }
        func presentRecording(_ isRecording: Bool) { recordingLog.append(isRecording) }
        func presentPlaying(_ isPlaying: Bool) { playingLog.append(isPlaying) }
        func presentLiveSample(_ r: VoiceColorsModels.LiveSample.Response) { liveSamples.append(r) }
        func presentScore(_ r: VoiceColorsModels.Score.Response) { scores.append(r) }
        func presentComplete(_ r: VoiceColorsModels.Complete.Response) { completes.append(r) }
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

    private final class MockVoiceCapture: VoiceCaptureControlling {
        var scripted: VoiceCaptureSnapshot = .empty
        private(set) var started = false
        private(set) var stopped = false

        func start() async throws { started = true }
        func stop() { stopped = true }
        func liveSnapshot() async -> VoiceCaptureSnapshot { scripted }
        func finalSnapshot() async -> VoiceCaptureSnapshot { scripted }
    }

    // MARK: - Fixtures

    private func session(
        intonation: [IntonationTask] = [],
        stress: [StressTask] = [],
        emotion: [EmotionTask] = []
    ) -> VoiceColorsSession {
        VoiceColorsSession(intonation: intonation, stress: stress, emotion: emotion)
    }

    private func mamaIntonation() -> IntonationTask {
        IntonationTask(
            id: "into-mama", text: "Мама пришла",
            variants: [
                .init(mode: .question, mark: "?", hint: "вопрос"),
                .init(mode: .exclamation, mark: "!", hint: "восклицание"),
                .init(mode: .calm, mark: ".", hint: "спокойно")
            ]
        )
    }

    /// Интонация с единственным «домиком» — для тестов перехода/завершения
    /// (одно задание = одна краска = одна попытка).
    private func singleIntonation() -> IntonationTask {
        IntonationTask(
            id: "into-single", text: "Мама пришла",
            variants: [.init(mode: .question, mark: "?", hint: "вопрос")]
        )
    }

    private func koshkaStress() -> StressTask {
        StressTask(
            id: "stress-koshka", words: ["кошка", "ест", "рыбу"],
            targets: [
                .init(index: 0, question: "Кто ест рыбу?", emoji: "🐱"),
                .init(index: 2, question: "Что ест кошка?", emoji: "🐟")
            ]
        )
    }

    private func snegEmotion() -> EmotionTask {
        EmotionTask(
            id: "emo-sneg", text: "Снег пошёл",
            options: [
                .init(emotion: .joy, phrase: "Снег пошёл!", emoji: "😄", name: "Весело", hint: "h"),
                .init(emotion: .sad, phrase: "Снег пошёл…", emoji: "😢", name: "Грустно", hint: "h"),
                .init(emotion: .surprise, phrase: "Снег пошёл?!", emoji: "😮", name: "Удивлённо", hint: "h")
            ]
        )
    }

    private func makeSUT(
        session sess: VoiceColorsSession,
        emotion: (any EmotionDetectionServiceProtocol)? = nil
    ) -> (VoiceColorsInteractor, SpyPresenter, PlannerSpy, MockVoiceCapture) {
        let presenter = SpyPresenter()
        let planner = PlannerSpy()
        let capture = MockVoiceCapture()
        let interactor = VoiceColorsInteractor(
            childId: "child-1",
            childAge: 7,
            capture: capture,
            emotionService: emotion,
            adaptivePlanner: planner,
            seededSession: sess
        )
        interactor.presenter = presenter
        return (interactor, presenter, planner, capture)
    }

    /// Контур, нормализованно совпадающий с целевым «вопросом» (рост в финале).
    private func risingContour() -> [PitchPoint] {
        (0...20).map { step in
            let t = Double(step) / 20.0
            let f: Double = t < 0.7 ? 230 + 5 * t : 230 + 3.5 + 330 * (t - 0.7)
            return PitchPoint(time: t, frequencyHz: f)
        }
    }

    /// Огибающая, где первое слово (3 кадра) громко, остальные тихо.
    private func envelopeLoudFirst() -> [Float] {
        [0.9, 0.85, 0.9] + [0.2, 0.18, 0.2] + [0.22, 0.2, 0.21]
    }

    /// Огибающая, где третье слово громче.
    private func envelopeLoudThird() -> [Float] {
        [0.2, 0.18, 0.2] + [0.2, 0.18, 0.2] + [0.9, 0.88, 0.9]
    }

    // MARK: - Start

    func test_start_intonationFirst_presentsIntonationPhase() async {
        let (sut, spy, _, _) = makeSUT(session: session(intonation: [mamaIntonation()]))
        await sut.start(.init(childId: "child-1"))

        XCTAssertEqual(spy.starts.count, 1)
        XCTAssertEqual(spy.starts.first?.mode, .intonation)
        XCTAssertEqual(spy.starts.first?.phase, .intonation)
        XCTAssertEqual(spy.starts.first?.phraseText, "Мама пришла")
        // Дефолтный домик — вопрос; контур не пустой.
        XCTAssertEqual(spy.starts.first?.firstIntonationMode, .question)
        XCTAssertFalse(spy.starts.first?.firstContour.isEmpty ?? true)
    }

    func test_start_emptySession_completesImmediately() async {
        let (sut, spy, _, _) = makeSUT(session: session())
        await sut.start(.init(childId: "child-1"))
        XCTAssertEqual(spy.completes.count, 1)
        XCTAssertTrue(spy.starts.isEmpty)
    }

    // MARK: - Intonation branch

    func test_selectIntonation_changesTargetContour() async {
        let (sut, spy, _, _) = makeSUT(session: session(intonation: [mamaIntonation()]))
        await sut.start(.init(childId: "child-1"))

        sut.selectIntonation(.init(mode: .exclamation))
        XCTAssertEqual(spy.selectIntonations.last?.mode, .exclamation)
        XCTAssertEqual(spy.selectIntonations.last?.mark, "!")
        XCTAssertFalse(spy.selectIntonations.last?.targetContour.isEmpty ?? true)
    }

    func test_intonation_matchingContour_isMatch() async {
        let (sut, spy, _, capture) = makeSUT(session: session(intonation: [mamaIntonation()]))
        await sut.start(.init(childId: "child-1"))
        sut.selectIntonation(.init(mode: .question))

        capture.scripted = VoiceCaptureSnapshot(
            contour: risingContour(), amplitudeEnvelope: [], amplitude: 0.5, pcmData: Data()
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(spy.scores.count, 1)
        XCTAssertEqual(spy.scores.first?.mode, .intonation)
        XCTAssertTrue(spy.scores.first?.isMatch ?? false,
                      "Восходящий контур должен совпасть с целевым вопросом")
        XCTAssertGreaterThan(spy.scores.first?.intonationSimilarity ?? 0,
                             VoiceColorsScoring.intonationMatchThreshold)
    }

    func test_intonation_emptyContour_notMatch() async {
        let (sut, spy, _, capture) = makeSUT(session: session(intonation: [mamaIntonation()]))
        await sut.start(.init(childId: "child-1"))
        sut.selectIntonation(.init(mode: .question))

        capture.scripted = .empty
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertFalse(spy.scores.first?.isMatch ?? true)
    }

    // MARK: - Stress branch

    func test_selectStressWord_updatesChosenIndex() async {
        let (sut, spy, _, _) = makeSUT(session: session(stress: [koshkaStress()]))
        await sut.start(.init(childId: "child-1"))

        sut.selectStressWord(.init(wordIndex: 2))
        XCTAssertEqual(spy.selectStress.last?.chosenIndex, 2)
    }

    func test_stress_loudFirstWord_matchesTargetZero() async {
        let (sut, spy, _, capture) = makeSUT(session: session(stress: [koshkaStress()]))
        await sut.start(.init(childId: "child-1"))
        // Первый target — индекс 0 («кошка»).

        capture.scripted = VoiceCaptureSnapshot(
            contour: [], amplitudeEnvelope: envelopeLoudFirst(), amplitude: 0.9, pcmData: Data()
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(spy.scores.first?.mode, .stress)
        XCTAssertEqual(spy.scores.first?.loudestWordIndex, 0)
        XCTAssertEqual(spy.scores.first?.targetWordIndex, 0)
        XCTAssertTrue(spy.scores.first?.isMatch ?? false)
        XCTAssertEqual(spy.scores.first?.perWordRMS.count, 3)
    }

    func test_stress_wrongWordLoud_notMatch() async {
        let (sut, spy, _, capture) = makeSUT(session: session(stress: [koshkaStress()]))
        await sut.start(.init(childId: "child-1"))
        // Target index 0, но громко — третье слово.

        capture.scripted = VoiceCaptureSnapshot(
            contour: [], amplitudeEnvelope: envelopeLoudThird(), amplitude: 0.9, pcmData: Data()
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(spy.scores.first?.loudestWordIndex, 2)
        XCTAssertFalse(spy.scores.first?.isMatch ?? true)
    }

    func test_stress_advanceMovesToSecondTarget() async {
        let (sut, spy, _, capture) = makeSUT(session: session(stress: [koshkaStress()]))
        await sut.start(.init(childId: "child-1"))

        capture.scripted = VoiceCaptureSnapshot(
            contour: [], amplitudeEnvelope: envelopeLoudFirst(), amplitude: 0.9, pcmData: Data()
        )
        await sut.startRecording()
        await sut.stopRecording()

        // Второй target — индекс 2 («рыбу»). advance не должен завершать сессию.
        await sut.advance()
        XCTAssertTrue(spy.completes.isEmpty)
        // Последний presentStart режима stress — с targetWordIndex 2.
        XCTAssertEqual(spy.starts.last?.mode, .stress)
        XCTAssertEqual(spy.starts.last?.targetWordIndex, 2)
    }

    // MARK: - Emotion branch

    func test_selectEmotion_updatesPhrase() async {
        let (sut, spy, _, _) = makeSUT(session: session(emotion: [snegEmotion()]))
        await sut.start(.init(childId: "child-1"))

        sut.selectEmotion(.init(emotion: .sad))
        XCTAssertEqual(spy.selectEmotions.last?.emotion, .sad)
        XCTAssertEqual(spy.selectEmotions.last?.phrase, "Снег пошёл…")
    }

    func test_emotion_detectedMatchesChosen_isMatch() async {
        let mock = MockEmotionDetectionService(emotion: .happy, confidence: 0.9)
        let (sut, spy, _, capture) = makeSUT(session: session(emotion: [snegEmotion()]), emotion: mock)
        await sut.start(.init(childId: "child-1"))
        sut.selectEmotion(.init(emotion: .joy)) // joy ↔ happy

        capture.scripted = VoiceCaptureSnapshot(
            contour: [], amplitudeEnvelope: [], amplitude: 0.5,
            pcmData: Data(repeating: 0, count: 64)
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(spy.scores.first?.mode, .emotion)
        XCTAssertEqual(spy.scores.first?.detectedEmotion, .joy)
        XCTAssertTrue(spy.scores.first?.isMatch ?? false)
    }

    func test_emotion_noService_reflectsChosen() async {
        // Без EmotionDetection: зеркалим выбранную эмоцию (безоценочно).
        let (sut, spy, _, capture) = makeSUT(session: session(emotion: [snegEmotion()]), emotion: nil)
        await sut.start(.init(childId: "child-1"))
        sut.selectEmotion(.init(emotion: .surprise))

        capture.scripted = VoiceCaptureSnapshot(
            contour: [], amplitudeEnvelope: [], amplitude: 0.4,
            pcmData: Data(repeating: 1, count: 32)
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(spy.scores.first?.detectedEmotion, .surprise)
        XCTAssertTrue(spy.scores.first?.isMatch ?? false)
    }

    func test_emotion_mappingFromDetected() {
        XCTAssertEqual(VoiceEmotion.from(detected: .happy), .joy)
        XCTAssertEqual(VoiceEmotion.from(detected: .sad), .sad)
        XCTAssertEqual(VoiceEmotion.from(detected: .frustrated), .surprise)
        XCTAssertEqual(VoiceEmotion.from(detected: .neutral), .joy)
    }

    // MARK: - Mode transition + persistence

    func test_advance_movesFromIntonationToStress() async {
        let (sut, spy, _, capture) = makeSUT(
            session: session(intonation: [singleIntonation()], stress: [koshkaStress()])
        )
        await sut.start(.init(childId: "child-1"))
        sut.selectIntonation(.init(mode: .question))
        capture.scripted = VoiceCaptureSnapshot(
            contour: risingContour(), amplitudeEnvelope: [], amplitude: 0.5, pcmData: Data()
        )
        await sut.startRecording()
        await sut.stopRecording()

        await sut.advance()
        XCTAssertEqual(spy.starts.last?.mode, .stress)
        XCTAssertTrue(spy.completes.isEmpty)
    }

    func test_intonation_advanceCyclesThroughHouses() async {
        // 3 домика → 3 записи в одном задании, потом завершение.
        let (sut, spy, _, capture) = makeSUT(session: session(intonation: [mamaIntonation()]))
        await sut.start(.init(childId: "child-1"))
        capture.scripted = VoiceCaptureSnapshot(
            contour: risingContour(), amplitudeEnvelope: [], amplitude: 0.5, pcmData: Data()
        )

        // Краска 1.
        await sut.startRecording(); await sut.stopRecording()
        await sut.advance()
        XCTAssertTrue(spy.completes.isEmpty, "После первой краски сессия не завершена")

        // Краска 2.
        await sut.startRecording(); await sut.stopRecording()
        await sut.advance()
        XCTAssertTrue(spy.completes.isEmpty, "После второй краски сессия не завершена")

        // Краска 3 → завершение.
        await sut.startRecording(); await sut.stopRecording()
        await sut.advance()
        XCTAssertEqual(spy.completes.count, 1, "Три краски пройдены → завершение")
    }

    func test_completeSession_recordsResultAndItemOutcome() async {
        let (sut, spy, planner, capture) = makeSUT(session: session(intonation: [singleIntonation()]))
        await sut.start(.init(childId: "child-1"))
        sut.selectIntonation(.init(mode: .question))
        capture.scripted = VoiceCaptureSnapshot(
            contour: risingContour(), amplitudeEnvelope: [], amplitude: 0.5, pcmData: Data()
        )
        await sut.startRecording()
        await sut.stopRecording()

        await sut.advance() // единственная краска единственного задания → complete

        XCTAssertEqual(spy.completes.count, 1)
        XCTAssertEqual(planner.sessionResults.count, 1)
        XCTAssertEqual(planner.sessionResults.first?.sound, "просодика")
        XCTAssertEqual(planner.itemOutcomes.count, 1)
        XCTAssertTrue(planner.itemOutcomes.first?.correct ?? false,
                      "Совпавшая интонация → пословный outcome correct")
    }

    func test_matchRate_reflectsMatches() async {
        let (sut, _, _, capture) = makeSUT(session: session(intonation: [singleIntonation()]))
        await sut.start(.init(childId: "child-1"))
        sut.selectIntonation(.init(mode: .question))
        capture.scripted = VoiceCaptureSnapshot(
            contour: risingContour(), amplitudeEnvelope: [], amplitude: 0.5, pcmData: Data()
        )
        await sut.startRecording()
        await sut.stopRecording()

        XCTAssertEqual(sut.matchFraction, 1.0, accuracy: 0.001)
    }

    // MARK: - Recording lifecycle

    func test_recording_emitsRecordingFlags() async {
        let (sut, spy, _, capture) = makeSUT(session: session(intonation: [mamaIntonation()]))
        await sut.start(.init(childId: "child-1"))
        sut.selectIntonation(.init(mode: .calm))
        capture.scripted = .empty

        await sut.startRecording()
        XCTAssertTrue(capture.started)
        XCTAssertTrue(spy.recordingLog.contains(true))

        await sut.stopRecording()
        XCTAssertTrue(capture.stopped)
        XCTAssertTrue(spy.recordingLog.contains(false))
    }

    func test_cancel_stopsCapture() async {
        let (sut, _, _, capture) = makeSUT(session: session(intonation: [mamaIntonation()]))
        await sut.start(.init(childId: "child-1"))
        sut.cancel()
        XCTAssertTrue(capture.stopped)
    }
}

// MARK: - WordStressAnalyzerTests

final class WordStressAnalyzerTests: XCTestCase {

    private let analyzer = WordStressAnalyzer()

    func test_perWordRMS_segmentsByWordCount() {
        let env: [Float] = [0.9, 0.9, 0.1, 0.1, 0.5, 0.5]
        let rms = analyzer.perWordRMS(envelope: env, wordCount: 3)
        XCTAssertEqual(rms.count, 3)
        XCTAssertGreaterThan(rms[0], rms[1])
    }

    func test_loudestIndex_picksMaxAboveFloor() {
        let rms: [Float] = [0.3, 0.85, 0.4]
        XCTAssertEqual(analyzer.loudestIndex(perWordRMS: rms), 1)
    }

    func test_loudestIndex_allSilent_returnsMinusOne() {
        let rms: [Float] = [0.01, 0.02, 0.01]
        XCTAssertEqual(analyzer.loudestIndex(perWordRMS: rms), -1)
    }

    func test_didEmphasiseTarget_contrastRequired() {
        // Целевое слово чётко громче остальных → совпадение.
        XCTAssertTrue(analyzer.didEmphasiseTarget(perWordRMS: [0.9, 0.3, 0.3], targetIndex: 0))
        // Целевое слово не самое громкое → нет.
        XCTAssertFalse(analyzer.didEmphasiseTarget(perWordRMS: [0.3, 0.9, 0.3], targetIndex: 0))
        // Все одинаково громко (нет контраста) → нет.
        XCTAssertFalse(analyzer.didEmphasiseTarget(perWordRMS: [0.5, 0.5, 0.5], targetIndex: 0))
    }

    func test_normalisedHeights_peakIsOne() {
        let heights = analyzer.normalisedHeights(perWordRMS: [0.2, 0.4, 0.8])
        XCTAssertEqual(heights.count, 3)
        XCTAssertEqual(heights.max() ?? 0, 1.0, accuracy: 0.001)
        XCTAssertTrue(heights.allSatisfy { $0 >= 0.2 })
    }
}

// MARK: - VoiceColorsCorpusTests

final class VoiceColorsCorpusTests: XCTestCase {

    func test_targetContour_questionRisesInFinale() {
        let contour = VoiceColorsCorpus.targetContour(for: .question)
        let first = contour.first?.frequencyHz ?? 0
        let last = contour.last?.frequencyHz ?? 0
        XCTAssertGreaterThan(last, first, "Вопрос — восходящий финал")
    }

    func test_targetContour_calmDescends() {
        let contour = VoiceColorsCorpus.targetContour(for: .calm)
        let first = contour.first?.frequencyHz ?? 0
        let last = contour.last?.frequencyHz ?? 0
        XCTAssertGreaterThan(first, last, "Спокойно — нисходящий контур")
    }

    func test_buildSession_filtersByAge_nonEmptyForFive() {
        let session = VoiceColorsCorpus.buildSession(age: 5)
        XCTAssertFalse(session.isEmpty, "Сессия для 5 лет не должна быть пустой")
    }

    func test_buildSession_olderGetsAllModes() {
        let session = VoiceColorsCorpus.buildSession(age: 8)
        XCTAssertFalse(session.intonation.isEmpty)
        XCTAssertFalse(session.stress.isEmpty)
        XCTAssertFalse(session.emotion.isEmpty)
    }
}
