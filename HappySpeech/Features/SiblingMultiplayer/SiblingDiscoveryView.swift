import MultipeerConnectivity
import OSLog
import SwiftUI

// MARK: - SiblingDiscoveryView
//
// Экран 1: поиск партнёра через MultipeerConnectivity.
// Контур: kid. Показывает анимацию-радар и список найденных пиров.

struct SiblingDiscoveryView: View {

    let childId: String

    @State private var viewModel = SiblingDiscoveryViewModel()
    @State private var interactor: SiblingDiscoveryInteractor?
    @State private var router: SiblingRouter?

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onPeerConnected: ((String) -> Void)?

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SiblingDiscovery")

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp5) {
                    radarSection

                    mascotSection

                    peersSection

                    cancelButton
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp6)
                .padding(.bottom, SpacingTokens.sp8)
            }

            if let errorMsg = viewModel.permissionError {
                permissionToast(message: errorMsg)
            }
        }
        .navigationTitle(String(localized: "sibling.discovery.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { bootstrap() }
        .onDisappear { interactor?.stopDiscovery() }
    }

    // MARK: - Radar

    private var radarSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            if reduceMotion {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(ColorTokens.Brand.sky)
                    .accessibilityHidden(true)
            } else {
                RadarAnimation()
                    .frame(width: 160, height: 160)
                    .accessibilityHidden(true)
            }

            Text(String(localized: "sibling.discovery.searching"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .opacity(viewModel.peers.isEmpty ? 1.0 : 0.0)
        }
    }

    // MARK: - Mascot

    private var mascotSection: some View {
        HSMascotView(
            mood: viewModel.peers.isEmpty ? .thinking : .encouraging,
            size: 80
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }

    // MARK: - Peers list

    private var peersSection: some View {
        Group {
            if viewModel.peers.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: SpacingTokens.sp3) {
                    ForEach(Array(viewModel.peers.enumerated()), id: \.element.id) { index, peer in
                        peerCell(peer: peer, index: index)
                    }
                }
            }
        }
    }

    private func peerCell(peer: SiblingPeerViewModel, index: Int) -> some View {
        Button {
            interactor?.invitePeer(displayName: peer.displayName)
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                avatarCircle(name: peer.displayName, size: 44)

                Text(peer.displayName)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp3)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String("\(peer.displayName), \(String(localized: "sibling.discovery.searching"))")
        )
        .accessibilityHint(String(localized: "sibling.discovery.searching"))
        .scaleEffect(viewModel.animateIn ? 1.0 : 0.95)
        .opacity(viewModel.animateIn ? 1.0 : 0.0)
        .animation(
            reduceMotion
                ? .easeIn(duration: 0.15)
                : MotionTokens.outQuick.delay(Double(index) * 0.05),
            value: viewModel.animateIn
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp6) {
            Image(systemName: "person.2.slash")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(ColorTokens.Kid.inkSoft)

            Text(String(localized: "sibling.discovery.empty"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp6)
        .accessibilityLabel(String(localized: "sibling.discovery.empty"))
    }

    // MARK: - Cancel button

    private var cancelButton: some View {
        HSButton(
            String(localized: "sibling.discovery.cancel"),
            style: .ghost
        ) {
            interactor?.cancelDiscovery()
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .accessibilityLabel(String(localized: "sibling.discovery.cancel"))
    }

    // MARK: - Permission toast

    private func permissionToast(message: String) -> some View {
        VStack {
            Spacer()
            HSToast(message, type: .error)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp4)
        }
    }

    // MARK: - Avatar helper

    private func avatarCircle(name: String, size: CGFloat) -> some View {
        let color = colorForName(name)
        return ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: size, height: size)
            Text(String(name.prefix(1)).uppercased())
                .font(TypographyTokens.headline(size * 0.4))
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }

    private func colorForName(_ name: String) -> Color {
        let colors: [Color] = [
            ColorTokens.Brand.primary,
            ColorTokens.Brand.sky,
            ColorTokens.Brand.mint,
            ColorTokens.Brand.butter,
            ColorTokens.Brand.lilac
        ]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        guard interactor == nil else { return }
        let localName = UIDevice.current.name
        let createdInteractor = SiblingDiscoveryInteractor(localDisplayName: localName)
        let presenter = SiblingDiscoveryPresenter()
        let createdRouter = SiblingRouter()
        createdRouter.coordinator = coordinator
        createdRouter.onRouteLobby = { [weak createdInteractor] peerID in
            onPeerConnected?(peerID.displayName)
        }
        createdRouter.onRouteBackDiscovery = {}
        createdInteractor.presenter = presenter
        createdInteractor.router = createdRouter
        presenter.view = viewModel
        self.interactor = createdInteractor
        self.router = createdRouter
        createdInteractor.startDiscovery()
        Self.logger.debug("SiblingDiscovery bootstrapped childId=\(childId, privacy: .public)")
    }
}

// MARK: - SiblingDiscoveryViewModel

@Observable
@MainActor
final class SiblingDiscoveryViewModel: SiblingDiscoveryDisplayLogic {
    var peers: [SiblingPeerViewModel] = []
    var isSearching: Bool = true
    var permissionError: String?
    var animateIn: Bool = false

    func displayPeers(_ viewModel: SiblingModels.Discovery.ViewModel) {
        peers = viewModel.peers
        isSearching = viewModel.isSearching
        withAnimation { animateIn = true }
    }

    func displayInviteSent(_ viewModel: SiblingModels.InvitePeer.ViewModel) {}

    func displayPermissionError(message: String) {
        permissionError = message
    }
}

// MARK: - RadarAnimation

private struct RadarAnimation: View {

    @State private var scale1: CGFloat = 0.3
    @State private var scale2: CGFloat = 0.3
    @State private var scale3: CGFloat = 0.3
    @State private var opacity1: Double = 0.8
    @State private var opacity2: Double = 0.8
    @State private var opacity3: Double = 0.8

    var body: some View {
        ZStack {
            radarRing(scale: scale3, opacity: opacity3)
                .onAppear {
                    withAnimation(
                        .easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(0.6)
                    ) {
                        scale3 = 1.0
                        opacity3 = 0.0
                    }
                }
            radarRing(scale: scale2, opacity: opacity2)
                .onAppear {
                    withAnimation(
                        .easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(0.3)
                    ) {
                        scale2 = 1.0
                        opacity2 = 0.0
                    }
                }
            radarRing(scale: scale1, opacity: opacity1)
                .onAppear {
                    withAnimation(
                        .easeOut(duration: 2.0).repeatForever(autoreverses: false)
                    ) {
                        scale1 = 1.0
                        opacity1 = 0.0
                    }
                }

            Image(systemName: "antenna.radiowaves.left.and.right")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(ColorTokens.Brand.sky)
        }
    }

    private func radarRing(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .stroke(ColorTokens.Brand.sky, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .frame(width: 140, height: 140)
    }
}

// MARK: - Preview

#Preview("Discovery — Light") {
    NavigationStack {
        SiblingDiscoveryView(childId: "preview-child-1")
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}
