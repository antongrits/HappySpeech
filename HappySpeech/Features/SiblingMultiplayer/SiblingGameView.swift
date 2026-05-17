import MultipeerConnectivity
import OSLog
import SwiftUI

// MARK: - SiblingGameView
//
// Экран 3: соревновательная игра (5 раундов).
// Контур: kid. ASR pipeline: AudioService → PronunciationScorer.

struct SiblingGameView: View {

    let mpcWorker: SiblingMPCWorker
    let peerID: MCPeerID
    let childId: String
    let localDisplayName: String

    @State private var display = SiblingGameDisplay()
    @State private var interactor: SiblingGameInteractor?
    // Strong reference: presenter.view — weak, без strong-владельца adapter освободится
    // моментально и presenter callbacks никогда не сработают.
    @State private var viewAdapter: SiblingGameViewAdapter?
    @State private var showExitAlert: Bool = false
    @State private var showRoundOverlay: Bool = false
    @State private var showEndGame: Bool = false

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SiblingGame")

    var body: some View {
        ZStack {
            ColorTokens.Kid.bgDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .frame(height: 52)

                Spacer(minLength: 0)

                targetWordZone
                    .frame(height: 180)

                micZone
                    .frame(height: 120)

                scoreBarsZone
                    .frame(height: 100)
                    .padding(.horizontal, SpacingTokens.screenEdge)

                exitZone
                    .frame(height: 56)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: SpacingTokens.sp4) }

            if showRoundOverlay {
                roundResultOverlay
                    .transition(.opacity)
            }

