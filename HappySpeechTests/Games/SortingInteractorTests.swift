import Testing
import UIKit
@testable import HappySpeech

// MARK: - Mock HapticService

private final class MockHapticService: HapticService, @unchecked Sendable {
    var selectionCount = 0
    var notificationCount = 0
    var impactCount = 0

    func selection() { selectionCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { notificationCount += 1 }
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { impactCount += 1 }
}

// MARK: - Spy

@MainActor
private final class SpySortingPresenter: SortingPresentationLogic {
    var loadSessionCalled = false
    var classifyWordCalled = false
    var timerTickCalled = false
    var completeCalled = false

    var lastLoadSession: SortingModels.LoadSession.Response?
    var lastClassifyWord: SortingModels.ClassifyWord.Response?
    var lastComplete: SortingModels.CompleteSession.Response?

    func presentLoadSession(_ response: SortingModels.LoadSession.Response) {
        loadSessionCalled = true
        lastLoadSession = response
    }
    func presentClassifyWord(_ response: SortingModels.ClassifyWord.Response) {
        classifyWordCalled = true
        lastClassifyWord = response
    }
    func presentTimerTick(_ response: SortingModels.TimerTick.Response) {
        timerTickCalled = true
    }
    func presentCompleteSession(_ response: SortingModels.CompleteSession.Response) {
        completeCalled = true
        lastComplete = response
    }
}

// MARK: - Tests

@Suite("SortingInteractor")
@MainActor
struct SortingInteractorTests {

    private func makeSUT() -> (SortingInteractor, SpySortingPresenter, MockHapticService) {
        let haptic = MockHapticService()
        let sut = SortingInteractor(hapticService: haptic)
        let spy = SpySortingPresenter()
        sut.presenter = spy
        return (sut, spy, haptic)
    }

    // MARK: - 1. loadSession загружает набор слов

    @Test("loadSession загружает набор слов и вызывает presenter")
    func loadSessionLoadsWords() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        #expect(spy.loadSessionCalled)
        #expect((spy.lastLoadSession?.words.count ?? 0) > 0)
    }

    // MARK: - 2. loadSession загружает 2 категории

    @Test("loadSession загружает 2 категории")
    func loadSessionTwoCategories() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "hissing", childName: "Ваня"))
        #expect(spy.lastLoadSession?.categories.count == 2)
    }

    // MARK: - 3. classifyWord: правильная категория

    @Test("classifyWord с правильной категорией → correct = true, haptic selection")
    func classifyWordCorrect() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.classifyWord(.init(wordId: word.id, categoryId: word.correctCategory))
        #expect(spy.classifyWordCalled)
        #expect(spy.lastClassifyWord?.correct == true)
        #expect(haptic.selectionCount >= 1 || haptic.notificationCount >= 1)
    }

    // MARK: - 4. classifyWord: неправильная категория

    @Test("classifyWord с неправильной категорией → correct = false")
    func classifyWordWrong() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first,
              let wrongCategory = spy.lastLoadSession?.categories.first(where: { $0.id != word.correctCategory }) else { return }
        await sut.classifyWord(.init(wordId: word.id, categoryId: wrongCategory.id))
        #expect(spy.lastClassifyWord?.correct == false)
        #expect(haptic.notificationCount >= 1)
    }

    // MARK: - 5. streak работает корректно

    @Test("streak увеличивается при последовательных правильных ответах")
    func streakIncreases() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let words = spy.lastLoadSession?.words else { return }
        var streak = 0
        for word in words.prefix(3) {
            await sut.classifyWord(.init(wordId: word.id, categoryId: word.correctCategory))
            streak = spy.lastClassifyWord?.streak ?? 0
        }
        #expect(streak >= 1)
    }

    // MARK: - 6. SortingSet.set(for:) возвращает набор

    @Test("SortingSet.set(for:) возвращает набор для каждой группы")
    func setForAllGroups() {
        for group in ["whistling", "hissing", "sonorant", "velar", "any"] {
            let set = SortingSet.set(for: group)
            #expect(!set.words.isEmpty, "Группа \(group) должна иметь слова")
        }
    }

    // MARK: - 7. cancel завершает игру

    @Test("cancel не крашится")
    func cancelDoesNotCrash() async {
        let (sut, _, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        sut.cancel()
        #expect(Bool(true))
    }

    // MARK: - 8. completeSession вызывает presenter

    @Test("completeSession вычисляет и передаёт finalScore")
    func completeSessionScore() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        await sut.completeSession(.init())
        #expect(spy.completeCalled)
        let score = spy.lastComplete?.finalScore ?? -1
        #expect(score >= 0 && score <= 1)
    }
}
