import ARKit
import SwiftUI
import Vision

struct MimicLyalyaView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: MimicLyalyaInteractor?
    @State private var presenter: MimicLyalyaPresenter?
    @State private var display = MimicLyalyaDisplay()

    // Block J: HandPoseWorker для детектирования жестов через Vision
    @State private var handWorker: HandPoseWorker?
    // Задача обработки кадров камеры для hand pose
    @State private var handPoseTask: Task<Void, Never>?

    private var isFaceSupported: Bool { ARFaceTrackingConfiguration.isSupported }

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
                    iconSystemName: display.emoji,
                    title: String(localized: "ar.mimic.title"),
                    subtitle: display.postureName.isEmpty ? nil : display.postureName,
                    scoreText: display.roundText.isEmpty ? nil : display.roundText,
                    onClose: { dismiss() }
                )

                if !isFaceSupported {
                    ARTrueDepthFallbackBanner()
                }

                // Block J: Hand pose hint banner
                if display.showHandPoseBanner {
                    HandPoseHintBanner(
                        hintText: display.handPoseHintText,
                        poseNameText: display.handPoseNameText,
                        isMatching: display.handPoseMatched
                    )
                    .padding(.horizontal, SpacingTokens.regular)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                HStack {
                    ARMascotGuide(
                        state: display.progress >= 1 ? .celebrating : .pointing,
                        message: display.mascotHint,
                        detail: display.postureName.isEmpty ? nil : display.postureName
                    )
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.bottom, SpacingTokens.small)

                ARControlPanel(
                    hintText: display.progress >= 1
                        ? String(localized: "ar.mimic.roundComplete")
                        : String(localized: "ar.hold.hint"),
                    isSuccess: display.progress >= 1,
                    progress: display.progress,
                    centerAction: { interactor?.nextRound() },
                    centerAccessibilityLabel: String(localized: "ar.mimic.nextRound"),
                    leading: { Color.clear.frame(width: 56, height: 56) },
                    trailing: { Color.clear.frame(width: 56, height: 56) }
                )
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: display.showHandPoseBanner)
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: display.progress >= 1)
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

        // Block J: создаём HandPoseWorker
        let worker = HandPoseWorker(maxHandCount: 1, confidenceThreshold: 0.6)
        self.handWorker = worker

        // Live на TrueDepth-устройстве. Симуляция — только превью/тесты (P1-1):
        // на реальном устройстве без TrueDepth игра не запускается и не скорит синтетику.
        if ARDeviceCapability.supportsFaceTracking {
            let live = LiveARSessionService()
            self.session = live
            try? await live.startSession()
            observeBlendshapes(service: live)
            // Block J: подписываемся на кадры AR сессии для hand pose
            observeHandPoseFromARSession(live: live, worker: worker)
            interactor.startGame(.init(rounds: 5))
        } else if ARDeviceCapability.allowsSimulatedSession {
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            observeBlendshapes(service: mock)
            interactor.startGame(.init(rounds: 5))
        }
        // Иначе (реальное устройство без TrueDepth): игра не запускается, прогресс
        // не пишется — body показывает честный ARUnsupportedView (P1-1).
    }

    private func observeBlendshapes(service: any ARSessionService) {
        let interactor = self.interactor
        Task { @MainActor in
            for await frame in service.blendshapeStream {
                interactor?.updateFrame(.init(blendshapes: frame))
            }
        }
    }

    // Block J: подписка на ARFrame.capturedImage → HandPoseWorker → Interactor
    // ARSession даёт доступ к pixelBuffer каждого кадра: используем ARSessionDelegate паттерн
    // через LiveARSessionService.pixelBufferStream если доступен, иначе пропускаем.
    private func observeHandPoseFromARSession(live: LiveARSessionService, worker: HandPoseWorker) {
        let interactor = self.interactor
        handPoseTask = Task { @MainActor in
            guard let stream = live.pixelBufferStream else { return }
            for await pixelBuffer in stream {
                guard !Task.isCancelled else { break }
                if let observation = try? await worker.detect(in: pixelBuffer) {
                    interactor?.updateHandPose(.init(observation: observation))
                }
            }
        }
    }

    private func teardown() {
        session?.stopSession()
        mockSession?.stopSession()
        handPoseTask?.cancel()
        handPoseTask = nil
    }
}

// MARK: - HandPoseHintBanner

/// Небольшой баннер с подсказкой жеста и индикатором совпадения.
private struct HandPoseHintBanner: View {

    let hintText: String
    let poseNameText: String
    let isMatching: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: isMatching ? "hand.thumbsup.fill" : "hand.raised.fill")
                .font(.title2)
                .foregroundStyle(isMatching ? ColorTokens.Brand.mint : ColorTokens.Brand.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(hintText)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text(poseNameText)
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .bold()
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
            if isMatching {
                Text("hand_pose.detect.matched")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Brand.mint)
                    .padding(.horizontal, SpacingTokens.tiny)
                    .padding(.vertical, 2)
                    .background(ColorTokens.Brand.mint.opacity(0.15), in: Capsule())
            }
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.small)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isMatching
            ? String(localized: "hand_pose.detect.matched")
            : hintText + " " + poseNameText
        )
    }
}

// MARK: - MimicLyalyaDisplay

@Observable
@MainActor
final class MimicLyalyaDisplay: MimicLyalyaDisplayLogic {
    var postureName: String = ""
    var mascotHint: String = ""
    var roundText: String = ""
    var progress: Float = 0
    // Block D v16: эмодзи заменены на SF Symbol name (UI chrome).
    var emoji: String = "face.smiling"
    var lastStars: Int?

    // Block J: Hand Pose state
    var showHandPoseBanner: Bool = false
    var handPoseHintText: String = ""
    var handPoseNameText: String = ""
    var handPoseMatched: Bool = false

    func displayStartGame(_ viewModel: MimicLyalyaModels.StartGame.ViewModel) {
        postureName = viewModel.postureName
        mascotHint = viewModel.mascotHint
        roundText = viewModel.roundText
    }

    func displayUpdateFrame(_ viewModel: MimicLyalyaModels.UpdateFrame.ViewModel) {
        progress = viewModel.progress
        emoji = viewModel.emoji
    }

    func displayScoreAttempt(_ viewModel: MimicLyalyaModels.ScoreAttempt.ViewModel) {
        lastStars = viewModel.stars
    }

    // Block J: Hand Pose update
    func displayHandPoseUpdate(_ viewModel: MimicLyalyaModels.UpdateHandPose.ViewModel) {
        handPoseHintText = String(localized: String.LocalizationValue(viewModel.hintKey))
        handPoseNameText = String(localized: String.LocalizationValue(viewModel.poseNameKey))
        handPoseMatched = viewModel.isMatching
        showHandPoseBanner = true
    }
}

#Preview {
    MimicLyalyaView()
        .environment(AppContainer.preview())
}
