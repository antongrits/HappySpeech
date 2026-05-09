@testable import HappySpeech
import XCTest

// MARK: - RemoteConfigServiceTests
//
// Block V v18 — покрытие MockRemoteConfigService (7 тестов).
// Тестируется поведение протокола RemoteConfigService через Mock-реализацию.
// LiveRemoteConfigService не тестируется напрямую — она требует Firebase SDK.

final class RemoteConfigServiceTests: XCTestCase {

    private func makeSUT() -> MockRemoteConfigService {
        MockRemoteConfigService()
    }

    // MARK: - Feature flags defaults

    func test_defaultFeatureFlags_voiceCloneDisabled() {
        let sut = makeSUT()
        XCTAssertFalse(sut.featureVoiceCloneEnabled)
    }

    func test_defaultFeatureFlags_bodyTrackingEnabled() {
        let sut = makeSUT()
        XCTAssertTrue(sut.featureBodyTrackingEnabled)
    }

    func test_defaultFeatureFlags_seasonalEventsEnabled() {
        let sut = makeSUT()
        XCTAssertTrue(sut.featureSeasonalEventsEnabled)
    }

    // MARK: - Content config defaults

    func test_defaultContentConfig_lyalyaVoiceIsPro() {
        let sut = makeSUT()
        XCTAssertEqual(sut.lyalyaVoiceDefault, "pro")
    }

    func test_defaultContentConfig_dailyReminderTime() {
        let sut = makeSUT()
        XCTAssertEqual(sut.dailyReminderTime, "17:00")
    }

    func test_defaultContentConfig_maxSessionDurationIs25() {
        let sut = makeSUT()
        XCTAssertEqual(sut.maxSessionDurationMin, 25)
    }

    // MARK: - A/B Testing

    func test_defaultTutorialVariant_isA() {
        let sut = makeSUT()
        XCTAssertEqual(sut.tutorialVariant, "A")
    }

    // MARK: - Overrides (DI test)

    func test_overrideVoiceCloneEnabled_propagates() {
        let sut = makeSUT()
        sut.featureVoiceCloneEnabled = true
        XCTAssertTrue(sut.featureVoiceCloneEnabled)
    }

    func test_overrideTutorialVariant_toBPropagates() {
        let sut = makeSUT()
        sut.tutorialVariant = "B"
        XCTAssertEqual(sut.tutorialVariant, "B")
    }

    func test_overrideDemoModeSteps_propagates() {
        let sut = makeSUT()
        sut.demoModeSteps = 5
        XCTAssertEqual(sut.demoModeSteps, 5)
    }

    // MARK: - Version management defaults

    func test_defaultMinAppVersion_is1_0_0() {
        let sut = makeSUT()
        XCTAssertEqual(sut.minAppVersion, "1.0.0")
    }

    // MARK: - fetch / activate (mock no-ops)

    func test_fetch_doesNotThrow() async {
        let sut = makeSUT()
        await XCTAssertNoThrowAsync { try await sut.fetch() }
    }

    func test_activate_returnsFalse() async throws {
        let sut = makeSUT()
        let result = try await sut.activate()
        XCTAssertFalse(result)
    }
}

// MARK: - XCTAssertNoThrowAsync helper

private func XCTAssertNoThrowAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        try await expression()
    } catch {
        XCTFail("Unexpected throw: \(error)", file: file, line: line)
    }
}
