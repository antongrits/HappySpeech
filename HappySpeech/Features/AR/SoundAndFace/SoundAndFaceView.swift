import ARKit
import SwiftUI

struct SoundAndFaceView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: SoundAndFaceInteractor?
    @State private var presenter: SoundAndFacePresenter?
    @State private var display = SoundAndFaceDisplay()

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
                    title: "ar.soundFace.title",
                    scoreText: display.lastStars.map { "\($0)⭐" },
                    onClose: { dismiss() }
                )
                HStack(spacing: SpacingTokens.medium) {
                    Text(display.soundText)
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                    VStack(alignment: .leading) {
                        Text(display.postureName)
                            .font(TypographyTokens.headline())
                            .foregroundStyle(.white)
                        Text(display.instruction)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding()
                .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: RadiusTokens.md))
                .padding(.horizontal, SpacingTokens.screenEdge)

                Spacer()

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(ColorTokens.Brand.mint)
                            .frame(width: proxy.size.width * CGFloat(display.postureProgress))
                    }
                }
                .frame(height: 12)
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
        let interactor = SoundAndFaceInteractor()
        let presenter = SoundAndFacePresenter()
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
        interactor.startGame(.init(targetSound: "С"))
    }

    private func observe(service: any ARSessionService) {
        let capturedInteractor = interactor
        Task { @MainActor in
            for await frame in service.blendshapeStream {
                capturedInteractor?.updateFrame(.init(blendshapes: frame))
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
final class SoundAndFaceDisplay: SoundAndFaceDisplayLogic {
    var soundText: String = ""
    var postureName: String = ""
    var instruction: String = ""
    var postureProgress: Float = 0
    var lastStars: Int?

    func displayStartGame(_ viewModel: SoundAndFaceModels.StartGame.ViewModel) {
        soundText = viewModel.soundText
        postureName = viewModel.postureName
        instruction = viewModel.instruction
    }

    func displayUpdateFrame(_ viewModel: SoundAndFaceModels.UpdateFrame.ViewModel) {
        postureProgress = viewModel.postureProgress
    }

    func displayScoreAttempt(_ viewModel: SoundAndFaceModels.ScoreAttempt.ViewModel) {
        lastStars = viewModel.stars
    }
}

#Preview {
    SoundAndFaceView()
        .environment(AppContainer.preview())
}
