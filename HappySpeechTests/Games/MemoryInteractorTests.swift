@testable import HappySpeech
import XCTest
import UIKit

// MARK: - Mock HapticService

private final class MemoryMockHaptic: HapticService, @unchecked Sendable {
    var selectionCount = 0
    var notificationSuccessCount = 0
    var notificationWarningCount = 0

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
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        XCTAssertTrue(spy.loadSessionCalled)
        XCTAssertEqual(spy.lastLoadSession?.cards.count, 16)
    }

    // MARK: - 2. все карточки изначально закрыты

    func test_allCardsFaceDown_onLoad() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        let faceUpCards = spy.lastLoadSession?.cards.filter(\.isFaceUp) ?? []
        XCTAssertTrue(faceUpCards.isEmpty)
    }

    // MARK: - 3. flipCard переворачивает карточку

    func test_flipCard_flipsOne() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
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
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
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
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
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
        let deck = MemoryCard.deck(for: "whistling")
        XCTAssertEqual(deck.count, 16)
    }

    // MARK: - 7. cancel не крашится

    func test_cancel_afterLoad_doesNotCrash() async {
        let (sut, _, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        sut.cancel()
        XCTAssertTrue(true)
    }

    // MARK: - 8. flipCard на matched карточку игнорируется

    func test_flipMatchedCard_ignored() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
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
}
