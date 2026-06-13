import MultipeerConnectivity
import OSLog
import SwiftUI

// MARK: - SiblingLobbyView
//
// Экран 2: лобби готовности игроков перед совместной игрой.
// Контур: kid. Тёплый кремовый фон, карточки игроков со статусом «готов»,
// маскот-подсказка и CTA «Начать игру» — по эталону multiplayer-lobby.

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

    private var readyCount: Int {
        (viewModel.localReady ? 1 : 0) + (viewModel.peerReady ? 1 : 0)
    }

    var body: some View {
        ZStack {
            HSMeshGradientBackground(palette: .kidWarm, animated: false)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sp5) {
                    nearbyChip

                    mascotCheer

                    playersSection

                    countdownLabel
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp4)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { footer }
        }
        .navigationTitle(String(localized: "sibling.lobby.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { bootstrap() }
    }

    // MARK: - Nearby chip

    private var nearbyChip: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Circle()
                .fill(viewModel.bothReady ? ColorTokens.Brand.mint : ColorTokens.Brand.butter)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)

            Text(String(localized: "sibling.lobby.chip_count"))
                .font(TypographyTokens.headline(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)

            Spacer(minLength: 0)

            Text(String(localized: "sibling.lobby.subtitle"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp3)
        .background(Capsule().fill(ColorTokens.Kid.surface))
        .overlay(Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "sibling.lobby.subtitle"))
    }

    // MARK: - Mascot cheer

    private var mascotCheer: some View {
        HStack(spacing: SpacingTokens.sp3) {
            HSMascotView(
                mood: viewModel.bothReady ? .celebrating : .happy,
                size: 64
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(String(localized: "sibling.lobby.cheer_title"))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)

                Text(String(localized: "sibling.lobby.cheer_sub"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Players

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                Text(String(localized: "sibling.lobby.players_title"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                readyCountPill
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: SpacingTokens.sp3),
                    GridItem(.flexible(), spacing: SpacingTokens.sp3)
                ],
                spacing: SpacingTokens.sp3
            ) {
                playerCard(
                    name: viewModel.localDisplayName.isEmpty ? localDisplayName : viewModel.localDisplayName,
                    isReady: viewModel.localReady,
                    isHost: true
                )
                playerCard(
                    name: viewModel.peerDisplayName.isEmpty ? peerID.displayName : viewModel.peerDisplayName,
                    isReady: viewModel.peerReady,
                    isHost: false
                )
            }
        }
    }

    private var readyCountPill: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: "checkmark.circle.fill")
                .font(TypographyTokens.caption(12))
            Text(String(format: String(localized: "sibling.lobby.ready_count"), readyCount, 2))
                .font(TypographyTokens.headline(13))
        }
        .foregroundStyle(readyCount == 2 ? ColorTokens.Brand.mint : ColorTokens.Kid.inkMuted)
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp1)
        .background(
            Capsule().fill(
                readyCount == 2
                    ? ColorTokens.Semantic.successBg
                    : ColorTokens.Kid.bgSoft
            )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "sibling.lobby.ready_count"), readyCount, 2))
    }

    private func playerCard(name: String, isReady: Bool, isHost: Bool) -> some View {
        let statusColor = isReady ? ColorTokens.Brand.mint : ColorTokens.Kid.inkSoft
        let statusText = isReady
            ? String(localized: "sibling.lobby.ready")
            : String(localized: "sibling.lobby.waiting")

        return HSCard(padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                avatarCircle(name: name, size: 46)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(name)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: SpacingTokens.micro) {
                        if isReady {
                            Image(systemName: "checkmark.circle.fill")
                                .font(TypographyTokens.caption(11))
                        } else {
                            ProgressView()
                                .controlSize(.mini)
                                .accessibilityHidden(true)
                        }
                        Text(statusText)
                            .font(TypographyTokens.caption(11))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(statusColor)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            if isHost {
                hostBadge
                    .offset(x: -SpacingTokens.sp2, y: -SpacingTokens.micro)
            }
        }
        .scaleEffect(isReady && !reduceMotion ? 1.0 : 0.99)
        .animation(reduceMotion ? nil : MotionTokens.spring, value: isReady)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isHost
                ? "\(name), \(String(localized: "sibling.a11y.host")), \(statusText)"
                : "\(name), \(statusText)"
        )
    }

    private var hostBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "crown.fill")
                .font(.system(size: 9, weight: .bold))
            Text(String(localized: "sibling.lobby.host"))
                .font(TypographyTokens.headline(10))
        }
        .foregroundStyle(ColorTokens.Brand.gold)
        .padding(.horizontal, SpacingTokens.sp2)
        .padding(.vertical, 3)
        .background(Capsule().fill(ColorTokens.Brand.butter.opacity(0.45)))
        .accessibilityHidden(true)
    }

    // MARK: - Countdown

    private var countdownLabel: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: "timer")
                .font(TypographyTokens.caption(11))
                .accessibilityHidden(true)
            Text("\(countdown)")
                .font(TypographyTokens.mono(13))
        }
        .foregroundStyle(ColorTokens.Kid.inkSoft)
        .accessibilityHidden(true)
        .task {
            for sec in stride(from: 60, through: 0, by: -1) {
                countdown = sec
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSButton(
                viewModel.localReady
                    ? String(localized: "sibling.lobby.cta_start")
                    : String(localized: "sibling.lobby.cta_ready"),
                style: .primary,
                icon: viewModel.localReady ? "play.fill" : "hand.thumbsup.fill"
            ) {
                guard !viewModel.localReady else { return }
                interactor?.setReady()
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .disabled(viewModel.localReady)
            .accessibilityLabel(String(localized: "sibling.lobby.cta_ready"))
            .accessibilityHint(String(localized: "sibling.lobby.cheer_sub"))

            HStack(spacing: SpacingTokens.micro) {
                Image(systemName: "checkmark.shield.fill")
                    .font(TypographyTokens.caption(11))
                Text(String(localized: "sibling.lobby.safe_note"))
                    .font(TypographyTokens.caption(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(ColorTokens.Kid.inkSoft)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "sibling.lobby.safe_note"))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.sp3)
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
        let createdInteractor = SiblingLobbyInteractor(
            mpcWorker: mpcWorker,
            peerID: peerID,
            childId: childId
        )
        let presenter = SiblingLobbyPresenter()
        createdInteractor.presenter = presenter
        presenter.view = viewModel
        createdInteractor.router = nil
        viewModel.onBothReadyAction = onBothReady
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

#Preview("Lobby — Dark") {
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
    .preferredColorScheme(.dark)
}
