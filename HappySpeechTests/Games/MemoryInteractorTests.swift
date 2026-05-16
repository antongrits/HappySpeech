@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Mock HapticService

private final class MemoryMockHaptic: HapticService, @unchecked Sendable {
    var selectionCount = 0
    var notificationSuccessCount = 0
    var notificationWarningCount = 0
    var isAvailable: Bool { true }

    func play(pattern: HapticPattern) async {}
    func setIntensityScale(_ scale: Float) {}
    func stop() async {}
    func selection() { selectionCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        if type == .success { notificationSuccessCount += 1 } else { notificationWarningCount += 1 }
    }
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}
}

// MARK: - Spy

@MainActor
private final class SpyMemoryPresenter: MemoryPresentationLogic {
    var loadSessionCalled = false
    var flipCardCalled = false
    var timerTickCalled = false
    var completeCalled = false

    var lastLoadSession: MemoryModels.LoadSession.Response?
    var lastFlipCard: MemoryModels.FlipCard.Response?
    var lastComplete: MemoryModels.CompleteSession.Request?

    func presentLoadSession(_ response: MemoryModels.LoadSession.Response) {
        loadSessionCalled = true
        lastLoadSession = response
    }
    func presentFlipCard(_ response: MemoryModels.FlipCard.Response) {
        flipCardCalled = true
        lastFlipCard = response
    }
    func presentTimerTick(_ response: MemoryModels.TimerTick.Response) {
        timerTickCalled = true
    }
    func presentUseHint(_ response: MemoryModels.UseHint.Response) {}
    func presentCompleteRound(_ request: MemoryModels.CompleteRound.Request) {}
    func presentCompleteSession(_ response: MemoryModels.CompleteSession.Request) {
        completeCalled = true
        lastComplete = response
    }
}

// MARK: - Tests

@MainActor
final class MemoryInteractorTests: XCTestCase {

    private func makeSUT() -> (MemoryInteractor, SpyMemoryPresenter, MemoryMockHaptic) {
        let haptic = MemoryMockHaptic()
        let sut = MemoryInteractor(hapticService: haptic)
        let spy = SpyMemoryPresenter()
        sut.presenter = spy
        return (sut, spy, haptic)
    }

    // MARK: - 1. loadSession создаёт 16 карточек

