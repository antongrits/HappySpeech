import Foundation
import MultipeerConnectivity
import OSLog

// MARK: - SendablePeerID
//
// MCPeerID не Sendable (ObjC class без аннотации).
// Оборачиваем в @unchecked Sendable box для безопасной передачи через Task-границы.
// Реальная thread-safety обеспечена тем, что значение иммутабельно после создания.

private struct SendablePeerID: @unchecked Sendable {
    let value: MCPeerID
}

// MARK: - SiblingMPCWorkerDelegate
//
// Делегат принимает displayName (String) вместо MCPeerID напрямую —
// это необходимо для Swift 6 strict concurrency: MCPeerID не Sendable,
// поэтому его нельзя передавать через actor-boundaries напрямую.
// Worker хранит маппинг displayName → MCPeerID на @MainActor.

@MainActor
protocol SiblingMPCWorkerDelegate: AnyObject {
    func mpcWorkerDidDiscoverPeer(displayName: String)
    func mpcWorkerDidLosePeer(displayName: String)
    func mpcWorkerDidReceiveInvite(from displayName: String, accept: @MainActor @escaping () -> Void)
    func mpcWorkerDidConnect(displayName: String)
    func mpcWorkerDidDisconnect(displayName: String)
    func mpcWorkerDidReceive(message: SiblingMessage, from displayName: String)
}

// MARK: - SiblingMPCWorker
//
// Обёртка над MultipeerConnectivity для модуля «Игра вдвоём».
// Service type: "hs-sibling" (≤ 15 chars, lowercase + hyphens).
// Протокол: Bonjour LAN, без интернета → COPPA-compliant.

@MainActor
final class SiblingMPCWorker: NSObject {

    // MARK: - Constants

    static let serviceType = "hs-sibling"

    // MARK: - State

    private let myPeerID: MCPeerID
    /// nonisolated(unsafe): читается из nonisolated advertiser delegate (background thread),
    /// но записывается только из MainActor. MCSession thread-safe для send/disconnect.
    nonisolated(unsafe) private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// displayName → MCPeerID.
    /// Все записи и чтения строго на @MainActor — data race исключён.
    private var peerRegistry: [String: MCPeerID] = [:]

    weak var delegate: (any SiblingMPCWorkerDelegate)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SiblingMPC")

    // MARK: - Init

    init(displayName: String) {
        self.myPeerID = MCPeerID(displayName: displayName)
        super.init()
    }

    // MARK: - Lifecycle

    func start() {
        let newSession = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        newSession.delegate = self
        self.session = newSession

        let adv = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        self.advertiser = adv

        let brw = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        self.browser = brw

        logger.info("MPC started displayName=\(self.myPeerID.displayName, privacy: .public)")
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        peerRegistry.removeAll()
        logger.info("MPC stopped")
    }

    // MARK: - Invite

    func invite(displayName: String) {
        guard let session, let browser, let peerID = peerRegistry[displayName] else {
            logger.warning("invite: no peerID for displayName=\(displayName, privacy: .public)")
            return
        }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        logger.info("invite sent to \(displayName, privacy: .public)")
    }

    // MARK: - Send

    func send(_ message: SiblingMessage) {
        guard let session else { return }
        let peers = session.connectedPeers
        guard !peers.isEmpty else { return }
        do {
            let data = try encoder.encode(message)
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            logger.error("MPC send error: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Accessors

    var connectedDisplayNames: [String] {
        session?.connectedPeers.map(\.displayName) ?? []
    }

    func peerID(for displayName: String) -> MCPeerID? {
        peerRegistry[displayName]
    }
}

// MARK: - MCSessionDelegate

extension SiblingMPCWorker: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID,
                             didChange state: MCSessionState) {
        let name = peerID.displayName
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.logger.info("MPC peer connected: \(name, privacy: .public)")
                self.delegate?.mpcWorkerDidConnect(displayName: name)
            case .notConnected:
                self.logger.info("MPC peer disconnected: \(name, privacy: .public)")
                self.peerRegistry.removeValue(forKey: name)
                self.delegate?.mpcWorkerDidDisconnect(displayName: name)
            case .connecting:
                self.logger.debug("MPC peer connecting: \(name, privacy: .public)")
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let name = peerID.displayName
        let localDecoder = JSONDecoder()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let message = try localDecoder.decode(SiblingMessage.self, from: data)
                self.delegate?.mpcWorkerDidReceive(message: message, from: name)
            } catch {
                self.logger.error("MPC decode error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                             withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension SiblingMPCWorker: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let name = peerID.displayName
        let box = SendablePeerID(value: peerID)
        // Захватываем session до перехода на MainActor (MCSession thread-safe для передачи)
        let capturedSession = session
        Task { @MainActor [weak self] in
            self?.peerRegistry[name] = box.value
        }
        // Принимаем инвайт немедленно на background thread — COPPA safe (нет user data)
        invitationHandler(true, capturedSession)
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didNotStartAdvertisingPeer error: any Error) {
        Task { @MainActor [weak self] in
            self?.logger.error("advertiser error: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension SiblingMPCWorker: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        let name = peerID.displayName
        let box = SendablePeerID(value: peerID)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.peerRegistry[name] = box.value
            self.logger.debug("MPC found peer: \(name, privacy: .public)")
            self.delegate?.mpcWorkerDidDiscoverPeer(displayName: name)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let name = peerID.displayName
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.peerRegistry.removeValue(forKey: name)
            self.logger.debug("MPC lost peer: \(name, privacy: .public)")
            self.delegate?.mpcWorkerDidLosePeer(displayName: name)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                             didNotStartBrowsingForPeers error: any Error) {
        Task { @MainActor [weak self] in
            self?.logger.error("browser error: \(error.localizedDescription, privacy: .public)")
        }
    }
}
