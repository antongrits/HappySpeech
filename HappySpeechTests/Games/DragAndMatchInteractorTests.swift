import Testing
import UIKit
@testable import HappySpeech

// MARK: - Mock

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

@Suite("DragAndMatchInteractor")
@MainActor
struct DragAndMatchInteractorTests {

    private func makeSUT() -> (DragAndMatchInteractor, SpyDragPresenter, DragMockHaptic) {
        let haptic = DragMockHaptic()
        let sut = DragAndMatchInteractor(hapticService: haptic)
        let spy = SpyDragPresenter()
        sut.presenter = spy
        return (sut, spy, haptic)
    }

    // MARK: - 1. loadSession загружает слова и корзины

    @Test("loadSession загружает слова и корзины для group whistling")
    func loadSessionLoadsData() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        #expect(spy.loadSessionCalled)
        #expect((spy.lastLoadSession?.words.count ?? 0) > 0)
        #expect((spy.lastLoadSession?.buckets.count ?? 0) > 0)
    }

    // MARK: - 2. DragWord.set возвращает данные для всех групп

    @Test("DragWord.set возвращает непустые слова и корзины для всех групп")
    func dragWordSetAllGroups() {
        for group in ["whistling", "hissing", "sonants", "velar", "any"] {
            let (words, buckets) = DragWord.set(for: group)
            #expect(!words.isEmpty, "Группа \(group) должна иметь слова")
            #expect(!buckets.isEmpty, "Группа \(group) должна иметь корзины")
        }
    }

    // MARK: - 3. dropWord: правильная корзина

    @Test("dropWord с правильной корзиной → correct = true, haptic selection")
    func dropWordCorrect() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        #expect(spy.dropWordCalled)
        #expect(spy.lastDropWord?.correct == true)
        #expect(haptic.selectionCount >= 1)
    }

    // MARK: - 4. dropWord: неправильная корзина

    @Test("dropWord с неправильной корзиной → correct = false, haptic warning")
    func dropWordWrong() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first,
              let wrongBucket = spy.lastLoadSession?.buckets.first(where: { $0.id != word.correctBucketId }) else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: wrongBucket.id))
        #expect(spy.lastDropWord?.correct == false)
        #expect(haptic.notificationCount >= 1)
    }

    // MARK: - 5. feedbackText передаётся в Response

    @Test("dropWord передаёт feedbackText в Response")
    func dropWordFeedbackText() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        #expect(!(spy.lastDropWord?.feedbackText.isEmpty ?? true))
    }

    // MARK: - 6. completeSession вычисляет correctCount

    @Test("completeSession без дропов → correctCount = 0")
    func completeSessionNoDrop() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        await sut.completeSession(.init())
        #expect(spy.completeCalled)
        #expect(spy.lastComplete?.correctCount == 0)
    }

    // MARK: - 7. completeSession после правильных дропов

    @Test("completeSession после правильных дропов → correctCount > 0")
    func completeAfterCorrectDrops() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let words = spy.lastLoadSession?.words else { return }
        for word in words.prefix(2) {
            await sut.dropWord(.init(wordId: word.id, bucketId: word.correctBucketId))
        }
        await sut.completeSession(.init())
        #expect((spy.lastComplete?.correctCount ?? 0) >= 1)
    }

    // MARK: - 8. dropWord неизвестного wordId — не крашится

    @Test("dropWord с неизвестным wordId не крашится")
    func dropUnknownWord() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        await sut.dropWord(.init(wordId: "nonexistent-id", bucketId: "bucket-1"))
        // не должно быть краша
        #expect(!spy.dropWordCalled)
    }
}
