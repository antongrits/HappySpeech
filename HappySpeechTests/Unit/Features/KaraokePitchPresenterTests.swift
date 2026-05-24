@testable import HappySpeech
import XCTest

// MARK: - KaraokePitchPresenterTests

@MainActor
final class KaraokePitchPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: KaraokePitchDisplayLogic {
        var lastStartVM: KaraokePitchModels.Start.ViewModel?
        var lastLiveSampleVM: KaraokePitchModels.LiveSample.ViewModel?
        var lastScoreVM: KaraokePitchModels.Score.ViewModel?

        func displayStart(viewModel: KaraokePitchModels.Start.ViewModel) async {
            lastStartVM = viewModel
        }

        func displayLiveSample(viewModel: KaraokePitchModels.LiveSample.ViewModel) async {
            lastLiveSampleVM = viewModel
        }

        func displayScore(viewModel: KaraokePitchModels.Score.ViewModel) async {
            lastScoreVM = viewModel
        }
    }

    private func makeSUT() -> (KaraokePitchPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = KaraokePitchPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makePhrase(
        id: String = "p-1",
        text: String = "Мама мыла раму",
        intonation: String = "statement",
        intonationSymbol: String = "waveform"
    ) -> KaraokePhrase {
        KaraokePhrase(id: id, text: text, intonation: intonation, intonationSymbol: intonationSymbol)
    }

    private func makePitchPoints(count: Int = 5) -> [PitchPoint] {
        (0..<count).map { i in
            PitchPoint(time: Double(i) / Double(count), frequencyHz: 200 + Double(i) * 10)
        }
    }

    private func makeStartResponse(
        phrase: KaraokePhrase? = nil,
        totalPhrases: Int = 10
    ) -> KaraokePitchModels.Start.Response {
        KaraokePitchModels.Start.Response(
            phrase: phrase ?? makePhrase(),
            modelContour: makePitchPoints(),
            totalPhrases: totalPhrases
        )
    }

    // MARK: - presentStart

    func test_presentStart_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentStart(response: makeStartResponse())
        XCTAssertNotNil(spy.lastStartVM)
    }

    func test_presentStart_phraseTextPassedThrough() async {
        let (sut, spy) = makeSUT()
        let phrase = makePhrase(text: "Шла Саша по шоссе")
        await sut.presentStart(response: makeStartResponse(phrase: phrase))
        XCTAssertEqual(spy.lastStartVM?.phraseText, "Шла Саша по шоссе")
    }

    func test_presentStart_intonationSymbolPassedThrough() async {
        let (sut, spy) = makeSUT()
        let phrase = makePhrase(intonationSymbol: "questionmark")
        await sut.presentStart(response: makeStartResponse(phrase: phrase))
        XCTAssertEqual(spy.lastStartVM?.intonationSymbol, "questionmark")
    }

    func test_presentStart_modelContourPassedThrough() async {
        let (sut, spy) = makeSUT()
        let points = makePitchPoints(count: 8)
        let response = KaraokePitchModels.Start.Response(
            phrase: makePhrase(),
            modelContour: points,
            totalPhrases: 5
        )
        await sut.presentStart(response: response)
        XCTAssertEqual(spy.lastStartVM?.modelContour.count, 8)
    }

    func test_presentStart_currentIndexIsZero() async {
        let (sut, spy) = makeSUT()
        await sut.presentStart(response: makeStartResponse())
        XCTAssertEqual(spy.lastStartVM?.currentIndex, 0)
    }

    func test_presentStart_totalPhrasesPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentStart(response: makeStartResponse(totalPhrases: 20))
        XCTAssertEqual(spy.lastStartVM?.totalPhrases, 20)
    }

    func test_presentStart_statementIntonation_a11yContainsPhrase() async {
        let (sut, spy) = makeSUT()
        let phrase = makePhrase(text: "Мама мыла раму", intonation: "statement")
        await sut.presentStart(response: makeStartResponse(phrase: phrase))
        let a11y = spy.lastStartVM?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("Мама мыла раму"))
    }

    func test_presentStart_questionIntonation_a11yContainsVopros() async {
        let (sut, spy) = makeSUT()
        let phrase = makePhrase(intonation: "question")
        await sut.presentStart(response: makeStartResponse(phrase: phrase))
        let a11y = spy.lastStartVM?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("вопрос"))
    }

    func test_presentStart_exclamationIntonation_a11yContainsVosklit() async {
        let (sut, spy) = makeSUT()
        let phrase = makePhrase(intonation: "exclamation")
        await sut.presentStart(response: makeStartResponse(phrase: phrase))
        let a11y = spy.lastStartVM?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("восклицание"))
    }

    func test_presentStart_unknownIntonation_a11yContainsPovestvovanie() async {
        let (sut, spy) = makeSUT()
        let phrase = makePhrase(intonation: "unknown_type")
        await sut.presentStart(response: makeStartResponse(phrase: phrase))
        let a11y = spy.lastStartVM?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("повествование"))
    }

    // MARK: - presentLiveSample

    func test_presentLiveSample_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.LiveSample.Response(
            liveContour: makePitchPoints(),
            amplitude: 0.5
        )
        await sut.presentLiveSample(response: response)
        XCTAssertNotNil(spy.lastLiveSampleVM)
    }

    func test_presentLiveSample_amplitudeNormalisedClamped_over1() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.LiveSample.Response(
            liveContour: [],
            amplitude: 2.5
        )
        await sut.presentLiveSample(response: response)
        XCTAssertEqual(spy.lastLiveSampleVM?.amplitudeNormalised ?? 0, 1.0, accuracy: 0.001)
    }

    func test_presentLiveSample_amplitudeNormalisedClamped_negative() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.LiveSample.Response(
            liveContour: [],
            amplitude: -0.5
        )
        await sut.presentLiveSample(response: response)
        XCTAssertEqual(spy.lastLiveSampleVM?.amplitudeNormalised ?? 1, 0.0, accuracy: 0.001)
    }

    func test_presentLiveSample_liveContourPassedThrough() async {
        let (sut, spy) = makeSUT()
        let points = makePitchPoints(count: 12)
        let response = KaraokePitchModels.LiveSample.Response(liveContour: points, amplitude: 0.3)
        await sut.presentLiveSample(response: response)
        XCTAssertEqual(spy.lastLiveSampleVM?.liveContour.count, 12)
    }

    // MARK: - presentScore

    func test_presentScore_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.Score.Response(
            phrase: makePhrase(),
            modelContour: makePitchPoints(),
            liveContour: makePitchPoints(),
            similarity: 0.85,
            starsEarned: 3
        )
        await sut.presentScore(response: response)
        XCTAssertNotNil(spy.lastScoreVM)
    }

    func test_presentScore_similarityPercent_roundsCorrectly() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.Score.Response(
            phrase: makePhrase(),
            modelContour: [],
            liveContour: [],
            similarity: 0.856,
            starsEarned: 3
        )
        await sut.presentScore(response: response)
        XCTAssertEqual(spy.lastScoreVM?.similarityPercent, 86)
    }

    func test_presentScore_threeStars_feedbackIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.Score.Response(
            phrase: makePhrase(), modelContour: [], liveContour: [],
            similarity: 0.95, starsEarned: 3
        )
        await sut.presentScore(response: response)
        XCTAssertFalse(spy.lastScoreVM?.feedbackMessage.isEmpty ?? true)
    }

    func test_presentScore_twoStars_feedbackIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.Score.Response(
            phrase: makePhrase(), modelContour: [], liveContour: [],
            similarity: 0.7, starsEarned: 2
        )
        await sut.presentScore(response: response)
        XCTAssertFalse(spy.lastScoreVM?.feedbackMessage.isEmpty ?? true)
    }

    func test_presentScore_oneStar_feedbackIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.Score.Response(
            phrase: makePhrase(), modelContour: [], liveContour: [],
            similarity: 0.4, starsEarned: 1
        )
        await sut.presentScore(response: response)
        XCTAssertFalse(spy.lastScoreVM?.feedbackMessage.isEmpty ?? true)
    }

    func test_presentScore_zeroStars_feedbackIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.Score.Response(
            phrase: makePhrase(), modelContour: [], liveContour: [],
            similarity: 0.1, starsEarned: 0
        )
        await sut.presentScore(response: response)
        XCTAssertFalse(spy.lastScoreVM?.feedbackMessage.isEmpty ?? true)
    }

    func test_presentScore_phraseTextPassedThrough() async {
        let (sut, spy) = makeSUT()
        let phrase = makePhrase(text: "Жук жужжал на жёлтом листе")
        let response = KaraokePitchModels.Score.Response(
            phrase: phrase, modelContour: [], liveContour: [],
            similarity: 0.5, starsEarned: 2
        )
        await sut.presentScore(response: response)
        XCTAssertEqual(spy.lastScoreVM?.phraseText, "Жук жужжал на жёлтом листе")
    }

    func test_presentScore_a11yLabelContainsPercentAndStars() async {
        let (sut, spy) = makeSUT()
        let response = KaraokePitchModels.Score.Response(
            phrase: makePhrase(), modelContour: [], liveContour: [],
            similarity: 0.75, starsEarned: 2
        )
        await sut.presentScore(response: response)
        let a11y = spy.lastScoreVM?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("75") || a11y.contains("2"))
    }
}
