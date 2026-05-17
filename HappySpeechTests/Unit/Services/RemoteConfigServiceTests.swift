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

    // MARK: - Remaining feature-flag defaults

    func test_defaultFeatureFlags_remainingValues() {
        let sut = makeSUT()
        XCTAssertFalse(sut.featureRealtimeLipsyncEnabled)
        XCTAssertTrue(sut.featureSpectrogramEnabled)
        XCTAssertTrue(sut.featureEmotionDetectionEnabled)
        XCTAssertTrue(sut.featureSpeakerVerificationEnabled)
        XCTAssertFalse(sut.featureQwenKidCircuit)
    }

    // MARK: - Remaining content-config defaults

    func test_defaultContentConfig_summaryDays() {
        let sut = makeSUT()
        XCTAssertEqual(sut.weeklySummaryDay, "sunday")
        XCTAssertEqual(sut.parentSummaryDay, "sunday")
    }

    func test_defaultOnboardingConfig_values() {
        let sut = makeSUT()
        XCTAssertTrue(sut.onboardingSkipAllowed)
        XCTAssertEqual(sut.demoModeSteps, 15)
    }

    func test_defaultUIFlags_values() {
        let sut = makeSUT()
        XCTAssertTrue(sut.homeShowStreakCelebration)
        XCTAssertTrue(sut.parentDashboardShowMLInsights)
    }

    func test_defaultVersionManagement_forceUpdateMinVersion() {
        let sut = makeSUT()
        XCTAssertEqual(sut.forceUpdateMinVersion, "1.0.0")
    }

    // MARK: - Overrides — full surface

    func test_overrideFeatureFlags_propagate() {
        let sut = makeSUT()
        sut.featureSeasonalEventsEnabled = false
        sut.featureBodyTrackingEnabled = false
        sut.featureRealtimeLipsyncEnabled = true
        sut.featureSpectrogramEnabled = false
        sut.featureEmotionDetectionEnabled = false
        sut.featureSpeakerVerificationEnabled = false
        sut.featureQwenKidCircuit = true
        XCTAssertFalse(sut.featureSeasonalEventsEnabled)
        XCTAssertFalse(sut.featureBodyTrackingEnabled)
        XCTAssertTrue(sut.featureRealtimeLipsyncEnabled)
        XCTAssertFalse(sut.featureSpectrogramEnabled)
        XCTAssertFalse(sut.featureEmotionDetectionEnabled)
        XCTAssertFalse(sut.featureSpeakerVerificationEnabled)
        XCTAssertTrue(sut.featureQwenKidCircuit)
    }

    func test_overrideContentAndVersionConfig_propagate() {
        let sut = makeSUT()
        sut.lyalyaVoiceDefault = "cute"
        sut.dailyReminderTime = "19:30"
        sut.weeklySummaryDay = "monday"
        sut.parentSummaryDay = "friday"
        sut.maxSessionDurationMin = 30
        sut.minAppVersion = "2.1.0"
        sut.forceUpdateMinVersion = "2.0.0"
        sut.homeShowStreakCelebration = false
        sut.parentDashboardShowMLInsights = false
        sut.onboardingSkipAllowed = false
        XCTAssertEqual(sut.lyalyaVoiceDefault, "cute")
        XCTAssertEqual(sut.dailyReminderTime, "19:30")
        XCTAssertEqual(sut.weeklySummaryDay, "monday")
        XCTAssertEqual(sut.parentSummaryDay, "friday")
        XCTAssertEqual(sut.maxSessionDurationMin, 30)
        XCTAssertEqual(sut.minAppVersion, "2.1.0")
        XCTAssertEqual(sut.forceUpdateMinVersion, "2.0.0")
        XCTAssertFalse(sut.homeShowStreakCelebration)
        XCTAssertFalse(sut.parentDashboardShowMLInsights)
        XCTAssertFalse(sut.onboardingSkipAllowed)
    }

    // MARK: - startRealtimeUpdates (mock no-op)

    func test_startRealtimeUpdates_isSafe() {
        let sut = makeSUT()
        sut.startRealtimeUpdates()
        sut.startRealtimeUpdates()
        // Повторный вызов безопасен — mock no-op.
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
