import XCTest
@testable import HappySpeech

// MARK: - SpacedRepetitionEngineTests
// ==================================================================================
// Covers the SM-2 implementation adapted for children 5-8:
//   1. Quality mapping from success rate + fatigue
//   2. Interval progression (1 -> 6 -> EF * prev) with 14-day cap
//   3. EF easing/hardening bounds (>= 1.3)
//   4. Quality < 3 resets interval to 1 but keeps EF adjustment
//   5. needsSpecialistReview flag at low EF
// ==================================================================================

final class SpacedRepetitionEngineTests: XCTestCase {

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Quality mapping

    func test_quality_fromSuccessRate_maps_to_correct_buckets() {
        XCTAssertEqual(SM2Quality.fromSuccessRate(0.99, hadFatigue: false), .perfect)
        XCTAssertEqual(SM2Quality.fromSuccessRate(0.85, hadFatigue: false), .correct)
        XCTAssertEqual(SM2Quality.fromSuccessRate(0.70, hadFatigue: false), .hardCorrect)
        XCTAssertEqual(SM2Quality.fromSuccessRate(0.50, hadFatigue: false), .hardWrong)
        XCTAssertEqual(SM2Quality.fromSuccessRate(0.30, hadFatigue: false), .wrong)
        XCTAssertEqual(SM2Quality.fromSuccessRate(0.10, hadFatigue: false), .blackout)
    }

    func test_quality_downgrades_with_fatigue() {
        let noFatigue = SM2Quality.fromSuccessRate(0.85, hadFatigue: false)
        let withFatigue = SM2Quality.fromSuccessRate(0.85, hadFatigue: true)
        XCTAssertLessThan(withFatigue.rawValue, noFatigue.rawValue,
                          "Fatigue should downgrade quality one bucket")
    }

    func test_isSuccessful_threshold_at_q3() {
        XCTAssertFalse(SM2Quality.blackout.isSuccessful)
        XCTAssertFalse(SM2Quality.wrong.isSuccessful)
        XCTAssertFalse(SM2Quality.hardWrong.isSuccessful)
        XCTAssertTrue(SM2Quality.hardCorrect.isSuccessful)
        XCTAssertTrue(SM2Quality.correct.isSuccessful)
        XCTAssertTrue(SM2Quality.perfect.isSuccessful)
    }

    // MARK: - Interval progression

    func test_firstSuccess_advancesInterval_to_1day() {
        let r = SM2Engine.calculate(
            quality: .correct,
            currentEF: SM2Engine.defaultEF,
            repetitions: 0,
            lastInterval: 0,
            now: baseDate
        )
        XCTAssertEqual(r.intervalDays, 1)
        XCTAssertEqual(r.repetitions, 1)
    }

    func test_secondSuccess_advancesInterval_to_6days() {
        let r = SM2Engine.calculate(
            quality: .correct,
            currentEF: 2.5,
            repetitions: 1,
            lastInterval: 1,
            now: baseDate
        )
        XCTAssertEqual(r.intervalDays, 6)
    }

    func test_thirdSuccess_multipliesPreviousBy_EF_but_caps_at_14() {
        let r = SM2Engine.calculate(
            quality: .correct,
            currentEF: 2.5,
            repetitions: 2,
            lastInterval: 6,
            now: baseDate
        )
        XCTAssertEqual(r.intervalDays, 14, "6 * 2.5 = 15 → capped at 14 for children")
    }

    func test_interval_hardCap_14days() {
        let r = SM2Engine.calculate(
            quality: .perfect,
            currentEF: 2.8,
            repetitions: 5,
            lastInterval: 30,
            now: baseDate
        )
        XCTAssertLessThanOrEqual(r.intervalDays, SM2Engine.maxIntervalDays)
    }

    // MARK: - Failure path

    func test_wrong_resetsInterval_to_1_and_repetitions_to_0() {
        let r = SM2Engine.calculate(
            quality: .wrong,
            currentEF: 2.5,
            repetitions: 4,
            lastInterval: 10,
            now: baseDate
        )
        XCTAssertEqual(r.intervalDays, 1, "Wrong answer returns to interval 1")
        XCTAssertEqual(r.repetitions, 0, "Repetitions reset on failure")
    }

    func test_blackout_keeps_intervalAt_1() {
        let r = SM2Engine.calculate(
            quality: .blackout,
            currentEF: 2.5,
            repetitions: 3,
            lastInterval: 7,
            now: baseDate
        )
        XCTAssertEqual(r.intervalDays, 1)
    }

    // MARK: - EF bounds

    func test_EF_never_drops_below_minimum() {
        var ef = 2.5
        for _ in 0..<20 {
            let r = SM2Engine.calculate(
                quality: .blackout, currentEF: ef,
                repetitions: 0, lastInterval: 1,
                now: baseDate
            )
            ef = r.easinessFactor
        }
        XCTAssertGreaterThanOrEqual(ef, SM2Engine.minimumEF,
                                    "EF is clamped at minimumEF (1.3)")
    }

    func test_EF_at_floor_flags_needsSpecialistReview() {
        var ef = 2.5
        var flagged = false
        for _ in 0..<20 {
            let r = SM2Engine.calculate(
                quality: .blackout, currentEF: ef,
                repetitions: 0, lastInterval: 1,
                now: baseDate
            )
            ef = r.easinessFactor
            if r.needsSpecialistReview { flagged = true }
        }
        XCTAssertTrue(flagged, "After many blackouts EF < 1.5 triggers specialist review")
    }

    // MARK: - nextReviewDate

    func test_nextReviewDate_is_now_plus_interval_days_from_startOfDay() {
        let cal = Calendar.current
        let r = SM2Engine.calculate(
            quality: .correct, currentEF: 2.5,
            repetitions: 1, lastInterval: 1,
            now: baseDate
        )
        let expected = cal.date(
            byAdding: .day, value: r.intervalDays,
            to: cal.startOfDay(for: baseDate)
        )
        XCTAssertEqual(r.nextReviewDate, expected)
    }
}
