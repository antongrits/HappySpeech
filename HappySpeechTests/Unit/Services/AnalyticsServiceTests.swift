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
}
