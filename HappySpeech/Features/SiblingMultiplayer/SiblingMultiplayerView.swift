import MultipeerConnectivity
import OSLog
import SwiftUI

// MARK: - SiblingMultiplayerRoute

enum SiblingMultiplayerRoute: Hashable {
    case lobby(peerDisplayName: String)
    case game(peerDisplayName: String)
}

// MARK: - SiblingMultiplayerView
//
// Root NavigationStack для всего модуля «Игра вдвоём».
// Управляет переходами: Discovery → Lobby → Game.
// mpcWorker живёт здесь и передаётся вниз — ownership чёткий.
// Контур: kid.

struct SiblingMultiplayerView: View {

    let childId: String

    @State private var navigationPath: [SiblingMultiplayerRoute] = []
    @State private var mpcWorker: SiblingMPCWorker?

    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SiblingMultiplayer")
    private let localDisplayName = UIDevice.current.name

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SiblingDiscoveryView(
                childId: childId,
                onPeerConnected: { peerDisplayName in
                    handlePeerConnected(displayName: peerDisplayName)
                }
            )
            .navigationDestination(for: SiblingMultiplayerRoute.self) { route in
                routeDestination(route)
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func routeDestination(_ route: SiblingMultiplayerRoute) -> some View {
        switch route {
        case .lobby(let peerDisplayName):
            if let worker = mpcWorker,
               let peerID = worker.peerID(for: peerDisplayName) {
                SiblingLobbyView(
                    peerID: peerID,
                    mpcWorker: worker,
                    localDisplayName: localDisplayName,
                    childId: childId,
                    onBothReady: {
                        handleBothReady(peerDisplayName: peerDisplayName)
                    }
                )
            } else {
                Text(String(localized: "sibling.error.connection"))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }

        case .game(let peerDisplayName):
            if let worker = mpcWorker,
               let peerID = worker.peerID(for: peerDisplayName) {
                SiblingGameView(
                    mpcWorker: worker,
                    peerID: peerID,
                    childId: childId,
                    localDisplayName: localDisplayName
                )
            } else {
                Text(String(localized: "sibling.error.connection"))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
    }

    // MARK: - Navigation logic

    private func handlePeerConnected(displayName: String) {
        Self.logger.info("routing to lobby peerDisplayName=\(displayName, privacy: .public)")
        navigationPath.append(.lobby(peerDisplayName: displayName))
    }

    private func handleBothReady(peerDisplayName: String) {
        Self.logger.info("both ready → routing to game")
        navigationPath.append(.game(peerDisplayName: peerDisplayName))
    }
}

// MARK: - Preview

#Preview("Sibling Multiplayer — Root") {
    SiblingMultiplayerView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
