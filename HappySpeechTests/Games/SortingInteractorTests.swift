@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Mock HapticService (local override для SortingInteractorTests)

private final class SortingMockHapticService: HapticService, @unchecked Sendable {
    var selectionCount = 0
    var notificationCount = 0
    var impactCount = 0
    var playedPatterns: [HapticPattern] = []
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async { playedPatterns.append(pattern) }
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func selection() { selectionCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { notificationCount += 1 }
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { impactCount += 1 }
    func playLevelUp() async {}
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
    func presentHint(_ response: SortingModels.RequestHint.Response) {}
    func presentAutoPlace(_ response: SortingModels.AutoPlace.Response) {}
    func presentStreakBonus(_ response: SortingModels.StreakBonus.Response) {}
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

    private func makeSUT() -> (SortingInteractor, SpySortingPresenter, SortingMockHapticService) {
        let haptic = SortingMockHapticService()
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

    // MARK: - Batch 1: расширенное покрытие

    func test_classifyWord_unknownWordId_ignored() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        spy.classifyWordCalled = false
        await sut.classifyWord(.init(wordId: "nonexistent", categoryId: "any"))
        XCTAssertFalse(spy.classifyWordCalled)
    }

    func test_classifyWord_twice_secondIgnored() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.classifyWord(.init(wordId: word.id, categoryId: word.correctCategory))
        spy.classifyWordCalled = false
        await sut.classifyWord(.init(wordId: word.id, categoryId: word.correctCategory))
        XCTAssertFalse(spy.classifyWordCalled, "Повторная классификация слова игнорируется")
    }

    func test_classifyWord_remainingCountDecreases() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let words = spy.lastLoadSession?.words, let first = words.first else { return }
        let totalWords = words.count
        await sut.classifyWord(.init(wordId: first.id, categoryId: first.correctCategory))
        XCTAssertEqual(spy.lastClassifyWord?.remainingCount, totalWords - 1)
    }

    func test_classifyWord_feedbackNotEmpty() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let word = spy.lastLoadSession?.words.first else { return }
        await sut.classifyWord(.init(wordId: word.id, categoryId: word.correctCategory))
        XCTAssertFalse(spy.lastClassifyWord?.feedback.isEmpty ?? true)
    }

    func test_classifyAllWords_autoCompletes() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let words = spy.lastLoadSession?.words else { return }
        for word in words {
            await sut.classifyWord(.init(wordId: word.id, categoryId: word.correctCategory))
        }
        XCTAssertTrue(spy.completeCalled, "Классификация всех слов завершает сессию")
    }

    func test_requestHint_level1_returnsHighlight() async {
        var hintResponses: [SortingModels.RequestHint.Response] = []
        let haptic = SortingMockHapticService()
        let sut = SortingInteractor(hapticService: haptic)
        let spy = HintCapturingPresenter { hintResponses.append($0) }
        sut.presenter = spy
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let word = spy.words.first else { return }
        await sut.requestHint(.init(wordId: word.id))
        XCTAssertEqual(hintResponses.first?.hintLevel, 1)
        XCTAssertEqual(hintResponses.first?.highlightCategoryId, word.correctCategory)
    }

    func test_requestHint_level3_isAutoPlace() async {
        var hintResponses: [SortingModels.RequestHint.Response] = []
        let haptic = SortingMockHapticService()
        let sut = SortingInteractor(hapticService: haptic)
        let spy = HintCapturingPresenter { hintResponses.append($0) }
        sut.presenter = spy
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        guard let word = spy.words.first else { return }
        await sut.requestHint(.init(wordId: word.id))
        await sut.requestHint(.init(wordId: word.id))
        await sut.requestHint(.init(wordId: word.id))
        XCTAssertEqual(hintResponses.last?.hintLevel, 3)
        XCTAssertEqual(hintResponses.last?.isAutoPlace, true)
    }

    func test_requestHint_unknownWord_ignored() async {
        var hintCalled = false
        let haptic = SortingMockHapticService()
        let sut = SortingInteractor(hapticService: haptic)
        let spy = HintCapturingPresenter { _ in hintCalled = true }
        sut.presenter = spy
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        await sut.requestHint(.init(wordId: "nonexistent"))
        XCTAssertFalse(hintCalled)
    }

    func test_autoDistribute_placesRemainingWords() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        await sut.autoDistribute()
        XCTAssertTrue(spy.completeCalled, "autoDistribute завершает сессию")
    }

    func test_completeSession_categoryBreakdownNotEmpty() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "animate", childName: "Маша"))
        await sut.completeSession(.init())
        XCTAssertFalse(spy.lastComplete?.categoryBreakdown.isEmpty ?? true)
    }

    func test_taskType_allSetsHaveTaskType() {
        for set in SortingSet.catalog {
            XCTAssertFalse(set.words.isEmpty)
            XCTAssertFalse(set.categories.isEmpty)
        }
    }

    func test_set_mappingPerGroup() {
        XCTAssertEqual(SortingSet.set(for: "whistling").taskType, .soundPosition)
        XCTAssertEqual(SortingSet.set(for: "hissing").taskType, .firstSound)
        XCTAssertEqual(SortingSet.set(for: "sonorant").taskType, .syllableCount)
        XCTAssertEqual(SortingSet.set(for: "velar").taskType, .voicedUnvoiced)
        XCTAssertEqual(SortingSet.set(for: "unknown").taskType, .semantic)
    }
}

// MARK: - Hint-capturing Presenter (для SortingInteractorTests batch 1)

@MainActor
private final class HintCapturingPresenter: SortingPresentationLogic {
    var words: [SortingWord] = []
    private let onHint: (SortingModels.RequestHint.Response) -> Void

    init(onHint: @escaping (SortingModels.RequestHint.Response) -> Void) {
        self.onHint = onHint
    }

    func presentLoadSession(_ response: SortingModels.LoadSession.Response) {
        words = response.words
    }
    func presentClassifyWord(_ response: SortingModels.ClassifyWord.Response) {}
    func presentHint(_ response: SortingModels.RequestHint.Response) { onHint(response) }
    func presentAutoPlace(_ response: SortingModels.AutoPlace.Response) {}
    func presentStreakBonus(_ response: SortingModels.StreakBonus.Response) {}
    func presentTimerTick(_ response: SortingModels.TimerTick.Response) {}
    func presentCompleteSession(_ response: SortingModels.CompleteSession.Response) {}
}
