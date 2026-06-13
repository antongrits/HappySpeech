import MultipeerConnectivity
import OSLog
import SwiftUI

// MARK: - SiblingDiscoveryView
//
// Экран 1: поиск партнёра через MultipeerConnectivity.
// Контур: kid. Тёплый кремовый фон, радар-поиск, список найденных устройств
// в стиле эталона multiplayer-lobby (состояние «Поиск друзей»).

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
            HSMeshGradientBackground(palette: .kidWarm, animated: false)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp5) {
                    statusChip

                    radarSection

                    mascotCheer

                    foundSection

                    networkHint
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp4)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { footer }

            if let errorMsg = viewModel.permissionError {
                permissionToast(message: errorMsg)
            }
        }
        .navigationTitle(String(localized: "sibling.discovery.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { bootstrap() }
        .onDisappear { interactor?.stopDiscovery() }
    }

    // MARK: - Status chip

    private var statusChip: some View {
        HStack(spacing: SpacingTokens.sp2) {
            statusDot

            Text(String(localized: "sibling.discovery.chip_searching"))
                .font(TypographyTokens.headline(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)

            Spacer(minLength: 0)

            Text(String(localized: "sibling.discovery.subtitle"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            Capsule().fill(ColorTokens.Kid.surface)
        )
        .overlay(
            Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "sibling.discovery.chip_searching"))
    }

    private var statusDot: some View {
        Circle()
            .fill(ColorTokens.Brand.butter)
            .frame(width: 9, height: 9)
            .overlay(
                Circle()
                    .stroke(ColorTokens.Brand.butter.opacity(0.4), lineWidth: 2)
                    .scaleEffect(viewModel.animateIn && !reduceMotion ? 2.0 : 1.0)
                    .opacity(viewModel.animateIn && !reduceMotion ? 0 : 1)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                        value: viewModel.animateIn
                    )
            )
            .accessibilityHidden(true)
    }

    // MARK: - Radar

    private var radarSection: some View {
        ZStack {
            if reduceMotion {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
            } else {
                RadarAnimation()
                    .frame(width: 200, height: 200)
                    .accessibilityHidden(true)
            }

            LyalyaMascotView(
                state: viewModel.peers.isEmpty ? .thinking : .waving,
                size: 76
            )
            .accessibilityHidden(true)
        }
        .frame(height: 206)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mascot cheer bubble

    private var mascotCheer: some View {
        VStack(spacing: SpacingTokens.sp1) {
            Text(String(localized: "sibling.discovery.cheer_title"))
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            Text(String(localized: "sibling.discovery.cheer_sub"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Found devices

    private var foundSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                Text(String(localized: "sibling.discovery.found_title"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if !viewModel.peers.isEmpty {
                    countPill(viewModel.peers.count)
                }
            }

            if viewModel.peers.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: SpacingTokens.listGap) {
                    ForEach(Array(viewModel.peers.enumerated()), id: \.element.id) { index, peer in
                        deviceRow(peer: peer, index: index)
                    }
                }
            }
        }
    }

    private func countPill(_ count: Int) -> some View {
        Text(String.localizedStringWithFormat(String(localized: "sibling.discovery.found_count"), count))
            .font(TypographyTokens.headline(13))
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp1)
            .background(
                Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.5))
            )
            .accessibilityHidden(true)
    }

    private func deviceRow(peer: SiblingPeerViewModel, index: Int) -> some View {
        HSCard(padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                avatarCircle(name: peer.displayName, size: 44)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(peer.displayName)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: SpacingTokens.micro) {
                        Circle()
                            .fill(ColorTokens.Brand.mint)
                            .frame(width: 6, height: 6)
                        Text(String(localized: "sibling.discovery.device_ready"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Spacer(minLength: SpacingTokens.sp2)

                Button {
                    interactor?.invitePeer(displayName: peer.displayName)
                } label: {
                    Text(String(localized: "sibling.discovery.invite"))
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .padding(.horizontal, SpacingTokens.sp4)
                        .padding(.vertical, SpacingTokens.sp2)
                        .background(
                            Capsule().fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(String(localized: "sibling.discovery.invite")), \(peer.displayName)"
                )
                .accessibilityHint(String(localized: "sibling.a11y.invite_hint"))
            }
        }
        .scaleEffect(viewModel.animateIn ? 1.0 : 0.96)
        .opacity(viewModel.animateIn ? 1.0 : 0.0)
        .animation(
            reduceMotion
                ? .easeIn(duration: 0.15)
                : MotionTokens.outQuick.delay(Double(index) * 0.06),
            value: viewModel.animateIn
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HSCard {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "person.2.wave.2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .accessibilityHidden(true)

                Text(String(localized: "sibling.discovery.empty"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "sibling.discovery.empty"))
    }

    // MARK: - Network hint

    private var networkHint: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "wifi")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)

            Text(String(localized: "sibling.discovery.network_hint"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Kid.bgSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "sibling.discovery.network_hint"))
    }

    // MARK: - Footer

    private var footer: some View {
        HSButton(
            String(localized: "sibling.discovery.cancel"),
            style: .ghost
        ) {
            interactor?.cancelDiscovery()
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.sp3)
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
                .fill(color.opacity(0.22))
                .frame(width: size, height: size)
            Text(String(name.prefix(1)).uppercased())
                .font(TypographyTokens.headline(size * 0.42))
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }

    private func colorForName(_ name: String) -> Color {
        let colors: [Color] = [
            ColorTokens.Brand.primary,
            ColorTokens.Brand.rose,
            ColorTokens.Brand.lilac,
            ColorTokens.Brand.gold,
            ColorTokens.Brand.sky
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
        createdRouter.onRouteLobby = { peerID in
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
            staticRing(120)
            staticRing(180)

            radarPulse(scale: scale3, opacity: opacity3)
                .onAppear {
                    withAnimation(
                        .easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(1.8)
                    ) {
                        scale3 = 3.0
                        opacity3 = 0.0
                    }
                }
            radarPulse(scale: scale2, opacity: opacity2)
                .onAppear {
                    withAnimation(
                        .easeOut(duration: 2.6).repeatForever(autoreverses: false).delay(0.9)
                    ) {
                        scale2 = 3.0
                        opacity2 = 0.0
                    }
                }
            radarPulse(scale: scale1, opacity: opacity1)
                .onAppear {
                    withAnimation(
                        .easeOut(duration: 2.6).repeatForever(autoreverses: false)
                    ) {
                        scale1 = 3.0
                        opacity1 = 0.0
                    }
                }
        }
    }

    private func staticRing(_ size: CGFloat) -> some View {
        Circle()
            .stroke(ColorTokens.Brand.primary.opacity(0.30), lineWidth: 1.5)
            .frame(width: size, height: size)
    }

    private func radarPulse(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [ColorTokens.Brand.primary.opacity(0.25), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 30
                )
            )
            .frame(width: 60, height: 60)
            .scaleEffect(scale)
            .opacity(opacity)
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

#Preview("Discovery — Dark") {
    NavigationStack {
        SiblingDiscoveryView(childId: "preview-child-1")
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
    .preferredColorScheme(.dark)
}
