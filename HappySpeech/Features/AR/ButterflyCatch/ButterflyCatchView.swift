import ARKit
import SwiftUI

struct ButterflyCatchView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: ButterflyCatchInteractor?
    @State private var presenter: ButterflyCatchPresenter?
    @State private var display = ButterflyCatchDisplay()
    @State private var spawnTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if ARFaceTrackingConfiguration.isSupported, let session {
                ARFaceViewContainer(session: session.underlyingSession)
                    .ignoresSafeArea()
            } else {
                ColorTokens.Kid.bgDeep.ignoresSafeArea()
                ARUnsupportedView()
            }

            GeometryReader { proxy in
                ForEach(Array(display.butterflies.values)) { butterfly in
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(ColorTokens.Brand.lilac)
                        .position(
                            x: proxy.size.width * butterfly.position.x,
                            y: proxy.size.height * butterfly.position.y
                        )
                        .accessibilityLabel(Text("ar.butterfly.itemLabel"))
                }
            }

            VStack {
                ARGameHUD(
                    title: "ar.butterfly.title",
                    scoreText: display.scoreText,
                    onClose: { dismiss() }
                )
                Spacer()
                if !display.statusMessage.isEmpty {
                    Text(display.statusMessage)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(.white)
                        .padding(.horizontal, SpacingTokens.medium)
                        .padding(.vertical, SpacingTokens.small)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.bottom, SpacingTokens.xLarge)
                }
            }
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .navigationBarHidden(true)
    }

    private func bootstrap() async {
        guard interactor == nil else { return }
        let interactor = ButterflyCatchInteractor()
        let presenter = ButterflyCatchPresenter()
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
        interactor.startGame(.init(durationSec: 60))

        spawnTask = Task { @MainActor [weak interactor] in
            while !Task.isCancelled {
                interactor?.spawnButterfly(.init())
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    private func observe(service: any ARSessionService) {
        let interactor = self.interactor
        let display = self.display
        Task { @MainActor in
            for await frame in service.blendshapeStream {
                for butterfly in display.butterflies.values {
                    interactor?.scoreAttempt(.init(
                        butterflyId: butterfly.id,
                        blendshapes: frame
                    ))
                }
            }
        }
    }

    private func teardown() {
        spawnTask?.cancel()
        session?.stopSession()
        mockSession?.stopSession()
    }
}

@Observable
@MainActor
final class ButterflyCatchDisplay: ButterflyCatchDisplayLogic {
    var butterflies: [UUID: ButterflyCatchModels.Butterfly] = [:]
    var scoreText: String = "0"
    var statusMessage: String = ""

    func displayStartGame(_ viewModel: ButterflyCatchModels.StartGame.ViewModel) {
        statusMessage = String(localized: "ar.butterfly.start")
        scoreText = "0"
    }

    func displaySpawnButterfly(_ viewModel: ButterflyCatchModels.SpawnButterfly.ViewModel) {
        butterflies[viewModel.butterfly.id] = viewModel.butterfly
    }

    func displayScoreAttempt(_ viewModel: ButterflyCatchModels.ScoreAttempt.ViewModel) {
        if viewModel.caught { statusMessage = String(localized: "ar.butterfly.caught") }
        scoreText = viewModel.scoreText
    }
}

#Preview {
    ButterflyCatchView()
        .environment(AppContainer.preview())
}
