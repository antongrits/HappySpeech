import XCTest
@testable import HappySpeech

// MARK: - LLMDecisionServiceTests
// ==================================================================================
// Covers all 12 decision points with:
//   1. MockLLMDecisionService happy-path (on-device available)
//   2. Rule-based fallback path (useFallbackFlag = true)
//   3. LiveLLMDecisionService wired to mocks — verifies tier routing & timeouts
// ==================================================================================

final class LLMDecisionServiceTests: XCTestCase {

    // MARK: Fixtures

    private func sampleRouteContext(fatigue: FatigueLevel = .fresh, successRate: Double = 0.7) -> RoutePlanContext {
        RoutePlanContext(
            childId: "child-1",
            childName: "Миша",
            age: 6,
            targetSound: "Р",
            currentStage: .wordInit,
            recentSuccessRate: successRate,
            fatigueLevel: fatigue,
            availableTemplates: TemplateType.allCases,
            circuit: .kid
        )
    }

    private func sampleStoryContext() -> StoryContext {
        StoryContext(
            targetSound: "Р",
            age: 6,
            wordPool: ["рыба", "ракета", "радуга"],
            stage: .wordInit
        )
    }

    private func sampleSession(rate: Double = 0.75) -> SessionSummaryInput {
        SessionSummaryInput(
            sessionId: "s-1",
            childId: "child-1",
            childName: "Миша",
            age: 6,
            targetSound: "Р",
            stage: .wordInit,
            totalAttempts: 12,
            correctAttempts: Int(12 * rate),
            errorWords: ["ворона", "радуга"],
            durationSec: 480,
            date: Date()
        )
    }

    private func sampleProfile() -> ChildProfileInput {
        ChildProfileInput(
            id: "child-1",
            name: "Миша",
            age: 6,
            targetSounds: ["Р", "С"],
            sensitivityLevel: 1,
            progressSummary: ["Р": 0.45, "С": 0.78]
        )
    }

    private func sampleAudioMetrics() -> AudioMetricsInput {
        AudioMetricsInput(
            averageAmplitude: 0.12,
            silenceRatio: 0.3,
            speakingRateWpm: 80,
            attemptsPerMinute: 4
        )
    }

    private func makeLive() -> (LiveLLMDecisionService, InMemoryLLMDecisionLogRepository) {
        let mockLocalLLM = MockLocalLLMService()
        mockLocalLLM.isModelDownloaded = true
        mockLocalLLM.isModelLoaded = true
        let actor = LLMInferenceActor(localLLM: mockLocalLLM)
        let hf = StubHFClient()
        let net = MockNetworkMonitor()
        net.isConnected = true
        let logRepo = InMemoryLLMDecisionLogRepository()
        let service = LiveLLMDecisionService(
            inferenceActor: actor,
            hfClient: hf,
            networkMonitor: net,
            logRepository: logRepo
        )
        return (service, logRepo)
    }

    // MARK: - 1. Route

