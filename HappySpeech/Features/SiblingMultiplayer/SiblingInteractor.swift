import Foundation
import MultipeerConnectivity
import OSLog

// MARK: - SiblingDiscoveryBusinessLogic

@MainActor
protocol SiblingDiscoveryBusinessLogic: AnyObject {
    func startDiscovery()
    func stopDiscovery()
    func invitePeer(displayName: String)
    func cancelDiscovery()
}

// MARK: - SiblingLobbyBusinessLogic

@MainActor
protocol SiblingLobbyBusinessLogic: AnyObject {
    func loadLobby(peerDisplayName: String, localDisplayName: String)
    func setReady()
    func leaveLobby()
}

// MARK: - SiblingGameBusinessLogic

@MainActor
protocol SiblingGameBusinessLogic: AnyObject {
    func loadGame(childId: String, peerDisplayName: String, localDisplayName: String)
    func startRound(index: Int)
    func evaluateAttempt()
    func submitScore(_ score: Float)
    func requestRematch()
    func exitGame()
}

// MARK: - SiblingDiscoveryInteractor

@MainActor
final class SiblingDiscoveryInteractor: SiblingDiscoveryBusinessLogic {

    var presenter: (any SiblingDiscoveryPresentationLogic)?
    var router: (any SiblingRoutingLogic)?
    let mpcWorker: SiblingMPCWorker

    private var discoveredNames: [String] = []
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SiblingDiscovery")

    init(localDisplayName: String) {
        self.mpcWorker = SiblingMPCWorker(displayName: localDisplayName)
    }

    func startDiscovery() {
        mpcWorker.delegate = self
        mpcWorker.start()
        logger.info("discovery started")
        presenter?.presentPeers(.init(peers: []))
    }

    func stopDiscovery() {
        mpcWorker.stop()
        discoveredNames = []
        logger.info("discovery stopped")
    }

    func invitePeer(displayName: String) {
        mpcWorker.invite(displayName: displayName)
    }

    func cancelDiscovery() {
        stopDiscovery()
        router?.routeBackToChildHome()
    }

    private func buildPeerViewModels() -> [SiblingPeerViewModel] {
        discoveredNames.compactMap { name in
            guard let peerID = mpcWorker.peerID(for: name) else { return nil }
            return SiblingPeerViewModel(id: name, displayName: name, peerID: peerID)
        }
    }
}

// MARK: - SiblingDiscoveryInteractor + SiblingMPCWorkerDelegate

extension SiblingDiscoveryInteractor: SiblingMPCWorkerDelegate {

    func mpcWorkerDidDiscoverPeer(displayName: String) {
        if !discoveredNames.contains(displayName) {
            discoveredNames.append(displayName)
        }
        let vms = buildPeerViewModels()
        presenter?.presentPeers(.init(peers: vms.map(\.peerID)))
    }

    func mpcWorkerDidLosePeer(displayName: String) {
        discoveredNames.removeAll { $0 == displayName }
        let vms = buildPeerViewModels()
        presenter?.presentPeers(.init(peers: vms.map(\.peerID)))
    }

    func mpcWorkerDidReceiveInvite(from displayName: String, accept: @MainActor @escaping () -> Void) {
        accept()
    }

    func mpcWorkerDidConnect(displayName: String) {
        logger.info("connected to \(displayName, privacy: .public)")
        if let peerID = mpcWorker.peerID(for: displayName) {
            router?.routeToLobby(peerID: peerID)
        }
    }

    func mpcWorkerDidDisconnect(displayName: String) {
        discoveredNames.removeAll { $0 == displayName }
        let vms = buildPeerViewModels()
        presenter?.presentPeers(.init(peers: vms.map(\.peerID)))
    }

    func mpcWorkerDidReceive(message: SiblingMessage, from displayName: String) {}
}

// MARK: - SiblingLobbyInteractor

@MainActor
final class SiblingLobbyInteractor: SiblingLobbyBusinessLogic {

    var presenter: (any SiblingLobbyPresentationLogic)?
    var router: (any SiblingRoutingLogic)?

    private let mpcWorker: SiblingMPCWorker
    private let peerID: MCPeerID
    private let currentChildId: String
    private var localReady: Bool = false
    private var peerReady: Bool = false
    private var countdownTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SiblingLobby")

    init(mpcWorker: SiblingMPCWorker, peerID: MCPeerID, childId: String) {
        self.mpcWorker = mpcWorker
        self.peerID = peerID
        self.currentChildId = childId
    }

