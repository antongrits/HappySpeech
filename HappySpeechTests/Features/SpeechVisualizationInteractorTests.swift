@testable import HappySpeech
import XCTest

// MARK: - Spy Presenter

@MainActor
private final class SpySpeechVisualizationPresenter: SpeechVisualizationPresentationLogic, @unchecked Sendable {
    var loadCallCount = 0
    var setModeCallCount = 0
    var scoreCallCount = 0

    var lastLoad: SpeechVisualizationModels.Load.Response?
    var lastMode: VisualizationMode?
    var lastScore: SpeechVisualizationModels.Score.Response?
    var lastScoreSyllables: [KaraokeSyllable] = []

    func presentLoad(response: SpeechVisualizationModels.Load.Response) async {
        loadCallCount += 1
        lastLoad = response
    }
    func presentSetMode(mode: VisualizationMode) async {
        setModeCallCount += 1
        lastMode = mode
    }
    func presentScore(
        response: SpeechVisualizationModels.Score.Response,
        syllables: [KaraokeSyllable]
    ) async {
        scoreCallCount += 1
        lastScore = response
        lastScoreSyllables = syllables
    }
}

// MARK: - Tests

@MainActor
final class SpeechVisualizationInteractorTests: XCTestCase {

    private func makeSUT() -> (SpeechVisualizationInteractor, SpySpeechVisualizationPresenter) {
        let sut = SpeechVisualizationInteractor()
        let spy = SpySpeechVisualizationPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    // MARK: - load

    func test_load_buildsSyllables() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "корова", targetSound: "Р"))
        XCTAssertEqual(spy.loadCallCount, 1)
        XCTAssertEqual(spy.lastLoad?.word, "корова")
        XCTAssertEqual(spy.lastLoad?.syllables.count, 3, "ко-ро-ва")
    }

    func test_load_totalDurationMatchesSyllableCount() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "мама", targetSound: "М"))
        let count = spy.lastLoad?.syllables.count ?? 0
        let expected = Double(count) * 0.45
        XCTAssertEqual(spy.lastLoad?.totalDuration ?? -1, expected, accuracy: 0.001)
    }

    func test_load_syllablesHaveSequentialOffsets() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "собака", targetSound: "С"))
        let syllables = spy.lastLoad?.syllables ?? []
        for (index, syllable) in syllables.enumerated() {
            XCTAssertEqual(syllable.startOffset, Double(index) * 0.45, accuracy: 0.001)
        }
    }

    func test_load_syllableIdsAreUnique() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "малина", targetSound: "Л"))
        let ids = (spy.lastLoad?.syllables ?? []).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - setMode

    func test_setMode_practiceForwarded() async {
        let (sut, spy) = makeSUT()
        await sut.setMode(request: .init(mode: .practice))
        XCTAssertEqual(spy.setModeCallCount, 1)
        XCTAssertEqual(spy.lastMode, .practice)
    }

    func test_setMode_listenForwarded() async {
        let (sut, spy) = makeSUT()
        await sut.setMode(request: .init(mode: .listen))
        XCTAssertEqual(spy.lastMode, .listen)
    }

    // MARK: - computeScore

    func test_computeScore_withoutLoad_ignored() async {
        let (sut, spy) = makeSUT()
        await sut.computeScore(request: .init(attemptDurationSeconds: 1.0))
        XCTAssertEqual(spy.scoreCallCount, 0, "Без загруженного слова scoring пропускается")
    }

    func test_computeScore_afterLoad_emitsScore() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "рыба", targetSound: "Р"))
        await sut.computeScore(request: .init(attemptDurationSeconds: 0.9))
        XCTAssertEqual(spy.scoreCallCount, 1)
        let perSyllable = spy.lastScore?.perSyllableAccuracy ?? []
        XCTAssertEqual(perSyllable.count, spy.lastLoad?.syllables.count)
    }

    func test_computeScore_accuracyInRange() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "молоко", targetSound: "Л"))
        await sut.computeScore(request: .init(attemptDurationSeconds: 1.35))
        for accuracy in spy.lastScore?.perSyllableAccuracy ?? [] {
            XCTAssertGreaterThanOrEqual(accuracy, 0.0)
            XCTAssertLessThanOrEqual(accuracy, 1.0)
        }
        let overall = spy.lastScore?.overallAccuracy ?? -1
        XCTAssertGreaterThanOrEqual(overall, 0.0)
        XCTAssertLessThanOrEqual(overall, 1.0)
    }

    func test_computeScore_perfectDuration_highAccuracy() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "каша", targetSound: "Ш"))
        let expected = Double(spy.lastLoad?.syllables.count ?? 2) * 0.45
        await sut.computeScore(request: .init(attemptDurationSeconds: expected))
        XCTAssertGreaterThan(spy.lastScore?.overallAccuracy ?? 0, 0.7)
    }

    func test_computeScore_zeroDuration_clampedNotCrash() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "дом", targetSound: "Д"))
        await sut.computeScore(request: .init(attemptDurationSeconds: 0))
        XCTAssertEqual(spy.scoreCallCount, 1)
    }

    func test_computeScore_overallIsAverageOfSyllables() async {
        let (sut, spy) = makeSUT()
        await sut.load(request: .init(word: "корова", targetSound: "Р"))
        await sut.computeScore(request: .init(attemptDurationSeconds: 1.0))
        let perSyllable = spy.lastScore?.perSyllableAccuracy ?? []
        let computed = perSyllable.reduce(0, +) / Double(perSyllable.count)
        XCTAssertEqual(spy.lastScore?.overallAccuracy ?? -1, computed, accuracy: 0.0001)
    }

    // MARK: - splitToSyllables (pure helper)

    func test_splitToSyllables_singleSyllableWord() {
        let result = SpeechVisualizationInteractor.splitToSyllables(word: "стол")
        XCTAssertEqual(result, ["стол"])
    }

    func test_splitToSyllables_twoSyllables() {
        let result = SpeechVisualizationInteractor.splitToSyllables(word: "лес")
        XCTAssertEqual(result, ["лес"])
    }

    func test_splitToSyllables_threeSyllables() {
        let result = SpeechVisualizationInteractor.splitToSyllables(word: "корова")
        XCTAssertEqual(result, ["ко", "ро", "ва"])
    }

    func test_splitToSyllables_trailingConsonantsAttachToLast() {
        let result = SpeechVisualizationInteractor.splitToSyllables(word: "обезьян")
        XCTAssertEqual(result.joined(), "обезьян")
        XCTAssertTrue(result.last?.hasSuffix("н") ?? false)
    }

    func test_splitToSyllables_noVowels_returnsWholeWord() {
        let result = SpeechVisualizationInteractor.splitToSyllables(word: "пффт")
        XCTAssertEqual(result, ["пффт"])
    }

    func test_splitToSyllables_uppercaseVowels() {
        let result = SpeechVisualizationInteractor.splitToSyllables(word: "АнЯ")
        XCTAssertEqual(result.count, 2, "А-нЯ")
    }

    func test_splitToSyllables_emptyWord_returnsEmptyWordWrapped() {
        let result = SpeechVisualizationInteractor.splitToSyllables(word: "")
        XCTAssertEqual(result, [""])
    }

    // MARK: - computeAcousticSimilarity

    func test_computeAcousticSimilarity_nilChildURL_returnsNil() async {
        let (sut, _) = makeSUT()
        let result = await sut.computeAcousticSimilarity(
            childAudioURL: nil,
            referenceAudioURL: URL(fileURLWithPath: "/tmp/ref.wav")
        )
        XCTAssertNil(result)
    }

    func test_computeAcousticSimilarity_nilReferenceURL_returnsNil() async {
        let (sut, _) = makeSUT()
        let result = await sut.computeAcousticSimilarity(
            childAudioURL: URL(fileURLWithPath: "/tmp/child.wav"),
            referenceAudioURL: nil
        )
        XCTAssertNil(result)
    }

    func test_computeAcousticSimilarity_missingFiles_returnsNilGracefully() async {
        let (sut, _) = makeSUT()
        // Несуществующие файлы → loadFloatPCM бросает → catch возвращает nil
        let result = await sut.computeAcousticSimilarity(
            childAudioURL: URL(fileURLWithPath: "/tmp/nonexistent_child_\(UUID().uuidString).wav"),
            referenceAudioURL: URL(fileURLWithPath: "/tmp/nonexistent_ref_\(UUID().uuidString).wav")
        )
        XCTAssertNil(result)
    }
}
