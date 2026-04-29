@testable import HappySpeech
import XCTest

// MARK: - HealthKitServiceTests
//
// Покрывает MockHealthKitService — используется в preview и unit-тестах.
// LiveHealthKitService не тестируется напрямую: требует HK entitlement + устройство.

final class HealthKitServiceTests: XCTestCase {

    // MARK: - isAvailable

    func test_mock_isAvailable_returnsTrue() {
        let sut = MockHealthKitService()
        XCTAssertTrue(sut.isAvailable())
    }

    // MARK: - isAuthorized

    func test_mock_isAuthorized_defaultTrue() async {
        let sut = MockHealthKitService()
        let authorized = await sut.isAuthorized()
        XCTAssertTrue(authorized)
    }

    func test_mock_isAuthorized_whenSimulateAuthorizedFalse() async {
        let sut = MockHealthKitService()
        await sut.setSimulateAuthorized(false)
        let authorized = await sut.isAuthorized()
        XCTAssertFalse(authorized)
    }

    // MARK: - requestAuthorization

    func test_mock_requestAuthorization_setsAuthorizedTrue() async throws {
        let sut = MockHealthKitService()
        await sut.setSimulateAuthorized(false)
        try await sut.requestAuthorization()
        let authorized = await sut.isAuthorized()
        XCTAssertTrue(authorized)
    }

    func test_mock_requestAuthorization_incrementsCounter() async throws {
        let sut = MockHealthKitService()
        try await sut.requestAuthorization()
        try await sut.requestAuthorization()
        let count = await sut.authorizationRequestCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - logMindfulSession

    func test_mock_logMindfulSession_appendsToSavedSessions() async throws {
        let sut = MockHealthKitService()
        let start = Date(timeIntervalSinceNow: -300)
        let end = Date()
        try await sut.logMindfulSession(start: start, end: end, sessionType: .breathing)
        let sessions = await sut.savedSessions
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].0, .breathing)
        XCTAssertEqual(sessions[0].1, start, accuracy: 0.001)
        XCTAssertEqual(sessions[0].2, end, accuracy: 0.001)
    }

    func test_mock_logMindfulSession_stutteringPractice() async throws {
        let sut = MockHealthKitService()
        let start = Date(timeIntervalSinceNow: -120)
        let end = Date()
        try await sut.logMindfulSession(start: start, end: end, sessionType: .stutteringPractice)
        let sessions = await sut.savedSessions
        XCTAssertEqual(sessions[0].0, .stutteringPractice)
    }

    func test_mock_logMindfulSession_throwsWhenNotAuthorized() async {
        let sut = MockHealthKitService()
        await sut.setSimulateAuthorized(false)
        do {
            try await sut.logMindfulSession(start: Date(), end: Date(), sessionType: .breathing)
            XCTFail("Expected HealthKitError.notAuthorized")
        } catch let error as HealthKitError {
            XCTAssertEqual(error, .notAuthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_mock_logMindfulSession_multipleSessions_allSaved() async throws {
        let sut = MockHealthKitService()
        for _ in 0..<5 {
            try await sut.logMindfulSession(start: Date(), end: Date(), sessionType: .breathing)
        }
        let sessions = await sut.savedSessions
        XCTAssertEqual(sessions.count, 5)
    }

    // MARK: - reset

    func test_mock_reset_clearsSavedSessions() async throws {
        let sut = MockHealthKitService()
        try await sut.logMindfulSession(start: Date(), end: Date(), sessionType: .breathing)
        await sut.reset()
        let sessions = await sut.savedSessions
        XCTAssertTrue(sessions.isEmpty)
    }

    func test_mock_reset_resetsAuthorizationCount() async throws {
        let sut = MockHealthKitService()
        try await sut.requestAuthorization()
        await sut.reset()
        let count = await sut.authorizationRequestCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - MindfulSessionType

    func test_mindfulSessionType_rawValues_areUnique() {
        let values = Set(MindfulSessionType.allCases.map(\.rawValue))
        XCTAssertEqual(values.count, MindfulSessionType.allCases.count)
    }

    func test_mindfulSessionType_rawValues() {
        XCTAssertEqual(MindfulSessionType.breathing.rawValue, "breathing")
        XCTAssertEqual(MindfulSessionType.stutteringPractice.rawValue, "stutteringPractice")
        XCTAssertEqual(MindfulSessionType.meditation.rawValue, "meditation")
    }

    // MARK: - HealthKitError

    func test_healthKitError_notAvailable_localizedDescription_notNil() {
        let error = HealthKitError.notAvailable
        XCTAssertNotNil(error.errorDescription)
    }

    func test_healthKitError_notAuthorized_localizedDescription_notNil() {
        let error = HealthKitError.notAuthorized
        XCTAssertNotNil(error.errorDescription)
    }
}

// MARK: - MockHealthKitService Test Helpers

extension MockHealthKitService {
    func setSimulateAuthorized(_ value: Bool) async {
        simulateAuthorized = value
    }
}

// MARK: - HealthKitError Equatable

extension HealthKitError: Equatable {
    public static func == (lhs: HealthKitError, rhs: HealthKitError) -> Bool {
        switch (lhs, rhs) {
        case (.notAvailable, .notAvailable): return true
        case (.notAuthorized, .notAuthorized): return true
        default: return false
        }
    }
}

// MARK: - XCTAssertEqual for Date with accuracy

private func XCTAssertEqual(
    _ expression1: Date,
    _ expression2: Date,
    accuracy: TimeInterval,
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertEqual(
        expression1.timeIntervalSinceReferenceDate,
        expression2.timeIntervalSinceReferenceDate,
        accuracy: accuracy,
        file: file,
        line: line
    )
}
