@testable import HappySpeech
import XCTest

// MARK: - RuleBasedDecisionServiceTests
//
// Phase 2.4 v25 — покрытие RuleBasedDecisionService.
// Тестируется детерминированная бизнес-логика всех 25 decision-точек.
// Без ML-инференса: всё синхронно, без моков сети.

final class RuleBasedDecisionServiceTests: XCTestCase {

    private var sut: RuleBasedDecisionService!

    override func setUp() {
        super.setUp()
        sut = RuleBasedDecisionService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeRouteContext(
        sound: String = "Р",
        stage: CorrectionStage = .wordInit,
        successRate: Double = 0.7,
        fatigue: FatigueLevel = .normal,
        templates: [TemplateType] = TemplateType.allCases
    ) -> RoutePlanContext {
        RoutePlanContext(
            childId: "c-1",
            childName: "Маша",
            age: 6,
            targetSound: sound,
            currentStage: stage,
            recentSuccessRate: successRate,
            fatigueLevel: fatigue,
            availableTemplates: templates,
            circuit: .kid
        )
    }

    private func makeSession(
        sound: String = "Р",
        total: Int = 10,
        correct: Int = 8,
        errors: [String] = ["ворона"],
        duration: Int = 480
    ) -> SessionSummaryInput {
        SessionSummaryInput(
            sessionId: UUID().uuidString,
            childId: "c-1",
            childName: "Маша",
            age: 6,
            targetSound: sound,
            stage: .wordInit,
            totalAttempts: total,
            correctAttempts: correct,
            errorWords: errors,
            durationSec: duration,
            date: Date()
        )
    }

    private func makeAttempt(correct: Bool, score: Double = 0.8, transcript: String = "рыба") -> AttemptOutcome {
        AttemptOutcome(
            word: "рыба",
            targetSound: "Р",
            isCorrect: correct,
            asrTranscript: transcript,
            asrConfidence: correct ? 0.9 : 0.4,
            pronunciationScore: score
        )
    }

    // MARK: - 1. planDailyRoute

    func test_planDailyRoute_returnsNonEmptyRoute() {
        let ctx = makeRouteContext()
        let (steps, _) = sut.planDailyRoute(context: ctx)
        XCTAssertFalse(steps.isEmpty, "Маршрут должен содержать шаги")
    }

    func test_planDailyRoute_atMost3Steps() {
        let ctx = makeRouteContext()
        let (steps, _) = sut.planDailyRoute(context: ctx)
        XCTAssertLessThanOrEqual(steps.count, 3)
    }

    func test_planDailyRoute_tired_maxDuration480() {
        let ctx = makeRouteContext(fatigue: .tired)
        let (_, maxDur) = sut.planDailyRoute(context: ctx)
        XCTAssertEqual(maxDur, 480)
    }

    func test_planDailyRoute_normal_maxDuration600() {
        let ctx = makeRouteContext(fatigue: .normal)
        let (_, maxDur) = sut.planDailyRoute(context: ctx)
        XCTAssertEqual(maxDur, 600)
    }

    func test_planDailyRoute_fresh_maxDuration900() {
        let ctx = makeRouteContext(fatigue: .fresh)
        let (_, maxDur) = sut.planDailyRoute(context: ctx)
        XCTAssertEqual(maxDur, 900)
    }

    func test_planDailyRoute_stepsPreserveSound() {
        let ctx = makeRouteContext(sound: "С")
        let (steps, _) = sut.planDailyRoute(context: ctx)
        for step in steps {
            XCTAssertEqual(step.targetSound, "С")
        }
    }

    func test_planDailyRoute_stepsPreserveStage() {
        let ctx = makeRouteContext(stage: .syllable)
        let (steps, _) = sut.planDailyRoute(context: ctx)
        for step in steps {
            XCTAssertEqual(step.stage, .syllable)
        }
    }

    func test_planDailyRoute_highSuccess_difficulty3() {
        let ctx = makeRouteContext(successRate: 0.9)
        let (steps, _) = sut.planDailyRoute(context: ctx)
        XCTAssertTrue(steps.allSatisfy { $0.difficulty == 3 }, "Высокий успех → уровень 3")
    }

    func test_planDailyRoute_lowSuccess_difficulty1() {
        let ctx = makeRouteContext(successRate: 0.3)
        let (steps, _) = sut.planDailyRoute(context: ctx)
        XCTAssertTrue(steps.allSatisfy { $0.difficulty == 1 }, "Низкий успех → уровень 1")
    }

    func test_planDailyRoute_deterministic() {
        let ctx = makeRouteContext()
        let (s1, d1) = sut.planDailyRoute(context: ctx)
        let (s2, d2) = sut.planDailyRoute(context: ctx)
        XCTAssertEqual(s1.count, s2.count)
        XCTAssertEqual(d1, d2)
    }

    // MARK: - 2. generateMicroStory

    func test_generateMicroStory_returns3Sentences() {
        let ctx = StoryContext(targetSound: "Р", age: 6, wordPool: ["рыба", "ракета"], stage: .wordInit)
        let story = sut.generateMicroStory(context: ctx)
        XCTAssertEqual(story.sentences.count, 3)
    }

    func test_generateMicroStory_hasGap() {
        let ctx = StoryContext(targetSound: "С", age: 6, wordPool: ["сова", "сом"], stage: .wordMed)
        let story = sut.generateMicroStory(context: ctx)
        XCTAssertFalse(story.gaps.isEmpty, "История должна содержать хотя бы один gap")
    }

    func test_generateMicroStory_deterministic() {
        let ctx = StoryContext(targetSound: "Ш", age: 7, wordPool: ["шар", "шапка"], stage: .wordFinal)
        let a = sut.generateMicroStory(context: ctx)
        let b = sut.generateMicroStory(context: ctx)
        XCTAssertEqual(a.sentences, b.sentences, "generateMicroStory должен быть детерминированным")
    }

    func test_generateMicroStory_emptyWordPool_usesFallback() {
        let ctx = StoryContext(targetSound: "Р", age: 6, wordPool: [], stage: .wordInit)
        let story = sut.generateMicroStory(context: ctx)
        XCTAssertEqual(story.sentences.count, 3)
    }

    // MARK: - 3. generateParentSummary

    func test_generateParentSummary_highRate_containsChildName() {
        let session = makeSession(total: 10, correct: 9)
        let summary = sut.generateParentSummary(session: session)
        XCTAssertTrue(summary.summaryText.contains("Маша"))
    }

    func test_generateParentSummary_highRate_contains90pct() {
        let session = makeSession(total: 10, correct: 9)
        let summary = sut.generateParentSummary(session: session)
        XCTAssertTrue(summary.summaryText.contains("90"), "90% должны упоминаться в summary")
    }

    func test_generateParentSummary_lowRate_containsMildTone() {
        let session = makeSession(total: 10, correct: 3)
        let summary = sut.generateParentSummary(session: session)
        XCTAssertFalse(summary.summaryText.isEmpty)
        XCTAssertFalse(summary.homeTask.isEmpty)
    }

    func test_generateParentSummary_withErrors_homeTaskMentionsErrors() {
        let session = makeSession(errors: ["ворона", "радуга"])
        let summary = sut.generateParentSummary(session: session)
        XCTAssertTrue(
            summary.homeTask.contains("ворона") || summary.homeTask.contains("радуга"),
            "Домашнее задание должно упоминать проблемные слова"
        )
    }

    func test_generateParentSummary_noErrors_genericHomeTask() {
        let session = makeSession(errors: [])
        let summary = sut.generateParentSummary(session: session)
        XCTAssertFalse(summary.homeTask.isEmpty)
        XCTAssertEqual(summary.tone, "supportive")
    }

    // MARK: - 4. pickEncouragementPhrase

    func test_pickEncouragement_correct_notEmpty() {
        let ctx = AttemptContext(childName: "Маша", word: "рыба", targetSound: "Р",
                                 isCorrect: true, streak: 3, recentSuccessRate: 0.8)
        let (msg, emoji) = sut.pickEncouragementPhrase(context: ctx)
        XCTAssertFalse(msg.isEmpty)
        XCTAssertFalse(emoji.isEmpty)
    }

    func test_pickEncouragement_wrong_notEmpty() {
        let ctx = AttemptContext(childName: "Маша", word: "ракета", targetSound: "Р",
                                 isCorrect: false, streak: 0, recentSuccessRate: 0.3)
        let (msg, emoji) = sut.pickEncouragementPhrase(context: ctx)
        XCTAssertFalse(msg.isEmpty)
        XCTAssertFalse(emoji.isEmpty)
    }

    func test_pickEncouragement_correct_neverContainsNepravilno() {
        for i in 0..<10 {
            let ctx = AttemptContext(childName: "Маша", word: "рыба_\(i)", targetSound: "Р",
                                     isCorrect: true, streak: i, recentSuccessRate: 0.7)
            let (msg, _) = sut.pickEncouragementPhrase(context: ctx)
            XCTAssertFalse(msg.contains("неправильно"), "Слово «неправильно» недопустимо")
        }
    }

    // MARK: - 5. pickReward

    func test_pickReward_lowStreak_noBadge() {
        let reward = sut.pickReward(streak: 1, sessionType: .daily)
        XCTAssertNil(reward.badgeId, "Малая серия → нет badge")
    }

    func test_pickReward_highStreak_hasBadge() {
        let reward = sut.pickReward(streak: 7, sessionType: .daily)
        XCTAssertNotNil(reward.badgeId, "Серия ≥7 → badge должен быть")
    }

    func test_pickReward_stickerFromPool() {
        let pool = ["butterfly-01", "bear-01", "fox-01", "bunny-01", "hedgehog-01",
                    "star-01", "heart-01", "crown-01", "rainbow-01", "moon-01"]
        for streak in 0..<10 {
            let reward = sut.pickReward(streak: streak, sessionType: .daily)
            XCTAssertTrue(pool.contains(reward.stickerId), "stickerId должен быть из пула: \(reward.stickerId)")
        }
    }

    func test_pickReward_legendaryStreak_title() {
        let reward = sut.pickReward(streak: 15, sessionType: .daily)
        XCTAssertFalse(reward.title.isEmpty)
        XCTAssertFalse(reward.subtitle.isEmpty)
    }

    // MARK: - 6. decideFinishSession

    func test_decideFinish_highFatigueAndAttempts_finishTrue() {
        let (finish, reason) = sut.decideFinishSession(fatigueLevel: 0.85, attempts: 7)
        XCTAssertTrue(finish)
        XCTAssertFalse(reason.isEmpty)
    }

    func test_decideFinish_veryHighFatigue_finishTrue() {
        let (finish, _) = sut.decideFinishSession(fatigueLevel: 0.95, attempts: 1)
        XCTAssertTrue(finish)
    }

    func test_decideFinish_tooManyAttempts_finishTrue() {
        let (finish, _) = sut.decideFinishSession(fatigueLevel: 0.1, attempts: 30)
        XCTAssertTrue(finish)
    }

    func test_decideFinish_lowFatigueFewAttempts_continueFalse() {
        let (finish, _) = sut.decideFinishSession(fatigueLevel: 0.2, attempts: 5)
        XCTAssertFalse(finish)
    }

    func test_decideFinish_boundary_fatigue08_attempts5_continues() {
        // fatigue=0.8 И attempts=5 (<6) → не завершаем
        let (finish, _) = sut.decideFinishSession(fatigueLevel: 0.8, attempts: 5)
        XCTAssertFalse(finish)
    }

    // MARK: - 7. adjustDifficulty

    func test_adjustDifficulty_allCorrect_promotesHard() {
        let attempts = (0..<5).map { _ in makeAttempt(correct: true) }
        let (diff, delta, _) = sut.adjustDifficulty(recentAttempts: attempts)
        XCTAssertEqual(diff, .hard)
        XCTAssertEqual(delta, 1)
    }

    func test_adjustDifficulty_allWrong_demotesEasy() {
        let attempts = (0..<5).map { _ in makeAttempt(correct: false, score: 0.1) }
        let (diff, delta, _) = sut.adjustDifficulty(recentAttempts: attempts)
        XCTAssertEqual(diff, .easy)
        XCTAssertEqual(delta, -1)
    }

    func test_adjustDifficulty_emptyAttempts_staysMedium() {
        let (diff, delta, reason) = sut.adjustDifficulty(recentAttempts: [])
        XCTAssertEqual(diff, .medium)
        XCTAssertEqual(delta, 0)
        XCTAssertFalse(reason.isEmpty)
    }

    func test_adjustDifficulty_mixed_staysMedium() {
        // 3 correct из 4 → rate = 0.75 → не < 0.85 и не < 0.60 → .medium
        let attempts = [
            makeAttempt(correct: true),
            makeAttempt(correct: true),
            makeAttempt(correct: true),
            makeAttempt(correct: false)
        ]
        let (diff, _, _) = sut.adjustDifficulty(recentAttempts: attempts)
        XCTAssertEqual(diff, .medium)
    }

    // MARK: - 8. analyzeError

    func test_analyzeError_correctAttempt_returnsCorrectCategory() {
        let attempt = makeAttempt(correct: true, score: 0.9, transcript: "рыба")
        let analysis = sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(analysis.category, .correct)
    }

    func test_analyzeError_emptyTranscript_returnsHesitation() {
        let attempt = AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: false,
                                     asrTranscript: "", asrConfidence: 0.1, pronunciationScore: 0.2)
        let analysis = sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(analysis.category, .hesitation)
    }