    func loadLobby(peerDisplayName: String, localDisplayName: String) {
        mpcWorker.delegate = self
        localReady = false
        peerReady = false
        presenter?.presentLobbyLoaded(.init(
            localDisplayName: localDisplayName,
            peerDisplayName: peerDisplayName
        ))
        startCountdown()
    }

    func setReady() {
        localReady = true
        mpcWorker.send(.readyState(isReady: true))
        logger.info("localReady=true")
        checkBothReady()
    }

    func leaveLobby() {
        countdownTask?.cancel()
        mpcWorker.send(.disconnect)
        router?.routeBackToDiscovery()
    }

    private func checkBothReady() {
        let response = SiblingModels.ReadyState.Response(
            localReady: localReady,
            peerReady: peerReady
        )
        presenter?.presentReadyState(response)
        if localReady && peerReady {
            countdownTask?.cancel()
            router?.routeToGame(peerID: peerID, childId: currentChildId)
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(60))
                await MainActor.run { [weak self] in
                    self?.handleTimeout()
                }
            } catch {}
        }
    }

    private func handleTimeout() {
        logger.info("lobby timeout")
        mpcWorker.send(.disconnect)
        presenter?.presentTimeout(.init())
    }
}

// MARK: - SiblingLobbyInteractor + SiblingMPCWorkerDelegate

extension SiblingLobbyInteractor: SiblingMPCWorkerDelegate {

    func mpcWorkerDidDiscoverPeer(displayName: String) {}
    func mpcWorkerDidLosePeer(displayName: String) {}

    func mpcWorkerDidReceiveInvite(from displayName: String, accept: @MainActor @escaping () -> Void) {
        accept()
    }

    func mpcWorkerDidConnect(displayName: String) {}

    func mpcWorkerDidDisconnect(displayName: String) {
        countdownTask?.cancel()
        presenter?.presentTimeout(.init())
    }

    func mpcWorkerDidReceive(message: SiblingMessage, from displayName: String) {
        switch message {
        case .readyState(let isReady):
            peerReady = isReady
            checkBothReady()
        default:
            break
        }
    }
}

// MARK: - SiblingGameInteractor

@MainActor
final class SiblingGameInteractor: SiblingGameBusinessLogic {

    var presenter: (any SiblingGamePresentationLogic)?
    var router: (any SiblingRoutingLogic)?

