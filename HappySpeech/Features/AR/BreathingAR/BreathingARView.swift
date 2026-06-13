import ARKit
import SwiftUI

struct BreathingARView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                cameraOverlay
            } else {
                // 2D-fallback без камеры: спокойный тёплый дыхательный экран.
                fallbackBreathing
            }
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .navigationBarHidden(true)
    }

    // MARK: - Camera overlay (AR-supported)

    private var cameraOverlay: some View {
        VStack {
            ARGameHUD(
                title: "ar.breathing.title",
                scoreText: display.totalText,
                onClose: { dismiss() }
            )
            Spacer()
            Image(systemName: display.isBlowing ? "wind" : "wind.snow")
                .font(TypographyTokens.kidDisplay(64))
                .foregroundStyle(ColorTokens.Brand.primaryHi)
                .scaleEffect(1 + CGFloat(display.strength) * 0.2)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: display.strength)
            Text(display.hint)
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.small)
                .background(ColorTokens.Overlay.dimmerHeavy, in: Capsule())
                .padding(.horizontal, SpacingTokens.screenEdge)
            Spacer()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Overlay.highlight)
                    Capsule().fill(ColorTokens.Brand.primary)
                        .frame(width: proxy.size.width * CGFloat(display.strength))
                }
            }
            .frame(height: 10)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.xLarge)
        }
    }

    // MARK: - 2D fallback (no TrueDepth camera)

    private var fallbackBreathing: some View {
        ZStack {
            HSMeshGradientBackground(palette: .calm, animated: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.sp4) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(String(localized: "Закрыть"))
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)

                Spacer(minLength: 0)

                HSBreathingOrb(
                    expansion: CGFloat(display.strength),
                    ringProgress: CGFloat(display.strength),
                    phaseTitle: display.isBlowing
                        ? String(localized: "Выдох…")
                        : String(localized: "Вдохни"),
                    phaseCount: nil,
                    size: 240
                )

                Text(display.hint.isEmpty
                    ? String(localized: "Дуй ровно и долго")
                    : display.hint)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SpacingTokens.screenEdge)

                Spacer(minLength: 0)

                ARUnsupportedView()
                    .padding(.bottom, SpacingTokens.xLarge)
            }
        }
    }

    private func bootstrap() async {
        guard interactor == nil else { return }
        let interactor = BreathingARInteractor()
        let presenter = BreathingARPresenter()
        interactor.presenter = presenter
        presenter.display = display
        self.interactor = interactor
        self.presenter = presenter

        // AR-игра требует TrueDepth (cheekPuff/jawOpen усиливают сигнал выдоха).
        // На реальном устройстве без TrueDepth игра не запускается и не скорит
        // синтетику — body показывает ARUnsupportedView (P1-1). Симуляция —
        // только превью/тесты.
        guard ARDeviceCapability.supportsFaceTracking || ARDeviceCapability.allowsSimulatedSession else {
            return
        }

        // Запускаем реальную запись микрофона: амплитуда выдоха берётся из
        // живого аудио-потока (RMS буфера), а не из mock-значения.
        await startMicCapture()

        if ARDeviceCapability.supportsFaceTracking {
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

    private func startMicCapture() async {
        let audio = container.audioService
        if !audio.isPermissionGranted {
            _ = await audio.requestPermission()
        }
        try? await audio.startRecording()
    }

    private func observe(service: any ARSessionService) {
        // SwiftUI View is a value type — capture the @State-backed interactor
        // directly. No weak self required (no retain cycle risk on structs).
        let capturedInteractor = interactor
        let audio = container.audioService
        Task { @MainActor in
            for await frame in service.blendshapeStream {
                guard capturedInteractor != nil else { break }
                // Реальная амплитуда выдоха: RMS живого микрофона, усиленный
                // при реальном надувании щёк (ARKit cheekPuff blendshape).
                let micRMS = Float(WhisperGameInteractor.rmsLevel(of: audio.amplitudeBuffer()))
                let cheekGain: Float = frame.cheekPuff > 0.2 ? 1.0 : 0.6
                let mic = min(1, micRMS * cheekGain)
                capturedInteractor?.updateFrame(.init(blendshapes: frame, micAmplitude: mic))
            }
        }
    }

    private func teardown() {
        session?.stopSession()
        mockSession?.stopSession()
        let audio = container.audioService
        if audio.isRecording {
            Task { _ = try? await audio.stopRecording() }
        }
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
