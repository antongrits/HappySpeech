import ARKit
import SwiftUI

struct ButterflyCatchView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: ButterflyCatchInteractor?
    @State private var presenter: ButterflyCatchPresenter?
    @State private var display = ButterflyCatchDisplay()
    @State private var spawnTask: Task<Void, Never>?

    /// Игра идёт по mock/обычной камере (TrueDepth недоступен).
    private var isFallbackCamera: Bool { mockSession != nil }

    var body: some View {
        ZStack {
            if ARFaceTrackingConfiguration.isSupported, let session {
                ARFaceViewContainer(session: session.underlyingSession)
                    .ignoresSafeArea()
            } else {
                ColorTokens.Kid.bgDeep.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(0.4)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                ARUnsupportedView()
            }

            GeometryReader { proxy in
                ForEach(Array(display.butterflies.values)) { butterfly in
                    ButterflyFloater(reduceMotion: reduceMotion)
                        .position(
                            x: proxy.size.width * butterfly.position.x,
                            y: proxy.size.height * butterfly.position.y
                        )
                        .accessibilityLabel(Text("ar.butterfly.itemLabel"))
                }
            }

            VStack(spacing: SpacingTokens.small) {
                ARTaskPill(
                    iconSystemName: "sparkles",
                    title: String(localized: "ar.butterfly.title"),
                    subtitle: String(localized: "ar.butterfly.hud.subtitle"),
                    scoreText: display.scoreText,
                    onClose: { dismiss() }
                )

                if isFallbackCamera {
                    ARTrueDepthFallbackBanner()
                }

                Spacer()

                if !display.statusMessage.isEmpty {
                    ARMascotGuide(
                        state: display.scoreText == "0" ? .explaining : .encouraging,
                        message: display.statusMessage,
                        detail: nil
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SpacingTokens.screenEdge)
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

        // Бабочка ловится высовыванием/подъёмом языка (tongueOut blendshape) —
        // нужен TrueDepth. На реальном устройстве без TrueDepth игра НЕ запускается
        // и не скорит синтетику: показывается честный ARUnsupportedView (P1-1).
        // Симуляция (Mock) допускается только в SwiftUI-превью и под тестами.
        if ARDeviceCapability.supportsFaceTracking {
            let live = LiveARSessionService()
            self.session = live
            try? await live.startSession()
            observe(service: live)
        } else if ARDeviceCapability.allowsSimulatedSession {
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            observe(service: mock)
        } else {
            // Устройство без TrueDepth — упражнение недоступно, прогресс не пишется.
            HSLogger.ar.info("ButterflyCatch: TrueDepth недоступен — unsupported, без скоринга")
            return
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
        statusMessage = viewModel.instruction
    }

    func displayScoreAttempt(_ viewModel: ButterflyCatchModels.ScoreAttempt.ViewModel) {
        if viewModel.caught { statusMessage = String(localized: "ar.butterfly.caught") }
        scoreText = viewModel.scoreText
    }
}

// MARK: - ButterflyFloater

/// Тёплая бабочка-цель с лёгким «парящим» покачиванием (gated by reduce-motion).
private struct ButterflyFloater: View {

    let reduceMotion: Bool
    @State private var float = false

    var body: some View {
        Image("reward_butterfly")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 64, height: 64)
            .shadow(color: ColorTokens.Overlay.dimmer, radius: 6, y: 4)
            .rotationEffect(.degrees(float && !reduceMotion ? 4 : -4))
            .offset(y: float && !reduceMotion ? -6 : 6)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                    float = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ButterflyCatchView()
        .environment(AppContainer.preview())
}
