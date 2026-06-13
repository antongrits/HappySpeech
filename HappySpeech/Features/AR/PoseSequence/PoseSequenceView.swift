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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSuccess: Bool { display.progress >= 1 }

    var body: some View {
        ZStack {
            cameraBackground
            overlayContent
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: isSuccess)
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
        VStack(spacing: SpacingTokens.tiny) {
            ARTaskPill(
                iconSystemName: display.mode == .body ? "figure.walk" : "face.smiling",
                title: String(localized: "ar.poseSequence.title"),
                subtitle: nil,
                scoreText: display.lastStars.map { "\($0)" },
                onClose: { dismiss() }
            )

            if display.mode != .body, !ARFaceTrackingConfiguration.isSupported {
                ARTrueDepthFallbackBanner()
            }

            // Полоска прогресса по позам
            poseChipsRow
                .padding(.top, SpacingTokens.micro)

            // Body-mode: score badge + hint
            if display.mode == .body {
                bodyFeedbackSection
                    .padding(.top, SpacingTokens.small)
            }

            // Название текущей позы — карточка-цель поверх камеры.
            Text(display.currentName)
                .font(TypographyTokens.title(30))
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.small)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
                )
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.top, SpacingTokens.small)
                .accessibilityLabel(Text("ar.poseSequence.currentPose \(display.currentName)"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer()

            HStack {
                ARMascotGuide(
                    state: isSuccess ? .celebrating : .pointing,
                    message: display.currentName.isEmpty
                        ? String(localized: "ar.poseSequence.title")
                        : display.currentName,
                    detail: display.currentHint.isEmpty ? nil : display.currentHint
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.small)

            ARControlPanel(
                hintText: isSuccess
                    ? String(localized: "ar.poseSequence.success")
                    : String(localized: "ar.hold.hint"),
                isSuccess: isSuccess,
                progress: display.progress,
                centerAction: nil,
                centerAccessibilityLabel: String(localized: "ar.hold.hint"),
                leading: { Color.clear.frame(width: 56, height: 56) },
                trailing: { Color.clear.frame(width: 56, height: 56) }
            )
        }
    }

    // MARK: - Pose chips

    private var poseChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(Array(display.postureNames.enumerated()), id: \.offset) { index, name in
                    let isUpcoming = index > display.currentIndex
                    Text(name)
                        .font(TypographyTokens.body(11))
                        .padding(.horizontal, SpacingTokens.small)
                        .padding(.vertical, SpacingTokens.micro)
                        .background(
                            isUpcoming ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(chipColor(for: index)),
                            in: Capsule()
                        )
                        .foregroundStyle(isUpcoming ? ColorTokens.Kid.ink : ColorTokens.Overlay.onAccent)
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

    /// Цвет для пройденной (mint) и текущей (coral) позы. Будущие позы рисуются
    /// на тёплом стекле в `poseChipsRow` (этот хелпер для них не вызывается).
    private func chipColor(for index: Int) -> Color {
        index < display.currentIndex ? ColorTokens.Brand.mint : ColorTokens.Brand.primary
    }

    // MARK: - Body feedback

    private var bodyFeedbackSection: some View {
        // Score badge (только в body-режиме). Подсказка показывается в ARMascotGuide.
        Text("\(display.bodyScore)%")
            .font(TypographyTokens.title(38))
            .foregroundStyle(scoreColor(display.bodyScore))
            .monospacedDigit()
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.vertical, SpacingTokens.small)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
            )
            .accessibilityLabel(Text("ar.poseSequence.score \(display.bodyScore)"))
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? ColorTokens.Brand.mint
            : score >= 50 ? ColorTokens.Brand.primary
            : ColorTokens.Semantic.warning
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
        } else if ARDeviceCapability.supportsFaceTracking {
            let live = LiveARSessionService()
            self.session = live
            try? await live.startSession()
            observeFace(service: live)
            interactor.startGame(.init(postures: [.smile, .pucker, .cupShape, .mushroom]))
        } else if ARDeviceCapability.allowsSimulatedSession {
            // Симуляция — только превью/тесты (P1-1): даёт детерминированный вход
            // для верификации VIP-логики без TrueDepth-железа.
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            observeFace(service: mock)
            interactor.startGame(.init(postures: [.smile, .pucker, .cupShape, .mushroom]))
        }
        // Иначе (реальное устройство без TrueDepth и без body-трекинга): цепочка
        // поз не запускается и не скорит синтетику — body показывает честный
        // ARUnsupportedView (P1-1).
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
