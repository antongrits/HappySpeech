import ARKit
import SwiftUI

struct SoundAndFaceView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: SoundAndFaceInteractor?
    @State private var presenter: SoundAndFacePresenter?
    @State private var display = SoundAndFaceDisplay()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFaceSupported: Bool { ARFaceTrackingConfiguration.isSupported }
    private var isSuccess: Bool { display.postureProgress >= 1 }

    var body: some View {
        ZStack {
            if isFaceSupported, let session {
                ARFaceViewContainer(session: session.underlyingSession)
                    .ignoresSafeArea()
            } else {
                ColorTokens.Kid.bgDeep.ignoresSafeArea()
                ARUnsupportedView()
            }

            VStack(spacing: SpacingTokens.tiny) {
                ARTaskPill(
                    iconSystemName: "waveform",
                    title: String(localized: "ar.soundFace.title"),
                    subtitle: display.postureName.isEmpty ? nil : display.postureName,
                    scoreText: display.lastStars.map { "\($0)" },
                    onClose: { dismiss() }
                )

                if !isFaceSupported {
                    ARTrueDepthFallbackBanner()
                }

                // Большая целевая буква-звук поверх камеры — карточка-цель.
                HStack(spacing: SpacingTokens.medium) {
                    Text(display.soundText)
                        .font(TypographyTokens.kidDisplay(64))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .minimumScaleFactor(0.85)
                        .accessibilityHidden(true)
                    Text(display.postureName)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(SpacingTokens.small)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
                )
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.top, SpacingTokens.micro)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("\(display.soundText). \(display.postureName)"))

                Spacer()

                HStack {
                    ARMascotGuide(
                        state: isSuccess ? .celebrating : .explaining,
                        message: display.instruction.isEmpty
                            ? String(localized: "ar.soundFace.title")
                            : display.instruction,
                        detail: display.postureName.isEmpty ? nil : display.postureName
                    )
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.bottom, SpacingTokens.small)

                ARControlPanel(
                    hintText: isSuccess
                        ? String(localized: "ar.soundFace.success")
                        : String(localized: "ar.hold.hint"),
                    isSuccess: isSuccess,
                    progress: display.postureProgress,
                    centerAction: nil,
                    centerAccessibilityLabel: String(localized: "ar.hold.hint"),
                    leading: { Color.clear.frame(width: 56, height: 56) },
                    trailing: { Color.clear.frame(width: 56, height: 56) }
                )
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: isSuccess)
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

        // Live на TrueDepth-устройстве. Симуляция — только превью/тесты (P1-1):
        // на реальном устройстве без TrueDepth игра не запускается и не скорит синтетику.
        if ARDeviceCapability.supportsFaceTracking {
            let live = LiveARSessionService()
            self.session = live
            try? await live.startSession()
            observe(service: live)
            interactor.startGame(.init(targetSound: "С"))
        } else if ARDeviceCapability.allowsSimulatedSession {
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            observe(service: mock)
            interactor.startGame(.init(targetSound: "С"))
        }
        // Иначе: устройство без TrueDepth — body показывает ARUnsupportedView,
        // упражнение не запускается, прогресс не пишется.
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