            if showEndGame {
                endGameOverlay
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.95).combined(with: .opacity)
                    )
            }
        }
        .navigationBarHidden(true)
        .alert(String(localized: "sibling.game.exit"), isPresented: $showExitAlert) {
            Button(String(localized: "sibling.game.exit"), role: .destructive) {
                interactor?.exitGame()
            }
            Button(String(localized: "sibling.discovery.cancel"), role: .cancel) {}
        }
        .onAppear { bootstrap() }
    }

    // MARK: - HeaderBar

    private var headerBar: some View {
        HStack {
            Text(display.roundLabel)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .accessibilityHidden(true)

            Spacer()

            Text("\(display.localDisplayName) \(display.ourScore) — \(display.peerScore) \(display.peerDisplayName)")
                .font(TypographyTokens.mono(13))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityLabel(
                    String(
                        format: String(localized: "sibling.a11y.score_format"),
                        display.localDisplayName,
                        display.ourScore,
                        display.peerScore,
                        display.peerDisplayName
                    )
                )

            Spacer()

            Button {
                showExitAlert = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(TypographyTokens.body(20))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "sibling.game.exit"))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .background(ColorTokens.Kid.surface.opacity(0.95))
    }

    // MARK: - TargetWord

    private var targetWordZone: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSCard {
                VStack(spacing: SpacingTokens.sp2) {
                    Text(String(localized: "sibling.game.instruction"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)

                    Text(display.currentWord)
                        .font(TypographyTokens.kidDisplay(40))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .accessibilityLabel(
                            "\(String(localized: "sibling.game.instruction")) \(display.currentWord)"
                        )
                        .scaleEffect(display.currentWord.isEmpty ? 0.9 : 1.0)
                        .animation(
                            reduceMotion ? nil : MotionTokens.outQuick,
                            value: display.currentWord
                        )

                    Button {
                    } label: {
                        Label(
                            String(localized: "sibling.game.instruction"),
                            systemImage: "speaker.wave.2.fill"
                        )
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                    }
                    .accessibilityLabel("Послушать как произносит Ляля")
                }
                .padding(SpacingTokens.sp4)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding(.horizontal, SpacingTokens.screenEdge)

            HSMascotView(
            mood: mascotState,
                size: 56
            )
            .accessibilityHidden(true)
        }
    }

    private var mascotState: MascotMood {
        switch display.roundPhase {
        case .listening: return .thinking
        case .result(let winner):
            return winner == localDisplayName ? .celebrating : .encouraging
        case .gameOver(let winner):
            return winner == localDisplayName ? .celebrating : .encouraging
        default: return .idle
        }
    }

    // MARK: - Mic

    private var micZone: some View {
        VStack {
            Button {
                handleMicTap()
            } label: {
                ZStack {
                    if display.isListening {
                        Circle()
                            .stroke(ColorTokens.Brand.primary.opacity(0.5), lineWidth: 2)
                            .scaleEffect(display.isListening ? 1.3 : 1.0)
                            .opacity(display.isListening ? 0.0 : 1.0)
                            .frame(width: 80, height: 80)
                            .animation(
                                reduceMotion ? nil :
                                    .easeOut(duration: 0.8)
                                    .repeatForever(autoreverses: false),
                                value: display.isListening
                            )
                    }
                    Circle()
                        .fill(ColorTokens.Brand.primary)
                        .frame(width: 80, height: 80)
                    Image(systemName: display.isListening ? "stop.fill" : "mic.fill")
                        .font(TypographyTokens.kidDisplay(32))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Записать ответ")
            .accessibilityHint("Нажми и произнеси слово")
        }
        .frame(maxWidth: .infinity)
    }

    private func handleMicTap() {
        if display.isListening {
            display.isListening = false
            interactor?.evaluateAttempt()
        } else {
            display.isListening = true
            display.roundPhase = .listening
        }
    }

    // MARK: - Score bars

    private var scoreBarsZone: some View {
        VStack(spacing: SpacingTokens.sp2) {
            scoreRow(
                name: display.localDisplayName,
                result: display.ourRoundResult,
                points: display.ourScore,
                barColor: ColorTokens.Brand.primary,
                a11yLabel: "Твой результат \(Int(display.ourRoundResult * 100)) процентов"
            )
            scoreRow(
                name: display.peerDisplayName,
                result: display.peerRoundResult,
                points: display.peerScore,
                barColor: ColorTokens.Brand.sky,
                a11yLabel: "\(display.peerDisplayName): \(Int(display.peerRoundResult * 100)) процентов"
            )
        }
    }

    private func scoreRow(name: String, result: Float, points: Int,
                          barColor: Color, a11yLabel: String) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Text(name)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.ink)
                .frame(width: 60, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ColorTokens.Kid.surface)
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(result), height: 12)
                        .animation(
                            reduceMotion ? nil : MotionTokens.spring,
                            value: result
                        )
                }
            }
            .frame(height: 12)

            Text("\(points)")
                .font(TypographyTokens.mono(13))
                .foregroundStyle(ColorTokens.Kid.ink)
                .frame(width: 28, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
    }

    // MARK: - Exit zone

    private var exitZone: some View {
        Button {
            showExitAlert = true
        } label: {
            Text(String(localized: "sibling.game.exit"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(String(localized: "sibling.game.exit"))
    }

    // MARK: - Round result overlay

    private var roundResultOverlay: some View {
        ZStack {
            ColorTokens.Overlay.dimmer.ignoresSafeArea()

            if case .result(let winner) = display.roundPhase {
                HSCard {
                    VStack(spacing: SpacingTokens.sp3) {
                        let label = winner != nil
                            ? String(format: String(localized: "sibling.game.win"), winner ?? "")
                            : String(localized: "sibling.game.tie")
                        Text(label)
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .multilineTextAlignment(.center)

                        HSMascotView(
            mood: winner == localDisplayName ? .celebrating : .encouraging,
                            size: 64
                        )
                        .accessibilityHidden(true)
                    }
                    .padding(SpacingTokens.sp5)
                }
                .padding(.horizontal, SpacingTokens.screenEdge * 2)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.9).combined(with: .opacity)
                )
            }
        }
    }

    // MARK: - End game overlay

    private var endGameOverlay: some View {
        ZStack {
            ColorTokens.Kid.bgDeep.ignoresSafeArea()

            VStack(spacing: SpacingTokens.sp5) {
                Spacer()

                HSMascotView(
            mood: display.winnerName == localDisplayName ? .celebrating : .encouraging,
                    size: 140
                )
                .accessibilityHidden(true)

                let title = display.winnerName != nil
                    ? String(format: String(localized: "sibling.game.win"), display.winnerName ?? "")
                    : String(localized: "sibling.game.tie")
                Text(title)
                    .font(TypographyTokens.display(36))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .animation(
                        reduceMotion ? nil : MotionTokens.bounce,
                        value: showEndGame
                    )

                HStack(spacing: SpacingTokens.sp5) {
                    VStack(spacing: SpacingTokens.micro) {
                        Text(display.localDisplayName)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                        Text("\(display.ourScore)")
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Kid.ink)
                    }
                    Text("—")
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    VStack(spacing: SpacingTokens.micro) {
                        Text(display.peerDisplayName)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                        Text("\(display.peerScore)")
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Kid.ink)
                    }
                }

                HSButton(String(localized: "sibling.game.rematch"), style: .primary) {
                    showEndGame = false
                    interactor?.requestRematch()
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.horizontal, SpacingTokens.screenEdge)

                HSButton(String(localized: "sibling.game.exit"), style: .ghost) {
                    interactor?.exitGame()
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, SpacingTokens.screenEdge)

                Spacer()
            }
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        guard interactor == nil else { return }
        let createdInteractor = SiblingGameInteractor(mpcWorker: mpcWorker)
        let presenter = SiblingGamePresenter(localPeerDisplayName: localDisplayName)
        createdInteractor.presenter = presenter
        let adapter = SiblingGameViewAdapter(
            display: display,
            showRoundOverlay: { showRoundOverlay = $0 },
            showEndGame: { showEndGame = $0 }
        )
        presenter.view = adapter
        self.viewAdapter = adapter
        self.interactor = createdInteractor
        createdInteractor.loadGame(
            childId: childId,
            peerDisplayName: peerID.displayName,
            localDisplayName: localDisplayName
        )
        display.localDisplayName = localDisplayName
        display.peerDisplayName = peerID.displayName
        createdInteractor.startRound(index: 1)
        Self.logger.debug("SiblingGame bootstrapped peer=\(peerID.displayName, privacy: .public)")
    }
}