    private let mpcWorker: SiblingMPCWorker
    private var words: [String] = []
    private var currentRound: Int = 1
    private let totalRounds: Int = 5
    private var ourTotalPoints: Int = 0
    private var peerTotalPoints: Int = 0
    private var ourRoundScore: Float = 0.0
    private var peerRoundScore: Float = 0.0
    private var localDisplayName: String = ""
    private var peerDisplayName: String = ""
    private var roundResultTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "SiblingGame")

    private static let defaultWords = [
        "Мяч", "Шар", "Рыба", "Лось", "Зима",
        "Лист", "Соль", "Зубр", "Роса", "Луч"
    ]

    init(mpcWorker: SiblingMPCWorker) {
        self.mpcWorker = mpcWorker
    }

    func loadGame(childId: String, peerDisplayName: String, localDisplayName: String) {
        mpcWorker.delegate = self
        self.peerDisplayName = peerDisplayName
        self.localDisplayName = localDisplayName
        words = Array(Self.defaultWords.shuffled().prefix(totalRounds))
        currentRound = 1
        ourTotalPoints = 0
        peerTotalPoints = 0
        logger.info("game loaded peerDisplayName=\(peerDisplayName, privacy: .public)")
        presenter?.presentGameLoaded(.init(
            words: words,
            peerDisplayName: peerDisplayName,
            totalRounds: totalRounds
        ))
    }

    func startRound(index: Int) {
        currentRound = index
        ourRoundScore = 0.0
        peerRoundScore = 0.0
        guard index >= 1, index <= words.count else { return }
        let word = words[index - 1]
        let isHost = localDisplayName < peerDisplayName
        if isHost {
            mpcWorker.send(.roundStart(word: word, roundIndex: index))
        }
        presenter?.presentRoundStart(.init(
            roundIndex: index,
            word: word,
            totalRounds: totalRounds
        ))
    }

    func evaluateAttempt() {
        // Бизнес-логика оценки произношения.
        // Пока mock через случайное значение; заменить на PronunciationScorer при интеграции.
        let mockScore = Float.random(in: 0.4...0.95)
        submitScore(mockScore)
    }

    func submitScore(_ score: Float) {
        ourRoundScore = score
        mpcWorker.send(.scoreUpdate(score: score, roundIndex: currentRound))
        presenter?.presentScoreUpdate(.init(
            ourRoundResult: ourRoundScore,
            peerRoundResult: peerRoundScore,
            ourTotalPoints: ourTotalPoints,
            peerTotalPoints: peerTotalPoints
        ))
        evaluateRoundIfReady()
    }

    func requestRematch() {
        currentRound = 1
        ourTotalPoints = 0
        peerTotalPoints = 0
        words = Array(Self.defaultWords.shuffled().prefix(totalRounds))
        startRound(index: 1)
    }

    func exitGame() {
        roundResultTask?.cancel()
        mpcWorker.send(.disconnect)
        router?.routeBackToChildHome()
    }

    private func evaluateRoundIfReady() {
        guard ourRoundScore > 0 || peerRoundScore > 0 else { return }
        let winnerName: String?
        if ourRoundScore > peerRoundScore {
            ourTotalPoints += 1
            winnerName = localDisplayName
        } else if peerRoundScore > ourRoundScore {
            peerTotalPoints += 1
            winnerName = peerDisplayName
        } else {
            winnerName = nil
        }
        presenter?.presentRoundResult(.init(winnerName: winnerName))
        mpcWorker.send(.roundResult(winnerPeerID: winnerName))

        if currentRound >= totalRounds {
            scheduleGameOver()
        } else {
            scheduleNextRound()
        }
    }

    private func scheduleNextRound() {
        roundResultTask?.cancel()
        roundResultTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.startRound(index: self.currentRound + 1)
            }
        }
    }

    private func scheduleGameOver() {
        roundResultTask?.cancel()
        roundResultTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run { [weak self] in
                guard let self else { return }
                let scores = [
                    self.localDisplayName: self.ourTotalPoints,
                    self.peerDisplayName: self.peerTotalPoints
                ]
                self.mpcWorker.send(.gameResult(finalScores: scores))
                let winner: String?
                if self.ourTotalPoints > self.peerTotalPoints { winner = self.localDisplayName }
                else if self.peerTotalPoints > self.ourTotalPoints { winner = self.peerDisplayName }
                else { winner = nil }
                self.presenter?.presentGameResult(.init(
                    winnerName: winner,
                    ourFinalScore: self.ourTotalPoints,
                    peerFinalScore: self.peerTotalPoints
                ))
            }
        }
    }
}

// MARK: - SiblingGameInteractor + SiblingMPCWorkerDelegate

extension SiblingGameInteractor: SiblingMPCWorkerDelegate {

    func mpcWorkerDidDiscoverPeer(displayName: String) {}
    func mpcWorkerDidLosePeer(displayName: String) {}

    func mpcWorkerDidReceiveInvite(from displayName: String, accept: @MainActor @escaping () -> Void) {
        accept()
    }

    func mpcWorkerDidConnect(displayName: String) {}

    func mpcWorkerDidDisconnect(displayName: String) {
        roundResultTask?.cancel()
        presenter?.presentConnectionLost(
            message: String(localized: "sibling.error.connection")
        )
    }

    func mpcWorkerDidReceive(message: SiblingMessage, from displayName: String) {
        switch message {
        case .roundStart(let word, let roundIndex):
            let isHost = localDisplayName < peerDisplayName
            if !isHost {
                if roundIndex >= 1, roundIndex <= words.count {
                    words[roundIndex - 1] = word
                }
                startRound(index: roundIndex)
            }
        case .scoreUpdate(let score, _):
            peerRoundScore = score
            presenter?.presentScoreUpdate(.init(
                ourRoundResult: ourRoundScore,
                peerRoundResult: peerRoundScore,
                ourTotalPoints: ourTotalPoints,
                peerTotalPoints: peerTotalPoints
            ))
            evaluateRoundIfReady()
        case .roundResult:
            break
        case .gameResult(let scores):
            let ourScore = scores[localDisplayName] ?? 0
            let peerScore = scores[peerDisplayName] ?? 0
            let winner: String?
            if ourScore > peerScore { winner = localDisplayName }
            else if peerScore > ourScore { winner = peerDisplayName }
            else { winner = nil }
            presenter?.presentGameResult(.init(
                winnerName: winner,
                ourFinalScore: ourScore,
                peerFinalScore: peerScore
            ))
        case .disconnect:
            roundResultTask?.cancel()
            presenter?.presentConnectionLost(
                message: String(localized: "sibling.error.connection")
            )
        default:
            break
        }
    }
}
