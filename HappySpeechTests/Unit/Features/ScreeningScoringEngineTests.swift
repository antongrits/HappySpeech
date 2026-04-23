import XCTest
@testable import HappySpeech

// MARK: - ScreeningScoringEngineTests
//
// Pure aggregation tests for the screening outcome engine. The engine takes
// 20 per-prompt scores and produces a verdict per sound + priority order +
// recommended session duration. All tests are deterministic with no I/O.
// ==================================================================================

final class ScreeningScoringEngineTests: XCTestCase {

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Verdict thresholds

    func test_allHighScores_allNormal() {
        let prompts = ScreeningPromptFactory.prompts(for: 7)
        var scores: [String: Float] = [:]
        for p in prompts { scores[p.id] = 0.95 }

        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 7, scores: scores, prompts: prompts, now: baseDate
        )
        XCTAssertTrue(outcome.priorityTargetSounds.isEmpty)
        XCTAssertTrue(outcome.perSound.values.allSatisfy { $0 == .normal })
    }

    func test_allLowScores_allIntervention() {
        let prompts = ScreeningPromptFactory.prompts(for: 6)
        var scores: [String: Float] = [:]
        for p in prompts { scores[p.id] = 0.1 }

        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 6, scores: scores, prompts: prompts, now: baseDate
        )
        XCTAssertFalse(outcome.priorityTargetSounds.isEmpty)
        // At least the 4 production-tested sound groups (С, Ш, Р, Л) must be
        // flagged — plus any of К/Г/З/Ж depending on block composition.
        XCTAssertGreaterThanOrEqual(outcome.priorityTargetSounds.count, 4)
        XCTAssertTrue(outcome.perSound.values.allSatisfy { $0 == .intervention })
    }

    func test_mixedScores_flagsOnlyLowSounds() {
        let prompts = ScreeningPromptFactory.prompts(for: 6)
        var scores: [String: Float] = [:]
        for p in prompts {
            scores[p.id] = (p.targetSound == "Р") ? 0.2 : 0.9
        }

        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 6, scores: scores, prompts: prompts, now: baseDate
        )
        XCTAssertTrue(outcome.priorityTargetSounds.contains("Р"))
        XCTAssertEqual(outcome.perSound["Р"], .intervention)
    }

    // MARK: - Priority ordering

    func test_priorityOrder_lowestScoreFirst() {
        let prompts = ScreeningPromptFactory.prompts(for: 6)
        var scores: [String: Float] = [:]
        for p in prompts {
            switch p.targetSound {
            case "Р": scores[p.id] = 0.1   // worst
            case "Ш": scores[p.id] = 0.4
            case "Л": scores[p.id] = 0.3   // second-worst
            default:  scores[p.id] = 0.9
            }
        }
        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 6, scores: scores, prompts: prompts, now: baseDate
        )
        guard outcome.priorityTargetSounds.count >= 3 else {
            return XCTFail("Expected at least 3 priority targets, got \(outcome.priorityTargetSounds.count)")
        }
        XCTAssertEqual(outcome.priorityTargetSounds.first, "Р",
                       "Lowest-score sound must be first priority")
    }

    // MARK: - Session duration scaling

    func test_sessionDuration_5yearOld_base8min() {
        let prompts = ScreeningPromptFactory.prompts(for: 5)
        let scores = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, Float(0.95)) })
        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 5, scores: scores, prompts: prompts, now: baseDate
        )
        XCTAssertEqual(outcome.recommendedSessionDurationSec, 8 * 60)
    }

    func test_sessionDuration_8yearOld_base15min() {
        let prompts = ScreeningPromptFactory.prompts(for: 8)
        let scores = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, Float(0.95)) })
        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 8, scores: scores, prompts: prompts, now: baseDate
        )
        XCTAssertEqual(outcome.recommendedSessionDurationSec, 15 * 60)
    }

    func test_sessionDuration_capsAt_20min() {
        let prompts = ScreeningPromptFactory.prompts(for: 8)
        // All low → many interventions → would otherwise exceed 20 min
        let scores = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, Float(0.1)) })
        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 8, scores: scores, prompts: prompts, now: baseDate
        )
        XCTAssertLessThanOrEqual(outcome.recommendedSessionDurationSec, 20 * 60)
    }

    // MARK: - Initial stage suggestions

    func test_initialStage_intervention_withDiscriminationFail_startsAtIsolated() {
        let prompts = ScreeningPromptFactory.prompts(for: 6)
        var scores: [String: Float] = [:]
        for p in prompts {
            // Р fails production AND R/L pair discrimination fails
            if p.targetSound == "Р" || p.id == "pair_r_l" {
                scores[p.id] = 0.2
            } else {
                scores[p.id] = 0.9
            }
        }
        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 6, scores: scores, prompts: prompts, now: baseDate
        )
        XCTAssertEqual(outcome.initialStagePerSound["Р"], "isolated",
                       "When discrimination also fails → start at the most elementary stage")
    }

    func test_initialStage_intervention_withGoodDiscrimination_startsAtSyllable() {
        let prompts = ScreeningPromptFactory.prompts(for: 6)
        var scores: [String: Float] = [:]
        for p in prompts {
            if p.targetSound == "Р" && p.block != .minimalPairs {
                scores[p.id] = 0.2   // production bad
            } else {
                scores[p.id] = 0.9   // discrimination + others fine
            }
        }
        let outcome = ScreeningScoringEngine.evaluate(
            childId: "c1", childAge: 6, scores: scores, prompts: prompts, now: baseDate
        )
        XCTAssertEqual(outcome.initialStagePerSound["Р"], "syllable")
    }
}
