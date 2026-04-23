import ARKit
import SwiftUI

struct PoseSequenceView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: PoseSequenceInteractor?
    @State private var presenter: PoseSequencePresenter?
    @State private var display = PoseSequenceDisplay()

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
                    title: "ar.poseSequence.title",
                    scoreText: display.lastStars.map { "\($0)⭐" },
                    onClose: { dismiss() }
                )

                HStack(spacing: SpacingTokens.tiny) {
                    ForEach(Array(display.postureNames.enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .font(TypographyTokens.body(11))
                            .padding(.horizontal, SpacingTokens.tiny)
                            .padding(.vertical, SpacingTokens.micro)
                            .background(
                                index < display.currentIndex
                                    ? ColorTokens.Brand.mint
                                    : (index == display.currentIndex
                                        ? ColorTokens.Brand.primary
                                        : Color.white.opacity(0.25)),
                                in: Capsule()
                            )
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

                Spacer()

                Text(display.currentName)
                    .font(TypographyTokens.title(32))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.vertical, SpacingTokens.small)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: RadiusTokens.md))

                Spacer()

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(ColorTokens.Brand.primary)
                            .frame(width: proxy.size.width * CGFloat(display.progress))
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
        let interactor = PoseSequenceInteractor()
        let presenter = PoseSequencePresenter()
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
        interactor.startGame(.init(postures: [.smile, .pucker, .cupShape, .mushroom]))
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
final class PoseSequenceDisplay: PoseSequenceDisplayLogic {
    var postureNames: [String] = []
    var currentIndex: Int = 0
    var currentName: String = ""
    var progress: Float = 0
    var lastStars: Int?

    func displayStartGame(_ viewModel: PoseSequenceModels.StartGame.ViewModel) {
        postureNames = viewModel.postureNames
        currentIndex = viewModel.currentIndex
        currentName = viewModel.currentName
    }

    func displayUpdateFrame(_ viewModel: PoseSequenceModels.UpdateFrame.ViewModel) {
        progress = viewModel.progress
        if viewModel.advanced { currentIndex += 1 }
        if postureNames.indices.contains(currentIndex) {
            currentName = postureNames[currentIndex]
        }
    }

    func displayScoreAttempt(_ viewModel: PoseSequenceModels.ScoreAttempt.ViewModel) {
        lastStars = viewModel.stars
    }
}

#Preview {
    PoseSequenceView()
        .environment(AppContainer.preview())
}
