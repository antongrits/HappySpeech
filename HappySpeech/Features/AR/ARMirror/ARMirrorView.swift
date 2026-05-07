import ARKit
import RealityKit
import SwiftUI

// MARK: - ARMirrorView

/// Ребёнок видит своё лицо через переднюю камеру и повторяет артикуляционные упражнения.
/// На экране: контур-подсказка желаемой позы, прогресс-бар симметрии губ, real-time feedback.
struct ARMirrorView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mascotLipSyncState) private var lipSyncState
    @Environment(\.mascotEyeContactState) private var eyeContactState

    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: ARMirrorInteractor?
    @State private var presenter: ARMirrorPresenter?
    @State private var router: ARMirrorRouter?
    @State private var display = ARMirrorDisplay()
    @State private var facePoseWorker = UnifiedFacePoseWorker()
    @State private var eyeFocusWorker = EyeFocusWorker()

    @State private var isSessionStarted = false
    @State private var startError: String?
    @State private var lastHintDate: Date = .distantPast

    private var arService: (any ARSessionService)? {
        session ?? mockSession
    }

    var body: some View {
        ZStack {
            if ARFaceTrackingConfiguration.isSupported, let session {
                ARFaceViewContainer(session: session.underlyingSession)
                    .ignoresSafeArea()
            } else {
                ColorTokens.Kid.bgDeep.ignoresSafeArea()
                ARUnsupportedView()
            }

            overlay
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Battery: останавливаем ARSession при уходе в background.
            session?.stopSession()
            mockSession?.stopSession()
            lipSyncState.isTracking = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Возобновляем ARSession при возврате из background (только если экран всё ещё показывается).
            guard isSessionStarted else { return }
            Task { @MainActor in
                do {
                    if let live = session {
                        try await live.startSession()
                        startFrameStream(service: live)
                    }
                } catch {
                    HSLogger.ar.error("ARMirror resume failed: \(error.localizedDescription)")
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Overlay UI

    @ViewBuilder
    private var overlay: some View {
        VStack {
            ARGameHUD(
                title: "ar.mirror.title",
                scoreText: display.lastStars.map { "\($0)⭐" },
                onClose: { dismiss() }
            )

            if let currentVM = display.start {
                exerciseHeader(currentVM)
            }

            Spacer()

            VStack(spacing: SpacingTokens.small) {
                if !display.instruction.isEmpty {
                    Text(display.instruction)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.medium)
                        .padding(.vertical, SpacingTokens.small)
                        .background(ColorTokens.Overlay.dimmerHeavy, in: Capsule())
                        .accessibilityAddTraits(.updatesFrequently)
                }

                symmetryBar

                attentionIndicator

                progressBar
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.xLarge)
        }

        // Block L: Маскот Ляля с real-time lip-sync из ARFaceAnchor.
        // Размещается в правом нижнем углу поверх AR-камеры.
        // mouthOpen и viseme получаем из lipSyncState, обновляемого в startFrameStream.
        // При isTracking = false (нет TrueDepth, фон, симулятор) — состояние idle без lip-sync.
        // Reduced Motion: анимация внутри LyalyaMascotView отключается автоматически.
        lyalyaLipSyncMascot

        if display.showAttentionHint {
            VStack {
                Spacer()
                Text(String(localized: "eye_focus.hint.look_at_me"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.vertical, SpacingTokens.small)
                    .background(ColorTokens.Brand.primary.opacity(0.9), in: Capsule())
                    .accessibilityLabel(Text("eye_focus.hint.look_at_me"))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, SpacingTokens.xLarge * 2)
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: display.showAttentionHint)
        }

        if let startError {
            ColorTokens.Overlay.dimmerHeavy.ignoresSafeArea()
            VStack(spacing: SpacingTokens.small) {
                Text("ar.mirror.startError")
                    .font(TypographyTokens.headline())
                Text(startError)
                    .font(TypographyTokens.body(13))
                    .multilineTextAlignment(.center)
                Button("common.close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(ColorTokens.Kid.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
            .padding(SpacingTokens.screenEdge)
        }
    }

    // MARK: - Lyalya lip-sync mascot (Block L)

    /// Маскот Ляля с real-time lip-sync из ARFaceAnchor blendshapes.
    /// Позиционируется в правом нижнем углу экрана.
    /// LyalyaMascotView читает lipSyncState через @Environment(\.mascotLipSyncState)
    /// и рендерит MouthBubbleOverlay когда isTracking = true.
    private var lyalyaLipSyncMascot: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                LyalyaMascotView(
                    state: lyalyaMascotState,
                    size: 88
                )
                .accessibilityLabel(Text("ar.mirror.lyalya.accessibility"))
                .accessibilityHidden(false)
                .padding(.trailing, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.xLarge * 2 + SpacingTokens.large)
            }
        }
    }

    /// Определяет эмоциональное состояние Ляли на основе прогресса упражнения.
    /// Celebrating при завершении (stars есть), encouraging при хорошем прогрессе,
    /// explaining в обычном режиме.
    private var lyalyaMascotState: LyalyaState {
        if display.lastStars != nil { return .celebrating }
        if display.progress > 0.6 { return .encouraging }
        return .explaining
    }

    @ViewBuilder
    private func exerciseHeader(_ vm: ARMirrorModels.StartGame.ViewModel) -> some View {
        HStack {
            Text("\(vm.exerciseNumber) / \(vm.totalExercises)")
                .font(TypographyTokens.body(13))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(String(localized: String.LocalizationValue(vm.currentExercise.displayNameKey)))
                .font(TypographyTokens.headline(15))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.tiny)
    }

    private var symmetryBar: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text("ar.mirror.symmetry")
                .font(TypographyTokens.body(12))
                .foregroundStyle(.white.opacity(0.85))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Overlay.highlight)
                    Capsule()
                        .fill(ColorTokens.Brand.mint)
                        .frame(width: proxy.size.width * CGFloat(display.lipSymmetry))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: display.lipSymmetry)
                }
            }
            .frame(height: 8)
        }
    }

    private var attentionIndicator: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: eyeContactState.isEyeContact ? "eye.fill" : "eye.slash")
                .font(TypographyTokens.caption(11))
                .foregroundStyle(eyeContactState.isEyeContact
                    ? ColorTokens.Brand.mint
                    : .white.opacity(0.5))
                .accessibilityHidden(true)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(eyeContactState.attentionScore > 0.6
                            ? ColorTokens.Brand.mint
                            : ColorTokens.Brand.butter)
                        .frame(width: proxy.size.width * CGFloat(eyeContactState.attentionScore))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: eyeContactState.attentionScore)
                }
            }
            .frame(height: 5)
        }
        .accessibilityLabel(Text("ar.mirror.attention"))
        .accessibilityValue(Text(eyeContactState.isEyeContact
            ? String(localized: "eye_focus.hint.well_done")
            : String(localized: "eye_focus.attention_low")))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text("ar.mirror.holdProgress")
                .font(TypographyTokens.body(12))
                .foregroundStyle(.white.opacity(0.85))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Overlay.highlight)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [ColorTokens.Brand.primary, ColorTokens.Brand.butter],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: proxy.size.width * CGFloat(display.progress))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: display.progress)
                }
            }
            .frame(height: 12)
        }
    }

    // MARK: - Wiring

    private func bootstrap() async {
        guard interactor == nil else { return }

        let interactor = ARMirrorInteractor()
        let presenter = ARMirrorPresenter()
        let router = ARMirrorRouter()
        interactor.presenter = presenter
        presenter.display = display
        router.dismiss = { [weak display] in
            display?.start = nil
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        // Выбираем service: Live на устройстве, Mock на симуляторе/неподдерживаемых.
        if ARFaceTrackingConfiguration.isSupported {
            let live = LiveARSessionService()
            self.session = live
            do {
                try await live.startSession()
                isSessionStarted = true
                startFrameStream(service: live)
            } catch {
                startError = error.localizedDescription
                HSLogger.ar.error("ARMirror start failed: \(error.localizedDescription)")
            }
        } else {
            let mock = MockARSessionService()
            self.mockSession = mock
            try? await mock.startSession()
            isSessionStarted = true
            startFrameStream(service: mock)
        }

        interactor.startGame(.init())
    }

    private func startFrameStream(service: any ARSessionService) {
        let interactor = self.interactor
        let display = self.display
        let lipSyncState = self.lipSyncState
        let facePoseWorker = self.facePoseWorker
        let eyeFocusWorker = self.eyeFocusWorker
        let eyeContactState = self.eyeContactState

        Task { @MainActor in
            for await frame in service.blendshapeStream {
                display.lipSymmetry = frame.lipSymmetry
                interactor?.updateFrame(.init(blendshapes: frame))
                if display.shouldAdvance {
                    display.shouldAdvance = false
                    interactor?.advanceToNextExercise()
                }
            }
        }

        // Unified Face Pose: вычисляем viseme из FaceBlendshapes и обновляем
        // MascotLipSyncState для real-time lip-sync оверлея маскота Ляли.
        // ARFaceTrackingConfiguration.isSupported гарантирует TrueDepth на устройстве.
        // Confidence = мин. jawOpen*2 (чем больше открытие, тем выше уверенность).
        Task { @MainActor in
            for await frame in service.blendshapeStream {
                let pose = UnifiedFacePose(
                    mouthOpen:   frame.jawOpen,
                    lipsPucker:  frame.mouthPucker,
                    lipsFunnel:  frame.mouthFunnel,
                    lipsSmile:   (frame.mouthSmileLeft + frame.mouthSmileRight) / 2,
                    tongueOut:   frame.tongueOut,
                    lipSymmetry: frame.lipSymmetry,
                    landmarks76: nil
                )
                let viseme = facePoseWorker.currentViseme(pose)
                display.currentViseme = viseme

                // Обновляем shared lip-sync state для LyalyaMascotView
                lipSyncState.mouthOpen  = frame.jawOpen
                lipSyncState.viseme     = LipSyncViseme(from: viseme)
                lipSyncState.confidence = min(frame.jawOpen * 2.5, 1.0)
                lipSyncState.isTracking = true
            }
            // Stream завершился — ARSession остановлена
            lipSyncState.isTracking = false
        }

        // Block L: Eye/focus tracking через ARFaceAnchor.lookAtPoint.
        // Используем LiveARSessionService.eyeFocusStream (доступен только при TrueDepth).
        // На симуляторе / MockARSessionService → guard не пройдёт, worker не вызывается.
        guard let liveService = service as? LiveARSessionService else { return }
        Task { @MainActor in
            for await anchor in liveService.faceAnchorStream {
                let obs = await eyeFocusWorker.analyze(faceAnchor: anchor)
                let history = await eyeFocusWorker.recentHistory()
                let avgAttention = await eyeFocusWorker.computeAttention(history: history)
                eyeContactState.update(isLookingAtCamera: obs.isLookingAtCamera, attention: avgAttention)

                // Attention hint: если среднее внимание низкое >5 сек → подсказка Ляли
                if avgAttention < 0.3 {
                    let now = Date()
                    if now.timeIntervalSince(lastHintDate) > 5.0 {
                        lastHintDate = now
                        display.showAttentionHint = true
                        // Скрываем подсказку через 2 сек
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            display.showAttentionHint = false
                        }
                    }
                }
            }
            eyeContactState.reset()
        }
    }

    private func teardown() {
        session?.stopSession()
        mockSession?.stopSession()
        lipSyncState.isTracking = false
        eyeContactState.reset()
    }
}

// MARK: - ARMirrorDisplay

@Observable
@MainActor
final class ARMirrorDisplay: ARMirrorDisplayLogic {
    var start: ARMirrorModels.StartGame.ViewModel?
    var instruction: String = ""
    var progress: Float = 0
    var lipSymmetry: Float = 1
    var shouldAdvance: Bool = false
    var lastStars: Int?
    /// Текущая визема для real-time lip-sync маскота Ляли.
    var currentViseme: Viseme = .closed
    /// Block L: показывать attention hint «Посмотри на меня!»
    var showAttentionHint: Bool = false

    func displayStartGame(_ viewModel: ARMirrorModels.StartGame.ViewModel) {
        self.start = viewModel
        self.instruction = viewModel.instruction
        self.progress = 0
    }

    func displayUpdateFrame(_ viewModel: ARMirrorModels.UpdateFrame.ViewModel) {
        self.progress = viewModel.progress
        if viewModel.shouldAdvance { self.shouldAdvance = true }
    }

    func displayScoreAttempt(_ viewModel: ARMirrorModels.ScoreAttempt.ViewModel) {
        self.lastStars = viewModel.stars
    }
}

// MARK: - Preview

#Preview {
    ARMirrorView()
        .environment(AppContainer.preview())
}
