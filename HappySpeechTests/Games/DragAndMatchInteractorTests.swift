@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Mock HapticService

private final class DragMockHaptic: HapticService, @unchecked Sendable {
    var selectionCount = 0
    var notificationCount = 0
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async {}
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func selection() { selectionCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { notificationCount += 1 }
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}
}

// MARK: - Spy

@MainActor
private final class SpyDragPresenter: DragAndMatchPresentationLogic {
    var loadSessionCalled = false
    var dropWordCalled = false
    var completeCalled = false

    var lastLoadSession: DragAndMatchModels.LoadSession.Response?
    var lastDropWord: DragAndMatchModels.DropWord.Response?
    var lastComplete: DragAndMatchModels.CompleteSession.Response?

    func presentLoadSession(_ response: DragAndMatchModels.LoadSession.Response) {
        loadSessionCalled = true
        lastLoadSession = response
    }
    func presentDropWord(_ response: DragAndMatchModels.DropWord.Response) {
        dropWordCalled = true
        lastDropWord = response
    }
    func presentHint(_ response: DragAndMatchModels.RequestHint.Response) {}
    func presentCompleteRound(_ response: DragAndMatchModels.CompleteRound.Response) {}
    func presentCompleteSession(_ response: DragAndMatchModels.CompleteSession.Response) {
        completeCalled = true
        lastComplete = response
    }
}

// MARK: - Tests

@MainActor
final class DragAndMatchInteractorTests: XCTestCase {

    private func makeSUT() -> (DragAndMatchInteractor, SpyDragPresenter, DragMockHaptic) {
        let haptic = DragMockHaptic()
        let sut = DragAndMatchInteractor(hapticService: haptic)
        let spy = SpyDragPresenter()
        sut.presenter = spy
        return (sut, spy, haptic)
    }

    // MARK: - 1. loadSession загружает слова и корзины

