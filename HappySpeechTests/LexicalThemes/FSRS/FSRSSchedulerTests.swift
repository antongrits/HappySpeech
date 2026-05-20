@testable import HappySpeech
import XCTest

// MARK: - FSRSScheduler Tests
//
// v31 Волна D Ф.2 — пользу алгоритма FSRS-6 проверяем на детерминированных
// (через явные `now`) транзициях. Никакой случайности.

final class FSRSSchedulerTests: XCTestCase {

    private let scheduler = FSRSScheduler()

    // MARK: - new-card

    func test_newCard_isDueImmediately() {
        let now = Date()
        let state = scheduler.newCard(date: now)
        XCTAssertEqual(state.reps, 0)
        XCTAssertEqual(state.lapses, 0)
        XCTAssertEqual(state.stability, 0)
        XCTAssertTrue(state.isDue(at: now))
    }

    func test_newCard_initialNextReview_equalsLastReview() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let state = scheduler.newCard(date: now)
        XCTAssertEqual(state.nextReview, state.lastReview)
    }

    // MARK: - first review

    func test_firstReviewGood_setsPositiveStability_andSchedulesIntoFuture() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let initial = scheduler.newCard(date: now)
        let after = scheduler.next(state: initial, rating: .good, now: now)
        XCTAssertGreaterThan(after.stability, 0)
        XCTAssertGreaterThan(after.nextReview.timeIntervalSince(now), 86_400 - 1)
        XCTAssertEqual(after.reps, 1)
        XCTAssertEqual(after.lapses, 0)
    }

    func test_firstReviewEasy_higherStability_thanGood() {
        let now = Date()
        let initial = scheduler.newCard(date: now)
        let good = scheduler.next(state: initial, rating: .good, now: now)
        let easy = scheduler.next(state: initial, rating: .easy, now: now)
        XCTAssertGreaterThan(easy.stability, good.stability)
    }

    func test_firstReviewHard_lowerStability_thanGood() {
        let now = Date()
        let initial = scheduler.newCard(date: now)
        let good = scheduler.next(state: initial, rating: .good, now: now)
        let hard = scheduler.next(state: initial, rating: .hard, now: now)
        XCTAssertLessThan(hard.stability, good.stability)
    }

    func test_firstReviewAgain_incrementsLapses() {
        let now = Date()
        let initial = scheduler.newCard(date: now)
        let after = scheduler.next(state: initial, rating: .again, now: now)
        XCTAssertEqual(after.lapses, 1)
        XCTAssertEqual(after.reps, 1)
    }

    // MARK: - successive reviews

    func test_consecutiveGoodReviews_increaseStability() {
        let baseNow = Date(timeIntervalSince1970: 1_700_000_000)
        var state = scheduler.newCard(date: baseNow)
        state = scheduler.next(state: state, rating: .good, now: baseNow)
        let s1 = state.stability
        // через интервал в днях
        let next1 = state.nextReview
        state = scheduler.next(state: state, rating: .good, now: next1)
        let s2 = state.stability
        XCTAssertGreaterThan(s2, s1)
        XCTAssertEqual(state.reps, 2)
    }

    func test_againAfterGood_resetsStabilityDownward() {
        let baseNow = Date(timeIntervalSince1970: 1_700_000_000)
        var state = scheduler.newCard(date: baseNow)
        state = scheduler.next(state: state, rating: .good, now: baseNow)
        let beforeAgain = state.stability
        let lapseTime = state.nextReview
        state = scheduler.next(state: state, rating: .again, now: lapseTime)
        XCTAssertLessThan(state.stability, beforeAgain)
        XCTAssertEqual(state.lapses, 1)
    }

    // MARK: - interval

    func test_interval_zeroStability_isZero() {
        XCTAssertEqual(scheduler.interval(stability: 0), 0)
    }

    func test_interval_positiveStability_atLeastOneDay() {
        XCTAssertGreaterThanOrEqual(scheduler.interval(stability: 1.0), 1.0)
    }

    func test_interval_clampedAt365Days() {
        // огромная stability — интервал не превышает 365.
        XCTAssertLessThanOrEqual(scheduler.interval(stability: 1_000_000), 365.0)
    }

    // MARK: - retrievability

    func test_retrievability_atZeroElapsed_isOne() {
        XCTAssertEqual(
            scheduler.retrievability(elapsedDays: 0, stability: 5.0),
            1.0,
            accuracy: 0.001
        )
    }

    func test_retrievability_decreasesWithTime() {
        let day1 = scheduler.retrievability(elapsedDays: 1, stability: 5.0)
        let day10 = scheduler.retrievability(elapsedDays: 10, stability: 5.0)
        XCTAssertGreaterThan(day1, day10)
    }

    func test_retrievability_zeroStability_isZero() {
        XCTAssertEqual(
            scheduler.retrievability(elapsedDays: 5, stability: 0),
            0,
            accuracy: 0.001
        )
    }

    // MARK: - due

    func test_isDue_falseImmediatelyAfterFirstGood() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let initial = scheduler.newCard(date: now)
        let after = scheduler.next(state: initial, rating: .good, now: now)
        // следующий обзор как минимум через сутки.
        XCTAssertFalse(after.isDue(at: now))
        XCTAssertFalse(after.isDue(at: now.addingTimeInterval(3600)))
    }

    func test_isDue_trueAfterScheduledInterval() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let initial = scheduler.newCard(date: now)
        let after = scheduler.next(state: initial, rating: .good, now: now)
        XCTAssertTrue(after.isDue(at: after.nextReview.addingTimeInterval(1)))
    }

    // MARK: - difficulty clamp

    func test_difficulty_alwaysInRange1to10() {
        var state = scheduler.newCard()
        for _ in 0..<20 {
            state = scheduler.next(state: state, rating: .easy, now: state.nextReview)
        }
        XCTAssertGreaterThanOrEqual(state.difficulty, 1.0)
        XCTAssertLessThanOrEqual(state.difficulty, 10.0)
    }
}