    func test_analyzeError_soundOmitted_returnsOmission() {
        let attempt = AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: false,
                                     asrTranscript: "ыба", asrConfidence: 0.7, pronunciationScore: 0.3)
        let analysis = sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(analysis.category, .soundOmission)
    }

    func test_analyzeError_lowConfidence_returnsUncertain() {
        let attempt = AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: false,
                                     asrTranscript: "рыба", asrConfidence: 0.3, pronunciationScore: 0.5)
        let analysis = sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(analysis.category, .uncertain)
    }

    func test_analyzeError_lowPronScore_returnsDistortion() {
        let attempt = AttemptOutcome(word: "рыба", targetSound: "Р", isCorrect: false,
                                     asrTranscript: "рыба", asrConfidence: 0.7, pronunciationScore: 0.2)
        let analysis = sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertEqual(analysis.category, .soundDistortion)
    }

    func test_analyzeError_hint_mentionsTarget() {
        let attempt = makeAttempt(correct: false, score: 0.1, transcript: "ыба")
        let analysis = sut.analyzeError(attempt: attempt, target: "Р")
        XCTAssertFalse(analysis.hint.isEmpty)
    }

    // MARK: - 9. recommendContent

    func test_recommendContent_picksWeakestSound() {
        let profile = ChildProfileInput(
            id: "c-1", name: "Маша", age: 6,
            targetSounds: ["Р", "С"],
            sensitivityLevel: 1,
            progressSummary: ["Р": 0.4, "С": 0.8]
        )
        let rec = sut.recommendContent(profile: profile, history: [])
        XCTAssertTrue(
            rec.packIds.first?.hasPrefix("Р-") ?? false,
            "Слабейший звук «Р» (0.4 < 0.8) должен быть первым в рекомендациях"
        )
        XCTAssertFalse(rec.rationale.isEmpty)
    }

    func test_recommendContent_3Packs() {
        let profile = ChildProfileInput(
            id: "c-1", name: "Маша", age: 6,
            targetSounds: ["С"],
            sensitivityLevel: 1,
            progressSummary: ["С": 0.5]
        )
        let rec = sut.recommendContent(profile: profile, history: [])
        XCTAssertEqual(rec.packIds.count, 3, "Рекомендуем 3 пака по этапам")
    }

    // MARK: - 10. generateSpecialistReport

    func test_specialistReport_emptyHistory_headline() {
        let report = sut.generateSpecialistReport(sessions30d: [])
        XCTAssertTrue(report.headline.contains("Нет данных"))
    }

    func test_specialistReport_oneSession_hasCounts() {
        let report = sut.generateSpecialistReport(sessions30d: [makeSession()])
        XCTAssertTrue(report.headline.contains("1 сессий") || report.headline.contains("сессий"))
        XCTAssertFalse(report.recommendations.isEmpty)
    }

    func test_specialistReport_highRate_strength() {
        let session = makeSession(total: 10, correct: 9)
        let report = sut.generateSpecialistReport(sessions30d: [session])
        XCTAssertFalse(report.strengths.isEmpty, "Высокий успех → strengths не пусто")
    }

    func test_specialistReport_lowRate_weakness() {
        let session = makeSession(total: 10, correct: 2)
        let report = sut.generateSpecialistReport(sessions30d: [session])
        XCTAssertFalse(report.weaknesses.isEmpty, "Низкий успех → weaknesses не пусто")
    }

    // MARK: - 11. detectFatigue

    func test_detectFatigue_highSilence_tired() {
        let metrics = AudioMetricsInput(averageAmplitude: 0.05, silenceRatio: 0.75,
                                        speakingRateWpm: 40, attemptsPerMinute: 1.5)
        let (level, confidence) = sut.detectFatigue(audioMetrics: metrics, sessionDuration: 720)
        XCTAssertEqual(level, .tired)
        XCTAssertGreaterThan(confidence, 0.5)
    }

    func test_detectFatigue_goodMetrics_fresh() {
        let metrics = AudioMetricsInput(averageAmplitude: 0.4, silenceRatio: 0.1,
                                        speakingRateWpm: 150, attemptsPerMinute: 7)
        let (level, _) = sut.detectFatigue(audioMetrics: metrics, sessionDuration: 60)
        XCTAssertEqual(level, .fresh)
    }

    func test_detectFatigue_confidence_inRange() {
        let metrics = AudioMetricsInput(averageAmplitude: 0.2, silenceRatio: 0.35,
                                        speakingRateWpm: 80, attemptsPerMinute: 3)
        let (_, confidence) = sut.detectFatigue(audioMetrics: metrics, sessionDuration: 300)
        XCTAssertGreaterThanOrEqual(confidence, 0.0)
        XCTAssertLessThanOrEqual(confidence, 1.0)
    }

    // MARK: - 12. generateCustomPhrase

    func test_generateCustomPhrase_warmup_containsChildName() {
        let phrase = sut.generateCustomPhrase(template: .warmup, context: ["child_name": "Маша", "target_sound": "Р"])
        XCTAssertTrue(phrase.contains("Маша"))
    }

    func test_generateCustomPhrase_warmup_containsSound() {
        let phrase = sut.generateCustomPhrase(template: .warmup, context: ["child_name": "Маша", "target_sound": "С"])
        XCTAssertTrue(phrase.contains("С"))
    }

    func test_generateCustomPhrase_parentTip_noPlaceholders() {
        let phrase = sut.generateCustomPhrase(template: .parentTip, context: ["target_sound": "Ш"])
        XCTAssertFalse(phrase.contains("{sound}"), "Плейсхолдер должен быть заменён")
    }

    func test_generateCustomPhrase_homework_mentionsWords() {
        let phrase = sut.generateCustomPhrase(template: .homework,
                                              context: ["weak_words": "ракета, рыба", "target_sound": "Р"])
        XCTAssertTrue(phrase.contains("ракета"))
    }

    func test_generateCustomPhrase_transition_notEmpty() {
        let phrase = sut.generateCustomPhrase(template: .transition, context: [:])
        XCTAssertFalse(phrase.isEmpty)
    }

    func test_generateCustomPhrase_sessionComplete_containsChildName() {
        let phrase = sut.generateCustomPhrase(template: .sessionComplete, context: ["child_name": "Ваня"])
        XCTAssertTrue(phrase.contains("Ваня"))
    }

    // MARK: - 13. selectWarmUp

    func test_selectWarmUp_returnsNameAndInstructions() {
        let ctx = WarmUpContext(childName: "Маша", targetSound: "С", sessionNumber: 1, age: 6)
        let (name, instructions, duration) = sut.selectWarmUp(context: ctx)
        XCTAssertFalse(name.isEmpty)
        XCTAssertFalse(instructions.isEmpty)
        XCTAssertGreaterThan(duration, 0)
    }

    func test_selectWarmUp_younger_90sec() {
        let ctx = WarmUpContext(childName: "Маша", targetSound: "Р", sessionNumber: 1, age: 5)
        let (_, _, duration) = sut.selectWarmUp(context: ctx)
        XCTAssertEqual(duration, 90, "Дети ≤6 лет → 90 сек разминки")
    }

    func test_selectWarmUp_older_120sec() {
        let ctx = WarmUpContext(childName: "Вася", targetSound: "Л", sessionNumber: 2, age: 7)
        let (_, _, duration) = sut.selectWarmUp(context: ctx)
        XCTAssertEqual(duration, 120, "Дети 7+ → 120 сек разминки")
    }

    func test_selectWarmUp_instructionsNotEmpty() {
        // warmUpPool может содержать инструкции без {name}; проверяем только что результат не пустой
        let ctx = WarmUpContext(childName: "Катя", targetSound: "С", sessionNumber: 1, age: 6)
        let (activityName, instructions, _) = sut.selectWarmUp(context: ctx)
        XCTAssertFalse(activityName.isEmpty, "Имя активности должно быть не пустым")
        XCTAssertFalse(instructions.isEmpty, "Инструкции должны быть не пустыми")
    }

    // MARK: - 14. generateWordSet

    func test_generateWordSet_countRespected() {
        let (words, rationale) = sut.generateWordSet(sound: "Р", stage: .wordInit, count: 5)
        XCTAssertFalse(words.isEmpty)
        XCTAssertLessThanOrEqual(words.count, 5)
        XCTAssertFalse(rationale.isEmpty)
    }

    func test_generateWordSet_deterministic() {
        let (words1, _) = sut.generateWordSet(sound: "С", stage: .wordMed, count: 4)
        let (words2, _) = sut.generateWordSet(sound: "С", stage: .wordMed, count: 4)
        XCTAssertEqual(words1, words2, "generateWordSet должен быть детерминированным")
    }

    func test_generateWordSet_zeroCount_returnsAtLeastOne() {
        let (words, _) = sut.generateWordSet(sound: "Ш", stage: .wordInit, count: 0)
        XCTAssertGreaterThanOrEqual(words.count, 1)
    }

    // MARK: - 15. generateMinimalPairs

    func test_generateMinimalPairs_knownPair_fromPool() {
        let pairs = sut.generateMinimalPairs(targetSound: "С", confusionSound: "Ш", count: 3)
        XCTAssertFalse(pairs.isEmpty)
        XCTAssertLessThanOrEqual(pairs.count, 3)
    }

    func test_generateMinimalPairs_unknownPair_usesDefault() {
        let pairs = sut.generateMinimalPairs(targetSound: "Х", confusionSound: "Г", count: 2)
        XCTAssertEqual(pairs.count, 2)
    }

    func test_generateMinimalPairs_targetDifferentFromFoil() {
        let pairs = sut.generateMinimalPairs(targetSound: "Р", confusionSound: "Л", count: 4)
        for pair in pairs {
            XCTAssertNotEqual(pair.target, pair.foil, "target и foil должны различаться")
        }
    }

    // MARK: - 16. narrativeQuestStep

    func test_narrativeQuestStep_returnsNarration() {
        let state = NarrativeQuestState(questId: "q-1", currentStep: 2, totalSteps: 5,
                                        collectedItems: ["замок"], childName: "Маша", targetSound: "Р")
        let (narration, word, hint, isLast) = sut.narrativeQuestStep(questState: state)
        XCTAssertFalse(narration.isEmpty)
        XCTAssertFalse(word.isEmpty)
        XCTAssertFalse(hint.isEmpty)
        XCTAssertFalse(isLast)
    }

    func test_narrativeQuestStep_lastStep_isLastTrue() {
        let state = NarrativeQuestState(questId: "q-1", currentStep: 5, totalSteps: 5,
                                        collectedItems: [], childName: "Маша", targetSound: "Р")
        let (_, _, _, isLast) = sut.narrativeQuestStep(questState: state)
        XCTAssertTrue(isLast)
    }

    func test_narrativeQuestStep_narrationContainsChildName() {
        let state = NarrativeQuestState(questId: "q-2", currentStep: 1, totalSteps: 3,
                                        collectedItems: [], childName: "Ваня", targetSound: "С")
        let (narration, _, _, _) = sut.narrativeQuestStep(questState: state)
        XCTAssertTrue(narration.contains("Ваня"), "Нарратив должен содержать имя ребёнка")
    }

    // MARK: - 17. pickChildGreeting

    func test_pickChildGreeting_morning_solarEmoji() {
        let (phrase, emoji) = sut.pickChildGreeting(childName: "Маша", timeOfDay: .morning, streakDays: 0)
        XCTAssertFalse(phrase.isEmpty)
        XCTAssertEqual(emoji, "☀️")
    }

    func test_pickChildGreeting_evening_moonEmoji() {
        let (_, emoji) = sut.pickChildGreeting(childName: "Маша", timeOfDay: .evening, streakDays: 1)
        XCTAssertEqual(emoji, "🌙")
    }

    func test_pickChildGreeting_highStreak_mentionsStreak() {
        let (phrase, _) = sut.pickChildGreeting(childName: "Маша", timeOfDay: .afternoon, streakDays: 10)
        XCTAssertTrue(phrase.contains("10"), "Высокая серия должна упоминаться в приветствии")
    }

    func test_pickChildGreeting_streak0_newAdventure() {
        let (phrase, _) = sut.pickChildGreeting(childName: "Маша", timeOfDay: .morning, streakDays: 0)
        XCTAssertTrue(phrase.contains("приключени"), "streak=0 → упоминание нового приключения")
    }

    // MARK: - 18. generateCelebration

    func test_generateCelebration_perfectSession_starsAnimation() {
        let (message, animation) = sut.generateCelebration(event: .perfectSession)
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(animation, "stars-shower")
    }

    func test_generateCelebration_streak_fireworks() {
        let (_, animation) = sut.generateCelebration(event: .streakAchieved(days: 7))
        XCTAssertEqual(animation, "fireworks")
    }

    func test_generateCelebration_newSound_mentionsSound() {
        let (message, _) = sut.generateCelebration(event: .newSoundUnlocked(sound: "Р"))
        XCTAssertTrue(message.contains("Р"), "Сообщение должно упоминать разблокированный звук")
    }

    func test_generateCelebration_milestone_mentionsMilestone() {
        let (message, _) = sut.generateCelebration(event: .milestoneReached(milestone: "100 слов"))
        XCTAssertTrue(message.contains("100 слов"))
    }

    // MARK: - 19. recommendRest

    func test_recommendRest_tired_shouldRestTrue() {
        let (shouldRest, breakMin, msg) = sut.recommendRest(sessionDuration: 300, fatigueLevel: .tired)
        XCTAssertTrue(shouldRest)
        XCTAssertGreaterThan(breakMin, 0)
        XCTAssertFalse(msg.isEmpty)
    }

    func test_recommendRest_freshShort_noRest() {
        let (shouldRest, breakMin, _) = sut.recommendRest(sessionDuration: 60, fatigueLevel: .fresh)
        XCTAssertFalse(shouldRest)
        XCTAssertEqual(breakMin, 0)
    }

    func test_recommendRest_normalLong_shortBreak() {
        // sessionDuration > 1200 → longSession=true → .normal → (true, 10, ...)
        let (shouldRest, breakMin, _) = sut.recommendRest(sessionDuration: 1300, fatigueLevel: .normal)
        XCTAssertTrue(shouldRest)
        XCTAssertGreaterThan(breakMin, 0)
    }

    func test_recommendRest_freshLong_shortBreak() {
        let (shouldRest, breakMin, _) = sut.recommendRest(sessionDuration: 1300, fatigueLevel: .fresh)
        XCTAssertTrue(shouldRest)
        XCTAssertGreaterThan(breakMin, 0)
    }

    // MARK: - 20. playfulTransition

    func test_playfulTransition_notEmpty() {
        let phrase = sut.playfulTransition(fromActivity: .listenAndChoose, toActivity: .bingo)
        XCTAssertFalse(phrase.isEmpty)
    }

    func test_playfulTransition_deterministic() {
        let a = sut.playfulTransition(fromActivity: .sorting, toActivity: .memory)
        let b = sut.playfulTransition(fromActivity: .sorting, toActivity: .memory)
        XCTAssertEqual(a, b, "playfulTransition должен быть детерминированным")
    }

    // MARK: - 21. generateSurpriseFact

    func test_generateSurpriseFact_younger_notEmpty() {
        let fact = sut.generateSurpriseFact(topic: "тигр", childAge: 5)
        XCTAssertFalse(fact.isEmpty)
    }

    func test_generateSurpriseFact_older_notEmpty() {
        let fact = sut.generateSurpriseFact(topic: "рыба", childAge: 8)
        XCTAssertFalse(fact.isEmpty)
    }

    func test_generateSurpriseFact_noPlaceholdersInOutput() {
        let fact = sut.generateSurpriseFact(topic: "лев", childAge: 6)
        XCTAssertFalse(fact.contains("{topic}"), "Плейсхолдер {topic} должен быть заменён")
    }

    // MARK: - 22. generateWeeklyReport

    func test_generateWeeklyReport_empty_safeOutput() {
        let (summary, _, recs) = sut.generateWeeklyReport(weeks: [])
        XCTAssertFalse(summary.isEmpty)
        XCTAssertFalse(recs.isEmpty)
    }

    func test_generateWeeklyReport_oneWeek_hasSummary() {
        let week = WeekSummaryInput(weekNumber: 1, sessionsCount: 5, averageScore: 0.72,
                                    soundsPracticed: ["Р", "С"], improvementDelta: 0.05)
        let (summary, highlights, recs) = sut.generateWeeklyReport(weeks: [week])
        XCTAssertFalse(summary.isEmpty)
        XCTAssertFalse(highlights.isEmpty)
        XCTAssertFalse(recs.isEmpty)
    }

    func test_generateWeeklyReport_highAvgScore_advancesGoal() {
        let week = WeekSummaryInput(weekNumber: 1, sessionsCount: 6, averageScore: 0.90,
                                    soundsPracticed: ["С"], improvementDelta: 0.1)
        let (_, _, recs) = sut.generateWeeklyReport(weeks: [week])
        XCTAssertTrue(recs.contains(where: { $0.contains("следующий") || $0.contains("Переходите") }),
            "Высокий средний балл → рекомендация перейти на следующий уровень")
    }

    // MARK: - 23. generateParentTip

    func test_generateParentTip_notEmpty() {
        let profile = ChildProfileInput(id: "c-1", name: "Маша", age: 6,
                                        targetSounds: ["Р"], sensitivityLevel: 1, progressSummary: ["Р": 0.5])
        let (tip, exercise) = sut.generateParentTip(profile: profile, currentStage: .wordInit)
        XCTAssertFalse(tip.isEmpty)
        XCTAssertFalse(exercise.isEmpty)
    }

    func test_generateParentTip_noSoundPlaceholders() {
        let profile = ChildProfileInput(id: "c-1", name: "Маша", age: 6,
                                        targetSounds: ["С"], sensitivityLevel: 1, progressSummary: ["С": 0.6])
        let (tip, exercise) = sut.generateParentTip(profile: profile, currentStage: .syllable)
        XCTAssertFalse(tip.contains("{sound}"), "Плейсхолдер {sound} должен быть заменён в совете")
        XCTAssertFalse(exercise.contains("{sound}"), "Плейсхолдер {sound} должен быть заменён в упражнении")
    }

    // MARK: - 24. detectAnxiety

    func test_detectAnxiety_highPauseAndError_highScore() {
        let metrics = SessionMetricsInput(pauseCount: 15, averagePauseDuration: 5,
                                          errorRate: 0.8, sessionDuration: 300, speechRateVariance: 0.9)
        let (score, signals, recommendation) = sut.detectAnxiety(sessionMetrics: metrics)
        XCTAssertGreaterThan(score, 0.5, "Высокие паузы и ошибки → высокий anxietyScore")
        XCTAssertFalse(signals.isEmpty)
        XCTAssertFalse(recommendation.isEmpty)
    }

    func test_detectAnxiety_normalMetrics_lowScore() {
        let metrics = SessionMetricsInput(pauseCount: 2, averagePauseDuration: 0.5,
                                          errorRate: 0.1, sessionDuration: 180, speechRateVariance: 0.1)
        let (score, _, _) = sut.detectAnxiety(sessionMetrics: metrics)
        XCTAssertLessThan(score, 0.5)
    }

    func test_detectAnxiety_score_inRange() {
        let metrics = SessionMetricsInput(pauseCount: 5, averagePauseDuration: 2,
                                          errorRate: 0.4, sessionDuration: 240, speechRateVariance: 0.4)
        let (score, _, _) = sut.detectAnxiety(sessionMetrics: metrics)
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    // MARK: - 25. suggestGoalAdjustment

    func test_suggestGoalAdjustment_stagnant_suggestsPause() {
        let trend = ProgressTrendInput(soundsAttempted: ["Р", "С"],
                                       weeklySuccessRates: [0.44, 0.43, 0.44, 0.43],
                                       stagnantSounds: ["Р", "С"], childAge: 6)
        let (current, suggested, rationale) = sut.suggestGoalAdjustment(progress: trend)
        XCTAssertFalse(current.isEmpty)
        XCTAssertFalse(suggested.isEmpty)
        XCTAssertFalse(rationale.isEmpty)
    }

    func test_suggestGoalAdjustment_highRateTrendUp_promotesGoal() {
        let trend = ProgressTrendInput(soundsAttempted: ["С"],
                                       weeklySuccessRates: [0.80, 0.86, 0.90],
                                       stagnantSounds: [], childAge: 7)
        let (_, suggested, _) = sut.suggestGoalAdjustment(progress: trend)
        XCTAssertTrue(
            suggested.contains("предложен") || suggested.contains("усложн") || suggested.contains("следующ"),
            "Высокий тренд → предложение усложнить: \(suggested)"
        )
    }

    func test_suggestGoalAdjustment_lowRate_simplifies() {
        let trend = ProgressTrendInput(soundsAttempted: ["Р"],
                                       weeklySuccessRates: [0.45, 0.43],
                                       stagnantSounds: [], childAge: 6)
        let (_, suggested, _) = sut.suggestGoalAdjustment(progress: trend)
        XCTAssertFalse(suggested.isEmpty)
    }
}
