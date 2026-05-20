@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Spy HapticService

private final class ObjectHuntSpyHaptic: HapticService, @unchecked Sendable {
    private(set) var selectionCount = 0
    private(set) var notificationCount = 0
    private(set) var impactCount = 0
    private(set) var playedPatterns: [HapticPattern] = []
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async { playedPatterns.append(pattern) }
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func selection() { selectionCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { notificationCount += 1 }
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { impactCount += 1 }
    func playLevelUp() async {}
}

// MARK: - Spy SoundService

private final class ObjectHuntSpySoundService: SoundServiceProtocol, @unchecked Sendable {
    private(set) var playedSounds: [UISound] = []
    var isMuted: Bool = false

    func playUISound(_ sound: UISound) { playedSounds.append(sound) }
    func playLyalya(_ phrase: LyalyaPhrase) {}
    func setMuted(_ muted: Bool) { isMuted = muted }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyObjectHuntPresenter: ObjectHuntPresentationLogic {
    var loadSceneCalled = false
    var tapObjectCallCount = 0
    var useHintCallCount = 0
    var timerTickCallCount = 0
    var completeSceneCallCount = 0
    var completeGameCallCount = 0

    var lastLoadScene: ObjectHuntModels.LoadScene.Response?
    var lastTapObject: ObjectHuntModels.TapObject.Response?
    var allTapObjects: [ObjectHuntModels.TapObject.Response] = []
    var lastUseHint: ObjectHuntModels.UseHint.Response?
    var lastTimerTick: ObjectHuntModels.TimerTick.Response?
    var lastCompleteScene: ObjectHuntModels.CompleteScene.Response?
    var lastCompleteGame: ObjectHuntModels.CompleteGame.Response?

    func presentLoadScene(_ response: ObjectHuntModels.LoadScene.Response) {
        loadSceneCalled = true
        lastLoadScene = response
    }
    func presentTapObject(_ response: ObjectHuntModels.TapObject.Response) {
        tapObjectCallCount += 1
        lastTapObject = response
        allTapObjects.append(response)
    }
    func presentUseHint(_ response: ObjectHuntModels.UseHint.Response) {
        useHintCallCount += 1
        lastUseHint = response
    }
    func presentTimerTick(_ response: ObjectHuntModels.TimerTick.Response) {
        timerTickCallCount += 1
        lastTimerTick = response
    }
    func presentCompleteScene(_ response: ObjectHuntModels.CompleteScene.Response) {
        completeSceneCallCount += 1
        lastCompleteScene = response
    }
    func presentCompleteGame(_ response: ObjectHuntModels.CompleteGame.Response) {
        completeGameCallCount += 1
        lastCompleteGame = response
    }
}

// MARK: - Tests

@MainActor
final class ObjectHuntInteractorTests: XCTestCase {

    private func makeSUT(
        targetSound: String = "С"
    ) -> (ObjectHuntInteractor, SpyObjectHuntPresenter, ObjectHuntSpyHaptic, ObjectHuntSpySoundService, SpyAdaptivePlannerService) {
        let haptic = ObjectHuntSpyHaptic()
        let sound = ObjectHuntSpySoundService()
        let planner = SpyAdaptivePlannerService()
        let sut = ObjectHuntInteractor(
            targetSound: targetSound,
            childId: "child-1",
            hapticService: haptic,
            soundService: sound,
            adaptivePlanner: planner
        )
        let spy = SpyObjectHuntPresenter()
        sut.presenter = spy
        return (sut, spy, haptic, sound, planner)
    }

    private func loadRequest(sound: String = "С", index: Int = 0) -> ObjectHuntModels.LoadScene.Request {
        ObjectHuntModels.LoadScene.Request(
            soundGroup: ObjectHuntInteractor.resolveSoundGroup(for: sound),
            targetSound: sound,
            sceneIndex: index
        )
    }

    // MARK: - resolveSoundGroup

