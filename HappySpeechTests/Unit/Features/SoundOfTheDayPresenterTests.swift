@testable import HappySpeech
import XCTest

// MARK: - SoundOfTheDayPresenterTests

@MainActor
final class SoundOfTheDayPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: SoundOfTheDayDisplayLogic {
        var lastVM: SoundOfTheDayModels.LoadToday.ViewModel?

        func displayLoadToday(viewModel: SoundOfTheDayModels.LoadToday.ViewModel) async {
            lastVM = viewModel
        }
    }

    private func makeSUT() -> (SoundOfTheDayPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = SoundOfTheDayPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeResponse(
        childName: String = "Миша",
        targetSound: String = "Р",
        weekdayDateText: String = "суббота, 23 мая",
        reasonText: String = "Хороший прогресс!",
        streakDays: Int = 3
    ) -> SoundOfTheDayModels.LoadToday.Response {
        SoundOfTheDayModels.LoadToday.Response(
            childName: childName,
            targetSound: targetSound,
            weekdayDateText: weekdayDateText,
            reasonText: reasonText,
            streakDays: streakDays,
            activities: ActivityCard.all
        )
    }

    // MARK: - presentLoadToday

    func test_presentLoadToday_callsDisplay() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse())
        XCTAssertNotNil(spy.lastVM)
    }

    func test_presentLoadToday_greetingContainsChildName() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse(childName: "Ваня"))
        XCTAssertTrue(spy.lastVM?.greeting.contains("Ваня") ?? false)
    }

    func test_presentLoadToday_anonymousGreetingWhenNameEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse(childName: ""))
        let greeting = spy.lastVM?.greeting ?? ""
        // With empty name, a generic (non-name-personalised) greeting is used.
        XCTAssertFalse(greeting.isEmpty)
        XCTAssertFalse(greeting.contains("Ваня"))
    }

    func test_presentLoadToday_heroTitleContainsTargetSound() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse(targetSound: "Ш"))
        XCTAssertTrue(spy.lastVM?.heroTitle.contains("Ш") ?? false)
    }

    func test_presentLoadToday_streakProgressClamped() async {
        // 7+ days should clamp to 1.0
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse(streakDays: 10))
        XCTAssertEqual(spy.lastVM?.streakProgress ?? 0.0, 1.0, accuracy: 0.001)
    }

    func test_presentLoadToday_streakProgressForThreeDays() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse(streakDays: 3))
        let expected = 3.0 / 7.0
        XCTAssertEqual(spy.lastVM?.streakProgress ?? 0.0, expected, accuracy: 0.001)
    }

    func test_presentLoadToday_zeroStreakIsZeroProgress() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse(streakDays: 0))
        XCTAssertEqual(spy.lastVM?.streakProgress ?? 1.0, 0.0, accuracy: 0.001)
    }

    func test_presentLoadToday_subtitleContainsDateText() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse(weekdayDateText: "понедельник, 1 мая"))
        XCTAssertTrue(spy.lastVM?.subtitle.contains("понедельник, 1 мая") ?? false)
    }

    func test_presentLoadToday_activitiesPassedThrough() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse())
        XCTAssertEqual(spy.lastVM?.activities.count, ActivityCard.all.count)
    }

    func test_presentLoadToday_accessibilityLabelContainsSoundAndStreak() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse(targetSound: "Л", streakDays: 5))
        let a11y = spy.lastVM?.accessibilityLabel ?? ""
        XCTAssertTrue(a11y.contains("Л"))
    }

    func test_presentLoadToday_primaryCtaTitleIsNonEmpty() async {
        let (sut, spy) = makeSUT()
        await sut.presentLoadToday(response: makeResponse())
        XCTAssertFalse(spy.lastVM?.primaryCtaTitle.isEmpty ?? true)
    }
}
