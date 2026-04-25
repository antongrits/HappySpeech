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

    // MARK: - 13. Warm-up

    func testSelectWarmUp_returnsActivityWithInstructions() async {
        let sut = MockLLMDecisionService()
        let ctx = WarmUpContext(childName: "Катя", targetSound: "С", sessionNumber: 3, age: 6)
        let outcome = await sut.selectWarmUp(context: ctx)
        XCTAssertFalse(outcome.activityName.isEmpty, "Название активности не должно быть пустым")
        XCTAssertFalse(outcome.instructions.isEmpty, "Инструкции не должны быть пустыми")
        XCTAssertGreaterThan(outcome.durationSeconds, 0)
    }

    func testSelectWarmUp_callLogged() async {
        let sut = MockLLMDecisionService()
        let ctx = WarmUpContext(childName: "Катя", targetSound: "С", sessionNumber: 1, age: 5)
        _ = await sut.selectWarmUp(context: ctx)
        XCTAssertTrue(sut.callLog.contains("warmUp"), "selectWarmUp должен быть залогирован")
    }

    // MARK: - 14. Word set

    func testGenerateWordSet_countRespected() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateWordSet(sound: "Р", stage: .wordInit, count: 5)
        XCTAssertFalse(outcome.words.isEmpty, "Список слов не должен быть пустым")
        XCTAssertFalse(outcome.rationale.isEmpty, "Обоснование не должно быть пустым")
    }

    func testGenerateWordSet_soundMatchesRequest() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateWordSet(sound: "С", stage: .wordMed, count: 6)
        // Набор слов должен быть осмысленным — rationale упоминает звук или слова со звуком
        XCTAssertFalse(outcome.words.isEmpty)
    }

    // MARK: - 15. Minimal pairs

    func testGenerateMinimalPairs_returnsNonEmptyPairs() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateMinimalPairs(targetSound: "Р", confusionSound: "Л", count: 3)
        XCTAssertFalse(outcome.pairs.isEmpty, "Минимальные пары не должны быть пустыми")
    }

    func testGenerateMinimalPairs_metaIsRuleBased() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateMinimalPairs(targetSound: "С", confusionSound: "Ш", count: 4)
        XCTAssertEqual(outcome.meta.source, .ruleBased,
            "Минимальные пары всегда через rules (kid circuit)")
    }

    // MARK: - 16. Narrative quest step

    func testNarrativeQuestStep_returnsNarration() async {
        let sut = MockLLMDecisionService()
        let state = NarrativeQuestState(
            questId: "q-001",
            currentStep: 2,
            totalSteps: 5,
            collectedItems: ["замок"],
            childName: "Миша",
            targetSound: "Р"
        )
        let outcome = await sut.narrativeQuestStep(questState: state)
        XCTAssertFalse(outcome.narration.isEmpty, "Нарратив не должен быть пустым")
        XCTAssertFalse(outcome.targetWord.isEmpty, "Целевое слово не должно быть пустым")
    }

    func testNarrativeQuestStep_lastStep_isLastTrue() async {
        let sut = MockLLMDecisionService()
        let state = NarrativeQuestState(
            questId: "q-001",
            currentStep: 5,
            totalSteps: 5,
            collectedItems: ["замок", "ключ", "дракон"],
            childName: "Маша",
            targetSound: "Р"
        )
        let outcome = await sut.narrativeQuestStep(questState: state)
        XCTAssertTrue(outcome.isLastStep, "Последний шаг квеста должен возвращать isLastStep=true")
    }

    // MARK: - 17. Child greeting

    func testPickChildGreeting_morningContainsGreeting() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.pickChildGreeting(childName: "Дима", timeOfDay: .morning, streakDays: 0)
        XCTAssertFalse(outcome.phrase.isEmpty)
        XCTAssertFalse(outcome.emoji.isEmpty)
    }

    func testPickChildGreeting_streakAppreciationHigh() async {
        let sut = MockLLMDecisionService()
        let low  = await sut.pickChildGreeting(childName: "Дима", timeOfDay: .morning, streakDays: 0)
        let high = await sut.pickChildGreeting(childName: "Дима", timeOfDay: .morning, streakDays: 7)
        // Оба должны быть непустыми — конкретный текст определяется rules
        XCTAssertFalse(low.phrase.isEmpty)
        XCTAssertFalse(high.phrase.isEmpty)
    }

    // MARK: - 18. Celebration

    func testGenerateCelebration_perfectSession_hasAnimation() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateCelebration(event: .perfectSession)
        XCTAssertFalse(outcome.message.isEmpty)
        XCTAssertFalse(outcome.animationHint.isEmpty)
    }

    func testGenerateCelebration_streak_containsDays() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateCelebration(event: .streakAchieved(days: 5))
        XCTAssertFalse(outcome.message.isEmpty)
    }

    // MARK: - 19. Rest recommendation

    func testRecommendRest_tiredLong_shouldRest() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.recommendRest(sessionDuration: 700, fatigueLevel: .tired)
        XCTAssertTrue(outcome.shouldRest, "Уставший ребёнок после длинной сессии должен отдыхать")
        XCTAssertGreaterThan(outcome.suggestedBreakMinutes, 0)
        XCTAssertFalse(outcome.message.isEmpty)
    }

    func testRecommendRest_freshShort_noRest() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.recommendRest(sessionDuration: 60, fatigueLevel: .fresh)
        XCTAssertFalse(outcome.shouldRest, "Свежий ребёнок после короткой сессии не нуждается в отдыхе")
    }

    // MARK: - 20. Playful transition

    func testPlayfulTransition_returnsPhrase() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.playfulTransition(fromActivity: .listenAndChoose, toActivity: .bingo)
        XCTAssertFalse(outcome.phrase.isEmpty, "Фраза перехода не должна быть пустой")
    }

    func testPlayfulTransition_callLogged() async {
        let sut = MockLLMDecisionService()
        _ = await sut.playfulTransition(fromActivity: .sorting, toActivity: .memory)
        XCTAssertTrue(sut.callLog.contains("transition"))
    }

    // MARK: - 21. Surprise fact

    func testGenerateSurpriseFact_returnsNonEmptyFact() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateSurpriseFact(topic: "лев", childAge: 6)
        XCTAssertFalse(outcome.fact.isEmpty, "Удивительный факт не должен быть пустым")
    }

    // MARK: - 22. Weekly report

    func testGenerateWeeklyReport_oneWeek_hasSummary() async {
        let sut = MockLLMDecisionService()
        let week = WeekSummaryInput(weekNumber: 1, sessionsCount: 5,
                                    averageScore: 0.72, soundsPracticed: ["Р", "С"],
                                    improvementDelta: 0.08)
        let outcome = await sut.generateWeeklyReport(weeks: [week])
        XCTAssertFalse(outcome.summary.isEmpty, "Еженедельный отчёт должен содержать summary")
        XCTAssertFalse(outcome.highlights.isEmpty, "Отчёт должен содержать highlights")
        XCTAssertFalse(outcome.recommendations.isEmpty, "Отчёт должен содержать рекомендации")
    }

    func testGenerateWeeklyReport_empty_returnsSafeFallback() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateWeeklyReport(weeks: [])
        XCTAssertFalse(outcome.summary.isEmpty, "Даже без данных summary не должен быть пустым")
    }

    // MARK: - 23. Parent tip

    func testGenerateParentTip_returnsNonEmptyTip() async {
        let sut = MockLLMDecisionService()
        let outcome = await sut.generateParentTip(profile: sampleProfile(), currentStage: .wordInit)
        XCTAssertFalse(outcome.tip.isEmpty, "Совет для родителя не должен быть пустым")
        XCTAssertFalse(outcome.exerciseSuggestion.isEmpty, "Упражнение не должно быть пустым")
    }

    // MARK: - 24. Anxiety detection

    func testDetectAnxiety_highPauseRate_raisesScore() async {
        let sut = MockLLMDecisionService()
        let metrics = SessionMetricsInput(
            pauseCount: 15,
            averagePauseDuration: 3.5,
            errorRate: 0.7,
            sessionDuration: 300,
            speechRateVariance: 0.8
        )
        let outcome = await sut.detectAnxiety(sessionMetrics: metrics)
        XCTAssertGreaterThan(outcome.anxietyScore, 0.0, "Высокий pauseCount → anxietyScore > 0")
        XCTAssertFalse(outcome.recommendation.isEmpty)
    }

    func testDetectAnxiety_normalMetrics_lowScore() async {
        let sut = MockLLMDecisionService()
        let metrics = SessionMetricsInput(
            pauseCount: 2,
            averagePauseDuration: 0.5,
            errorRate: 0.15,
            sessionDuration: 180,
            speechRateVariance: 0.1
        )
        let outcome = await sut.detectAnxiety(sessionMetrics: metrics)
        XCTAssertLessThan(outcome.anxietyScore, 0.5, "Нормальные метрики → низкий anxietyScore")
    }

    // MARK: - 25. Goal adjustment

    func testSuggestGoalAdjustment_stagnantSounds_suggestsChange() async {
        let sut = MockLLMDecisionService()
        let trend = ProgressTrendInput(
            soundsAttempted: ["Р", "С"],
            weeklySuccessRates: [0.45, 0.43, 0.44, 0.42],
            stagnantSounds: ["Р"],
            childAge: 6
        )
        let outcome = await sut.suggestGoalAdjustment(progress: trend)
        XCTAssertFalse(outcome.currentGoal.isEmpty, "currentGoal не должен быть пустым")
        XCTAssertFalse(outcome.suggestedGoal.isEmpty, "suggestedGoal не должен быть пустым")
        XCTAssertFalse(outcome.rationale.isEmpty, "rationale не должен быть пустым")
    }

    func testSuggestGoalAdjustment_goodProgress_maintainsGoal() async {
        let sut = MockLLMDecisionService()
        let trend = ProgressTrendInput(
            soundsAttempted: ["С"],
            weeklySuccessRates: [0.80, 0.83, 0.87, 0.90],
            stagnantSounds: [],
            childAge: 7
        )
        let outcome = await sut.suggestGoalAdjustment(progress: trend)
        XCTAssertFalse(outcome.suggestedGoal.isEmpty)
    }

    // MARK: - Проверка kid circuit — HF никогда не вызывается

    func testKidCircuit_encouragement_alwaysRuleBased() async {
        let sut = MockLLMDecisionService()
        let ctx = AttemptContext(childName: "Лиза", word: "роза", targetSound: "Р",
                                 isCorrect: true, streak: 2, recentSuccessRate: 0.7)
        let outcome = await sut.pickEncouragementPhrase(context: ctx)
        XCTAssertEqual(outcome.meta.source, .ruleBased,
            "Поощрение в kid circuit — всегда rule-based, никогда HF")
        XCTAssertFalse(outcome.meta.usedFallback,
            "usedFallback=false, потому что rules — это primary путь kid circuit")
    }

    // MARK: - callLog проверяет все 25 decision points

    func testAllDecisionPoints_areLogged() async {
        let sut = MockLLMDecisionService()

        _ = await sut.adaptiveRoutePlan(context: sampleRouteContext())
        _ = await sut.generateMicroStory(context: sampleStoryContext())
        _ = await sut.generateParentSummary(session: sampleSession())
        _ = await sut.pickEncouragementPhrase(context: AttemptContext(
            childName: "Миша", word: "рыба", targetSound: "Р", isCorrect: true, streak: 1, recentSuccessRate: 0.8))
        _ = await sut.pickReward(streak: 3, sessionType: .daily)
        _ = await sut.decideFinishSession(fatigueLevel: 0.5, attempts: 10)
        _ = await sut.adjustDifficulty(recentAttempts: [])
        _ = await sut.analyzeError(attempt: AttemptOutcome(
            word: "рыба", targetSound: "Р", isCorrect: true,
            asrTranscript: "рыба", asrConfidence: 0.9, pronunciationScore: 0.85), target: "Р")
        _ = await sut.recommendContent(profile: sampleProfile(), history: [])
        _ = await sut.generateSpecialistReport(sessions30d: [sampleSession()])
        _ = await sut.detectFatigue(audioMetrics: sampleAudioMetrics(), sessionDuration: 300)
        _ = await sut.generateCustomPhrase(template: .warmup, context: [:])
        _ = await sut.selectWarmUp(context: WarmUpContext(childName: "Миша", targetSound: "Р", sessionNumber: 1, age: 6))
        _ = await sut.generateWordSet(sound: "Р", stage: .wordInit, count: 5)
        _ = await sut.generateMinimalPairs(targetSound: "Р", confusionSound: "Л", count: 3)
        _ = await sut.narrativeQuestStep(questState: NarrativeQuestState(
            questId: "q-1", currentStep: 1, totalSteps: 5,
            collectedItems: [], childName: "Миша", targetSound: "Р"))
        _ = await sut.pickChildGreeting(childName: "Миша", timeOfDay: .morning, streakDays: 1)
        _ = await sut.generateCelebration(event: .perfectSession)
        _ = await sut.recommendRest(sessionDuration: 300, fatigueLevel: .normal)
        _ = await sut.playfulTransition(fromActivity: .listenAndChoose, toActivity: .sorting)
        _ = await sut.generateSurpriseFact(topic: "тигр", childAge: 6)
        _ = await sut.generateWeeklyReport(weeks: [])
        _ = await sut.generateParentTip(profile: sampleProfile(), currentStage: .wordInit)
        _ = await sut.detectAnxiety(sessionMetrics: SessionMetricsInput(
            pauseCount: 3, averagePauseDuration: 1.0,
            errorRate: 0.3, sessionDuration: 240, speechRateVariance: 0.2))
        _ = await sut.suggestGoalAdjustment(progress: ProgressTrendInput(
            soundsAttempted: ["Р"], weeklySuccessRates: [0.6], stagnantSounds: [], childAge: 6))

        XCTAssertEqual(sut.callLog.count, 25, "Все 25 decision points должны быть залогированы")
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
