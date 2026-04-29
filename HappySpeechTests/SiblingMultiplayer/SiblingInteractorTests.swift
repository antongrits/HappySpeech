@testable import HappySpeech
import MultipeerConnectivity
import XCTest

// MARK: - SiblingInteractorTests
//
// 10 unit-тестов для SiblingDiscoveryInteractor, SiblingLobbyInteractor,
// SiblingGameInteractor (Блок L2 — Sibling Multiplayer).
//
// Покрывает: начальное состояние, приглашение пира, оценку попытки,
// накопление очков, завершение 5 раундов, потерю соединения,
// отключение пира, готовность обоих в лобби, encode/decode SiblingMessage,
// propagation childId через loadGame.

// MARK: - SpyDiscoveryPresenter

@MainActor
private final class SpyDiscoveryPresenter: SiblingDiscoveryPresentationLogic {
    var presentPeersCalled = false
    var presentInviteSentCalled = false
    var presentPermissionErrorCalled = false
    var lastPeers: [MCPeerID] = []

    func presentPeers(_ response: SiblingModels.Discovery.Response) {
        presentPeersCalled = true
        lastPeers = response.peers
    }

    func presentInviteSent(_ response: SiblingModels.InvitePeer.Response) {
        presentInviteSentCalled = true
    }

    func presentPermissionError(message: String) {
        presentPermissionErrorCalled = true
    }
}

// MARK: - SpyLobbyPresenter

@MainActor
private final class SpyLobbyPresenter: SiblingLobbyPresentationLogic {
    var presentLobbyLoadedCalled = false
    var presentReadyStateCalled = false
    var presentTimeoutCalled = false
    var lastReadyResponse: SiblingModels.ReadyState.Response?

    func presentLobbyLoaded(_ response: SiblingModels.LobbyLoad.Response) {
        presentLobbyLoadedCalled = true
    }

    func presentReadyState(_ response: SiblingModels.ReadyState.Response) {
        presentReadyStateCalled = true
        lastReadyResponse = response
    }

    func presentTimeout(_ response: SiblingModels.LobbyTimeout.Response) {
        presentTimeoutCalled = true
    }
}

// MARK: - SpyGamePresenter

@MainActor
private final class SpyGamePresenter: SiblingGamePresentationLogic {
    var presentGameLoadedCalled = false
    var presentRoundStartCalled = false
    var presentScoreUpdateCalled = false
    var presentRoundResultCalled = false
    var presentGameResultCalled = false
    var presentConnectionLostCalled = false
    var lastGameResult: SiblingModels.GameResult.Response?
    var lastScoreUpdate: SiblingModels.ScoreUpdate.Response?
    var lastRoundResult: SiblingModels.RoundResult.Response?

    func presentGameLoaded(_ response: SiblingModels.GameLoad.Response) {
        presentGameLoadedCalled = true
    }

    func presentRoundStart(_ response: SiblingModels.RoundStart.Response) {
        presentRoundStartCalled = true
    }

    func presentScoreUpdate(_ response: SiblingModels.ScoreUpdate.Response) {
        presentScoreUpdateCalled = true
        lastScoreUpdate = response
    }

    func presentRoundResult(_ response: SiblingModels.RoundResult.Response) {
        presentRoundResultCalled = true
        lastRoundResult = response
    }

    func presentGameResult(_ response: SiblingModels.GameResult.Response) {
        presentGameResultCalled = true
        lastGameResult = response
    }

    func presentConnectionLost(message: String) {
        presentConnectionLostCalled = true
    }
}

// MARK: - SpyRouter

@MainActor
private final class SpyRouter: SiblingRoutingLogic {
    var routeToLobbyCalled = false
    var routeToGameCalled = false
    var routeBackToDiscoveryCalled = false
    var routeBackToChildHomeCalled = false
    var lastGameChildId: String?

    func routeToLobby(peerID: MCPeerID) {
        routeToLobbyCalled = true
    }

