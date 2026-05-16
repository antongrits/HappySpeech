@testable import HappySpeech
import XCTest

// MARK: - AnalyticsServiceTests
//
// Block V v18 — покрытие MockAnalyticsService и AnalyticsEvent (8 тестов).
// Тестируется контрактное поведение через MockAnalyticsService.

final class AnalyticsServiceTests: XCTestCase {

    private func makeSUT() -> MockAnalyticsService {
        MockAnalyticsService()
    }

    // MARK: - AnalyticsEvent

    func test_analyticsEvent_init_setsNameAndParameters() {
        let event = AnalyticsEvent(name: "session_complete", parameters: ["sound": "Р"])
        XCTAssertEqual(event.name, "session_complete")
        XCTAssertEqual(event.parameters["sound"], "Р")
    }

    func test_analyticsEvent_noParameters_parametersIsEmpty() {
        let event = AnalyticsEvent(name: "app_launch")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    func test_analyticsEvent_timestampIsRecent() {
        let before = Date()
        let event = AnalyticsEvent(name: "test")
        let after = Date()
        XCTAssertGreaterThanOrEqual(event.timestamp, before)
        XCTAssertLessThanOrEqual(event.timestamp, after)
    }

    // MARK: - MockAnalyticsService.track

    func test_track_singleEvent_isRecorded() {
        let sut = makeSUT()
        let event = AnalyticsEvent(name: "onboarding_start")
        sut.track(event: event)
        XCTAssertEqual(sut.events.count, 1)
        XCTAssertEqual(sut.events.first?.name, "onboarding_start")
    }

    func test_track_multipleEvents_allRecorded() {
        let sut = makeSUT()
        sut.track(event: AnalyticsEvent(name: "event_a"))
        sut.track(event: AnalyticsEvent(name: "event_b"))
        sut.track(event: AnalyticsEvent(name: "event_c"))
        XCTAssertEqual(sut.events.count, 3)
    }

    func test_track_eventsPreserveOrder() {
        let sut = makeSUT()
        sut.track(event: AnalyticsEvent(name: "first"))
        sut.track(event: AnalyticsEvent(name: "second"))
        XCTAssertEqual(sut.events[0].name, "first")
        XCTAssertEqual(sut.events[1].name, "second")
    }

    func test_initialState_eventsIsEmpty() {
        let sut = makeSUT()
        XCTAssertTrue(sut.events.isEmpty)
    }

    func test_track_eventWithMultipleParameters_stored() {
        let sut = makeSUT()
        let event = AnalyticsEvent(name: "session_complete", parameters: [
            "sound": "Р",
            "stage": "word",
            "score": "0.92"
        ])
        sut.track(event: event)
        let stored = sut.events.first
        XCTAssertEqual(stored?.parameters["sound"], "Р")
        XCTAssertEqual(stored?.parameters["stage"], "word")
        XCTAssertEqual(stored?.parameters["score"], "0.92")
    }

    // MARK: - Batch 2.8.4 v25: LiveAnalyticsService (no-op OSLog bus)
    //
    // LiveAnalyticsService — per ADR-004 локальное логирование через OSLog,
    // без внешних SDK (Kids Category). Проверяем, что track() не падает на
    // любых событиях и фабрики AnalyticsEvent формируют корректные payload.

    func test_liveAnalyticsService_track_doesNotCrash() {
        let live = LiveAnalyticsService()
        live.track(event: AnalyticsEvent(name: "live_test"))
    }

    func test_liveAnalyticsService_track_withParameters() {
        let live = LiveAnalyticsService()
        live.track(event: AnalyticsEvent(name: "with_params", parameters: ["k": "v"]))
    }

    func test_liveAnalyticsService_track_manyEvents() {
        let live = LiveAnalyticsService()
        for i in 0..<30 {
            live.track(event: AnalyticsEvent(name: "event_\(i)"))
        }
    }

    // MARK: - AnalyticsEvent factories

    func test_factory_sessionStarted() {
        let event = AnalyticsEvent.sessionStarted(
            childId: "c1", sound: "Р", template: "listen_and_choose"
        )
        XCTAssertEqual(event.name, "session_started")
        XCTAssertEqual(event.parameters["child_id"], "c1")
        XCTAssertEqual(event.parameters["sound"], "Р")
        XCTAssertEqual(event.parameters["template"], "listen_and_choose")
    }

    func test_factory_sessionCompleted_formatsSuccessRate() {
        let event = AnalyticsEvent.sessionCompleted(
            childId: "c1", successRate: 0.876, durationSec: 240
        )
        XCTAssertEqual(event.name, "session_completed")
        XCTAssertEqual(event.parameters["success_rate"], "0.88")
        XCTAssertEqual(event.parameters["duration_sec"], "240")
    }

    func test_factory_sessionCompleted_zeroValues() {
        let event = AnalyticsEvent.sessionCompleted(childId: "c2", successRate: 0, durationSec: 0)
        XCTAssertEqual(event.parameters["success_rate"], "0.00")
        XCTAssertEqual(event.parameters["duration_sec"], "0")
    }

    func test_factory_lessonAttempted_correct() {
        let event = AnalyticsEvent.lessonAttempted(word: "рак", isCorrect: true, score: 0.91)
        XCTAssertEqual(event.name, "lesson_attempted")
        XCTAssertEqual(event.parameters["word"], "рак")
        XCTAssertEqual(event.parameters["is_correct"], "1")
        XCTAssertEqual(event.parameters["score"], "0.91")
    }

    func test_factory_lessonAttempted_incorrect() {
        let event = AnalyticsEvent.lessonAttempted(word: "лак", isCorrect: false, score: 0.2)
        XCTAssertEqual(event.parameters["is_correct"], "0")
        XCTAssertEqual(event.parameters["score"], "0.20")
    }

    func test_factory_rewardEarned() {
        let event = AnalyticsEvent.rewardEarned(type: "sticker", rewardId: "star-01")
        XCTAssertEqual(event.name, "reward_earned")
        XCTAssertEqual(event.parameters["type"], "sticker")
        XCTAssertEqual(event.parameters["reward_id"], "star-01")
    }

    func test_factory_demoModeEntered_noParameters() {
        let event = AnalyticsEvent.demoModeEntered()
        XCTAssertEqual(event.name, "demo_mode_entered")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    func test_factory_onboardingCompleted_carriesRole() {
        let event = AnalyticsEvent.onboardingCompleted(role: "parent")
        XCTAssertEqual(event.name, "onboarding_completed")
        XCTAssertEqual(event.parameters["role"], "parent")
    }

    func test_factory_eventsTrackableThroughLiveService() {
        let live = LiveAnalyticsService()
        live.track(event: .sessionStarted(childId: "c1", sound: "С", template: "bingo"))
        live.track(event: .demoModeEntered())
        live.track(event: .onboardingCompleted(role: "child"))
    }
}
