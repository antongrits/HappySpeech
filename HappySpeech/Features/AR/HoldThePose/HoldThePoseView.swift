import ARKit
import SwiftUI

struct HoldThePoseView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: HoldThePoseInteractor?
    @State private var presenter: HoldThePosePresenter?
    @State private var display = HoldThePoseDisplay()

    /// Игра идёт по mock/обычной камере (TrueDepth недоступен).
    private var isFallbackCamera: Bool { mockSession != nil }

    /// Поза удержана достаточно долго (визуальный success-стейт капчер-кольца).
    private var isHeld: Bool { display.lastStars != nil || display.progress >= 1.0 }

    var body: some View {
        ZStack {
            if ARFaceTrackingConfiguration.isSupported, let session {
                ARFaceViewContainer(session: session.underlyingSession)
                    .ignoresSafeArea()
            } else {
                ColorTokens.Kid.bgDeep.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                ARUnsupportedView()
            }

            VStack(spacing: SpacingTokens.small) {
                ARTaskPill(
                    iconSystemName: "face.smiling.fill",
                    title: String(localized: "ar.holdPose.title"),
                    subtitle: postureSubtitle,
                    scoreText: display.lastStars.map { "\($0)" },
                    onClose: { dismiss() }
                )

                if isFallbackCamera {
                    ARTrueDepthFallbackBanner()
                }

                Spacer()

                ARControlPanel(
                    hintText: isHeld
                        ? String(localized: "ar.holdPose.hint.done")
                        : String(localized: "ar.holdPose.hint.hold"),
                    isSuccess: isHeld,
                    progress: display.progress,
                    centerAction: nil,
                    centerAccessibilityLabel: String(localized: "ar.holdPose.title"),
                    leading: { sideMetric },
                    trailing: { confidenceBadge }
                )
            }
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .navigationBarHidden(true)
    }

    /// Подзаголовок task-pill: имя целевой позы (или общая подсказка, пока не задано).
    private var postureSubtitle: String {
        display.postureName.isEmpty
            ? String(localized: "ar.holdPose.hud.subtitle")
            : display.postureName
    }

    /// Левая боковая иконка-метрика панели — лицо-индикатор с pulse.
    private var sideMetric: some View {
        Image(systemName: "face.smiling.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(ColorTokens.Brand.mint)
            .frame(width: 56, height: 56)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1))
            .hsSymbolEffect(.pulse, value: display.confidencePercent)
            .accessibilityHidden(true)
    }

    /// Правый бейдж панели — текущая уверенность позы в процентах.
    private var confidenceBadge: some View {
        VStack(spacing: 2) {
            Text("\(display.confidencePercent)")
                .font(TypographyTokens.headline(18).weight(.heavy))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
            Text(verbatim: "%")
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(width: 56, height: 56)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("ar.holdPose.title"))
        .accessibilityValue(Text("\(display.confidencePercent)%"))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func bootstrap() async {
        guard interactor == nil else { return }
        let interactor = HoldThePoseInteractor()
        let presenter = HoldThePosePresenter()
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
            interactor.startGame(.init(targetPosture: .smile, holdDurationSec: 5))
        } else if ARDeviceCapability.allowsSimulatedSession {
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            observe(service: mock)
            interactor.startGame(.init(targetPosture: .smile, holdDurationSec: 5))
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
