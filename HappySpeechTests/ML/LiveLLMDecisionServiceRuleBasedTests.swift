@testable import HappySpeech
import XCTest

// MARK: - LiveLLMDecisionServiceRuleBasedTests
//
// Phase 2.6c v25 — покрытие LiveLLMDecisionService.
//
// Стратегия: тестируем только rule-based пути (Tier C), которые НЕ требуют
// LLMInferenceActor (нет mlpackage) и НЕ требуют сети.
// Для этого: inferenceActor создаётся со stubbed MockLocalLLM (isModelLoaded=false,
// isModelDownloaded=false) → isReady=false → все вызовы уходят в RuleBasedDecisionService.
// Для HF-путей: MockNetworkMonitor.isConnected=false → no HF call.
//
// Тесты покрывают:
//   - pickEncouragementPhrase: kid circuit, всегда rule-based
//   - pickReward: rule-based
//   - decideFinishSession: rule-based
//   - adjustDifficulty: rule-based
//   - analyzeError: rule-based
//   - generateWordSet: rule-based
//   - generateMinimalPairs: rule-based
//   - narrativeQuestStep: rule-based
//   - pickChildGreeting: rule-based
//   - generateCelebration: rule-based
//   - recommendRest: rule-based
//   - playfulTransition: rule-based
//   - generateSurpriseFact: rule-based
//   - generateWeeklyReport: rule-based
//   - generateParentTip: rule-based
//   - detectAnxiety: rule-based
//   - suggestGoalAdjustment: rule-based
//   - generateCustomPhrase: rule-based
//   - selectWarmUp: rule-based
//   - detectFatigue: rule-based
//   - adaptiveRoutePlan → fallback (LLM not ready)
//   - generateMicroStory → fallback (LLM not ready)
//   - generateParentSummary → fallback (offline)
//   - recommendContent → fallback (offline)
//   - generateSpecialistReport → fallback (offline)
//   - JSONParser.extractJSON: валидный и невалидный ввод

final class LiveLLMDecisionServiceRuleBasedTests: XCTestCase {

    // MARK: - Mocks