// MARK: - SiblingGameViewAdapter (DisplayLogic bridge → SiblingGameDisplay)

@MainActor
final class SiblingGameViewAdapter: SiblingGameDisplayLogic {

    private let display: SiblingGameDisplay
    private let showRoundOverlay: (Bool) -> Void
    private let showEndGame: (Bool) -> Void

    init(display: SiblingGameDisplay,
         showRoundOverlay: @escaping (Bool) -> Void,
         showEndGame: @escaping (Bool) -> Void) {
        self.display = display
        self.showRoundOverlay = showRoundOverlay
        self.showEndGame = showEndGame
    }

    func displayGameLoaded(_ viewModel: SiblingModels.GameLoad.ViewModel) {
        display.totalRounds = viewModel.totalRounds
        display.peerDisplayName = viewModel.peerDisplayName
    }

    func displayRoundStart(_ viewModel: SiblingModels.RoundStart.ViewModel) {
        withAnimation(MotionTokens.outQuick) {
            display.currentWord = viewModel.word
            display.roundIndex = viewModel.roundIndex
            display.roundLabel = viewModel.roundLabel
            display.roundPhase = .playing
            display.ourRoundResult = 0.0
            display.peerRoundResult = 0.0
        }
        showRoundOverlay(false)
    }

    func displayScoreUpdate(_ viewModel: SiblingModels.ScoreUpdate.ViewModel) {
        withAnimation(MotionTokens.spring) {
            display.ourRoundResult = viewModel.ourRoundResult
            display.peerRoundResult = viewModel.peerRoundResult
            display.ourScore = viewModel.ourTotalPoints
            display.peerScore = viewModel.peerTotalPoints
        }
    }

    func displayRoundResult(_ viewModel: SiblingModels.RoundResult.ViewModel) {
        display.roundPhase = .result(winnerName: viewModel.winnerName)
        withAnimation(.easeIn(duration: 0.3)) {
            showRoundOverlay(true)
        }
    }

    func displayGameResult(_ viewModel: SiblingModels.GameResult.ViewModel) {
        display.winnerName = viewModel.winnerName
        display.roundPhase = .gameOver(winnerName: viewModel.winnerName)
        withAnimation(MotionTokens.bounce) {
            showRoundOverlay(false)
            showEndGame(true)
        }
    }

    func displayConnectionLost(message: String) {
        display.roundPhase = .idle
    }
}

// MARK: - Preview

#Preview("Game — Playing") {
    SiblingGameView(
        mpcWorker: SiblingMPCWorker(displayName: "Петя"),
        peerID: MCPeerID(displayName: "Маша"),
        childId: "preview-child-1",
        localDisplayName: "Петя"
    )
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}