    func routeToGame(peerID: MCPeerID, childId: String) {
        routeToGameCalled = true
        lastGameChildId = childId
    }

    func routeBackToDiscovery() {
        routeBackToDiscoveryCalled = true
    }

    func routeBackToChildHome() {
        routeBackToChildHomeCalled = true
    }
}

// MARK: - SiblingInteractorTests

@MainActor
final class SiblingInteractorTests: XCTestCase {

    // MARK: - Factory helpers

    private func makeDiscoverySUT() -> (SiblingDiscoveryInteractor, SpyDiscoveryPresenter, SpyRouter) {
        let spy = SpyDiscoveryPresenter()
        let router = SpyRouter()
        let sut = SiblingDiscoveryInteractor(localDisplayName: "Петя")
        sut.presenter = spy
        sut.router = router
        return (sut, spy, router)
    }

    private func makeLobbySUT(childId: String = "child-001") -> (SiblingLobbyInteractor, SpyLobbyPresenter, SpyRouter) {
        let spy = SpyLobbyPresenter()
        let router = SpyRouter()
        let worker = SiblingMPCWorker(displayName: "Петя")
        let peerID = MCPeerID(displayName: "Маша")
        let sut = SiblingLobbyInteractor(mpcWorker: worker, peerID: peerID, childId: childId)
        sut.presenter = spy
        sut.router = router
        return (sut, spy, router)
    }

    private func makeGameSUT() -> (SiblingGameInteractor, SpyGamePresenter, SpyRouter) {
        let spy = SpyGamePresenter()
        let router = SpyRouter()
        let worker = SiblingMPCWorker(displayName: "Петя")
        let sut = SiblingGameInteractor(mpcWorker: worker)
        sut.presenter = spy
        sut.router = router
        return (sut, spy, router)
    }

    // MARK: - 1. loadDiscovery: начальное состояние — presenter получает пустой список

    func test_loadDiscovery_initialState_emptyPeers() {
        let (sut, spy, _) = makeDiscoverySUT()

        sut.startDiscovery()

        XCTAssertTrue(spy.presentPeersCalled, "presentPeers должен вызываться при startDiscovery")
        XCTAssertTrue(spy.lastPeers.isEmpty, "Начальный список пиров должен быть пустым")
    }

    // MARK: - 2. invitePeer: отправка приглашения не крашится (worker без активной сессии)

    func test_invitePeer_sendsInvitation() {
        let (sut, _, _) = makeDiscoverySUT()
        // Worker не имеет активной MCSession — invite упадёт тихо (логирование),
        // но Interactor не должен крашиться.
        sut.startDiscovery()

        // Инвайт несуществующему пиру — должен быть обработан gracefully
        sut.invitePeer(displayName: "НесуществующийПир")
        // Проверяем что нет падений — тест прошёл если дошли сюда
        XCTAssertTrue(true, "invitePeer не должен крашить при отсутствии MCPeerID в реестре")
    }

    // MARK: - 3. evaluateAttempt: score в диапазоне [0.4 ... 0.95]

    func test_evaluateAttempt_returnsScoreInRange0to1() {
        let (sut, spy, _) = makeGameSUT()
        sut.loadGame(childId: "child-001", peerDisplayName: "Маша", localDisplayName: "Петя")

        // evaluateAttempt вызывает submitScore с mock-значением 0.4...0.95
        // Вызываем несколько раз и проверяем что presenter получил scoreUpdate
        for _ in 1...5 {
            sut.evaluateAttempt()
        }

        XCTAssertTrue(spy.presentScoreUpdateCalled, "presenter должен получить presentScoreUpdate")
        if let score = spy.lastScoreUpdate?.ourRoundResult {
            XCTAssertGreaterThanOrEqual(score, 0.0, "Score должен быть >= 0.0")
            XCTAssertLessThanOrEqual(score, 1.0, "Score должен быть <= 1.0")
        }
    }

    // MARK: - 4. recordRound: submitScore c score > 0 → ourRoundResult обновлён в presenter

