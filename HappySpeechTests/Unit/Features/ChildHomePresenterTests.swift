@testable import HappySpeech
import XCTest

// MARK: - ChildHomePresenterTests
//
// Verifies the Response → ViewModel mapping that the ChildHome presenter
// actually performs (not pure pass-through fields):
//   - isStreakHot threshold (>= 7)
//   - quick-play difficulty clamp to 1...3
//   - sound family classification (accent) for SoundProgressItem
//   - mission detail title/description formatting (non-empty, sound included)
//   - recent-session title resolution from templateType
//   - array counts preserved through mapping
//   - formattedDate populated
//   - mascot tap emits a non-empty phrase

@MainActor
final class ChildHomePresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: ChildHomeDisplayLogic {
        var lastVM: ChildHomeModels.Fetch.ViewModel?
        var lastMascotPhrase: String?
        var fetchCount = 0

        func displayFetch(_ viewModel: ChildHomeModels.Fetch.ViewModel) {
            fetchCount += 1
            lastVM = viewModel
        }

        func displayMascotTap(phrase: String) {
            lastMascotPhrase = phrase
        }
    }

    private func makeSUT() -> (ChildHomePresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = ChildHomePresenter()
        presenter.viewModel = spy
        return (presenter, spy)
    }

    // MARK: - Response builder

    private func makeResponse(
        currentStreak: Int = 3,
        dailyTargetSound: String = "Р",
        soundProgress: [ChildHomeModels.SoundProgressData] = [],
        quickPlay: [ChildHomeModels.QuickPlayData] = [],
        worldZones: [ChildHomeModels.WorldZoneData] = [],
        recentSessions: [ChildHomeModels.RecentSessionData] = [],
        achievement: ChildHomeModels.AchievementData? = nil,
        recentRewards: [ChildHomeModels.RecentRewardData] = [],
        hasOverdueTask: Bool = false,
        todayWords: [ChildHomeModels.TodayWordData] = [],
        homeTasks: [ChildHomeModels.HomeTaskPreviewData] = []
    ) -> ChildHomeModels.Fetch.Response {
        ChildHomeModels.Fetch.Response(
            childName: "Маша",
            currentStreak: currentStreak,
            mascotMood: .happy,
            mascotPhrase: "Привет!",
            dailyTargetSound: dailyTargetSound,
            dailyStage: "Этап 3",
            dailyProgress: 0.5,
            soundProgress: soundProgress,
            quickPlay: quickPlay,
            worldZones: worldZones,
            recentSessions: recentSessions,
            achievement: achievement,
            dailyMissionDetail: ChildHomeModels.DailyMissionDetailData(
                id: "m1",
                titleKey: "child.home.mission.title.format",
                descriptionKey: "child.home.mission.description.format",
                targetSound: dailyTargetSound,
                templateType: TemplateType.repeatAfterModel.rawValue,
                requiredReps: 5,
                completedReps: 2
            ),
            recentRewards: recentRewards,
            hasOverdueTask: hasOverdueTask,
            todayWords: todayWords,
            homeTasks: homeTasks
        )
    }

    // MARK: - Pass-through basics

    func test_presentFetch_callsDisplay() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse())
        XCTAssertEqual(spy.fetchCount, 1)
        XCTAssertNotNil(spy.lastVM)
    }

    func test_presentFetch_childNameAndStreakPassedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(currentStreak: 4))
        XCTAssertEqual(spy.lastVM?.childName, "Маша")
        XCTAssertEqual(spy.lastVM?.currentStreak, 4)
    }

    func test_presentFetch_formattedDateNonEmpty() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse())
        XCTAssertFalse(spy.lastVM?.formattedDate.isEmpty ?? true)
    }

    // MARK: - isStreakHot threshold

    func test_streakBelow7_notHot() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(currentStreak: 6))
        XCTAssertEqual(spy.lastVM?.isStreakHot, false)
    }

    func test_streakAt7_isHot() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(currentStreak: 7))
        XCTAssertEqual(spy.lastVM?.isStreakHot, true)
    }

    func test_streakAbove7_isHot() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(currentStreak: 15))
        XCTAssertEqual(spy.lastVM?.isStreakHot, true)
    }

    // MARK: - quickPlay difficulty clamp

    func test_quickPlay_difficultyClampedAtUpperBound() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.QuickPlayData(
            id: "q1", templateType: "bingo", titleKey: "child.home.daily.title",
            icon: "star", accent: .coral, difficulty: 9
        )
        sut.presentFetch(makeResponse(quickPlay: [data]))
        XCTAssertEqual(spy.lastVM?.quickPlayItems.first?.difficulty, 3)
    }

    func test_quickPlay_difficultyClampedAtLowerBound() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.QuickPlayData(
            id: "q1", templateType: "bingo", titleKey: "child.home.daily.title",
            icon: "star", accent: .coral, difficulty: 0
        )
        sut.presentFetch(makeResponse(quickPlay: [data]))
        XCTAssertEqual(spy.lastVM?.quickPlayItems.first?.difficulty, 1)
    }

    func test_quickPlay_validDifficultyUnchanged() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.QuickPlayData(
            id: "q1", templateType: "bingo", titleKey: "child.home.daily.title",
            icon: "star", accent: .coral, difficulty: 2
        )
        sut.presentFetch(makeResponse(quickPlay: [data]))
        XCTAssertEqual(spy.lastVM?.quickPlayItems.first?.difficulty, 2)
    }

    // MARK: - Sound family classification

    func test_soundProgress_whistlingFamily() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.SoundProgressData(sound: "С", stageName: "Слоги", rate: 0.5)
        sut.presentFetch(makeResponse(soundProgress: [data]))
        XCTAssertEqual(spy.lastVM?.soundProgress.first?.accent, .whistling)
    }

    func test_soundProgress_hissingFamily() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.SoundProgressData(sound: "Ш", stageName: "Слоги", rate: 0.5)
        sut.presentFetch(makeResponse(soundProgress: [data]))
        XCTAssertEqual(spy.lastVM?.soundProgress.first?.accent, .hissing)
    }

    func test_soundProgress_sonorantFamily() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.SoundProgressData(sound: "Р", stageName: "Слоги", rate: 0.5)
        sut.presentFetch(makeResponse(soundProgress: [data]))
        XCTAssertEqual(spy.lastVM?.soundProgress.first?.accent, .sonorant)
    }

    func test_soundProgress_velarFamily() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.SoundProgressData(sound: "К", stageName: "Слоги", rate: 0.5)
        sut.presentFetch(makeResponse(soundProgress: [data]))
        XCTAssertEqual(spy.lastVM?.soundProgress.first?.accent, .velar)
    }

    func test_soundProgress_lowercaseSoundStillClassified() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.SoundProgressData(sound: "с", stageName: "Слоги", rate: 0.5)
        sut.presentFetch(makeResponse(soundProgress: [data]))
        XCTAssertEqual(spy.lastVM?.soundProgress.first?.accent, .whistling)
    }

    // MARK: - Daily mission

    func test_dailyMission_carriesTargetSound() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(dailyTargetSound: "Ж"))
        XCTAssertEqual(spy.lastVM?.dailyMission.targetSound, "Ж")
        XCTAssertFalse(spy.lastVM?.dailyMission.title.isEmpty ?? true)
    }

    func test_missionDetail_reps_passedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse())
        XCTAssertEqual(spy.lastVM?.dailyMissionDetail.requiredReps, 5)
        XCTAssertEqual(spy.lastVM?.dailyMissionDetail.completedReps, 2)
        XCTAssertFalse(spy.lastVM?.dailyMissionDetail.title.isEmpty ?? true)
    }

    // MARK: - Recent session title resolution

    func test_recentSession_knownTemplate_resolvesDisplayName() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.RecentSessionData(
            id: "s1", date: Date(),
            templateType: TemplateType.bingo.rawValue,
            targetSound: "С", score: 0.95
        )
        sut.presentFetch(makeResponse(recentSessions: [data]))
        let title = spy.lastVM?.recentSessions.first?.gameTitle ?? ""
        XCTAssertEqual(title, TemplateType.bingo.displayName)
    }

    func test_recentSession_unknownTemplate_usesFallback() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.RecentSessionData(
            id: "s1", date: Date(),
            templateType: "not-a-real-template",
            targetSound: "С", score: 0.5
        )
        sut.presentFetch(makeResponse(recentSessions: [data]))
        XCTAssertFalse(spy.lastVM?.recentSessions.first?.gameTitle.isEmpty ?? true)
    }

    func test_recentSession_scoreStars_highScoreThreeStars() {
        let (sut, spy) = makeSUT()
        let data = ChildHomeModels.RecentSessionData(
            id: "s1", date: Date(),
            templateType: TemplateType.bingo.rawValue,
            targetSound: "С", score: 0.95
        )
        sut.presentFetch(makeResponse(recentSessions: [data]))
        XCTAssertEqual(spy.lastVM?.recentSessions.first?.scoreStars, 3)
    }

    // MARK: - Array counts preserved

    func test_arrays_countsPreserved() {
        let (sut, spy) = makeSUT()
        let zone = ChildHomeModels.WorldZoneData(
            id: "z1", sound: "Р", emoji: "🌋", progress: 0.3, family: .sonorant
        )
        let reward = ChildHomeModels.RecentRewardData(
            id: "r1", emoji: "medal.fill", titleKey: "child.home.rewards.placeholder.title",
            earnedAt: Date()
        )
        sut.presentFetch(makeResponse(worldZones: [zone, zone], recentRewards: [reward]))
        XCTAssertEqual(spy.lastVM?.worldZones.count, 2)
        XCTAssertEqual(spy.lastVM?.recentRewards.count, 1)
    }

    func test_achievement_mapped_whenPresent() {
        let (sut, spy) = makeSUT()
        let ach = ChildHomeModels.AchievementData(
            id: "a1", titleKey: "child.home.achievement.placeholder.title",
            descriptionKey: "child.home.achievement.placeholder.description",
            emoji: "party.popper.fill", isNew: true
        )
        sut.presentFetch(makeResponse(achievement: ach))
        XCTAssertNotNil(spy.lastVM?.achievement)
        XCTAssertEqual(spy.lastVM?.achievement?.isVisible, true)
    }

    func test_achievement_nil_whenAbsent() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(achievement: nil))
        XCTAssertNil(spy.lastVM?.achievement)
    }

    func test_hasOverdueTask_passedThrough() {
        let (sut, spy) = makeSUT()
        sut.presentFetch(makeResponse(hasOverdueTask: true))
        XCTAssertEqual(spy.lastVM?.hasOverdueTask, true)
    }

    // MARK: - mascot tap

    func test_mascotTap_emitsNonEmptyPhrase() {
        let (sut, spy) = makeSUT()
        sut.presentMascotTap(.init())
        XCTAssertFalse(spy.lastMascotPhrase?.isEmpty ?? true)
    }
}
