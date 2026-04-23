import ARKit
import SwiftUI

struct BreathingARView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: BreathingARInteractor?
    @State private var presenter: BreathingARPresenter?
    @State private var display = BreathingARDisplay()

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
                    title: "ar.breathing.title",
                    scoreText: display.totalText,
                    onClose: { dismiss() }
                )
                Spacer()
                Image(systemName: display.isBlowing ? "wind" : "wind.snow")
                    .font(.system(size: 64))
                    .foregroundStyle(ColorTokens.Brand.sky)
                    .scaleEffect(1 + CGFloat(display.strength) * 0.2)
                    .animation(.easeOut(duration: 0.15), value: display.strength)
                Text(display.hint)
                    .font(TypographyTokens.headline())
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.vertical, SpacingTokens.small)
                    .background(.black.opacity(0.45), in: Capsule())
                Spacer()
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(ColorTokens.Brand.sky)
                            .frame(width: proxy.size.width * CGFloat(display.strength))
                    }
                }
                .frame(height: 10)
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
        let interactor = BreathingARInteractor()
        let presenter = BreathingARPresenter()
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
        interactor.startGame(.init(dandelionCount: 5))
    }

    private func observe(service: any ARSessionService) {
        // SwiftUI View is a value type — capture the @State-backed interactor
        // directly. No weak self required (no retain cycle risk on structs).
        let capturedInteractor = interactor
        Task { @MainActor in
            for await frame in service.blendshapeStream {
                guard capturedInteractor != nil else { break }
                // Амплитуда микрофона подтягивается из AudioService; в M0 заменена mock-значением.
                let mic = Float.random(in: 0.1...0.5) * (frame.cheekPuff > 0.2 ? 1.0 : 0.3)
                capturedInteractor?.updateFrame(.init(blendshapes: frame, micAmplitude: mic))
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
final class BreathingARDisplay: BreathingARDisplayLogic {
    var totalText: String = ""
    var isBlowing: Bool = false
    var strength: Float = 0
    var hint: String = ""
    var lastStars: Int?

    func displayStartGame(_ viewModel: BreathingARModels.StartGame.ViewModel) {
        totalText = viewModel.totalText
    }

    func displayUpdateFrame(_ viewModel: BreathingARModels.UpdateFrame.ViewModel) {
        isBlowing = viewModel.isBlowing
        strength = viewModel.strength
        hint = viewModel.hint
    }

    func displayScoreAttempt(_ viewModel: BreathingARModels.ScoreAttempt.ViewModel) {
        lastStars = viewModel.stars
    }
}

#Preview {
    BreathingARView()
        .environment(AppContainer.preview())
}
