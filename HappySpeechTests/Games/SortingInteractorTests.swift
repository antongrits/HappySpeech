@testable import HappySpeech
import XCTest
import UIKit

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

@MainActor
final class SortingInteractorTests: XCTestCase {

    private func makeSUT() -> (SortingInteractor, SpySortingPresenter, MockHapticService) {
        let haptic = MockHapticService()
        let sut = SortingInteractor(hapticService: haptic)
        let spy = SpySortingPresenter()
        sut.presenter = spy
        return (sut, spy, haptic)
    }

    // MARK: - 1. loadSession загружает набор слов

    func test_loadSession_loadsWords() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        XCTAssertTrue(spy.loadSessionCalled)
        XCTAssertGreaterThan(spy.lastLoadSession?.words.count ?? 0, 0)
    }

    // MARK: - 2. loadSession загружает 2 категории

    func test_loadSession_twoCategories() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "hissing", childName: "Ваня"))
        XCTAssertEqual(spy.lastLoadSession?.categories.count, 2)
    }

    // MARK: - 3. classifyWord: правильная категория

    func test_classifyWord_correct_hapticFires() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.classifyWord(.init(wordId: word.id, categoryId: word.correctCategory))
        XCTAssertTrue(spy.classifyWordCalled)
        XCTAssertEqual(spy.lastClassifyWord?.correct, true)
        XCTAssertTrue(haptic.selectionCount >= 1 || haptic.notificationCount >= 1)
    }

    // MARK: - 4. classifyWord: неправильная категория

    func test_classifyWord_wrong_hapticWarning() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first,
              let wrongCategory = spy.lastLoadSession?.categories.first(where: { $0.id != word.correctCategory }) else { return }
        await sut.classifyWord(.init(wordId: word.id, categoryId: wrongCategory.id))
        XCTAssertEqual(spy.lastClassifyWord?.correct, false)
        XCTAssertGreaterThanOrEqual(haptic.notificationCount, 1)
    }

    // MARK: - 5. streak работает корректно

    func test_streak_increases() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let words = spy.lastLoadSession?.words else { return }
        var streak = 0
        for word in words.prefix(3) {
            await sut.classifyWord(.init(wordId: word.id, categoryId: word.correctCategory))
            streak = spy.lastClassifyWord?.streak ?? 0
        }
        XCTAssertGreaterThanOrEqual(streak, 1)
    }

    // MARK: - 6. SortingSet.set(for:) возвращает набор

    func test_sortingSet_allGroups() {
        for group in ["whistling", "hissing", "sonorant", "velar", "any"] {
            let set = SortingSet.set(for: group)
            XCTAssertFalse(set.words.isEmpty, "Группа \(group) должна иметь слова")
        }
    }

    // MARK: - 7. cancel завершает игру

    func test_cancel_doesNotCrash() async {
        let (sut, _, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        sut.cancel()
        XCTAssertTrue(true)
    }

    // MARK: - 8. completeSession вычисляет finalScore

    func test_completeSession_scoreInRange() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        await sut.completeSession(.init())
        XCTAssertTrue(spy.completeCalled)
        let score = spy.lastComplete?.finalScore ?? -1
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 1)
    }
}
