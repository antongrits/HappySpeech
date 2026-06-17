@testable import HappySpeech
import XCTest

// MARK: - StoryPicturesInteractorTests
//
// Проверяет бизнес-логику «Рассказа по серии картинок» (связная речь):
//   • упорядочивание кадров (drag в слоты) и валидацию порядка;
//   • матчинг смысловых звеньев из ASR-транскрипта (устойчивый к словоформам);
//   • расчёт радар-арки полноты (завязка/действие/развязка);
//   • запись пословного outcome и SM-2 сессии в планировщик.
// ASR/Audio замоканы (детерминированный транскрипт без микрофона).

@MainActor
final class StoryPicturesInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class SpyPresenter: StoryPicturesPresentationLogic {
        var starts: [StoryPicturesModels.Start.Response] = []
        var placements: [StoryPicturesModels.PlaceFrame.Response] = []
        var confirms: [StoryPicturesModels.ConfirmOrder.Response] = []
        var tellFrames: [StoryPicturesModels.LoadTellFrame.Response] = []
        var recordStates: [StoryPicturesModels.Recording.StateResponse] = []
        var transcribes: [StoryPicturesModels.Transcribe.Response] = []
        var movies: [StoryPicturesModels.BuildMovie.Response] = []
        var playingLog: [Bool] = []

        func presentStart(_ r: StoryPicturesModels.Start.Response) { starts.append(r) }
        func presentPlaceFrame(_ r: StoryPicturesModels.PlaceFrame.Response, series: PictureSeries) { placements.append(r) }
        func presentConfirmOrder(_ r: StoryPicturesModels.ConfirmOrder.Response) { confirms.append(r) }
        func presentTellFrame(_ r: StoryPicturesModels.LoadTellFrame.Response) { tellFrames.append(r) }
        func presentRecordingState(_ r: StoryPicturesModels.Recording.StateResponse) { recordStates.append(r) }
        func presentTranscribe(_ r: StoryPicturesModels.Transcribe.Response, frame: PictureFrame) { transcribes.append(r) }
        func presentMovie(_ r: StoryPicturesModels.BuildMovie.Response) { movies.append(r) }
        func presentPlaying(_ isPlaying: Bool) { playingLog.append(isPlaying) }
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

    // MARK: - Mock ASR (scripted transcript)

    private final class MockASRService: ASRService, @unchecked Sendable {
        var scriptedTranscript: String = ""
        var isReady: Bool = true
        func transcribe(url: URL) async throws -> ASRResult {
            ASRResult(transcript: scriptedTranscript, confidence: 0.9, wordTimestamps: [])
        }
        func transcribe(url: URL, expectedWord: String?, childAge: Int?) async throws -> ASRResult {
            ASRResult(transcript: scriptedTranscript, confidence: 0.9, wordTimestamps: [])
        }
        func loadModel() async throws {}
        func loadModel(tier: ASRTier) async throws {}
    }

    // MARK: - Mock Audio (no-op recording)

    private final class MockAudioService: AudioService, @unchecked Sendable {
        var isPermissionGranted: Bool = true
        var amplitude: Float = 0.5
        var isRecording: Bool = false
        func requestPermission() async -> Bool { true }
        func startRecording() async throws { isRecording = true }
        func stopRecording() async throws -> URL {
            isRecording = false
            return URL(fileURLWithPath: "/tmp/story_test.m4a")
        }
        func playAudio(url: URL) async throws {}
        func stopPlayback() {}
        func amplitudeBuffer() -> [Float] { [] }
    }

    // MARK: - Fixtures

    /// Тестовая серия из 3 кадров (завязка/действие/развязка) с ключами.
    private func threeFrameSeries() -> PictureSeries {
        func link(_ id: String, _ role: StoryLinkRole, _ q: String, _ hint: String, _ kw: [String]) -> StoryLink {
            StoryLink(id: id, role: role, question: q, answerHint: hint, keywords: kw)
        }
        return PictureSeries(
            id: "test_series",
            title: "Тест",
            minAge: 6, maxAge: 7, scene: .generic,
            frames: [
                PictureFrame(id: "f1", order: 1, scene: .generic, caption: "Кадр 1", imageAsset: nil,
                    links: [link("l1_who", .setup, "Кто?", "ёжик", ["ёжик", "еж"]),
                            link("l1_see", .setup, "Что увидел?", "яблоки", ["яблок"])]),
                PictureFrame(id: "f2", order: 2, scene: .generic, caption: "Кадр 2", imageAsset: nil,
                    links: [link("l2_do", .action, "Что делает?", "трясёт", ["тряс", "качал"])]),
                PictureFrame(id: "f3", order: 3, scene: .generic, caption: "Кадр 3", imageAsset: nil,
                    links: [link("l3_end", .resolution, "Чем закончилось?", "домой", ["домой", "норк"])])
            ]
        )
    }