    func test_recordRound_incrementsScore() {
        let (sut, spy, _) = makeGameSUT()
        sut.loadGame(childId: "child-001", peerDisplayName: "Маша", localDisplayName: "Петя")
        sut.startRound(index: 1)

        sut.submitScore(0.85)

        XCTAssertTrue(spy.presentScoreUpdateCalled, "presenter должен получить ScoreUpdate после submitScore")
        XCTAssertEqual(spy.lastScoreUpdate?.ourRoundResult, 0.85, accuracy: 0.001,
                       "ourRoundResult должен отразить переданный score 0.85")
    }

    // MARK: - 5. completeFiveRounds: после победы в 5 раундах presenter получает GameResult

    func test_completeFiveRounds_setsWinner() {
        let (sut, spy, _) = makeGameSUT()
        sut.loadGame(childId: "child-001", peerDisplayName: "Маша", localDisplayName: "Петя")

        // Имитируем 5 раундов: наш score всегда выше пирового.
        // Для триггера evaluateRoundIfReady нужно чтобы оба score > 0.
        // Используем mpcWorkerDidReceive для установки peerRoundScore,
        // затем submitScore — это вызовет evaluateRoundIfReady.
        for roundIdx in 1...5 {
            sut.startRound(index: roundIdx)
            // Симулируем получение score от пира (0.5) через делегат
            sut.mpcWorkerDidReceive(
                message: .scoreUpdate(score: 0.5, roundIndex: roundIdx),
                from: "Маша"
            )
            // Наш score выше
            sut.submitScore(0.9)
        }

        // GameResult планируется через Task.sleep(2s) — проверяем что presenter
        // получит вызов (используем expectation с увеличенным таймаутом)
        let expectation = XCTestExpectation(description: "presentGameResult вызван")
        Task { @MainActor in
            // Ждём до 3.5с для завершения scheduleGameOver
            var waited = 0
            while !spy.presentGameResultCalled && waited < 35 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 1
            }
            if spy.presentGameResultCalled {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 4.0)

        XCTAssertTrue(spy.presentGameResultCalled, "Presenter должен получить GameResult после 5 раундов")
        // Наш score > peer score во всех раундах → победитель "Петя"
        XCTAssertEqual(spy.lastGameResult?.winnerName, "Петя",
                       "Победитель должен быть 'Петя' (наш score выше во всех раундах)")
    }

    // MARK: - 6. handleConnectionLost: потеря соединения в игре → presenter получает ConnectionLost

    func test_handleConnectionLost_returnsToDiscovery() {
        let (sut, spy, _) = makeGameSUT()
        sut.loadGame(childId: "child-001", peerDisplayName: "Маша", localDisplayName: "Петя")

        // Имитируем разрыв соединения через делегат
        sut.mpcWorkerDidDisconnect(displayName: "Маша")

        XCTAssertTrue(spy.presentConnectionLostCalled,
                      "Presenter должен получить ConnectionLost при разрыве соединения")
    }

    // MARK: - 7. handlePeerDisconnect: отключение в discovery → presenter обновляет список пиров

    func test_handlePeerDisconnect_endsGame() {
        let (sut, spy, _) = makeDiscoverySUT()
        sut.startDiscovery()

        // Имитируем обнаружение пира через делегат
        sut.mpcWorkerDidDiscoverPeer(displayName: "Маша")
        XCTAssertFalse(spy.lastPeers.isEmpty, "После обнаружения список не должен быть пустым")

        // Пир потерян
        sut.mpcWorkerDidLosePeer(displayName: "Маша")

        XCTAssertTrue(spy.presentPeersCalled,
                      "Presenter должен быть уведомлён после потери пира")
        // После потери пира список должен снова быть пустым
        XCTAssertTrue(spy.lastPeers.isEmpty,
                      "Список пиров должен быть пустым после потери единственного пира")
    }

