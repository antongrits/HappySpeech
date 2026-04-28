@testable import HappySpeech
import XCTest

// MARK: - GrammarScoringWorkerTests
//
// 5 тестов для GrammarScoringWorker (F1-011).
// Покрывает: recordAttempt correct, reset, sessionSuccessRate zero rounds,
// currentStreak perfect game, partial bonus threshold.

@MainActor
final class GrammarScoringWorkerTests: XCTestCase {

    private func makeSUT(totalRounds: Int = 5) -> GrammarScoringWorker {
        let sut = GrammarScoringWorker()
        sut.reset(totalRounds: totalRounds)
        return sut
    }

    private func makeRoundId() -> UUID { UUID() }

    // MARK: - 11. recordAttempt correct → correctCount увеличивается

    func test_recordAttempt_correct_incrementsCorrectCount() {
        let sut = makeSUT(totalRounds: 5)
        let rid = makeRoundId()

        let before = sut.correctCount
        _ = sut.recordAttempt(roundId: rid, isCorrect: true, difficulty: .easy)

        XCTAssertEqual(sut.correctCount, before + 1, "correctCount должен вырасти на 1")
        XCTAssertEqual(sut.totalAnswered, 1)
    }

    // MARK: - 12. reset → все счётчики обнуляются

    func test_reset_clearsState() {
        let sut = makeSUT(totalRounds: 5)
        let rid = makeRoundId()

        // Наделаем активности
        _ = sut.recordAttempt(roundId: rid, isCorrect: false, difficulty: .medium)
        _ = sut.recordAttempt(roundId: rid, isCorrect: true,  difficulty: .medium)

        sut.reset(totalRounds: 3)

        XCTAssertEqual(sut.correctCount,  0, "correctCount после reset должен быть 0")
        XCTAssertEqual(sut.totalAnswered, 0, "totalAnswered после reset должен быть 0")
        XCTAssertEqual(sut.errorsOnRound(rid), 0, "ошибки на раунде должны очиститься")
    }

    // MARK: - 13. sessionSuccessRate zero rounds → 0

    func test_sessionSuccessRate_zeroRounds_returnsZero() {
        let sut = GrammarScoringWorker()
        sut.reset(totalRounds: 0)

        let rate = sut.sessionSuccessRate()

        XCTAssertEqual(rate, 0, "При 0 раундах successRate должен быть 0 (защита от деления)")
    }

    // MARK: - 14. Идеальная игра → correctCount == totalRounds

    func test_perfectGame_correctCountEqualsTotalRounds() {
        let total = 5
        let sut = makeSUT(totalRounds: total)
        var roundIds: [UUID] = []

        for _ in 0..<total {
            let rid = makeRoundId()
            roundIds.append(rid)
            _ = sut.recordAttempt(roundId: rid, isCorrect: true, difficulty: .easy)
        }

        XCTAssertEqual(sut.correctCount, total, "correctCount должен равняться количеству раундов")
        XCTAssertEqual(sut.sessionSuccessRate(), 1.0, accuracy: 0.001)
    }

    // MARK: - 15. Порог награды для easy (каждые 3 правильных)

    func test_rewardThreshold_easy_triggersAt3rdCorrect() {
        let sut = makeSUT(totalRounds: 10)
        var rewardFired = false

        for i in 1...3 {
            let rid = makeRoundId()
            let result = sut.recordAttempt(roundId: rid, isCorrect: true, difficulty: .easy)
            if i == 3 {
                rewardFired = result.shouldShowReward
            }
        }

        XCTAssertTrue(rewardFired, "Награда должна срабатывать на 3-м правильном ответе (easy)")
    }
}
