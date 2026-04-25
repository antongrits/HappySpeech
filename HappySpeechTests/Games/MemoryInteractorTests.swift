import Testing
import UIKit
@testable import HappySpeech

// MARK: - Mock HapticService (shared in this file)

private final class MemoryMockHaptic: HapticService, @unchecked Sendable {
    var selectionCount = 0
    var notificationSuccessCount = 0
    var notificationWarningCount = 0

    func selection() { selectionCount += 1 }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        if type == .success { notificationSuccessCount += 1 }
        else { notificationWarningCount += 1 }
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

@Suite("MemoryInteractor")
@MainActor
struct MemoryInteractorTests {

    private func makeSUT() -> (MemoryInteractor, SpyMemoryPresenter, MemoryMockHaptic) {
        let haptic = MemoryMockHaptic()
        let sut = MemoryInteractor(hapticService: haptic)
        let spy = SpyMemoryPresenter()
        sut.presenter = spy
        return (sut, spy, haptic)
    }

    // MARK: - 1. loadSession создаёт 16 карточек

    @Test("loadSession загружает 16 карточек (8 пар)")
    func loadSessionLoads16Cards() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        #expect(spy.loadSessionCalled)
        #expect(spy.lastLoadSession?.cards.count == 16)
    }

    // MARK: - 2. все карточки изначально закрыты

    @Test("все карточки после loadSession — лицом вниз")
    func allCardsFaceDownOnLoad() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        let faceUpCards = spy.lastLoadSession?.cards.filter(\.isFaceUp) ?? []
        #expect(faceUpCards.isEmpty)
    }

    // MARK: - 3. flipCard переворачивает карточку

    @Test("flipCard переворачивает одну карточку")
    func flipCardFlipsOne() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let firstCard = spy.lastLoadSession?.cards.first else { return }
        await sut.flipCard(.init(cardId: firstCard.id))
        #expect(spy.flipCardCalled)
        #expect(haptic.selectionCount >= 1)
        let updatedCard = spy.lastFlipCard?.cards.first(where: { $0.id == firstCard.id })
        #expect(updatedCard?.isFaceUp == true)
    }

    // MARK: - 4. flipCard на одинаковую пару → matchFound

    @Test("flip двух карточек одной пары → matchFound = true")
    func flipMatchingPair() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let cards = spy.lastLoadSession?.cards else { return }
        // Находим пару — две карточки с одинаковым pairId
        guard let firstCard = cards.first,
              let secondCard = cards.first(where: { $0.pairId == firstCard.pairId && $0.id != firstCard.id }) else { return }
        await sut.flipCard(.init(cardId: firstCard.id))
        await sut.flipCard(.init(cardId: secondCard.id))
        #expect(spy.lastFlipCard?.matchFound == true)
        #expect(haptic.notificationSuccessCount >= 1)
    }

    // MARK: - 5. flipCard на разные карточки → matchFound = false

    @Test("flip двух карточек разных пар → matchFound = false")
    func flipNonMatchingPair() async {
        let (sut, spy, haptic) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let cards = spy.lastLoadSession?.cards else { return }
        let firstCard = cards[0]
        guard let secondCard = cards.first(where: { $0.pairId != firstCard.pairId }) else { return }
        await sut.flipCard(.init(cardId: firstCard.id))
        await sut.flipCard(.init(cardId: secondCard.id))
        #expect(spy.lastFlipCard?.matchFound == false)
        #expect(haptic.notificationWarningCount >= 1)
    }

    // MARK: - 6. MemoryCard.deck возвращает 16 карточек

    @Test("MemoryCard.deck возвращает 16 карточек")
    func deckHas16Cards() {
        let deck = MemoryCard.deck(for: "whistling")
        #expect(deck.count == 16)
    }

    // MARK: - 7. cancel завершает игру

    @Test("cancel не крашится после loadSession")
    func cancelAfterLoad() async {
        let (sut, _, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        sut.cancel()
        #expect(Bool(true))
    }

    // MARK: - 8. flipCard на уже matched карточку игнорируется

    @Test("flipCard на уже matched карточку игнорируется")
    func flipMatchedCardIgnored() async {
        let (sut, spy, _) = makeSUT()
        await sut.loadSession(.init(soundGroup: "whistling", childName: "Маша"))
        guard let cards = spy.lastLoadSession?.cards,
              let firstCard = cards.first,
              let secondCard = cards.first(where: { $0.pairId == firstCard.pairId && $0.id != firstCard.id }) else { return }
        // Открываем пару и матчим
        await sut.flipCard(.init(cardId: firstCard.id))
        await sut.flipCard(.init(cardId: secondCard.id))
        let flipCountAfterMatch = spy.lastFlipCard?.cards.filter(\.isMatched).count ?? 0
        // Пытаемся снова открыть matched карточку
        await sut.flipCard(.init(cardId: firstCard.id))
        let flipCountAfterRetry = spy.lastFlipCard?.cards.filter(\.isMatched).count ?? 0
        #expect(flipCountAfterMatch == flipCountAfterRetry)
    }
}