    private func makeSUT(
        series: PictureSeries? = nil,
        asr: MockASRService = MockASRService(),
        planner: PlannerSpy = PlannerSpy()
    ) -> (StoryPicturesInteractor, SpyPresenter, MockASRService, PlannerSpy) {
        let presenter = SpyPresenter()
        let interactor = StoryPicturesInteractor(
            childId: "child-1",
            childAge: 6,
            builder: StoryPicturesBuilder(),
            audioService: MockAudioService(),
            asrService: asr,
            adaptivePlanner: planner,
            seededSeries: series ?? threeFrameSeries(),
            shuffleSeed: 42
        )
        interactor.presenter = presenter
        return (interactor, presenter, asr, planner)
    }

    // MARK: - Ordering

    func testStartShufflesAllFrames() async {
        let (interactor, presenter, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))

        XCTAssertEqual(presenter.starts.count, 1)
        let start = presenter.starts[0]
        XCTAssertEqual(start.shuffledFrameIds.count, 3)
        XCTAssertEqual(Set(start.shuffledFrameIds), Set(["f1", "f2", "f3"]))
    }

    func testCorrectOrderIsDetected() async {
        let (interactor, presenter, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))

        interactor.placeFrame(.init(frameId: "f1", slotIndex: 0))
        interactor.placeFrame(.init(frameId: "f2", slotIndex: 1))
        interactor.placeFrame(.init(frameId: "f3", slotIndex: 2))

        let last = presenter.placements.last
        XCTAssertEqual(last?.isFilled, true)
        XCTAssertEqual(last?.isOrderCorrect, true)
    }

    func testWrongOrderIsRejected() async {
        let (interactor, presenter, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))

        interactor.placeFrame(.init(frameId: "f3", slotIndex: 0))
        interactor.placeFrame(.init(frameId: "f2", slotIndex: 1))
        interactor.placeFrame(.init(frameId: "f1", slotIndex: 2))

        let last = presenter.placements.last
        XCTAssertEqual(last?.isFilled, true)
        XCTAssertEqual(last?.isOrderCorrect, false)
    }

    func testRemoveFrameReturnsToTray() async {
        let (interactor, presenter, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))

        interactor.placeFrame(.init(frameId: "f1", slotIndex: 0))
        interactor.removeFrame(slotIndex: 0)

        let last = presenter.placements.last
        XCTAssertTrue(last?.trayFrameIds.contains("f1") ?? false)
        XCTAssertNil(last?.placedFrameIds[0] ?? nil)
    }

    func testConfirmOrderOnlyWhenCorrect() async {
        let (interactor, presenter, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))

        // Неверный порядок — confirm не должен сработать.
        interactor.placeFrame(.init(frameId: "f2", slotIndex: 0))
        interactor.placeFrame(.init(frameId: "f1", slotIndex: 1))
        interactor.placeFrame(.init(frameId: "f3", slotIndex: 2))
        interactor.confirmOrder()
        XCTAssertTrue(presenter.confirms.isEmpty, "Confirm не должен срабатывать при неверном порядке")

        // Исправим первые два слота.
        interactor.removeFrame(slotIndex: 0)
        interactor.removeFrame(slotIndex: 1)
        interactor.placeFrame(.init(frameId: "f1", slotIndex: 0))
        interactor.placeFrame(.init(frameId: "f2", slotIndex: 1))
        interactor.confirmOrder()
        XCTAssertEqual(presenter.confirms.count, 1)
        XCTAssertEqual(presenter.confirms[0].orderedFrames.map { $0.id }, ["f1", "f2", "f3"])
    }

    // MARK: - Semantic link matching

    func testTranscriptMarksNamedLinks() async {
        let (interactor, _, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))
        let frame = threeFrameSeries().frames[0]

        await interactor.applyTranscript("Ёжик увидел красные яблоки на дереве", for: frame)

        XCTAssertTrue(interactor.coveredLinks.contains("l1_who"))
        XCTAssertTrue(interactor.coveredLinks.contains("l1_see"))
    }

    func testSemanticMatchToleratesWordForms() async {
        let (interactor, _, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))
        let frame = threeFrameSeries().frames[1]   // "тряс"/"качал"

        // Словоформа «потряс» содержит корень «тряс».
        await interactor.applyTranscript("Он потряс яблоньку", for: frame)
        XCTAssertTrue(interactor.coveredLinks.contains("l2_do"))
    }

    func testEmptyTranscriptCoversNothing() async {
        let (interactor, presenter, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))
        let frame = threeFrameSeries().frames[0]

        await interactor.applyTranscript("", for: frame)
        XCTAssertTrue(interactor.coveredLinks.isEmpty)
        XCTAssertEqual(presenter.transcribes.last?.coveredLinkIds.isEmpty, true)
    }

    // MARK: - Arc completeness

    func testFullStoryYieldsCompleteArc() async {
        let (interactor, presenter, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))
        let frames = threeFrameSeries().frames

        await interactor.applyTranscript("Ёжик увидел яблоки", for: frames[0])
        await interactor.applyTranscript("Ёжик трясёт дерево", for: frames[1])
        await interactor.applyTranscript("Понёс домой в норку", for: frames[2])
        await interactor.buildMovie()

        let movie = presenter.movies.last
        XCTAssertNotNil(movie)
        XCTAssertEqual(movie?.arc.completeness ?? 0, 1.0, accuracy: 0.001)
        XCTAssertNil(movie?.arc.firstIncompleteRole)
    }

    func testMissingResolutionLeavesArcIncomplete() async {
        let (interactor, presenter, _, _) = makeSUT()
        await interactor.start(.init(childId: "child-1"))
        let frames = threeFrameSeries().frames

        await interactor.applyTranscript("Ёжик увидел яблоки", for: frames[0])
        await interactor.applyTranscript("Ёжик трясёт дерево", for: frames[1])
        // Развязку (frames[2]) не рассказываем.
        await interactor.buildMovie()

        let movie = presenter.movies.last
        XCTAssertNotNil(movie)
        XCTAssertLessThan(movie?.arc.completeness ?? 1, 1.0)
        XCTAssertEqual(movie?.arc.firstIncompleteRole, .resolution)
    }

    // MARK: - Persistence

    func testFrameOutcomeRecordedPerNamedFrame() async {
        let planner = PlannerSpy()
        let (interactor, _, _, _) = makeSUT(planner: planner)
        await interactor.start(.init(childId: "child-1"))
        let frames = threeFrameSeries().frames

        await interactor.applyTranscript("Ёжик увидел яблоки", for: frames[0])  // correct
        await interactor.applyTranscript("", for: frames[1])                    // empty → incorrect

        XCTAssertEqual(planner.itemOutcomes.count, 2)
        XCTAssertEqual(planner.itemOutcomes[0].itemId, "f1")
        XCTAssertTrue(planner.itemOutcomes[0].correct)
        XCTAssertFalse(planner.itemOutcomes[1].correct)
    }

    func testSessionResultRecordedOnBuildMovie() async {
        let planner = PlannerSpy()
        let (interactor, _, _, _) = makeSUT(planner: planner)
        await interactor.start(.init(childId: "child-1"))
        let frames = threeFrameSeries().frames

        await interactor.applyTranscript("Ёжик увидел яблоки", for: frames[0])
        await interactor.applyTranscript("Ёжик трясёт дерево", for: frames[1])
        await interactor.applyTranscript("Понёс домой", for: frames[2])
        await interactor.buildMovie()

        XCTAssertEqual(planner.sessionResults.count, 1)
        XCTAssertEqual(planner.sessionResults[0].sound, "связная-речь")
        // Полный рассказ → высокое качество SM-2.
        XCTAssertGreaterThanOrEqual(planner.sessionResults[0].quality.rawValue, SM2Quality.correct.rawValue)
    }

    // MARK: - Builder pure logic

    func testBuilderAgeFrameLimits() {
        XCTAssertEqual(StoryPicturesBuilder.maxFrames(forAge: 5), 3)
        XCTAssertEqual(StoryPicturesBuilder.maxFrames(forAge: 6), 4)
        XCTAssertEqual(StoryPicturesBuilder.maxFrames(forAge: 8), 6)
    }

    func testBuilderShuffleIsDeterministicWithSeed() {
        let builder = StoryPicturesBuilder()
        let series = threeFrameSeries()
        let a = builder.shuffledFrameIds(for: series, seed: 7)
        let b = builder.shuffledFrameIds(for: series, seed: 7)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, series.orderedFrames.map { $0.id }, "Перемешивание не должно совпадать с исходным порядком")
    }

    func testBuilderNormalizeHandlesYo() {
        XCTAssertEqual(StoryPicturesBuilder.normalize("Ёжик ПОБЕЖАЛ!"), "ежик побежал ")
    }

    func testBuilderPicksSeriesWithinAgeLimit() {
        let builder = StoryPicturesBuilder()
        let small = makeSeries(id: "small", frames: 2)
        let big = makeSeries(id: "big", frames: 6)
        // Для 5 лет лимит = 3 кадра → выбирается серия из 2 кадров.
        let picked = builder.pickSeries(from: [small, big], age: 5)
        XCTAssertEqual(picked?.id, "small")
    }

    // MARK: - Helpers

    private func makeSeries(id: String, frames: Int) -> PictureSeries {
        let f = (1...frames).map { i in
            PictureFrame(
                id: "\(id)_\(i)", order: i, scene: .generic, caption: "k\(i)", imageAsset: nil,
                links: [StoryLink(id: "\(id)_l\(i)", role: .action, question: "?", answerHint: "x", keywords: ["x"])]
            )
        }
        return PictureSeries(id: id, title: id, minAge: 5, maxAge: 8, scene: .generic, frames: f)
    }
}
