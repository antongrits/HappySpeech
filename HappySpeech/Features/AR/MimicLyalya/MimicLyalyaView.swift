import ARKit
import SwiftUI
import Vision

struct MimicLyalyaView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: MimicLyalyaInteractor?
    @State private var presenter: MimicLyalyaPresenter?
    @State private var display = MimicLyalyaDisplay()

    // Block J: HandPoseWorker для детектирования жестов через Vision
    @State private var handWorker: HandPoseWorker?
    // Задача обработки кадров камеры для hand pose
    @State private var handPoseTask: Task<Void, Never>?

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
                    title: "ar.mimic.title",
                    scoreText: display.roundText,
                    onClose: { dismiss() }
                )
                HStack {
                    Text(display.emoji)
                        .font(.system(size: 64))
                    Spacer()
                    Text(display.postureName)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(.white)
                        .padding(.horizontal, SpacingTokens.small)
                        .padding(.vertical, SpacingTokens.tiny)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                .padding(.horizontal, SpacingTokens.screenEdge)

                // Block J: Hand pose hint banner
                if display.showHandPoseBanner {
                    HandPoseHintBanner(
                        hintText: display.handPoseHintText,
                        poseNameText: display.handPoseNameText,
                        isMatching: display.handPoseMatched
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
                VStack {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.25))
                            Capsule()
                                .fill(ColorTokens.Brand.primary)
                                .frame(width: proxy.size.width * CGFloat(display.progress))
                        }
                    }
                    .frame(height: 14)
                    Button {
                        interactor?.nextRound()
                    } label: {
                        Text("ar.mimic.nextRound")
                            .font(TypographyTokens.headline())
                            .foregroundStyle(.white)
                            .padding(.horizontal, SpacingTokens.medium)
                            .padding(.vertical, SpacingTokens.small)
                            .background(ColorTokens.Brand.primary, in: Capsule())
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.xLarge)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: display.showHandPoseBanner)
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

        if ARFaceTrackingConfiguration.isSupported {
            let live = LiveARSessionService()
            self.session = live
            try? await live.startSession()
            observeBlendshapes(service: live)
            // Block J: подписываемся на кадры AR сессии для hand pose
            observeHandPoseFromARSession(live: live, worker: worker)
        } else {
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            observeBlendshapes(service: mock)
        }
        interactor.startGame(.init(rounds: 5))
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
                .foregroundStyle(isMatching ? ColorTokens.Semantic.success : .white)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(hintText)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text(poseNameText)
                    .font(TypographyTokens.body())
                    .foregroundStyle(.white)
                    .bold()
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
            if isMatching {
                Text("hand_pose.detect.matched")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Semantic.success)
                    .padding(.horizontal, SpacingTokens.tiny)
                    .padding(.vertical, 2)
                    .background(ColorTokens.Semantic.success.opacity(0.15), in: Capsule())
            }
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.small)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: RadiusTokens.md))
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
    var roundText: String = ""
    var progress: Float = 0
    var emoji: String = "🙂"
    var lastStars: Int?

    // Block J: Hand Pose state
    var showHandPoseBanner: Bool = false
    var handPoseHintText: String = ""
    var handPoseNameText: String = ""
    var handPoseMatched: Bool = false

    func displayStartGame(_ viewModel: MimicLyalyaModels.StartGame.ViewModel) {
        postureName = viewModel.postureName
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
