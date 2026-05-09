@testable import HappySpeech
import XCTest

// MARK: - AchievementsPresenterTests
//
// Block V v18 — покрытие AchievementsPresenter (7 тестов).
// Тестируются все основные методы через DisplaySpy.

@MainActor
final class AchievementsPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: AchievementsDisplayLogic {
        var loadVM: AchievementsModels.Load.ViewModel?
        var toastVM: AchievementsModels.ToastUnlocked.ViewModel?
        var nextProgressVM: AchievementsModels.NextAchievementProgress.ViewModel?
        var motivationalMessage: String?
        var shareText: String?
        var shareAchievement: Achievement?

        func displayAchievements(_ viewModel: AchievementsModels.Load.ViewModel) { loadVM = viewModel }
        func displayUnlockedToast(_ viewModel: AchievementsModels.ToastUnlocked.ViewModel) { toastVM = viewModel }
        func displayNextAchievementProgress(_ viewModel: AchievementsModels.NextAchievementProgress.ViewModel) { nextProgressVM = viewModel }
        func displayMotivationalMessage(_ message: String) { motivationalMessage = message }
        func displayShareSheet(shareText: String, achievement: Achievement) {
            self.shareText = shareText
            self.shareAchievement = achievement
        }
    }

    private func makeSUT() -> (AchievementsPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = AchievementsPresenter()
        presenter.view = spy
        return (presenter, spy)
    }

    private func makeLoadResponse(
        unlockedCount: Int = 3,
        total: Int = 10,
        siblings: [SiblingProgressDTO] = []
    ) -> AchievementsModels.Load.Response {
        let dtos = Achievement.allCases.prefix(total).map { ach in
            AchievementDTO(
                id: ach.rawValue,
                achievement: ach,
                isUnlocked: false,
                unlockedAt: nil
            )
        }
        return AchievementsModels.Load.Response(
            childId: "child-1",
            achievements: Array(dtos),
            totalUnlocked: unlockedCount,
            totalCount: total,
            sessions: [],
            siblingProfiles: siblings
        )
    }

    // MARK: - presentAchievements

    func test_presentAchievements_callsDisplayAchievements() {
        let (sut, spy) = makeSUT()
        sut.presentAchievements(makeLoadResponse())
        XCTAssertNotNil(spy.loadVM)
        XCTAssertFalse(spy.loadVM?.progressText.isEmpty ?? true)
    }

    func test_presentAchievements_noSiblings_showFamilyLeaderboardFalse() {
        let (sut, spy) = makeSUT()
        sut.presentAchievements(makeLoadResponse(siblings: []))
        XCTAssertFalse(spy.loadVM?.showFamilyLeaderboard ?? true)
    }

    func test_presentAchievements_twoSiblings_showFamilyLeaderboardTrue() {
        let (sut, spy) = makeSUT()
        let siblings = [
            SiblingProgressDTO(id: "s1", name: "Катя", totalUnlocked: 3),
            SiblingProgressDTO(id: "s2", name: "Ваня", totalUnlocked: 5)
        ]
        sut.presentAchievements(makeLoadResponse(siblings: siblings))
        XCTAssertTrue(spy.loadVM?.showFamilyLeaderboard ?? false)
    }

    // MARK: - presentUnlockedToast

    func test_presentUnlockedToast_setsMessageAndIconName() {
        let (sut, spy) = makeSUT()
        let response = AchievementsModels.ToastUnlocked.Response(achievement: .streak7Days)
        sut.presentUnlockedToast(response)
        XCTAssertNotNil(spy.toastVM)
        XCTAssertFalse(spy.toastVM?.message.isEmpty ?? true)
        XCTAssertFalse(spy.toastVM?.iconName.isEmpty ?? true)
    }

    // MARK: - presentNextAchievementProgress

    func test_presentNextAchievementProgress_setsProgressFraction() {
        let (sut, spy) = makeSUT()
        let progress = AchievementProgress(
            achievementKey: "streak7Days",
            currentValue: 4,
            requiredValue: 7,
            fraction: 4.0 / 7.0
        )
        let response = AchievementsModels.NextAchievementProgress.Response(progress: progress)
        sut.presentNextAchievementProgress(response)
        XCTAssertNotNil(spy.nextProgressVM)
        XCTAssertGreaterThan(spy.nextProgressVM?.progressFraction ?? 0, 0.0)
    }

    // MARK: - presentMotivationalMessage

    func test_presentMotivationalMessage_displaysMessage() {
        let (sut, spy) = makeSUT()
        let response = AchievementsModels.MotivationalMessage.Response(
            message: "Ты молодец!",
            achievementKey: "streak3Days"
        )
        sut.presentMotivationalMessage(response)
        XCTAssertEqual(spy.motivationalMessage, "Ты молодец!")
    }

    // MARK: - presentShareAchievement

    func test_presentShareAchievement_passesAchievementToDisplay() {
        let (sut, spy) = makeSUT()
        let shareResponse = AchievementsModels.Share.Response(
            achievement: .firstSoundMastered,
            shareText: "Я получил достижение!",
            childName: "Ваня"
        )
        sut.presentShareAchievement(shareResponse)
        XCTAssertEqual(spy.shareAchievement, .firstSoundMastered)
        XCTAssertFalse(spy.shareText?.isEmpty ?? true)
    }
}
