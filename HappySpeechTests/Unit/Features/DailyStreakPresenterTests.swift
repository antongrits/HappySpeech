@testable import HappySpeech
import XCTest

// MARK: - DailyStreakPresenterTests
//
// Block V v18 — покрытие DailyStreakPresenter (8 тестов).
// Тестируются все три метода presentationLogic через DisplaySpy.

@MainActor
final class DailyStreakPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: DailyStreakDisplayLogic {
        var loadVM: DailyStreakModels.Load.ViewModel?
        var checkInVM: DailyStreakModels.CheckIn.ViewModel?
        var useSaverVM: DailyStreakModels.UseSaver.ViewModel?

        func displayLoad(viewModel: DailyStreakModels.Load.ViewModel) async {
            loadVM = viewModel
        }
        func displayCheckIn(viewModel: DailyStreakModels.CheckIn.ViewModel) async {
            checkInVM = viewModel
        }
        func displayUseSaver(viewModel: DailyStreakModels.UseSaver.ViewModel) async {
            useSaverVM = viewModel
        }
    }

    private func makeSUT() -> (DailyStreakPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = DailyStreakPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeLoadResponse(
        currentStreak: Int = 5,
        longestStreak: Int = 10,
        status: DailyStreakStatus = .active,
        saverAvailable: Bool = true,
        unlockedMilestones: [DailyStreakMilestone] = [],
        nextMilestone: DailyStreakMilestone? = DailyStreakMilestone.all.first
    ) -> DailyStreakModels.Load.Response {
        DailyStreakModels.Load.Response(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            status: status,
            saver: StreakSaverState(lastUsedAt: nil, availableThisMonth: saverAvailable),
            unlockedMilestones: unlockedMilestones,
            nextMilestone: nextMilestone,
            lastActiveAt: Date()
        )
    }

    // MARK: - presentLoad

    func test_presentLoad_activeStatus_setsStatusLabel() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeLoadResponse(status: .active))
        XCTAssertNotNil(spy.loadVM)
        XCTAssertFalse(spy.loadVM?.statusLabel.isEmpty ?? true)
    }

    func test_presentLoad_brokenStatus_setsLabel() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeLoadResponse(status: .broken))
        XCTAssertNotNil(spy.loadVM)
        XCTAssertFalse(spy.loadVM?.statusEmoji.isEmpty ?? true)
    }

    func test_presentLoad_currentStreak_preserved() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeLoadResponse(currentStreak: 14))
        XCTAssertEqual(spy.loadVM?.currentStreak, 14)
    }

    func test_presentLoad_progressToNext_inRange0to1() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeLoadResponse(currentStreak: 2))
        let progress = spy.loadVM?.progressToNext ?? -1
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }

    func test_presentLoad_noNextMilestone_progressIs1() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoad(response: makeLoadResponse(
            currentStreak: 200,
            nextMilestone: nil
        ))
        XCTAssertEqual(spy.loadVM?.progressToNext ?? 0.0, 1.0, accuracy: 0.001)
    }

    // MARK: - presentCheckIn

    func test_presentCheckIn_milestoneUnlocked_celebrateIsTrue() async {
        let (sut, spy) = makeSUT()
        let milestone = DailyStreakMilestone.all[0]
        let response = DailyStreakModels.CheckIn.Response(
            newStreak: 3,
            unlockedMilestone: milestone,
            status: .active
        )
        await sut.presentCheckIn(response: response)
        XCTAssertTrue(spy.checkInVM?.celebrate ?? false)
        XCTAssertNotNil(spy.checkInVM?.unlockedMilestoneTitle)
    }

    func test_presentCheckIn_continuedStreak_hasToastMessage() async {
        let (sut, spy) = makeSUT()
        let response = DailyStreakModels.CheckIn.Response(
            newStreak: 5,
            unlockedMilestone: nil,
            status: .active
        )
        await sut.presentCheckIn(response: response)
        XCTAssertFalse(spy.checkInVM?.toastMessage.isEmpty ?? true)
    }

    // MARK: - presentUseSaver

    func test_presentUseSaver_success_hasBannerMessage() async {
        let (sut, spy) = makeSUT()
        let response = DailyStreakModels.UseSaver.Response(
            success: true,
            restoredStreak: 7,
            nextSaverAvailableAt: nil
        )
        await sut.presentUseSaver(response: response)
        XCTAssertTrue(spy.useSaverVM?.success ?? false)
        XCTAssertFalse(spy.useSaverVM?.bannerMessage.isEmpty ?? true)
    }

    func test_presentUseSaver_failure_hasBannerMessage() async {
        let (sut, spy) = makeSUT()
        let response = DailyStreakModels.UseSaver.Response(
            success: false,
            restoredStreak: 0,
            nextSaverAvailableAt: nil
        )
        await sut.presentUseSaver(response: response)
        XCTAssertFalse(spy.useSaverVM?.success ?? true)
        XCTAssertFalse(spy.useSaverVM?.bannerMessage.isEmpty ?? true)
    }
}
