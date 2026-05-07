import ARKit
import SwiftUI

// MARK: - PoseSequenceView

struct PoseSequenceView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var bodyWorker: BodyPoseWorker?
    @State private var interactor: PoseSequenceInteractor?
    @State private var presenter: PoseSequencePresenter?
    @State private var display = PoseSequenceDisplay()

    var body: some View {
        ZStack {
            cameraBackground
            overlayContent
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .navigationBarHidden(true)
    }

    // MARK: - Background

    @ViewBuilder
    private var cameraBackground: some View {
        if display.mode == .body {
            // Body tracking: просто фон — ARBodyTrackingConfiguration нельзя отображать
            // через ARFaceViewContainer (разные конфигурации). Для реального превью
            // на устройстве можно добавить ARView с body-конфигурацией отдельно.
            ColorTokens.Kid.bgDeep.ignoresSafeArea()
        } else if ARFaceTrackingConfiguration.isSupported, let session {
            ARFaceViewContainer(session: session.underlyingSession)
                .ignoresSafeArea()
        } else {
            ColorTokens.Kid.bgDeep.ignoresSafeArea()
            ARUnsupportedView()
        }
    }

    // MARK: - Overlay

    private var overlayContent: some View {
        VStack(spacing: 0) {
            ARGameHUD(
                title: "ar.poseSequence.title",
                scoreText: display.lastStars.map { "\($0) \(String(localized: "ar.stars"))" },
                onClose: { dismiss() }
            )

            // Полоска прогресса по позам
            poseChipsRow
                .padding(.top, SpacingTokens.tiny)

            Spacer()

            // Body-mode: score badge + hint
            if display.mode == .body {
                bodyFeedbackSection
            }

            // Название текущей позы
            Text(display.currentName)
                .font(TypographyTokens.title(32))
                .foregroundStyle(.white)
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.small)
                .background(ColorTokens.Overlay.dimmerHeavy, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
                .accessibilityLabel(Text("ar.poseSequence.currentPose \(display.currentName)"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer()

            progressBar
                .padding(.bottom, SpacingTokens.xLarge)
        }
    }

    // MARK: - Pose chips

    private var poseChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(Array(display.postureNames.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(TypographyTokens.body(11))
                        .padding(.horizontal, SpacingTokens.tiny)
                        .padding(.vertical, SpacingTokens.micro)
                        .background(
                            chipColor(for: index),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            index < display.currentIndex
                                ? Text("ar.poseSequence.chip.done \(name)")
                                : (index == display.currentIndex
                                    ? Text("ar.poseSequence.chip.current \(name)")
                                    : Text("ar.poseSequence.chip.upcoming \(name)"))
                        )
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    private func chipColor(for index: Int) -> Color {
        if index < display.currentIndex { return ColorTokens.Brand.mint }
        if index == display.currentIndex { return ColorTokens.Brand.primary }
        return Color.white.opacity(0.25)
    }

    // MARK: - Body feedback

    private var bodyFeedbackSection: some View {
        VStack(spacing: SpacingTokens.small) {
            // Score badge
            Text("\(display.bodyScore)%")
                .font(TypographyTokens.title(40))
                .foregroundStyle(scoreColor(display.bodyScore))
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.small)
                .background(ColorTokens.Overlay.dimmerHeavy, in: RoundedRectangle(cornerRadius: RadiusTokens.lg))
                .accessibilityLabel(Text("ar.poseSequence.score \(display.bodyScore)"))

            // Hint text
            if !display.currentHint.isEmpty {
                Text(display.currentHint)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.large)
                    .padding(.vertical, SpacingTokens.tiny)
                    .background(ColorTokens.Overlay.dimmer, in: RoundedRectangle(cornerRadius: RadiusTokens.sm))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityLabel(Text(display.currentHint))
            }
        }
        .padding(.bottom, SpacingTokens.small)
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? ColorTokens.Brand.mint
            : score >= 50 ? ColorTokens.Brand.primary
            : ColorTokens.Semantic.warning
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.Overlay.highlight)
                Capsule().fill(ColorTokens.Brand.primary)
                    .frame(width: proxy.size.width * CGFloat(display.progress))
            }
        }
        .frame(height: 12)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityValue(Text("ar.poseSequence.progress \(Int(display.progress * 100))"))
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard interactor == nil else { return }
        let interactor = PoseSequenceInteractor()
        let presenter = PoseSequencePresenter()
        interactor.presenter = presenter
        presenter.display = display
        self.interactor = interactor
        self.presenter = presenter

        if ARBodyTrackingConfiguration.isSupported {
            // Body tracking mode: пустой массив поз → Interactor переключится в body-режим
            startBodyTracking()
            interactor.startGame(.init(postures: []))
        } else if ARFaceTrackingConfiguration.isSupported {
            let live = LiveARSessionService()
            self.session = live
            try? await live.startSession()
            observeFace(service: live)
            interactor.startGame(.init(postures: [.smile, .pucker, .cupShape, .mushroom]))
        } else {
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            observeFace(service: mock)
            interactor.startGame(.init(postures: [.smile, .pucker, .cupShape, .mushroom]))
        }
    }

    private func startBodyTracking() {
        let worker = BodyPoseWorker()
        worker.onUpdate = { [weak interactor] update in
            Task { @MainActor in
                interactor?.updateBodyPose(.init(update: update))
            }
        }
        worker.start()
        self.bodyWorker = worker
    }

    private func observeFace(service: any ARSessionService) {
        let capturedInteractor = interactor
        Task { @MainActor in
            for await frame in service.blendshapeStream {
                capturedInteractor?.updateFrame(.init(blendshapes: frame))
            }
        }
    }

    // MARK: - Teardown

    private func teardown() {
        session?.stopSession()
        mockSession?.stopSession()
        bodyWorker?.stop()
    }
}

// MARK: - PoseSequenceDisplay

@Observable
@MainActor
final class PoseSequenceDisplay: PoseSequenceDisplayLogic {
    var postureNames: [String] = []
    var currentIndex: Int = 0
    var currentName: String = ""
    var currentHint: String = ""
    var progress: Float = 0
    var lastStars: Int?
    var mode: PoseSequenceMode = .face
    var bodyScore: Int = 0

    func displayStartGame(_ viewModel: PoseSequenceModels.StartGame.ViewModel) {
        postureNames = viewModel.postureNames
        currentIndex = viewModel.currentIndex
        currentName = viewModel.currentName
        currentHint = viewModel.currentHint
        mode = viewModel.mode
    }

    func displayUpdateFrame(_ viewModel: PoseSequenceModels.UpdateFrame.ViewModel) {
        progress = viewModel.progress
        if viewModel.advanced {
            currentIndex += 1
            if postureNames.indices.contains(currentIndex) {
                currentName = postureNames[currentIndex]
            }
        }
    }

    func displayUpdateBodyPose(_ viewModel: PoseSequenceModels.UpdateBodyPose.ViewModel) {
        progress = viewModel.progress
        bodyScore = viewModel.score
        if viewModel.advanced {
            currentIndex += 1
            if postureNames.indices.contains(currentIndex) {
                currentName = postureNames[currentIndex]
            }
        }
        if !viewModel.hintText.isEmpty {
            currentHint = viewModel.hintText
        }
    }

    func displayScoreAttempt(_ viewModel: PoseSequenceModels.ScoreAttempt.ViewModel) {
        lastStars = viewModel.stars
    }
}

// MARK: - Preview

#Preview {
    PoseSequenceView()
        .environment(AppContainer.preview())
}