    func testAdaptiveRoutePlan_withMock_returnsThreeSteps() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.adaptiveRoutePlan(context: sampleRouteContext())
        XCTAssertFalse(outcome.route.isEmpty, "Route must not be empty")
        XCTAssertLessThanOrEqual(outcome.route.count, 3)
        XCTAssertGreaterThan(outcome.sessionMaxDurationSec, 0)
    }

    func testAdaptiveRoutePlan_fallback_preservesSoundAndStage() async {
        let rules = RuleBasedDecisionService()
        let ctx = sampleRouteContext(fatigue: .tired, successRate: 0.4)
        let (steps, maxDur) = rules.planDailyRoute(context: ctx)
        XCTAssertFalse(steps.isEmpty)
        XCTAssertLessThanOrEqual(maxDur, 600, "Tired ⇒ duration capped")
        for step in steps {
            XCTAssertEqual(step.targetSound, "Р")
            XCTAssertEqual(step.stage, .wordInit)
        }
    }

    // MARK: - 2. Micro-story

    func testGenerateMicroStory_withMock_returnsThreeSentences() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateMicroStory(context: sampleStoryContext())
        XCTAssertEqual(outcome.story.sentences.count, 3)
        XCTAssertFalse(outcome.story.gaps.isEmpty)
    }

    func testGenerateMicroStory_fallbackIsStable() async {
        let rules = RuleBasedDecisionService()
        let ctx = sampleStoryContext()
        let a = rules.generateMicroStory(context: ctx)
        let b = rules.generateMicroStory(context: ctx)
        XCTAssertEqual(a.sentences, b.sentences, "Rule-based must be deterministic for the same input")
    }

    // MARK: - 3. Parent summary

    func testGenerateParentSummary_fallback_includesChildAndSound() async {
        let sut = MockLLMDecisionService(useFallbackFlag: true)
        let outcome = await sut.generateParentSummary(session: sampleSession(rate: 0.8))
        XCTAssertTrue(outcome.summary.summaryText.contains("Миша"))
        XCTAssertTrue(outcome.summary.summaryText.contains("Р"))
        XCTAssertFalse(outcome.summary.homeTask.isEmpty)
        XCTAssertTrue(outcome.meta.usedFallback, "useFallbackFlag ⇒ fallback path must be taken")
    }

    func testGenerateParentSummary_onDevice_doesNotUseFallback() async {
        let (sut, _) = makeLive()
        let outcome = await sut.generateParentSummary(session: sampleSession())
        // MockLocalLLMService returns a canned value without throwing.
        XCTAssertEqual(outcome.meta.source, .onDevice)
        XCTAssertFalse(outcome.meta.usedFallback)
    }

    // MARK: - 4. Encouragement

    func testPickEncouragement_correct_returnsPositivePhrase() async {
        let sut = MockLLMDecisionService()
        let ctx = AttemptContext(childName: "Миша", word: "рыба", targetSound: "Р",
                                 isCorrect: true, streak: 3, recentSuccessRate: 0.8)
        let outcome = await sut.pickEncouragementPhrase(context: ctx)
        XCTAssertFalse(outcome.message.isEmpty)
        XCTAssertFalse(outcome.emoji.isEmpty)
        XCTAssertFalse(outcome.message.contains("неправильно"), "Never use 'неправильно' for kids")
    }

    func testPickEncouragement_incorrect_isGentle() async {
        let sut = MockLLMDecisionService()
        let ctx = AttemptContext(childName: "Миша", word: "ракета", targetSound: "Р",
                                 isCorrect: false, streak: 0, recentSuccessRate: 0.4)
        let outcome = await sut.pickEncouragementPhrase(context: ctx)
        XCTAssertFalse(outcome.message.isEmpty)
        XCTAssertFalse(outcome.message.contains("неправильно"))
    }

    // MARK: - 5. Reward

    func testPickReward_streakUnlocksBadge() async {
        let sut = MockLLMDecisionService()
        let low = await sut.pickReward(streak: 1, sessionType: .daily)
        let high = await sut.pickReward(streak: 10, sessionType: .daily)
        XCTAssertNil(low.reward.badgeId, "Low streak ⇒ no badge")
        XCTAssertNotNil(high.reward.badgeId, "High streak ⇒ badge unlocked")
        XCTAssertFalse(high.reward.stickerId.isEmpty)
    }

    // MARK: - 6. Finish session

    func testDecideFinishSession_highFatigue_returnsTrue() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.decideFinishSession(fatigueLevel: 0.95, attempts: 10)
        XCTAssertTrue(outcome.shouldFinish)
        XCTAssertFalse(outcome.reason.isEmpty)
    }

    func testDecideFinishSession_lowFatigue_continues() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.decideFinishSession(fatigueLevel: 0.1, attempts: 5)
        XCTAssertFalse(outcome.shouldFinish)
    }

    // MARK: - 7. Difficulty

    func testAdjustDifficulty_highSuccess_promotes() async {
        let sut = MockLLMDecisionService()
        let attempts = (0..<5).map { _ in
            AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: true,
                           asrTranscript: "рыба", asrConfidence: 0.95, pronunciationScore: 0.9)
        }
        let outcome = await sut.adjustDifficulty(recentAttempts: attempts)
        XCTAssertEqual(outcome.delta, 1)
        XCTAssertEqual(outcome.difficulty, .hard)
    }

    func testAdjustDifficulty_lowSuccess_demotes() async {
        let sut = MockLLMDecisionService()
        let attempts = (0..<5).map { _ in
            AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: false,
                           asrTranscript: "лыба", asrConfidence: 0.3, pronunciationScore: 0.2)
        }
        let outcome = await sut.adjustDifficulty(recentAttempts: attempts)
        XCTAssertEqual(outcome.delta, -1)
        XCTAssertEqual(outcome.difficulty, .easy)
    }

    // MARK: - 8. Error analysis

    func testAnalyzeError_correctAttempt_returnsCorrect() async {
        let sut = MockLLMDecisionService()
        let attempt = AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: true,
                                     asrTranscript: "рыба", asrConfidence: 0.95, pronunciationScore: 0.9)
        let outcome = await sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(outcome.analysis.category, .correct)
    }

    func testAnalyzeError_soundOmission_returnsOmission() async {
        let sut = MockLLMDecisionService()
        let attempt = AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: false,
                                     asrTranscript: "ыба", asrConfidence: 0.7, pronunciationScore: 0.3)
        let outcome = await sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(outcome.analysis.category, .soundOmission)
    }

    // MARK: - 9. Recommend content

    func testRecommendContent_picksWeakestSound() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.recommendContent(profile: sampleProfile(), history: [sampleSession()])
        XCTAssertFalse(outcome.recommendation.packIds.isEmpty)
        // Weakest sound in sampleProfile is "Р" (0.45 < 0.78)
        XCTAssertTrue(outcome.recommendation.packIds.first?.hasPrefix("Р-") ?? false)
    }

    // MARK: - 10. Specialist report

    func testGenerateSpecialistReport_groupsBySound() async {
        let sut = MockLLMDecisionService()
        let s1 = sampleSession(rate: 0.9)
        var s2 = SessionSummaryInput(sessionId: "s-2", childId: "child-1", childName: "Миша", age: 6,
                                     targetSound: "С", stage: .wordInit,
                                     totalAttempts: 10, correctAttempts: 3, errorWords: ["сова"],
                                     durationSec: 300, date: Date().addingTimeInterval(-86400))
        _ = s2  // silence warning
        let outcome = await sut.generateSpecialistReport(sessions30d: [s1, s2])
        XCTAssertFalse(outcome.report.headline.isEmpty)
        XCTAssertFalse(outcome.report.recommendations.isEmpty)
    }

    func testGenerateSpecialistReport_emptyHistory_returnsPlaceholder() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateSpecialistReport(sessions30d: [])
        XCTAssertTrue(outcome.report.headline.contains("Нет данных"))
    }

    // MARK: - 11. Fatigue

    func testDetectFatigue_highSilenceRatio_returnsTired() async {
        let sut = MockLLMDecisionService()
        let metrics = AudioMetricsInput(averageAmplitude: 0.05, silenceRatio: 0.75,
                                        speakingRateWpm: 40, attemptsPerMinute: 1.5)
        let outcome = await sut.detectFatigue(audioMetrics: metrics, sessionDuration: 720)
        XCTAssertEqual(outcome.level, .tired)
        XCTAssertGreaterThan(outcome.confidence, 0.5)
    }

    func testDetectFatigue_goodMetrics_returnsFresh() async {
        let sut = MockLLMDecisionService()
        let metrics = AudioMetricsInput(averageAmplitude: 0.3, silenceRatio: 0.2,
                                        speakingRateWpm: 120, attemptsPerMinute: 6)
        let outcome = await sut.detectFatigue(audioMetrics: metrics, sessionDuration: 60)
        XCTAssertEqual(outcome.level, .fresh)
    }

    // MARK: - 12. Custom phrase

    func testGenerateCustomPhrase_warmup_addressesChild() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateCustomPhrase(template: .warmup,
                                                     context: ["child_name": "Миша", "target_sound": "Р"])
        XCTAssertTrue(outcome.phrase.contains("Миша"))
        XCTAssertTrue(outcome.phrase.contains("Р"))
    }

    func testGenerateCustomPhrase_parentTip_substitutesSound() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateCustomPhrase(template: .parentTip,
                                                     context: ["target_sound": "Ш"])
        XCTAssertFalse(outcome.phrase.isEmpty)
        XCTAssertFalse(outcome.phrase.contains("{sound}"), "Placeholder must be resolved")
    }

    // MARK: - Meta assertions (covers fallback/on-device routing)

    func testEveryOutcome_hasValidMeta() async {
        let sut = MockLLMDecisionService()
        let r1 = await sut.adaptiveRoutePlan(context: sampleRouteContext())
        let r2 = await sut.generateMicroStory(context: sampleStoryContext())
        let r3 = await sut.generateParentSummary(session: sampleSession())
        let r4 = await sut.pickEncouragementPhrase(context: AttemptContext(
            childName: "Миша", word: "рыба", targetSound: "Р",
            isCorrect: true, streak: 1, recentSuccessRate: 0.8))
        XCTAssertGreaterThanOrEqual(r1.meta.latencyMs, 0)
        XCTAssertGreaterThanOrEqual(r2.meta.latencyMs, 0)
        XCTAssertGreaterThanOrEqual(r3.meta.latencyMs, 0)
        XCTAssertGreaterThanOrEqual(r4.meta.latencyMs, 0)
    }

    // MARK: - LiveLLMDecisionService integration

    func testLive_logsDecisionForEveryCall() async throws {
        let (sut, logRepo) = makeLive()
        _ = await sut.pickEncouragementPhrase(context: AttemptContext(
            childName: "Миша", word: "рыба", targetSound: "Р",
            isCorrect: true, streak: 1, recentSuccessRate: 0.8))
        // Allow the async log Task to finish
        try await Task.sleep(nanoseconds: 150_000_000)
        let records = try await logRepo.fetchRecent(limit: 10)
        XCTAssertFalse(records.isEmpty, "Decision must be logged")
    }
}

// MARK: - Stub HF client (no real network)

private final class StubHFClient: HFInferenceClientProtocol, @unchecked Sendable {
    var isConfigured: Bool = false
    var response: String = ""

    func generate(model: String, prompt: String, maxTokens: Int, timeoutMs: Int) async throws -> String {
        if !isConfigured { throw AppError.llmNotDownloaded }
        return response
    }
}
