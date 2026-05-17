import MultipeerConnectivity
import OSLog
import SwiftUI

// MARK: - SiblingLobbyView
//
// Экран 2: ожидание готовности обоих игроков.
// Контур: kid.

struct SiblingLobbyView: View {

    let peerID: MCPeerID
    let mpcWorker: SiblingMPCWorker
    let localDisplayName: String
    let childId: String
    var onBothReady: (() -> Void)?

    @State private var viewModel = SiblingLobbyViewModel()
    @State private var interactor: SiblingLobbyInteractor?
    @State private var countdown: Int = 60

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SiblingLobby")

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.xxLarge) {
                Spacer()

                avatarPair

                mascotSection

                readyButton

                countdownLabel

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .navigationTitle(String(localized: "sibling.lobby.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { bootstrap() }
    }

    // MARK: - Avatar pair

    private var avatarPair: some View {
        HStack(spacing: SpacingTokens.xxxLarge) {
            playerAvatar(
                name: localDisplayName,
                isReady: viewModel.localReady
            )

            vsLabel

            playerAvatar(
                name: peerID.displayName,
                isReady: viewModel.peerReady
            )
        }
    }

    private func playerAvatar(name: String, isReady: Bool) -> some View {
        let badgeColor = isReady ? ColorTokens.Semantic.successBg : ColorTokens.Semantic.warningBg
        let badgeText = isReady
            ? String(localized: "sibling.lobby.ready")
            : String(localized: "sibling.lobby.waiting")
        let badgeSymbol = isReady ? "checkmark.circle.fill" : "clock.fill"

        return VStack(spacing: SpacingTokens.sp2) {
            avatarCircle(name: name, size: 80)

            Text(name)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: 100)

            HStack(spacing: 4) {
                Image(systemName: badgeSymbol)
                    .font(TypographyTokens.caption(12))
                Text(badgeText)
                    .font(TypographyTokens.caption(12))
            }
            .foregroundStyle(isReady ? ColorTokens.Semantic.success : ColorTokens.Semantic.warning)
            .padding(.horizontal, SpacingTokens.sp2)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(badgeColor)
            )
            .scaleEffect(isReady ? 1.0 : 0.8)
            .opacity(isReady ? 1.0 : 0.85)
            .animation(
                reduceMotion ? nil : MotionTokens.spring,
                value: isReady
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(name) \(isReady ? String(localized: "sibling.lobby.ready") : String(localized: "sibling.lobby.waiting"))"
        )
    }

    private var vsLabel: some View {
        Text(String(localized: "sibling.lobby.vs"))
            .font(TypographyTokens.display(36))
            .foregroundStyle(ColorTokens.Brand.primary)
            .scaleEffect(viewModel.vsPulse ? 1.1 : 1.0)
            .animation(
                reduceMotion ? nil : Animation.easeInOut(duration: 0.25).repeatCount(2, autoreverses: true),
                value: viewModel.vsPulse
            )
            .accessibilityHidden(true)
    }

    // MARK: - Mascot

    private var mascotSection: some View {
        HSMascotView(
            mood: viewModel.bothReady ? .celebrating : .idle,
            size: 100
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }

    // MARK: - Ready button

    private var readyButton: some View {
        HSButton(
            viewModel.localReady
                ? String(localized: "sibling.lobby.waiting")
                : String(localized: "sibling.lobby.cta_ready"),
            style: .primary,
            icon: "hand.thumbsup.fill"
        ) {
            guard !viewModel.localReady else { return }
            interactor?.setReady()
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .disabled(viewModel.localReady)
        .accessibilityLabel(String(localized: "sibling.lobby.cta_ready"))
        .accessibilityHint(String(localized: "sibling.lobby.waiting"))
    }

    // MARK: - Countdown

    private var countdownLabel: some View {
        Text("\(countdown)")
            .font(TypographyTokens.mono(13))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .accessibilityLabel(String(format: "%d", countdown))
            .task {
                for sec in stride(from: 60, through: 0, by: -1) {
                    countdown = sec
                    try? await Task.sleep(for: .seconds(1))
                }
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
        let createdInteractor = SiblingLobbyInteractor(
            mpcWorker: mpcWorker,
            peerID: peerID,
            childId: childId
        )
        let presenter = SiblingLobbyPresenter()
        createdInteractor.presenter = presenter
        presenter.view = viewModel
        createdInteractor.router = nil
        self.interactor = createdInteractor
        createdInteractor.loadLobby(
            peerDisplayName: peerID.displayName,
            localDisplayName: localDisplayName
        )
        Self.logger.debug("SiblingLobby bootstrapped peer=\(peerID.displayName, privacy: .public)")
    }
}

// MARK: - SiblingLobbyViewModel

@Observable
@MainActor
final class SiblingLobbyViewModel: SiblingLobbyDisplayLogic {
    var localDisplayName: String = ""
    var peerDisplayName: String = ""
    var localReady: Bool = false
    var peerReady: Bool = false
    var bothReady: Bool = false
    var vsPulse: Bool = false
    var toastError: String?

    var onBothReadyAction: (() -> Void)?

    func displayLobbyLoaded(_ viewModel: SiblingModels.LobbyLoad.ViewModel) {
        localDisplayName = viewModel.localDisplayName
        peerDisplayName = viewModel.peerDisplayName
    }

    func displayReadyState(_ viewModel: SiblingModels.ReadyState.ViewModel) {
        localReady = viewModel.localReady
        peerReady = viewModel.peerReady
        if viewModel.localReady && viewModel.peerReady && !bothReady {
            bothReady = true
            vsPulse = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                self?.onBothReadyAction?()
            }
        }
    }

    func displayTimeout(_ viewModel: SiblingModels.LobbyTimeout.ViewModel) {
        toastError = viewModel.errorMessage
    }
}

// MARK: - Preview

#Preview("Lobby — Waiting") {
    NavigationStack {
        SiblingLobbyView(
            peerID: MCPeerID(displayName: "Маша"),
            mpcWorker: SiblingMPCWorker(displayName: "Петя"),
            localDisplayName: "Петя",
            childId: "preview-child-1"
        )
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}
