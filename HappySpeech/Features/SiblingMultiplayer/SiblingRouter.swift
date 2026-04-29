import Foundation
import MultipeerConnectivity
import SwiftUI

// MARK: - SiblingRoutingLogic

@MainActor
protocol SiblingRoutingLogic: AnyObject {
    func routeToLobby(peerID: MCPeerID)
    func routeToGame(peerID: MCPeerID, childId: String)
    func routeBackToDiscovery()
    func routeBackToChildHome()
}

// MARK: - SiblingRouter

@MainActor
final class SiblingRouter: SiblingRoutingLogic {

    weak var coordinator: AppCoordinator?

    /// Коллбэки для навигации внутри SiblingMultiplayerView (NavigationStack).
    var onRouteLobby: ((_ peerID: MCPeerID) -> Void)?
    var onRouteGame: ((_ peerID: MCPeerID, _ childId: String) -> Void)?
    var onRouteBackDiscovery: (() -> Void)?

    func routeToLobby(peerID: MCPeerID) {
        onRouteLobby?(peerID)
    }

    func routeToGame(peerID: MCPeerID, childId: String) {
        onRouteGame?(peerID, childId)
    }

    func routeBackToDiscovery() {
        onRouteBackDiscovery?()
    }

    func routeBackToChildHome() {
        coordinator?.navigate(to: .childHome(childId: ""))
    }
}