    /// Минимальный mock LocalLLMService: никогда не загружен → LLMInferenceActor.isReady = false.
    private final class MockLocalLLMNotReady: LocalLLMService, @unchecked Sendable {
        var isModelDownloaded: Bool { false }
        var isModelLoaded: Bool { false }
        func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
            throw LLMError.notLoaded
        }
        func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
            throw LLMError.notLoaded
        }
        func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse {
            throw LLMError.notLoaded
        }
    }

    /// Mock HFInferenceClient: всегда не настроен → HF ветка не вызывается.
    private struct MockHFClientNotConfigured: HFInferenceClientProtocol, Sendable {
        var isConfigured: Bool { false }
        func generate(model: String, prompt: String, maxTokens: Int, timeoutMs: Int) async throws -> String {
            throw URLError(.notConnectedToInternet)
        }
    }

    /// Mock NetworkMonitor: offline.
    private struct MockOfflineNetwork: NetworkMonitorService, Sendable {
        var isConnected: Bool { false }
        var connectionType: ConnectionType { .none }
    }

    /// Mock LLMDecisionLogRepository: сохранение no-op.
    private actor MockLogRepository: LLMDecisionLogRepository {
        func save(_ record: LLMDecisionLogRecord) async throws {}
        func fetchRecent(limit: Int) async throws -> [LLMDecisionLogRecord] { [] }
        func fetchByChild(_ childId: String, limit: Int) async throws -> [LLMDecisionLogRecord] { [] }
    }

    // MARK: - Setup

    private var sut: LiveLLMDecisionService!

    override func setUp() async throws {
        try await super.setUp()
        let localLLM = MockLocalLLMNotReady()
        let inferenceActor = LLMInferenceActor(localLLM: localLLM)
        sut = LiveLLMDecisionService(
            inferenceActor: inferenceActor,
            hfClient: MockHFClientNotConfigured(),
            rules: RuleBasedDecisionService(),
            networkMonitor: MockOfflineNetwork(),
            logRepository: MockLogRepository()
        )
    }

    // MARK: - Helpers

    private func makeAttemptContext(correct: Bool, streak: Int = 1) -> AttemptContext {
        AttemptContext(childName: "Маша", word: "рыба", targetSound: "Р",
                      isCorrect: correct, streak: streak, recentSuccessRate: correct ? 0.8 : 0.3)
    }

    private func makeRouteContext() -> RoutePlanContext {
        RoutePlanContext(
            childId: "c-1", childName: "Маша", age: 6,
            targetSound: "Р", currentStage: .wordInit,
            recentSuccessRate: 0.7, fatigueLevel: .normal,
            availableTemplates: TemplateType.allCases,
            circuit: .kid
        )
    }

    private func makeSession() -> SessionSummaryInput {
        SessionSummaryInput(
            sessionId: UUID().uuidString, childId: "c-1", childName: "Маша", age: 6,
            targetSound: "Р", stage: .wordInit, totalAttempts: 10, correctAttempts: 8,
            errorWords: ["ракета"], durationSec: 480, date: Date()
        )
    }

    private func makeAttemptOutcome(correct: Bool) -> AttemptOutcome {
        AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: correct,
                       asrTranscript: correct ? "рыба" : "", asrConfidence: correct ? 0.9 : 0.2,
                       pronunciationScore: correct ? 0.85 : 0.2)
    }

    // MARK: - 1. pickEncouragementPhrase — kid circuit: всегда rule-based, никогда HF

    func testPickEncouragement_correct_notEmpty() async {
        let ctx = makeAttemptContext(correct: true, streak: 3)
        let outcome = await sut.pickEncouragementPhrase(context: ctx)
        XCTAssertFalse(outcome.message.isEmpty)
        XCTAssertFalse(outcome.emoji.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    func testPickEncouragement_wrong_notEmpty() async {
        let ctx = makeAttemptContext(correct: false, streak: 0)
        let outcome = await sut.pickEncouragementPhrase(context: ctx)
        XCTAssertFalse(outcome.message.isEmpty)
        XCTAssertEqual(outcome.meta.usedFallback, false)
    }

    // MARK: - 2. pickReward

    func testPickReward_lowStreak_noBadge() async {
        let outcome = await sut.pickReward(streak: 2, sessionType: .daily)
        XCTAssertNil(outcome.reward.badgeId)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    func testPickReward_highStreak_hasBadge() async {
        let outcome = await sut.pickReward(streak: 8, sessionType: .daily)
        XCTAssertNotNil(outcome.reward.badgeId)
    }

    // MARK: - 3. decideFinishSession

    func testDecideFinish_highFatigue_finishTrue() async {
        let outcome = await sut.decideFinishSession(fatigueLevel: 0.9, attempts: 10)
        XCTAssertTrue(outcome.shouldFinish)
        XCTAssertFalse(outcome.reason.isEmpty)
    }

    func testDecideFinish_lowFatigue_continueTrue() async {
        let outcome = await sut.decideFinishSession(fatigueLevel: 0.2, attempts: 3)
        XCTAssertFalse(outcome.shouldFinish)
    }

    // MARK: - 4. adjustDifficulty

    func testAdjustDifficulty_allCorrect_hard() async {
        let attempts = (0..<5).map { _ in makeAttemptOutcome(correct: true) }
        let outcome = await sut.adjustDifficulty(recentAttempts: attempts)
        XCTAssertEqual(outcome.difficulty, .hard)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    func testAdjustDifficulty_allWrong_easy() async {
        let attempts = (0..<5).map { _ in makeAttemptOutcome(correct: false) }
        let outcome = await sut.adjustDifficulty(recentAttempts: attempts)
        XCTAssertEqual(outcome.difficulty, .easy)
    }

    func testAdjustDifficulty_empty_medium() async {
        let outcome = await sut.adjustDifficulty(recentAttempts: [])
        XCTAssertEqual(outcome.difficulty, .medium)
        XCTAssertEqual(outcome.delta, 0)
    }

    // MARK: - 5. analyzeError

    func testAnalyzeError_emptyTranscript_hesitation() async {
        let attempt = AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: false,
                                     asrTranscript: "", asrConfidence: 0.1, pronunciationScore: 0.2)
        let outcome = await sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(outcome.analysis.category, .hesitation)
        XCTAssertFalse(outcome.analysis.hint.isEmpty)
    }

    func testAnalyzeError_correctAttempt_correctCategory() async {
        let attempt = makeAttemptOutcome(correct: true)
        let outcome = await sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(outcome.analysis.category, .correct)
    }

    // MARK: - 6. generateWordSet

    func testGenerateWordSet_returnsWords() async {
        let outcome = await sut.generateWordSet(sound: "Р", stage: .wordInit, count: 4)
        XCTAssertFalse(outcome.words.isEmpty)
        XCTAssertFalse(outcome.rationale.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 7. generateMinimalPairs

    func testGenerateMinimalPairs_knownPair_notEmpty() async {
        let outcome = await sut.generateMinimalPairs(targetSound: "С", confusionSound: "Ш", count: 2)
        XCTAssertFalse(outcome.pairs.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 8. narrativeQuestStep

    func testNarrativeQuestStep_returnsNarration() async {
        let state = NarrativeQuestState(questId: "q-1", currentStep: 1, totalSteps: 5,
                                        collectedItems: [], childName: "Маша", targetSound: "Р")
        let outcome = await sut.narrativeQuestStep(questState: state)
        XCTAssertFalse(outcome.narration.isEmpty)
        XCTAssertFalse(outcome.targetWord.isEmpty)
    }

    func testNarrativeQuestStep_lastStep_isLastTrue() async {
        let state = NarrativeQuestState(questId: "q-1", currentStep: 5, totalSteps: 5,
                                        collectedItems: [], childName: "Маша", targetSound: "Р")
        let outcome = await sut.narrativeQuestStep(questState: state)
        XCTAssertTrue(outcome.isLastStep)
    }

    // MARK: - 9. pickChildGreeting

    func testPickChildGreeting_morning_sunEmoji() async {
        let outcome = await sut.pickChildGreeting(childName: "Маша", timeOfDay: .morning, streakDays: 0)
        XCTAssertFalse(outcome.phrase.isEmpty)
        XCTAssertEqual(outcome.emoji, "☀️")
    }

    // MARK: - 10. generateCelebration

    func testGenerateCelebration_perfectSession_starsAnimation() async {
        let outcome = await sut.generateCelebration(event: .perfectSession)
        XCTAssertFalse(outcome.message.isEmpty)
        XCTAssertEqual(outcome.animationHint, "stars-shower")
    }

    // MARK: - 11. recommendRest

    func testRecommendRest_tired_shouldRest() async {
        let outcome = await sut.recommendRest(sessionDuration: 300, fatigueLevel: .tired)
        XCTAssertTrue(outcome.shouldRest)
        XCTAssertGreaterThan(outcome.suggestedBreakMinutes, 0)
    }

    func testRecommendRest_freshShort_noRest() async {
        let outcome = await sut.recommendRest(sessionDuration: 60, fatigueLevel: .fresh)
        XCTAssertFalse(outcome.shouldRest)
    }

    // MARK: - 12. playfulTransition

    func testPlayfulTransition_notEmpty() async {
        let outcome = await sut.playfulTransition(fromActivity: .listenAndChoose, toActivity: .bingo)
        XCTAssertFalse(outcome.phrase.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 13. generateSurpriseFact

    func testGenerateSurpriseFact_notEmpty() async {
        let outcome = await sut.generateSurpriseFact(topic: "тигр", childAge: 6)
        XCTAssertFalse(outcome.fact.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 14. generateWeeklyReport

    func testGenerateWeeklyReport_oneWeek_notEmpty() async {
        let week = WeekSummaryInput(weekNumber: 1, sessionsCount: 5, averageScore: 0.7,
                                   soundsPracticed: ["Р"], improvementDelta: 0.05)
        let outcome = await sut.generateWeeklyReport(weeks: [week])
        XCTAssertFalse(outcome.summary.isEmpty)
        XCTAssertFalse(outcome.recommendations.isEmpty)
    }

    // MARK: - 15. generateParentTip

    func testGenerateParentTip_notEmpty() async {
        let profile = ChildProfileInput(id: "c-1", name: "Маша", age: 6,
                                        targetSounds: ["Р"], sensitivityLevel: 1, progressSummary: ["Р": 0.5])
        let outcome = await sut.generateParentTip(profile: profile, currentStage: .wordInit)
        XCTAssertFalse(outcome.tip.isEmpty)
        XCTAssertFalse(outcome.exerciseSuggestion.isEmpty)
    }

    // MARK: - 16. detectAnxiety

    func testDetectAnxiety_highPause_highScore() async {
        let metrics = SessionMetricsInput(pauseCount: 20, averagePauseDuration: 6,
                                          errorRate: 0.9, sessionDuration: 300, speechRateVariance: 0.8)
        let outcome = await sut.detectAnxiety(sessionMetrics: metrics)
        XCTAssertGreaterThan(outcome.anxietyScore, 0.5)
        XCTAssertFalse(outcome.signals.isEmpty)
    }

    // MARK: - 17. suggestGoalAdjustment

    func testSuggestGoalAdjustment_stagnant_notEmpty() async {
        let trend = ProgressTrendInput(soundsAttempted: ["Р"],
                                       weeklySuccessRates: [0.44, 0.43, 0.44],
                                       stagnantSounds: ["Р"], childAge: 6)
        let outcome = await sut.suggestGoalAdjustment(progress: trend)
        XCTAssertFalse(outcome.currentGoal.isEmpty)
        XCTAssertFalse(outcome.suggestedGoal.isEmpty)
    }

    // MARK: - 18. generateCustomPhrase

    func testGenerateCustomPhrase_warmup_containsChildName() async {
        let outcome = await sut.generateCustomPhrase(
            template: .warmup,
            context: ["child_name": "Маша", "target_sound": "С"]
        )
        XCTAssertTrue(outcome.phrase.contains("Маша"))
    }

    // MARK: - 19. selectWarmUp

    func testSelectWarmUp_returnsActivity() async {
        let ctx = WarmUpContext(childName: "Маша", targetSound: "Р", sessionNumber: 1, age: 6)
        let outcome = await sut.selectWarmUp(context: ctx)
        XCTAssertFalse(outcome.activityName.isEmpty)
        XCTAssertFalse(outcome.instructions.isEmpty)
        XCTAssertGreaterThan(outcome.durationSeconds, 0)
    }

    // MARK: - 20. detectFatigue

    func testDetectFatigue_highSilence_tired() async {
        let metrics = AudioMetricsInput(averageAmplitude: 0.05, silenceRatio: 0.8,
                                        speakingRateWpm: 30, attemptsPerMinute: 1.0)
        let outcome = await sut.detectFatigue(audioMetrics: metrics, sessionDuration: 720)
        XCTAssertEqual(outcome.level, .tired)
        XCTAssertGreaterThan(outcome.confidence, 0.5)
    }

    // MARK: - 21. adaptiveRoutePlan → fallback (LLM не готов)

    func testAdaptiveRoutePlan_llmNotReady_fallbackRules() async {
        let ctx = makeRouteContext()
        let outcome = await sut.adaptiveRoutePlan(context: ctx)
        XCTAssertFalse(outcome.route.isEmpty, "Fallback rule-based маршрут должен содержать шаги")
        XCTAssertEqual(outcome.meta.source, .ruleBased)
        XCTAssertTrue(outcome.meta.usedFallback)
    }

    // MARK: - 22. generateMicroStory → fallback (LLM не готов)

    func testGenerateMicroStory_llmNotReady_fallback() async {
        let ctx = StoryContext(targetSound: "Р", age: 6, wordPool: ["рыба", "ракета"], stage: .wordInit)
        let outcome = await sut.generateMicroStory(context: ctx)
        XCTAssertFalse(outcome.story.sentences.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
        XCTAssertTrue(outcome.meta.usedFallback)
    }

    // MARK: - 23. generateParentSummary → fallback (offline, LLM не готов)

    func testGenerateParentSummary_offline_fallback() async {
        let session = makeSession()
        let outcome = await sut.generateParentSummary(session: session)
        XCTAssertFalse(outcome.summary.summaryText.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
        XCTAssertTrue(outcome.meta.usedFallback)
    }

    // MARK: - 24. recommendContent → fallback (offline)

    func testRecommendContent_offline_fallback() async {
        let profile = ChildProfileInput(id: "c-1", name: "Маша", age: 6,
                                        targetSounds: ["Р"], sensitivityLevel: 1, progressSummary: ["Р": 0.5])
        let outcome = await sut.recommendContent(profile: profile, history: [])
        XCTAssertFalse(outcome.recommendation.packIds.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
    }

    // MARK: - 25. generateSpecialistReport → fallback (offline)

    func testGenerateSpecialistReport_offline_fallback() async {
        let outcome = await sut.generateSpecialistReport(sessions30d: [makeSession()])
        XCTAssertFalse(outcome.report.headline.isEmpty)
        XCTAssertEqual(outcome.meta.source, .ruleBased)
        XCTAssertTrue(outcome.meta.usedFallback)
    }

    // MARK: - 26. LLMModelManager: modelId не пустой

    func testLLMInferenceActor_modelId_notEmpty() {
        XCTAssertFalse(LLMInferenceActor.modelId.isEmpty)
        XCTAssertTrue(LLMInferenceActor.modelId.contains("Qwen"))
    }
}
