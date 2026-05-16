@testable import HappySpeech
import XCTest

// MARK: - BreathingMetricsWorkerTests
//
// Block 2.6a v25 — unit-покрытие BreathingMetricsWorker (Workers).
// LiveBreathingMetricsWorker фиксирует длительность mindful-сессий локально
// (без внешних API). MockBreathingMetricsWorker — no-op дубль для тестов.

@MainActor
final class BreathingMetricsWorkerTests: XCTestCase {

    // MARK: - LiveBreathingMetricsWorker

    func test_live_logSession_appendsToLoggedSessions() async {
        let worker = LiveBreathingMetricsWorker()
        XCTAssertTrue(worker.loggedSessions.isEmpty)

        let start = Date()
        let end = start.addingTimeInterval(30)
        await worker.logSessionIfEnabled(start: start, end: end)

        XCTAssertEqual(worker.loggedSessions.count, 1)
        XCTAssertEqual(worker.loggedSessions.first?.start, start)
        XCTAssertEqual(worker.loggedSessions.first?.end, end)
    }

    func test_live_logSession_multipleSessions_accumulate() async {
        let worker = LiveBreathingMetricsWorker()
        for index in 0..<5 {
            let start = Date().addingTimeInterval(Double(index) * 60)
            await worker.logSessionIfEnabled(start: start, end: start.addingTimeInterval(20))
        }
        XCTAssertEqual(worker.loggedSessions.count, 5)
    }

    func test_live_logSession_preservesDuration() async {
        let worker = LiveBreathingMetricsWorker()
        let start = Date()
        let end = start.addingTimeInterval(45)
        await worker.logSessionIfEnabled(start: start, end: end)

        let logged = worker.loggedSessions.first
        XCTAssertNotNil(logged)
        let duration = logged!.end.timeIntervalSince(logged!.start)
        XCTAssertEqual(duration, 45, accuracy: 0.001)
    }

    // MARK: - MockBreathingMetricsWorker

    func test_mock_logSession_appendsToLoggedSessions() async {
        let worker = MockBreathingMetricsWorker()
        XCTAssertTrue(worker.loggedSessions.isEmpty)

        let start = Date()
        let end = start.addingTimeInterval(10)
        await worker.logSessionIfEnabled(start: start, end: end)

        XCTAssertEqual(worker.loggedSessions.count, 1)
    }

    func test_mock_logSession_multipleCalls_accumulate() async {
        let worker = MockBreathingMetricsWorker()
        await worker.logSessionIfEnabled(start: Date(), end: Date())
        await worker.logSessionIfEnabled(start: Date(), end: Date())
        XCTAssertEqual(worker.loggedSessions.count, 2)
    }

    func test_mock_conformsToProtocol() async {
        let worker: any BreathingMetricsWorkerProtocol = MockBreathingMetricsWorker()
        await worker.logSessionIfEnabled(start: Date(), end: Date())
        // Через протокол вызов не падает.
        XCTAssertTrue(true)
    }
}
