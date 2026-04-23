import ARKit
import SwiftUI

struct HoldThePoseView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: HoldThePoseInteractor?
    @State private var presenter: HoldThePosePresenter?
    @State private var display = HoldThePoseDisplay()

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
                    title: "ar.holdPose.title",
                    scoreText: display.lastStars.map { "\($0)⭐" },
                    onClose: { dismiss() }
                )
                Spacer()
                VStack(spacing: SpacingTokens.small) {
                    Text(display.postureName)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(.white)
                        .padding(.horizontal, SpacingTokens.medium)
                        .padding(.vertical, SpacingTokens.small)
                        .background(.black.opacity(0.45), in: Capsule())
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.25))
                            Capsule()
                                .fill(ColorTokens.Brand.mint)
                                .frame(width: proxy.size.width * CGFloat(display.progress))
                        }
                    }
                    .frame(height: 14)
                    Text("\(display.confidencePercent)%")
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(.white.opacity(0.85))
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
        let interactor = HoldThePoseInteractor()
        let presenter = HoldThePosePresenter()
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
        interactor.startGame(.init(targetPosture: .smile, holdDurationSec: 5))
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
final class HoldThePoseDisplay: HoldThePoseDisplayLogic {
    var postureName: String = ""
    var progress: Float = 0
    var confidencePercent: Int = 0
    var lastStars: Int?

    func displayStartGame(_ viewModel: HoldThePoseModels.StartGame.ViewModel) {
        postureName = viewModel.postureName
    }

    func displayUpdateFrame(_ viewModel: HoldThePoseModels.UpdateFrame.ViewModel) {
        progress = viewModel.progress
        confidencePercent = viewModel.confidencePercent
    }

    func displayScoreAttempt(_ viewModel: HoldThePoseModels.ScoreAttempt.ViewModel) {
        lastStars = viewModel.stars
    }
}

#Preview {
    HoldThePoseView()
        .environment(AppContainer.preview())
}
