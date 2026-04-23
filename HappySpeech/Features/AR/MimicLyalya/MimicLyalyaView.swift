import ARKit
import SwiftUI

struct MimicLyalyaView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: MimicLyalyaInteractor?
    @State private var presenter: MimicLyalyaPresenter?
    @State private var display = MimicLyalyaDisplay()

    var body: some View {
        ZStack {
            if ARFaceTrackingConfiguration.isSupported, let session {
                ARFaceViewContainer(session: session.underlyingSession)
                    .ignoresSafeArea()
            } else {
                ColorTokens.Kid.bgDeep.ignoresSafeArea()
                ARUnsupportedView()
            }

            VStack {
                ARGameHUD(
                    title: "ar.mimic.title",
                    scoreText: display.roundText,
                    onClose: { dismiss() }
                )
                HStack {
                    Text(display.emoji)
                        .font(.system(size: 64))
                    Spacer()
                    Text(display.postureName)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(.white)
                        .padding(.horizontal, SpacingTokens.small)
                        .padding(.vertical, SpacingTokens.tiny)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                Spacer()
                VStack {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.25))
                            Capsule()
                                .fill(ColorTokens.Brand.primary)
                                .frame(width: proxy.size.width * CGFloat(display.progress))
                        }
                    }
                    .frame(height: 14)
                    Button {
                        interactor?.nextRound()
                    } label: {
                        Text("ar.mimic.nextRound")
                            .font(TypographyTokens.headline())
                            .foregroundStyle(.white)
                            .padding(.horizontal, SpacingTokens.medium)
                            .padding(.vertical, SpacingTokens.small)
                            .background(ColorTokens.Brand.primary, in: Capsule())
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.xLarge)
            }
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .navigationBarHidden(true)
    }

    private func bootstrap() async {
        guard interactor == nil else { return }
        let interactor = MimicLyalyaInteractor()
        let presenter = MimicLyalyaPresenter()
        interactor.presenter = presenter
        presenter.display = display
        self.interactor = interactor
        self.presenter = presenter

        if ARFaceTrackingConfiguration.isSupported {
            let live = LiveARSessionService()
            self.session = live
            try? await live.startSession()
            observe(service: live)
        } else {
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            observe(service: mock)
        }
        interactor.startGame(.init(rounds: 5))
    }

    private func observe(service: any ARSessionService) {
        let interactor = self.interactor
        Task { @MainActor in
            for await frame in service.blendshapeStream {
                interactor?.updateFrame(.init(blendshapes: frame))
            }
        }
    }

    private func teardown() {
        session?.stopSession()
        mockSession?.stopSession()
    }
}

@Observable
@MainActor
final class MimicLyalyaDisplay: MimicLyalyaDisplayLogic {
    var postureName: String = ""
    var roundText: String = ""
    var progress: Float = 0
    var emoji: String = "🙂"
    var lastStars: Int?

    func displayStartGame(_ viewModel: MimicLyalyaModels.StartGame.ViewModel) {
        postureName = viewModel.postureName
        roundText = viewModel.roundText
    }

    func displayUpdateFrame(_ viewModel: MimicLyalyaModels.UpdateFrame.ViewModel) {
        progress = viewModel.progress
        emoji = viewModel.emoji
    }

    func displayScoreAttempt(_ viewModel: MimicLyalyaModels.ScoreAttempt.ViewModel) {
        lastStars = viewModel.stars
    }
}

#Preview {
    MimicLyalyaView()
        .environment(AppContainer.preview())
}