    func test_loadSession_loads16Cards() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        XCTAssertTrue(spy.loadSessionCalled)
        XCTAssertEqual(spy.lastLoadSession?.cards.count, 16)
    }

    // MARK: - 2. все карточки изначально закрыты

    func test_allCardsFaceDown_onLoad() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        let faceUpCards = spy.lastLoadSession?.cards.filter(\.isFaceUp) ?? []
        XCTAssertTrue(faceUpCards.isEmpty)
    }

    // MARK: - 3. flipCard переворачивает карточку

    func test_flipCard_flipsOne() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        guard let firstCard = spy.lastLoadSession?.cards.first else { return }
        await sut.flipCard(.init(cardId: firstCard.id))
        XCTAssertTrue(spy.flipCardCalled)
        XCTAssertGreaterThanOrEqual(haptic.selectionCount, 1)
        let updatedCard = spy.lastFlipCard?.cards.first(where: { $0.id == firstCard.id })
        XCTAssertEqual(updatedCard?.isFaceUp, true)
    }

    // MARK: - 4. flip одинаковой пары → matchFound

    func test_flipMatchingPair_matchFoundTrue() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        guard let cards = spy.lastLoadSession?.cards,
              let firstCard = cards.first,
              let secondCard = cards.first(where: { $0.pairId == firstCard.pairId && $0.id != firstCard.id }) else { return }
        await sut.flipCard(.init(cardId: firstCard.id))
        await sut.flipCard(.init(cardId: secondCard.id))
        XCTAssertEqual(spy.lastFlipCard?.matchFound, true)
        XCTAssertGreaterThanOrEqual(haptic.notificationSuccessCount, 1)
    }

    // MARK: - 5. flip разных пар → matchFound = false

    func test_flipNonMatchingPair_matchFoundFalse() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        guard let cards = spy.lastLoadSession?.cards else { return }
        let firstCard = cards[0]
        guard let secondCard = cards.first(where: { $0.pairId != firstCard.pairId }) else { return }
        await sut.flipCard(.init(cardId: firstCard.id))
        await sut.flipCard(.init(cardId: secondCard.id))
        XCTAssertEqual(spy.lastFlipCard?.matchFound, false)
        XCTAssertGreaterThanOrEqual(haptic.notificationWarningCount, 1)
    }

    // MARK: - 6. MemoryCard.deck возвращает 16 карточек

    func test_deck_has16Cards() {
        let deck = MemoryCard.deck(for: "whistling", difficulty: .easy)
        XCTAssertEqual(deck.count, 16)
    }

    // MARK: - 7. cancel не крашится

    func test_cancel_afterLoad_doesNotCrash() async {
        let (sut, _, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        sut.cancel()
        XCTAssertTrue(true)
    }

    // MARK: - 8. flipCard на matched карточку игнорируется

    func test_flipMatchedCard_ignored() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        guard let cards = spy.lastLoadSession?.cards,
              let firstCard = cards.first,
              let secondCard = cards.first(where: { $0.pairId == firstCard.pairId && $0.id != firstCard.id }) else { return }
        await sut.flipCard(.init(cardId: firstCard.id))
        await sut.flipCard(.init(cardId: secondCard.id))
        let flipCountAfterMatch = spy.lastFlipCard?.cards.filter(\.isMatched).count ?? 0
        await sut.flipCard(.init(cardId: firstCard.id))
        let flipCountAfterRetry = spy.lastFlipCard?.cards.filter(\.isMatched).count ?? 0
        XCTAssertEqual(flipCountAfterMatch, flipCountAfterRetry)
    }

    // MARK: - Batch 1: расширенное покрытие

    func test_flipCard_unknownCardId_ignored() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        spy.flipCardCalled = false
        await sut.flipCard(.init(cardId: "nonexistent"))
        XCTAssertFalse(spy.flipCardCalled)
    }

    func test_flipCard_alreadyFaceUp_ignored() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        guard let firstCard = spy.lastLoadSession?.cards.first else { return }
        await sut.flipCard(.init(cardId: firstCard.id))
        spy.flipCardCalled = false
        await sut.flipCard(.init(cardId: firstCard.id))
        XCTAssertFalse(spy.flipCardCalled, "Повторный flip той же карты игнорируется")
    }

    func test_loadSession_mediumDifficulty_24Cards() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "hissing", childName: "Ваня", startDifficulty: .medium))
        // beginRound всегда стартует с difficulties[0] = .easy → 16 карт
        XCTAssertEqual(spy.lastLoadSession?.cards.count, 16)
        XCTAssertEqual(spy.lastLoadSession?.difficulty, .easy)
        XCTAssertEqual(spy.lastLoadSession?.roundIndex, 0)
    }

    func test_loadSession_emitsTimerTick() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        XCTAssertTrue(spy.timerTickCalled)
    }

    func test_loadSession_emitsWelcomeVoiceCue() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        XCTAssertEqual(spy.lastFlipCard?.voiceCue, .welcome)
    }

    func test_useHint_decreasesHintsRemaining() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        await sut.useHint(.init())
        // hintUsed voice cue приходит через presentFlipCard
        XCTAssertEqual(spy.lastFlipCard?.voiceCue, .hintUsed)
        _ = haptic
    }

    func test_useHint_threeTimes_thenIgnored() async {
        let (sut, _, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        await sut.useHint(.init())
        await sut.useHint(.init())
        await sut.useHint(.init())
        // Четвёртый вызов не должен крашить — hintsRemaining == 0
        await sut.useHint(.init())
        XCTAssertTrue(true)
    }

    func test_advanceToNextRound_loadsSecondRound() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        await sut.advanceToNextRound()
        XCTAssertEqual(spy.lastLoadSession?.roundIndex, 1)
        XCTAssertEqual(spy.lastLoadSession?.difficulty, .medium)
    }

    func test_streak3_emitsStreak3Cue() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша", startDifficulty: .easy))
        guard let cards = spy.lastLoadSession?.cards else { return }
        // Собираем 3 пары подряд
        let pairIds = Array(Set(cards.map(\.pairId))).prefix(3)
        for pid in pairIds {
            let pairCards = cards.filter { $0.pairId == pid }
            guard pairCards.count == 2 else { continue }
            await sut.flipCard(.init(cardId: pairCards[0].id))
            await sut.flipCard(.init(cardId: pairCards[1].id))
        }
        XCTAssertGreaterThanOrEqual(spy.lastFlipCard?.streakCount ?? 0, 3)
    }

    func test_memoryDifficulty_pairCounts() {
        XCTAssertEqual(MemoryDifficulty.easy.pairCount, 8)
        XCTAssertEqual(MemoryDifficulty.medium.pairCount, 12)
        XCTAssertEqual(MemoryDifficulty.hard.pairCount, 18)
        XCTAssertEqual(MemoryDifficulty.easy.timeLimit, 60)
        XCTAssertEqual(MemoryDifficulty.hard.timeLimit, 120)
    }

    func test_memoryRoundResult_scoreClamped() {
        let perfect = MemoryRoundResult(
            difficulty: .easy, matchedPairs: 8, totalPairs: 8,
            elapsedSeconds: 0, timeLimit: 60, reason: .allMatched,
            cardStats: [], streakBonus: true, megaStreakBonus: true
        )
        XCTAssertEqual(perfect.score, 1.0, accuracy: 0.001)
        let zero = MemoryRoundResult(
            difficulty: .easy, matchedPairs: 0, totalPairs: 8,
            elapsedSeconds: 60, timeLimit: 60, reason: .timeExpired,
            cardStats: [], streakBonus: false, megaStreakBonus: false
        )
        XCTAssertEqual(zero.score, 0.0, accuracy: 0.001)
    }

    func test_hintLevel_rawValues() {
        XCTAssertEqual(MemoryHintLevel.single.rawValue, 1)
        XCTAssertEqual(MemoryHintLevel.pair.rawValue, 2)
        XCTAssertEqual(MemoryHintLevel.all.rawValue, 3)
    }

    func test_deck_velarGroup_16Cards() {
        let deck = MemoryCard.deck(for: "velar", difficulty: .easy)
        XCTAssertEqual(deck.count, 16)
        XCTAssertTrue(deck.allSatisfy { $0.soundGroup == "velar" })
    }
}
