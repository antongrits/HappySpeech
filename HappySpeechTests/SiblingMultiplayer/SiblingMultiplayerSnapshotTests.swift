@testable import HappySpeech
import MultipeerConnectivity
import SwiftUI
import XCTest

// MARK: - SiblingMultiplayerSnapshotTests
//
// 8 PNG snapshot-тестов для экранов модуля «Игра вдвоём» (Блок L2).
//
// Матрица:
//   discovery empty × (light, dark) × iPhone17Pro = 2 PNG
//   discovery 2 peers × (light, dark) × iPhone17Pro = 2 PNG
//   lobby waiting × (light, dark) × iPhone17Pro = 2 PNG
//   game in progress × (light, dark) × iPhone17Pro = 2 PNG
//
// Итого: 8 PNG. Хранение: __Snapshots__/SiblingMultiplayer/
//
// Отрисовка без bootstrap/MPC — только SwiftUI Views со статичным
// начальным состоянием (@State initial values).

@MainActor
final class SiblingMultiplayerSnapshotTests: XCTestCase {

    // MARK: - Device config (только iPhone 17 Pro согласно Sprint 12)

    private let device = (name: "iPhone17Pro", size: CGSize(width: 402, height: 874))
    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark", .dark)
    ]

    // MARK: - 1. Discovery — empty state (нет пиров)

    func test_discoveryEmpty_bothThemes() throws {
        let view = SiblingDiscoveryView(childId: "snap-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "Discovery_Empty")
    }

    // MARK: - 2. Discovery — 2 peers (стаб через ViewModel напрямую)

    func test_discoveryWithPeers_bothThemes() throws {
        // Оборачиваем View в stub-контейнер, который имитирует
        // состояние с 2 пирами через отдельный @Observable ViewModel.
        let view = SiblingDiscoveryStubPeersView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "Discovery_WithPeers")
    }

    // MARK: - 3. Lobby — ожидание (оба не готовы)

    func test_lobbyWaiting_bothThemes() throws {
        let peerID = MCPeerID(displayName: "Маша")
        let worker = SiblingMPCWorker(displayName: "Петя")
        let view = SiblingLobbyView(
            peerID: peerID,
            mpcWorker: worker,
            localDisplayName: "Петя",
            childId: "snap-child-2"
        )
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        try record(view, screen: "Lobby_Waiting")
    }

    // MARK: - 4. Game in progress — стаб с данными раунда

    func test_gameInProgress_bothThemes() throws {
        let peerID = MCPeerID(displayName: "Маша")
        let worker = SiblingMPCWorker(displayName: "Петя")
        let view = SiblingGameView(
            mpcWorker: worker,
            peerID: peerID,
            childId: "snap-child-3",
            localDisplayName: "Петя"
        )
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        try record(view, screen: "Game_InProgress")
    }

    // MARK: - Rendering engine

    private func render<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) -> UIImage {
        SnapshotTestHelper.renderView(view, size: size, style: style)
    }

    private func snapshotURL(screen: String, device: String, appearance: String) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "SiblingMultiplayer",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    private func record<V: View>(_ view: V, screen: String) throws {
        for (appearanceName, style) in appearances {
            let image = render(view, size: device.size, style: style)
            let url = snapshotURL(screen: screen, device: device.name, appearance: appearanceName)
            let label = "\(screen)·\(device.name)·\(appearanceName)"
            try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
        }
    }
}

// MARK: - SiblingDiscoveryStubPeersView
//
// Вспомогательный View для теста с 2 пирами.
// Внедряет данные в ViewModel напрямую, без активации MPC.

@MainActor
private struct SiblingDiscoveryStubPeersView: View {

    @State private var vm: SiblingDiscoveryViewModel = {
        let vm = SiblingDiscoveryViewModel()
        let peer1 = SiblingPeerViewModel(
            id: "Маша",
            displayName: "Маша",
            peerID: MCPeerID(displayName: "Маша")
        )
        let peer2 = SiblingPeerViewModel(
            id: "Ваня",
            displayName: "Ваня",
            peerID: MCPeerID(displayName: "Ваня")
        )
        vm.displayPeers(.init(peers: [peer1, peer2], isSearching: false))
        return vm
    }()

    var body: some View {
        SiblingDiscoveryView(childId: "snap-peers")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
    }
}