    func test_resolveSoundGroup_allGroups() {
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "С"), "whistling")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "З"), "whistling")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "Ц"), "whistling")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "Ш"), "hissing")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "Ж"), "hissing")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "Р"), "sonants")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "Л"), "sonants")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "К"), "velar")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "Х"), "velar")
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "?"), "whistling")
    }

    func test_resolveSoundGroup_lowercaseInput() {
        XCTAssertEqual(ObjectHuntInteractor.resolveSoundGroup(for: "ш"), "hissing")
    }

    // MARK: - buildAllScenes

    func test_buildAllScenes_returnsRequestedCount() {
        for group in ["whistling", "hissing", "sonants", "velar", "unknown"] {
            let scenes = ObjectHuntInteractor.buildAllScenes(group: group, targetSound: "С", totalScenes: 5)
            XCTAssertEqual(scenes.count, 5, "Group \(group) должен вернуть 5 сцен")
            XCTAssertTrue(scenes.allSatisfy { $0.count == 9 }, "Каждая сцена — 9 предметов")
        }
    }

    func test_sceneDescriptors_hasSixScenes() {
        XCTAssertEqual(ObjectHuntInteractor.sceneDescriptors.count, 6)
        XCTAssertTrue(ObjectHuntInteractor.sceneDescriptors.allSatisfy { !$0.name.isEmpty })
    }

    // MARK: - loadScene

    func test_loadScene_populatesResponse() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        XCTAssertTrue(spy.loadSceneCalled)
        XCTAssertEqual(spy.lastLoadScene?.sceneIndex, 0)
        XCTAssertEqual(spy.lastLoadScene?.totalScenes, 5)
        XCTAssertEqual(spy.lastLoadScene?.timeLimitSec, 60)
        XCTAssertEqual(spy.lastLoadScene?.items.count, 9)
        XCTAssertGreaterThan(spy.lastLoadScene?.targetCount ?? 0, 0)
    }

    func test_loadScene_clampsNegativeIndex() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest(index: -5))
        XCTAssertEqual(spy.lastLoadScene?.sceneIndex, 0)
    }

    func test_loadScene_clampsTooLargeIndex() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest(index: 99))
        XCTAssertEqual(spy.lastLoadScene?.sceneIndex, 4)
    }

    func test_loadScene_buildsScenesOnce() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest(index: 0))
        let firstItems = spy.lastLoadScene?.items.map(\.word)
        sut.loadScene(loadRequest(index: 0))
        let secondItems = spy.lastLoadScene?.items.map(\.word)
        XCTAssertEqual(firstItems, secondItems, "Перезагрузка сцены не должна перестраивать каталог")
    }

    // MARK: - tapObject correct

    func test_tapObject_correct_increasesScoreAndStreak() {
        let (sut, spy, haptic, sound, _) = makeSUT()
        sut.loadScene(loadRequest())
        guard let target = spy.lastLoadScene?.items.first(where: { $0.hasTargetSound }) else {
            return XCTFail("Нет целевого предмета")
        }
        sut.tapObject(.init(itemId: target.id))
        XCTAssertEqual(spy.lastTapObject?.isCorrect, true)
        XCTAssertEqual(spy.lastTapObject?.correctCount, 1)
        XCTAssertEqual(spy.lastTapObject?.streakCount, 1)
        XCTAssertEqual(spy.lastTapObject?.score, 5)
        XCTAssertEqual(haptic.selectionCount, 1)
        XCTAssertTrue(sound.playedSounds.contains(.correct))
    }

    func test_tapObject_wrong_resetsStreakAndWarns() {
        let (sut, spy, haptic, sound, _) = makeSUT()
        sut.loadScene(loadRequest())
        guard let distractor = spy.lastLoadScene?.items.first(where: { !$0.hasTargetSound }) else {
            return XCTFail("Нет отвлекающего предмета")
        }
        sut.tapObject(.init(itemId: distractor.id))
        XCTAssertEqual(spy.lastTapObject?.isCorrect, false)
        XCTAssertEqual(spy.lastTapObject?.newState, .wrong)
        XCTAssertEqual(spy.lastTapObject?.streakCount, 0)
        XCTAssertEqual(spy.lastTapObject?.score, 0)
        XCTAssertGreaterThanOrEqual(haptic.notificationCount, 1)
        XCTAssertTrue(sound.playedSounds.contains(.incorrect))
    }

    func test_tapObject_unknownId_ignored() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        let before = spy.tapObjectCallCount
        sut.tapObject(.init(itemId: UUID()))
        XCTAssertEqual(spy.tapObjectCallCount, before)
    }

    func test_tapObject_repeatTapIgnored() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        guard let target = spy.lastLoadScene?.items.first(where: { $0.hasTargetSound }) else {
            return XCTFail("Нет целевого предмета")
        }
        sut.tapObject(.init(itemId: target.id))
        let countAfterFirst = spy.tapObjectCallCount
        sut.tapObject(.init(itemId: target.id))
        XCTAssertEqual(spy.tapObjectCallCount, countAfterFirst, "Повторный тап игнорируется")
    }

    func test_tapObject_streakBonus_appliedAfterThree() {
        // Используем З-сцену: целевой звук «С» имеет 2 С-слова + распределённые.
        let (sut, spy, _, _, _) = makeSUT(targetSound: "С")
        sut.loadScene(loadRequest(sound: "С"))
        let targets = spy.lastLoadScene?.items.filter { $0.hasTargetSound } ?? []
        guard targets.count >= 3 else { return XCTFail("Недостаточно целей для серии") }
        for target in targets.prefix(3) {
            sut.tapObject(.init(itemId: target.id))
        }
        XCTAssertEqual(spy.lastTapObject?.streakCount, 3)
        // 5 + 5 + (5 + streakBonus 5) = 20
        XCTAssertEqual(spy.lastTapObject?.score, 20)
    }

    // MARK: - useHint

    func test_useHint_highlightsTargetItem() {
        let (sut, spy, _, sound, _) = makeSUT()
        sut.loadScene(loadRequest())
        sut.useHint(.init())
        XCTAssertNotNil(spy.lastUseHint?.hintedItemId)
        XCTAssertEqual(spy.lastUseHint?.hintLevel, 1)
        XCTAssertEqual(spy.lastUseHint?.hintsRemaining, 1)
        XCTAssertTrue(sound.playedSounds.contains(.tap))
    }

    func test_useHint_secondHintLevelTwo() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        sut.useHint(.init())
        sut.useHint(.init())
        XCTAssertEqual(spy.lastUseHint?.hintLevel, 2)
        XCTAssertEqual(spy.lastUseHint?.hintsRemaining, 0)
    }

    func test_useHint_exhausted_returnsNil() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        sut.useHint(.init())
        sut.useHint(.init())
        sut.useHint(.init())
        XCTAssertNil(spy.lastUseHint?.hintedItemId)
        XCTAssertEqual(spy.lastUseHint?.hintsRemaining, 0)
        XCTAssertEqual(spy.lastUseHint?.hintLevel, 0)
    }

    func test_useHint_noTargetsLeft_returnsNilWithRemaining() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        // Тапаем все целевые предметы
        let targets = spy.lastLoadScene?.items.filter { $0.hasTargetSound } ?? []
        for target in targets {
            sut.tapObject(.init(itemId: target.id))
        }
        // Сцена уже завершена; запрашиваем подсказку — целей нет
        sut.useHint(.init())
        XCTAssertNil(spy.lastUseHint?.hintedItemId)
    }

    // MARK: - timerTick

    func test_timerTick_decrements() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        sut.timerTick(.init())
        XCTAssertEqual(spy.lastTimerTick?.secondsRemaining, 59)
        XCTAssertEqual(spy.lastTimerTick?.isExpired, false)
    }

    func test_timerTick_expiresAndCompletesScene() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        for _ in 0..<60 { sut.timerTick(.init()) }
        XCTAssertEqual(spy.lastTimerTick?.secondsRemaining, 0)
        XCTAssertEqual(spy.lastTimerTick?.isExpired, true)
        XCTAssertEqual(spy.completeSceneCallCount, 1)
        // timeUsedSec вычисляется как Date().timeIntervalSince(sceneStartTime),
        // зажатое в [0, timeLimitSec]; в быстром тесте оно близко к нулю.
        let timeUsed = spy.lastCompleteScene?.timeUsedSec ?? -1
        XCTAssertGreaterThanOrEqual(timeUsed, 0)
        XCTAssertLessThanOrEqual(timeUsed, 60)
    }

    func test_timerTick_afterExpiry_ignored() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        for _ in 0..<60 { sut.timerTick(.init()) }
        let countAfterExpiry = spy.timerTickCallCount
        sut.timerTick(.init())
        XCTAssertEqual(spy.timerTickCallCount, countAfterExpiry)
    }

    // MARK: - scene complete via tapping all targets

    func test_tapAllTargets_marksSceneComplete() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        let targets = spy.lastLoadScene?.items.filter { $0.hasTargetSound } ?? []
        for target in targets {
            sut.tapObject(.init(itemId: target.id))
        }
        XCTAssertEqual(spy.lastTapObject?.isSceneComplete, true)
    }

    // MARK: - advanceToNextScene

    func test_advanceToNextScene_loadsNext() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest(index: 0))
        sut.advanceToNextScene()
        XCTAssertEqual(spy.lastLoadScene?.sceneIndex, 1)
    }

    func test_advanceToNextScene_lastScene_completesGame() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest(index: 4))
        sut.advanceToNextScene()
        XCTAssertEqual(spy.completeGameCallCount, 1)
        XCTAssertNotNil(spy.lastCompleteGame)
    }

    // MARK: - finishEarly / completeGame

    func test_finishEarly_completesGame() {
        let (sut, spy, _, sound, _) = makeSUT()
        sut.loadScene(loadRequest())
        sut.finishEarly()
        XCTAssertEqual(spy.completeGameCallCount, 1)
        XCTAssertTrue(sound.playedSounds.contains(.complete))
        XCTAssertNotNil(spy.lastCompleteGame)
    }

    func test_completeGame_accuracyAndStarsInRange() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        // Найти несколько целей для ненулевой точности
        let targets = spy.lastLoadScene?.items.filter { $0.hasTargetSound } ?? []
        for target in targets { sut.tapObject(.init(itemId: target.id)) }
        sut.finishEarly()
        let game = spy.lastCompleteGame
        XCTAssertNotNil(game)
        XCTAssertGreaterThanOrEqual(game?.accuracy ?? -1, 0)
        XCTAssertLessThanOrEqual(game?.accuracy ?? 2, 1)
        XCTAssertGreaterThanOrEqual(game?.starsEarned ?? -1, 1)
        XCTAssertLessThanOrEqual(game?.starsEarned ?? 99, 3)
        XCTAssertGreaterThan(game?.totalFound ?? -1, 0)
    }

    func test_completeGame_persistsResultViaPlanner() async {
        let (sut, spy, _, _, planner) = makeSUT()
        sut.loadScene(loadRequest())
        let targets = spy.lastLoadScene?.items.filter { $0.hasTargetSound } ?? []
        for target in targets { sut.tapObject(.init(itemId: target.id)) }
        sut.finishEarly()
        // persistResult выполняется в детачнутом Task — даём ему отработать
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertGreaterThanOrEqual(planner.recordedQualities.count, 1)
        XCTAssertEqual(planner.recordedQualities.first?.childId, "child-1")
        XCTAssertEqual(planner.recordedQualities.first?.soundTarget, "С")
    }

    func test_completeGame_zeroFound_starsStillOne() {
        let (sut, spy, _, _, _) = makeSUT()
        sut.loadScene(loadRequest())
        sut.finishEarly()
        XCTAssertEqual(spy.lastCompleteGame?.starsEarned, 1)
        XCTAssertEqual(spy.lastCompleteGame?.accuracy, 0)
    }
}
