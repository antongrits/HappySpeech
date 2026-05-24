import AVFoundation
import OSLog
import SwiftUI

// MARK: - FingerPlayViewModelHolder

@MainActor
@Observable
final class FingerPlayViewModelHolder: FingerPlayDisplayLogic {

    var startVM: FingerPlayModels.Start.ViewModel?
    var liveVM: FingerPlayModels.HandPoseUpdate.ViewModel?
    var summary: String?
    var isFinished: Bool = false

    func displayStart(viewModel: FingerPlayModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.liveVM = nil
        self.isFinished = false
    }

    func displayHandPoseUpdate(viewModel: FingerPlayModels.HandPoseUpdate.ViewModel) async {
        self.liveVM = viewModel
    }

    func displayAdvance(viewModel: FingerPlayModels.Advance.ViewModel) async {
        if viewModel.isSessionFinished {
            self.summary = viewModel.summaryMessage
            self.isFinished = true
            self.startVM = nil
        } else if let next = viewModel.nextStartVM {
            self.startVM = next
            self.liveVM = nil
        }
    }
}

// MARK: - FingerPlayView

struct FingerPlayView: View {

    let childId: String

    @State private var holder = FingerPlayViewModelHolder()
    @State private var interactor: FingerPlayInteractor?
    @State private var presenter: FingerPlayPresenter?
    @State private var router: FingerPlayRouter?
    @State private var didBootstrap = false
    @State private var cameraSession: HandPoseCameraSession?
    @State private var permissionDenied: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "FingerPlay.View"
    )

    @State private var mascotState: LyalyaState = .thinking
    @State private var showConfetti: Bool = false
    @State private var contentAppeared: Bool = false
    @State private var lastMatchState: Bool = false

    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch G — Pattern 1: kidWarm mesh палитра.
                HSMeshGradientBackground(palette: .kidWarm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                if permissionDenied {
                    deniedSection
                        .transition(.opacity)
                } else if holder.isFinished {
                    summarySection
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if let vm = holder.startVM {
                    gameSection(vm)
                        .transition(.opacity)
                } else {
                    loadingSection
                        .transition(.opacity)
                }

                // Конфетти при финале
                HSConfettiView(preset: .celebration, isActive: $showConfetti)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .animation(reduceMotion ? .none : MotionTokens.spring, value: holder.isFinished)
            .animation(reduceMotion ? .none : MotionTokens.spring, value: permissionDenied)
            .navigationTitle(Text("fingerPlay.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .onDisappear { cameraSession?.stop() }
            .onChange(of: holder.liveVM?.matchesTarget) { _, matches in
                guard let matches else { return }
                if matches && !lastMatchState {
                    mascotState = .celebrating
                    hapticService.notification(.success)
                } else if !matches {
                    mascotState = .pointing
                }
                lastMatchState = matches
            }
            .onChange(of: holder.isFinished) { _, finished in
                if finished {
                    mascotState = .waving
                    showConfetti = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        showConfetti = false
                    }
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    /// Промежуточное состояние до получения камеры / первого упражнения.
    /// Без него экран был «серой плиткой» на симуляторе (нет hardware камеры).
    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            LyalyaMascotView(state: .thinking, size: 120)
                .accessibilityHidden(true)
            ProgressView()
                .scaleEffect(1.2)
                .tint(ColorTokens.Brand.primary)
            Text("fingerPlay.camera.starting")
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("fingerPlay.camera.starting"))
    }

    // MARK: - Sections

    private func gameSection(_ vm: FingerPlayModels.Start.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            headerBlock(vm)
            cameraPreview
            targetGestureCard(vm)
            feedbackBlock
            skipButton
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.sp4)
    }

    private func headerBlock(_ vm: FingerPlayModels.Start.ViewModel) -> some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: mascotState, size: 72)
                .animation(reduceMotion ? .none : MotionTokens.spring, value: mascotState)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(vm.exerciseTitle)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(vm.stageDescription)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(vm.accessibilityLabel))
    }

    private var cameraPreview: some View {
        ZStack {
            if let session = cameraSession?.captureSession {
                CameraPreviewLayerView(session: session)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
                    .frame(height: 280)
                    .overlay {
                        Text("fingerPlay.camera.starting")
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
            }
        }
        .accessibilityLabel(Text("fingerPlay.camera.a11y"))
    }

    private func targetGestureCard(_ vm: FingerPlayModels.Start.ViewModel) -> some View {
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero gesture-card.
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp4) {
                VStack(spacing: SpacingTokens.sp1) {
                    Text("fingerPlay.target.label")
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    Image(systemName: vm.targetGestureSymbol)
                        .font(.system(size: 52))
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .symbolRenderingMode(.hierarchical)
                        // Step 10 Batch G — Pattern 5: pulse on target gesture.
                        .hsSymbolEffect(.pulse, value: vm.targetGestureSymbol)
                }
                Spacer()
                Image(systemName: holder.liveVM?.matchesTarget == true
                      ? "arrow.left.arrow.right.circle.fill"
                      : "arrow.left.arrow.right")
                    .font(.title3)
                    .foregroundStyle(holder.liveVM?.matchesTarget == true
                                     ? ColorTokens.Semantic.success
                                     : ColorTokens.Kid.line)
                    .animation(reduceMotion ? .none : MotionTokens.settleSpring,
                               value: holder.liveVM?.matchesTarget)
                    // Step 10 Batch G — Pattern 5: bounce on match toggle.
                    .hsSymbolEffect(.bounce, value: holder.liveVM?.matchesTarget)
                Spacer()
                VStack(spacing: SpacingTokens.sp1) {
                    Text("fingerPlay.you.label")
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    Image(systemName: holder.liveVM?.detectedPoseSymbol ?? "hand.raised")
                        .font(.system(size: 52))
                        .foregroundStyle(holder.liveVM?.matchesTarget == true
                                         ? ColorTokens.Semantic.success
                                         : ColorTokens.Kid.inkMuted)
                        .animation(reduceMotion ? .none : MotionTokens.settleSpring,
                                   value: holder.liveVM?.detectedPoseSymbol)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp1)
        }
        .accessibilityElement(children: .combine)
    }

    private var feedbackBlock: some View {
        HStack(spacing: SpacingTokens.sp2) {
            if let live = holder.liveVM, live.matchesTarget {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Semantic.success)
                Text("fingerPlay.feedback.match")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Semantic.success)
            } else {
                Image(systemName: "hand.point.up.left")
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                Text("fingerPlay.feedback.tryAgain")
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var skipButton: some View {
        Button {
            Task { await interactor?.skipToNext() }
        } label: {
            Text("fingerPlay.button.skip")
                .font(TypographyTokens.headline(17))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
                .foregroundStyle(ColorTokens.Overlay.onAccent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("fingerPlay.button.skip.a11y"))
    }

    private var summarySection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            LyalyaMascotView(state: .celebrating, size: 140)
                .accessibilityHidden(true)
            HSRewardBurst(isShowing: holder.isFinished, color: ColorTokens.Brand.gold)
                .frame(width: 200, height: 200)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.12))) {
                VStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .symbolRenderingMode(.hierarchical)
                    Text(holder.summary ?? "")
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
            }
            Button {
                dismiss()
            } label: {
                Text("fingerPlay.button.done")
                    .font(TypographyTokens.headline(18))
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.button)
                            .fill(ColorTokens.Brand.primary)
                    )
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(Text("fingerPlay.button.done"))
        }
        .padding(SpacingTokens.screenEdge)
    }

    private var deniedSection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            LyalyaMascotView(state: .thinking, size: 100)
                .accessibilityHidden(true)
            HSCard(style: .flat) {
                VStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .symbolRenderingMode(.hierarchical)
                    Text("fingerPlay.permission.title")
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                    Text("fingerPlay.permission.body")
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
            }
            Button {
                router?.openCameraPermissionFlow()
            } label: {
                Text("fingerPlay.permission.openSettings")
                    .font(TypographyTokens.headline(17))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.button)
                            .fill(ColorTokens.Brand.primary)
                    )
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(SpacingTokens.screenEdge)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                cameraSession?.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text("fingerPlay.close.a11y"))
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = FingerPlayPresenter(displayLogic: holder)
        let interactor = FingerPlayInteractor(presenter: presenter)
        let router = FingerPlayRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        let granted = await requestCameraPermission()
        permissionDenied = !granted
        if granted {
            await setupCamera()
        }
        await interactor.start(permissionGranted: granted)
    }

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func setupCamera() async {
        let session = HandPoseCameraSession()
        let worker = container.handPoseWorker
        session.onPixelBuffer = { pixelBuffer in
            // Эта closure вызывается на background-очереди.
            // CVPixelBuffer — CF-тип, не Sendable; перевозим через @unchecked-обёртку.
            nonisolated(unsafe) let buffer = pixelBuffer
            Task { @MainActor [weak interactor] in
                do {
                    if let observation = try await worker.detect(in: buffer) {
                        await interactor?.handleHandPoseObservation(
                            detectedPose: observation.pose.rawValue,
                            confidence: observation.confidence
                        )
                    }
                } catch {
                    // Игнорируем — Vision может бросать на «нет руки».
                }
            }
        }
        _ = session.start()
        cameraSession = session
    }
}

// MARK: - CameraPreviewLayerView

/// SwiftUI-обёртка над AVCaptureVideoPreviewLayer.
private struct CameraPreviewLayerView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context _: Context) -> UIView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        guard let preview = uiView as? PreviewView else { return }
        if preview.videoPreviewLayer.session !== session {
            preview.videoPreviewLayer.session = session
        }
    }

    final class PreviewView: UIView {
        // swiftlint:disable:next static_over_final_class
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Preview

#Preview("FingerPlay — Light") {
    FingerPlayView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
