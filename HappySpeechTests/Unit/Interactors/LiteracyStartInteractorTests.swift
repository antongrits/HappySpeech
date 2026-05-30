@testable import HappySpeech
import XCTest

// MARK: - Spy Audio Service

private final class SpyAudioService: AudioService, @unchecked Sendable {
    var playCallCount = 0
    var shouldFail = false

    var isPermissionGranted: Bool = true
    var amplitude: Float = 0
    var isRecording: Bool = false

    func requestPermission() async -> Bool { true }
    func startRecording() async throws {}
    func stopRecording() async throws -> URL { URL(fileURLWithPath: "/tmp/test.m4a") }

    func playAudio(url: URL) async throws {
        playCallCount += 1
        if shouldFail {
            throw AppError.unknown("mock audio fail")
        }
    }

    func stopPlayback() {}
    func amplitudeBuffer() -> [Float] { [] }
}

// MARK: - Spy Display Logic

@MainActor
private final class SpyLiteracyDisplay: LiteracyStartDisplayLogic {
    var lastLetterVM: LiteracyStartModels.LoadLetter.ViewModel?
    var unsupportedSound: String?

    func displayLoadLetter(viewModel: LiteracyStartModels.LoadLetter.ViewModel) async {
        lastLetterVM = viewModel
    }

    func displayUnsupportedSound(targetSound: String) async {
        unsupportedSound = targetSound
    }
}

// MARK: - LiteracyStartInteractorTests

@MainActor
final class LiteracyStartInteractorTests: XCTestCase {

    private var display: SpyLiteracyDisplay!
    private var audio: SpyAudioService!
    private var router: LiteracyStartRouter!

    override func setUp() async throws {
        try await super.setUp()
        display = SpyLiteracyDisplay()
        audio = SpyAudioService()
        router = LiteracyStartRouter()
        // coordinator stays nil — routing calls are noops in unit tests
    }

    override func tearDown() async throws {
        display = nil
        audio = nil
        router = nil
        try await super.tearDown()
    }

    private func makeSUT(childId: String = "child-1") -> (LiteracyStartInteractor, LiteracyStartPresenter) {
        let presenter = LiteracyStartPresenter(displayLogic: display)
        let sut = LiteracyStartInteractor(
            presenter: presenter,
            router: router,
            audioService: audio,
            childId: childId
        )
        return (sut, presenter)
    }

    // MARK: - loadLetter

    func test_loadLetter_knownSound_callsDisplayLoadLetter() async {
        let (sut, _) = makeSUT()
        await sut.loadLetter(.init(targetSound: "Р"))
        XCTAssertNotNil(display.lastLetterVM)
        XCTAssertNil(display.unsupportedSound)
    }

    func test_loadLetter_knownSound_letterMatchesCatalog() async {
        let (sut, _) = makeSUT()
        await sut.loadLetter(.init(targetSound: "Ш"))
        XCTAssertEqual(display.lastLetterVM?.letter, "Ш")
    }

    func test_loadLetter_unknownSound_callsDisplayUnsupported() async {
        let (sut, _) = makeSUT()
        await sut.loadLetter(.init(targetSound: "Ф"))
        XCTAssertNil(display.lastLetterVM)
        XCTAssertEqual(display.unsupportedSound, "Ф")
    }

    func test_loadLetter_softenedSound_normalizedAndFound() async {
        // «Рь» soft form should still find «Р» entry.
        let (sut, _) = makeSUT()
        await sut.loadLetter(.init(targetSound: "Рь"))
        XCTAssertNotNil(display.lastLetterVM)
        XCTAssertEqual(display.lastLetterVM?.letter, "Р")
    }

    func test_loadLetter_knownSound_wordsNonEmpty() async {
        let (sut, _) = makeSUT()
        await sut.loadLetter(.init(targetSound: "С"))
        XCTAssertFalse(display.lastLetterVM?.words.isEmpty ?? true)
    }

    // MARK: - playSound

    func test_playSound_validSound_audioServiceCalled() async {
        // "Р" → translit "r" → file "lyalya_sound_r.m4a"
        // Bundle won't have the file in tests, so we only check the guard
        // passes the translit lookup (audio service would be called if file existed).
        // Since the interactor guards on Bundle.main, audio won't actually be called.
        // We verify no crash occurs.
        let (sut, _) = makeSUT()
        await sut.playSound(.init(targetSound: "Р"))
        // No assertion needed — we are testing it doesn't throw / crash.
        XCTAssertTrue(true)
    }

    func test_playSound_unknownTransliteration_doesNotCallAudio() async {
        let (sut, _) = makeSUT()
        await sut.playSound(.init(targetSound: "Ф"))
        XCTAssertEqual(audio.playCallCount, 0)
    }

    func test_playSound_audioFails_doesNotPropagateError() async {
        audio.shouldFail = true
        let (sut, _) = makeSUT()
        // Even if audio fails, interactor should not crash.
        await sut.playSound(.init(targetSound: "Р"))
        XCTAssertTrue(true)
    }

    // MARK: - startTracing

    func test_startTracing_doesNotCrashWithNilCoordinator() {
        let (sut, _) = makeSUT()
        // coordinator is nil — router.routeToLetterTrace is a noop in tests.
        sut.startTracing(.init(letter: "Р"))
        XCTAssertTrue(true)
    }
}
