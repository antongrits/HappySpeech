@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Mock HapticService

private final class DragMockHaptic: HapticService, @unchecked Sendable {
    var selectionCount = 0
    var notificationCount = 0

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
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
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
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        XCTAssertTrue(spy.dropWordCalled)
        XCTAssertEqual(spy.lastDropWord?.correct, true)
        XCTAssertGreaterThanOrEqual(haptic.selectionCount, 1)
    }

    // MARK: - 4. dropWord: неправильная корзина

    func test_dropWord_wrong_hapticWarning() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first,
              let wrongBucket = spy.lastLoadSession?.buckets.first(where: { $0.id != word.correctBucketId }) else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: wrongBucket.id))
        XCTAssertEqual(spy.lastDropWord?.correct, false)
        XCTAssertGreaterThanOrEqual(haptic.notificationCount, 1)
    }

    // MARK: - 5. feedbackText передаётся в Response

    func test_dropWord_feedbackText_notEmpty() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        XCTAssertFalse(spy.lastDropWord?.feedbackText.isEmpty ?? true)
    }

    // MARK: - 6. completeSession без дропов → correctCount = 0

    func test_completeSession_noDrop_correctCountZero() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        await sut.completeSession(.init())
        XCTAssertTrue(spy.completeCalled)
        XCTAssertEqual(spy.lastComplete?.correctCount, 0)
    }

    // MARK: - 7. completeSession после правильных дропов → correctCount > 0

    func test_completeSession_afterCorrectDrops_correctCountPositive() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
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
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        await sut.dropWord(.init(wordId: "nonexistent-id", bucketId: "bucket-1"))
        XCTAssertFalse(spy.dropWordCalled)
    }
}
