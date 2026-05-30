@testable import HappySpeech
import XCTest

// MARK: - KaraokePitchInteractorTests
//
// Full VIP. Microphone capture (AVAudioEngine tap) is not exercised on the
// simulator — those paths (startRecording/stopRecording/live-stream) require
// a real input node. We cover the deterministic, mic-independent logic:
//   - session bootstrap (corpus selection, presentStart)
//   - phrase advancement and end-of-session
//   - recordingState default
//   - the supporting ContourComparator metric + star thresholds
//   - the procedural KaraokePitchCorpus reference contours

@MainActor
final class KaraokePitchInteractorTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: KaraokePitchDisplayLogic {
        var startCount = 0
        var liveCount = 0
        var scoreCount = 0
        var lastStartVM: KaraokePitchModels.Start.ViewModel?
        var lastScoreVM: KaraokePitchModels.Score.ViewModel?

        func displayStart(viewModel: KaraokePitchModels.Start.ViewModel) async {
            startCount += 1
            lastStartVM = viewModel
        }

        func displayLiveSample(viewModel: KaraokePitchModels.LiveSample.ViewModel) async {
            liveCount += 1
        }

        func displayScore(viewModel: KaraokePitchModels.Score.ViewModel) async {
            scoreCount += 1
            lastScoreVM = viewModel
        }
    }

    private func makeSUT(
        sessionPhraseCount: Int = 5
    ) -> (KaraokePitchInteractor, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = KaraokePitchPresenter(displayLogic: spy)
        let sut = KaraokePitchInteractor(
            presenter: presenter,
            sessionPhraseCount: sessionPhraseCount
        )
        return (sut, spy)
    }

    // MARK: - startSession

    func test_startSession_presentsFirstPhrase() async {
        let (sut, spy) = makeSUT()
        await sut.startSession()
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertNotNil(spy.lastStartVM)
    }

    func test_startSession_totalPhrasesIsAtMostSessionCount() async {
        // The corpus may hold fewer phrases than requested (in the test
        // environment ProsodyCorpus seeds the 3-phrase fallback), so the
        // session length is min(corpusSize, requested). Use a small request
        // that is safely <= corpus size for an exact check, plus the
        // upper-bound invariant for a large request.
        let (small, smallSpy) = makeSUT(sessionPhraseCount: 2)
        await small.startSession()
        XCTAssertEqual(smallSpy.lastStartVM?.totalPhrases, 2)

        let (large, largeSpy) = makeSUT(sessionPhraseCount: 99)
        await large.startSession()
        let total = largeSpy.lastStartVM?.totalPhrases ?? 0
        XCTAssertGreaterThanOrEqual(total, 1)
        XCTAssertLessThanOrEqual(total, 99)
    }

    func test_startSession_phraseTextIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.startSession()
        XCTAssertFalse(spy.lastStartVM?.phraseText.isEmpty ?? true)
    }

    func test_startSession_accessibilityLabelDescribesIntonation() async {
        let (sut, spy) = makeSUT()
        await sut.startSession()
        let label = spy.lastStartVM?.accessibilityLabel ?? ""
        XCTAssertTrue(label.contains("Интонация"))
    }

    func test_startSession_currentIndexStartsAtZero() async {
        let (sut, spy) = makeSUT()
        await sut.startSession()
        XCTAssertEqual(spy.lastStartVM?.currentIndex, 0)
    }

    // MARK: - advanceToNext

    func test_advanceToNext_presentsNextPhrase() async {
        let (sut, spy) = makeSUT(sessionPhraseCount: 3)
        await sut.startSession()
        let advanced = await sut.advanceToNext()
        XCTAssertTrue(advanced)
        XCTAssertEqual(spy.startCount, 2)
    }

    func test_advanceToNext_returnsFalseAtEnd() async {
        let (sut, _) = makeSUT(sessionPhraseCount: 1)
        await sut.startSession()
        // Only one phrase → cannot advance.
        let advanced = await sut.advanceToNext()
        XCTAssertFalse(advanced)
    }

    func test_advanceToNext_walksThroughAllPhrases() async {
        let (sut, _) = makeSUT(sessionPhraseCount: 3)
        await sut.startSession()
        let first = await sut.advanceToNext()
        let second = await sut.advanceToNext()
        let third = await sut.advanceToNext()
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertFalse(third) // past the end
    }

    // MARK: - recordingState

    func test_recordingState_defaultsToFalse() async {
        let (sut, _) = makeSUT()
        await sut.startSession()
        XCTAssertFalse(sut.recordingState())
    }

    // MARK: - ContourComparator

    func test_comparator_identicalContour_highSimilarity() {
        let comparator = ContourComparator()
        let phrase = KaraokePitchCorpus.phrases.first
            ?? KaraokePhrase(id: "x", text: "т", intonation: "statement", intonationSymbol: "minus")
        let model = KaraokePitchCorpus.modelContour(for: phrase)
        let similarity = comparator.similarity(model: model, live: model)
        XCTAssertGreaterThan(similarity, 0.9)
    }

    func test_comparator_emptyLive_zeroSimilarity() {
        let comparator = ContourComparator()
        let model = KaraokePitchCorpus.makeStatementProbe()
        XCTAssertEqual(comparator.similarity(model: model, live: []), 0)
    }

    func test_comparator_stars_thresholds() {
        let comparator = ContourComparator()
        XCTAssertEqual(comparator.stars(for: 0.90), 3)
        XCTAssertEqual(comparator.stars(for: 0.70), 2)
        XCTAssertEqual(comparator.stars(for: 0.50), 1)
        XCTAssertEqual(comparator.stars(for: 0.10), 0)
    }

    // MARK: - Corpus reference contours

    func test_corpus_questionContour_risesAtEnd() {
        let phrase = KaraokePhrase(id: "q", text: "Где?",
                                   intonation: "question", intonationSymbol: "q")
        let contour = KaraokePitchCorpus.modelContour(for: phrase)
        let firstFreq = contour.first?.frequencyHz ?? 0
        let lastFreq = contour.last?.frequencyHz ?? 0
        XCTAssertGreaterThan(lastFreq, firstFreq)
    }

    func test_corpus_statementContour_fallsToEnd() {
        let phrase = KaraokePhrase(id: "s", text: "Дом.",
                                   intonation: "statement", intonationSymbol: "minus")
        let contour = KaraokePitchCorpus.modelContour(for: phrase)
        let firstFreq = contour.first?.frequencyHz ?? 0
        let lastFreq = contour.last?.frequencyHz ?? 0
        XCTAssertLessThan(lastFreq, firstFreq)
    }

    func test_corpus_contour_has21Points() {
        let phrase = KaraokePhrase(id: "e", text: "Ура!",
                                   intonation: "exclamation", intonationSymbol: "e")
        XCTAssertEqual(KaraokePitchCorpus.modelContour(for: phrase).count, 21)
    }
}

// MARK: - Test helper

private extension KaraokePitchCorpus {
    /// A statement reference contour for tests that need a non-empty model.
    static func makeStatementProbe() -> [PitchPoint] {
        modelContour(for: KaraokePhrase(
            id: "probe", text: "Дом.",
            intonation: "statement", intonationSymbol: "minus"
        ))
    }
}