    func test_loadSession_loadsWordsAndBuckets() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        XCTAssertTrue(spy.loadSessionCalled)
        XCTAssertGreaterThan(spy.lastLoadSession?.words.count ?? 0, 0)
        XCTAssertGreaterThan(spy.lastLoadSession?.buckets.count ?? 0, 0)
    }

    // MARK: - 2. DragWord.set возвращает данные для всех групп

    func test_dragWordSet_allGroups() {
        for group in ["whistling", "hissing", "sonants", "velar", "any"] {
            let (words, buckets) = DragWord.set(for: group)
            XCTAssertFalse(words.isEmpty, "Группа \(group) должна иметь слова")
            XCTAssertFalse(buckets.isEmpty, "Группа \(group) должна иметь корзины")
        }
    }

    // MARK: - 3. dropWord: правильная корзина

    func test_dropWord_correct_hapticFires() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        XCTAssertTrue(spy.dropWordCalled)
        XCTAssertEqual(spy.lastDropWord?.correct, true)
        XCTAssertGreaterThanOrEqual(haptic.selectionCount, 1)
    }

    // MARK: - 4. dropWord: неправильная корзина

    func test_dropWord_wrong_hapticWarning() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        guard let word = spy.lastLoadSession?.words.first,
              let wrongBucket = spy.lastLoadSession?.buckets.first(where: { $0.id != word.correctBucketId }) else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: wrongBucket.id))
        XCTAssertEqual(spy.lastDropWord?.correct, false)
        XCTAssertGreaterThanOrEqual(haptic.notificationCount, 1)
    }

    // MARK: - 5. feedbackText передаётся в Response

    func test_dropWord_feedbackText_notEmpty() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        XCTAssertFalse(spy.lastDropWord?.feedbackText.isEmpty ?? true)
    }

    // MARK: - 6. completeSession без дропов → correctCount = 0

    func test_completeSession_noDrop_correctCountZero() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        await sut.completeSession(.init())
        XCTAssertTrue(spy.completeCalled)
        XCTAssertEqual(spy.lastComplete?.correctCount, 0)
    }

    // MARK: - 7. completeSession после правильных дропов → correctCount > 0

    func test_completeSession_afterCorrectDrops_correctCountPositive() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        guard let words = spy.lastLoadSession?.words else { return }
        for word in words.prefix(2) {
            await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        }
        await sut.completeSession(.init())
        XCTAssertGreaterThanOrEqual(spy.lastComplete?.correctCount ?? 0, 1)
    }

    // MARK: - 8. dropWord с неизвестным wordId не крашится

    func test_dropWord_unknownWordId_doesNotCrash() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        await sut.dropWord(.init(wordId: "nonexistent-id", bucketId: "bucket-1"))
        XCTAssertFalse(spy.dropWordCalled)
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_loadSession_setsRoundIndexAndTotal() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 3))
        XCTAssertEqual(spy.lastLoadSession?.roundIndex, 0)
        XCTAssertEqual(spy.lastLoadSession?.totalRounds, 3)
    }

    func test_dropWord_redropAfterError_recoversCorrect() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        guard let word = spy.lastLoadSession?.words.first,
              let wrongBucket = spy.lastLoadSession?.buckets.first(where: { $0.id != word.correctBucketId }) else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: wrongBucket.id))
        XCTAssertEqual(spy.lastDropWord?.correct, false)
        await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        XCTAssertEqual(spy.lastDropWord?.correct, true)
    }

    func test_dropWord_streakCountIncreases() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 5))
        guard let words = spy.lastLoadSession?.words else { return }
        for word in words.prefix(2) {
            await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        }
        XCTAssertGreaterThanOrEqual(spy.lastDropWord?.streakCount ?? 0, 2)
    }

    func test_inferConfusedPair_explicitPairs() {
        XCTAssertEqual(DragAndMatchInteractor.inferConfusedPair(for: "С/Ш")?.primary, "С")
        XCTAssertEqual(DragAndMatchInteractor.inferConfusedPair(for: "р-л")?.secondary, "Л")
        XCTAssertEqual(DragAndMatchInteractor.inferConfusedPair(for: "whistling")?.primary, "С")
        XCTAssertNil(DragAndMatchInteractor.inferConfusedPair(for: "unknown"))
    }

    func test_advanceRound_emitsCompleteRound() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 3))
        var completeRoundCalled = false
        let roundSpy = RoundSpyDragPresenter { _ in completeRoundCalled = true }
        sut.presenter = roundSpy
        await sut.advanceRound(.init())
        XCTAssertTrue(completeRoundCalled)
        _ = spy
    }

    func test_advanceRound_lastRound_completesSession() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 1))
        await sut.advanceRound(.init())
        XCTAssertTrue(spy.completeCalled)
    }

    func test_completeSession_twice_secondIgnored() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 3))
        await sut.completeSession(.init())
        spy.completeCalled = false
        await sut.completeSession(.init())
        XCTAssertFalse(spy.completeCalled)
    }

    func test_cancelSession_blocksFurtherDrops() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 3))
        sut.cancelSession()
        spy.dropWordCalled = false
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        XCTAssertFalse(spy.dropWordCalled, "После cancel дропы не обрабатываются")
    }

    func test_perPairAccuracy_emptyBeforeLoad() {
        let (sut, _, _) = makeSUT()
        XCTAssertTrue(sut.perPairAccuracy().isEmpty)
    }

    func test_sm2Quality_returnsValueAfterLoad() async {
        let (sut, _, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", totalRounds: 3))
        // Просто проверяем, что метод не крашится и возвращает SM2Quality
        _ = sut.sm2Quality()
        XCTAssertTrue(true)
    }

    func test_hintLevel_rawValues() {
        XCTAssertEqual(HintLevel.highlightBin.rawValue, 1)
        XCTAssertEqual(HintLevel.voicePrompt.rawValue, 2)
        XCTAssertEqual(HintLevel.autoSolve.rawValue, 3)
    }

    func test_roundStats_accuracyComputation() {
        let stats = RoundStats(
            roundIndex: 0, totalCards: 6, correctDrops: 3,
            incorrectDrops: 3, hintsUsed: 0, durationSeconds: 10
        )
        XCTAssertEqual(stats.accuracy, 0.5, accuracy: 0.001)
        let empty = RoundStats(
            roundIndex: 0, totalCards: 0, correctDrops: 0,
            incorrectDrops: 0, hintsUsed: 0, durationSeconds: 0
        )
        XCTAssertEqual(empty.accuracy, 0)
    }
}

// MARK: - Round-spy presenter (batch 1)

@MainActor
private final class RoundSpyDragPresenter: DragAndMatchPresentationLogic {
    private let onCompleteRound: (DragAndMatchModels.CompleteRound.Response) -> Void

    init(onCompleteRound: @escaping (DragAndMatchModels.CompleteRound.Response) -> Void) {
        self.onCompleteRound = onCompleteRound
    }

    func presentLoadSession(_ response: DragAndMatchModels.LoadSession.Response) {}
    func presentDropWord(_ response: DragAndMatchModels.DropWord.Response) {}
    func presentHint(_ response: DragAndMatchModels.RequestHint.Response) {}
    func presentCompleteRound(_ response: DragAndMatchModels.CompleteRound.Response) {
        onCompleteRound(response)
    }
    func presentCompleteSession(_ response: DragAndMatchModels.CompleteSession.Response) {}
}