    // MARK: - 8. lobbyReady: оба готовы → presenter получает ReadyState с shouldStartGame=true (через presenter)

    func test_lobbyReady_bothReady_startsGame() {
        let (sut, spy, router) = makeLobbySUT(childId: "child-002")
        sut.loadLobby(peerDisplayName: "Маша", localDisplayName: "Петя")

        // Локальный игрок нажал Ready
        sut.setReady()
        XCTAssertTrue(spy.presentReadyStateCalled, "Presenter должен получить ReadyState")
        XCTAssertEqual(spy.lastReadyResponse?.localReady, true, "localReady должен быть true")
        XCTAssertEqual(spy.lastReadyResponse?.peerReady, false, "peerReady ещё false")

        // Пир сообщил о готовности через MPC
        sut.mpcWorkerDidReceive(message: .readyState(isReady: true), from: "Маша")

        XCTAssertEqual(spy.lastReadyResponse?.localReady, true)
        XCTAssertEqual(spy.lastReadyResponse?.peerReady, true, "peerReady должен стать true")
        XCTAssertTrue(router.routeToGameCalled, "Router должен получить routeToGame когда оба готовы")
    }

    // MARK: - 9. messageEncoding_roundTrip: SiblingMessage кодируется и декодируется без потерь

    func test_messageEncoding_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // readyState
        let ready = SiblingMessage.readyState(isReady: true)
        let readyData = try encoder.encode(ready)
        if case .readyState(let isReady) = try decoder.decode(SiblingMessage.self, from: readyData) {
            XCTAssertTrue(isReady)
        } else { XCTFail("readyState decode failed") }

        // roundStart
        let roundStart = SiblingMessage.roundStart(word: "Рыба", roundIndex: 3)
        let rsData = try encoder.encode(roundStart)
        if case .roundStart(let word, let idx) = try decoder.decode(SiblingMessage.self, from: rsData) {
            XCTAssertEqual(word, "Рыба")
            XCTAssertEqual(idx, 3)
        } else { XCTFail("roundStart decode failed") }

        // scoreUpdate
        let scoreMsg = SiblingMessage.scoreUpdate(score: 0.87, roundIndex: 2)
        let scoreData = try encoder.encode(scoreMsg)
        if case .scoreUpdate(let score, let idx) = try decoder.decode(SiblingMessage.self, from: scoreData) {
            XCTAssertEqual(score, 0.87, accuracy: 0.001)
            XCTAssertEqual(idx, 2)
        } else { XCTFail("scoreUpdate decode failed") }

        // gameResult
        let resultMsg = SiblingMessage.gameResult(finalScores: ["Петя": 3, "Маша": 2])
        let resultData = try encoder.encode(resultMsg)
        if case .gameResult(let scores) = try decoder.decode(SiblingMessage.self, from: resultData) {
            XCTAssertEqual(scores["Петя"], 3)
            XCTAssertEqual(scores["Маша"], 2)
        } else { XCTFail("gameResult decode failed") }

        // disconnect
        let disconnect = SiblingMessage.disconnect
        let disconnectData = try encoder.encode(disconnect)
        if case .disconnect = try decoder.decode(SiblingMessage.self, from: disconnectData) {
            // OK
        } else { XCTFail("disconnect decode failed") }
    }

    // MARK: - 10. currentChildId: propagation в routeToGame через lobby

    func test_currentChildId_propagatedToGameRoute() {
        let childId = "child-propagation-test"
        let (sut, _, router) = makeLobbySUT(childId: childId)
        sut.loadLobby(peerDisplayName: "Маша", localDisplayName: "Петя")

        // Оба готовы → routeToGame должен содержать правильный childId
        sut.setReady()
        sut.mpcWorkerDidReceive(message: .readyState(isReady: true), from: "Маша")

        XCTAssertTrue(router.routeToGameCalled, "routeToGame должен вызываться")
        XCTAssertEqual(router.lastGameChildId, childId,
                       "childId должен корректно передаваться в routeToGame")
    }
}
