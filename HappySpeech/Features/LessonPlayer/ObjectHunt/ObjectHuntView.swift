import AVFoundation
import CoreVideo
import SwiftUI

// MARK: - ObjectHuntView
//
// 17-й шаблон игры — «Найди предмет».
//
// Поток:
//   1. Загрузка раунда (.loading)
//   2. Ляля: "Найди предмет на звук Ш!" (.scanning)
//   3. Rear camera кадры → ObjectDetectionWorker (1 fps)
//   4. Найден предмет → celebration overlay (.matchFound)
//   5. Ребёнок нажимает "Дальше" → следующий раунд
//   6. Все 3 раунда → .gameComplete → onComplete(score)
//
// Camera: AVCaptureSession (задняя камера) — не требует TrueDepth/Face ID.
// Detection: VNClassifyImageRequest (Vision built-in, ~30ms/frame на A15+).
// Рекомендуемая частота: 1 fps из CaptureOutput.

struct ObjectHuntView: View {

    // MARK: - Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var interactor: ObjectHuntInteractor?
    @State private var presenter: ObjectHuntPresenter?
    @State private var router: ObjectHuntRouter?
    @State private var display = ObjectHuntViewDisplay()
    @State private var adapter: ObjectHuntDisplayAdapter?

    // MARK: - Camera

    @State private var captureSession: AVCaptureSession?
    @State private var cameraService: ObjectHuntCameraService?
    @State private var bootstrapped = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Rear camera preview
            cameraBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                promptCard
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.medium)

                Spacer()

                switch display.phase {
                case .loading:
                    loadingView
                        .padding(.bottom, SpacingTokens.xLarge)
                case .scanning:
                    scanningHint
                        .padding(.bottom, SpacingTokens.xLarge)
                case .matchFound:
                    matchFoundOverlay
                        .padding(.bottom, SpacingTokens.xLarge)
                case .roundComplete:
                    roundCompleteView
                        .padding(.bottom, SpacingTokens.xLarge)
                case .gameComplete:
                    gameCompleteView
                        .padding(.bottom, SpacingTokens.xLarge)
                }
            }
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Camera Background

    @ViewBuilder
    private var cameraBackground: some View {
        if let session = captureSession {
            AVCapturePreviewView(session: session)
        } else {
            LinearGradient(
                colors: [ColorTokens.Brand.sky.opacity(0.35), ColorTokens.Kid.bgSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Prompt Card

    private var promptCard: some View {
        HSCard {
            HStack(spacing: SpacingTokens.small) {
                HSMascotView(mood: .explaining, size: 56)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(display.roundBadge)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)

                    Text(display.promptText.isEmpty
                        ? String(localized: "object_hunt.find_sound \(display.targetSoundLabel)")
                        : display.promptText)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !display.targetSoundLabel.isEmpty {
                    Text(display.targetSoundLabel)
                        .font(TypographyTokens.kidDisplay(38))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(ColorTokens.Brand.lilac.opacity(0.25)))
                        .accessibilityLabel(
                            String(localized: "object_hunt.target_sound_a11y \(display.targetSoundLabel)")
                        )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "object_hunt.loading"))
                .font(TypographyTokens.body())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
        }
    }

    // MARK: - Scanning Hint

    private var scanningHint: some View {
        VStack(spacing: SpacingTokens.small) {
            Image(systemName: "viewfinder")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.9))
                .symbolEffect(.pulse, isActive: !reduceMotion)

            Text(String(localized: "object_hunt.scanning_hint"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .shadow(color: .black.opacity(0.35), radius: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "object_hunt.scanning_a11y"))
    }

    // MARK: - Match Found

    private var matchFoundOverlay: some View {
        VStack(spacing: SpacingTokens.medium) {
            HSMascotView(mood: .celebrating, size: 96)
                .scaleEffect(reduceMotion ? 1.0 : 1.08)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.55),
                    value: display.phase
                )
                .accessibilityHidden(true)

            if let label = display.matchedLabel {
                Text(label)
                    .font(TypographyTokens.kidDisplay(34))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.vertical, SpacingTokens.small)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                            .fill(ColorTokens.Kid.surface.opacity(0.95))
                    )
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            }

            if let celebration = display.celebrationText {
                Text(celebration)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .background(
                        Capsule().fill(ColorTokens.Kid.surface.opacity(0.80))
                            .padding(.horizontal, -SpacingTokens.small)
                            .padding(.vertical, -SpacingTokens.tiny)
                    )
            }

            HSButton(
                String(localized: "object_hunt.next_round"),
                style: .primary,
                icon: "arrow.right.circle.fill"
            ) {
                advanceRound()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityHint(String(localized: "object_hunt.next_round_a11y"))
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Round Complete

    private var roundCompleteView: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(display.completionMessage)
                .font(TypographyTokens.headline(19))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.small)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .fill(ColorTokens.Kid.surface.opacity(0.88))
                )

            HSButton(
                String(localized: "object_hunt.continue"),
                style: .primary,
                icon: "play.fill"
            ) {
                startNextRound()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
    }

    // MARK: - Game Complete

    private var gameCompleteView: some View {
        VStack(spacing: SpacingTokens.large) {
            HSMascotView(mood: .celebrating, size: 110)
                .accessibilityHidden(true)

            starsRow

            Text(display.scoreLabel)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(display.summaryText)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)

            HSButton(
                String(localized: "object_hunt.finish"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                onComplete(display.lastScore)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityHint(String(localized: "object_hunt.finish_a11y"))
        }
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface.opacity(0.93))
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < display.starsEarned ? "star.fill" : "star")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(
                        index < display.starsEarned ? ColorTokens.Brand.gold : ColorTokens.Kid.line
                    )
                    .scaleEffect(index < display.starsEarned ? 1.0 : 0.85)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6)
                            .delay(Double(index) * 0.1),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "object_hunt.stars_a11y \(display.starsEarned)"))
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        // VIP wiring
        let interactor = ObjectHuntInteractor(detectionWorker: container.objectDetectionWorker)
        let presenter = ObjectHuntPresenter()
        let router = ObjectHuntRouter()
        let adapter = ObjectHuntDisplayAdapter(display: display)

        interactor.presenter = presenter
        interactor.router = router
        presenter.display = adapter

        router.onComplete = { [display] score in
            display.lastScore = score
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router
        self.adapter = adapter

        // Rear camera setup
        let cameraService = ObjectHuntCameraService()
        self.cameraService = cameraService

        do {
            let session = try cameraService.startCapture()
            self.captureSession = session
        } catch {
            HSLogger.ar.error("ObjectHunt: camera start failed — \(error.localizedDescription)")
        }

        // Detection loop — 1 fps из камеры, фильтрация по текущему targetSound
        let detectionWorker = container.objectDetectionWorker
        Task { [weak interactor, weak cameraService, display] in
            guard let pixelStream = cameraService?.pixelBufferStream else { return }
            for await wrapper in pixelStream {
                guard let interactor else { break }
                guard display.phase == .scanning else { continue }
                let targetSound = display.targetSoundLabel.lowercased()
                do {
                    let objects = try await detectionWorker.detect(
                        in: wrapper.buffer,
                        targetSound: targetSound.isEmpty ? nil : targetSound
                    )
                    await MainActor.run {
                        interactor.analyzeFrame(.init(detectedObjects: objects))
                    }
                } catch {
                    HSLogger.ar.error("ObjectHunt: detection failed — \(error.localizedDescription)")
                }
            }
        }

        // Первый раунд
        let group = Self.resolveSoundGroup(for: activity.soundTarget)
        interactor.loadRound(.init(
            soundGroup: group,
            targetSound: activity.soundTarget,
            roundIndex: 0
        ))
    }

    // MARK: - Round navigation

    private func advanceRound() {
        guard let interactor, let matched = display.lastMatchedObject else { return }
        interactor.confirmMatch(.init(
            matchedObject: matched,
            roundIndex: display.currentRoundIndex
        ))
    }

    private func startNextRound() {
        guard let interactor else { return }
        let group = Self.resolveSoundGroup(for: activity.soundTarget)
        interactor.loadRound(.init(
            soundGroup: group,
            targetSound: activity.soundTarget,
            roundIndex: display.currentRoundIndex
        ))
    }

    // MARK: - Teardown

    private func teardown() {
        cameraService?.stopCapture()
    }

    // MARK: - Helpers

    static func resolveSoundGroup(for targetSound: String) -> String {
        let first = targetSound.uppercased().prefix(1)
        switch first {
        case "С", "З", "Ц": return "whistling"
        case "Ш", "Ж", "Ч", "Щ": return "hissing"
        case "Р", "Л": return "sonorant"
        case "К", "Г", "Х": return "velar"
        default: return "hissing"
        }
    }
}

// MARK: - ObjectHuntDisplayAdapter

@MainActor
final class ObjectHuntDisplayAdapter: ObjectHuntDisplayLogic {

    private let display: ObjectHuntViewDisplay
    var lastScore: Float = 0

    init(display: ObjectHuntViewDisplay) {
        self.display = display
    }

    func displayLoadRound(_ viewModel: ObjectHuntModels.LoadRound.ViewModel) {
        display.targetSoundLabel = viewModel.targetSoundLabel
        display.promptText = viewModel.promptText
        display.roundBadge = viewModel.roundBadge
        display.matchedLabel = nil
        display.celebrationText = nil
        display.lastMatchedObject = nil
        display.phase = .scanning
    }

    func displayFrameAnalyzed(_ viewModel: ObjectHuntModels.FrameAnalyzed.ViewModel) {
        guard display.phase == .scanning else { return }
        if viewModel.isMatch {
            display.matchedLabel = viewModel.matchedLabel
            display.celebrationText = viewModel.celebrationText
            display.lastMatchedObject = viewModel.matchedObject
            display.phase = .matchFound
            HSLogger.ar.info("ObjectHunt: match '\(viewModel.matchedLabel ?? "")'")
        }
    }

    func displayCompleteRound(_ viewModel: ObjectHuntModels.CompleteRound.ViewModel) {
        display.completionMessage = viewModel.celebrationMessage
        if viewModel.shouldAdvance {
            display.phase = .roundComplete
            display.currentRoundIndex += 1
        }
    }

    func displayCompleteGame(_ viewModel: ObjectHuntModels.CompleteGame.ViewModel) {
        display.starsEarned = viewModel.starsEarned
        display.scoreLabel = viewModel.scoreLabel
        display.summaryText = viewModel.summaryText
        display.lastScore = Float(viewModel.starsEarned) / 3.0
        display.phase = .gameComplete
    }
}

// MARK: - ObjectHuntCameraService

/// Управляет `AVCaptureSession` для задней камеры и публикует
/// сырые `CVPixelBuffer` через `AsyncStream` с частотой ~1 fps.
/// Детектирование (VNClassifyImageRequest) выполняется в вызывающем коде,
/// чтобы можно было динамически менять targetSound между раундами.
/// Потокобезопасная обёртка над `CVPixelBuffer` для передачи через `AsyncStream`.
/// Swift 6: `CVPixelBuffer` не является `Sendable`, поэтому явно помечаем как `@unchecked Sendable`.
/// Ответственность за thread-safety: Vision обрабатывает буфер на своём потоке, после чего
/// буфер не используется снова.
struct SendablePixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

/// Управляет `AVCaptureSession` для задней камеры.
/// Не помечается `@MainActor` — `AVCaptureSession` и его делегат работают на фоновом потоке.
/// Публикует `CVPixelBuffer` (1 fps) через `AsyncStream` обёрнутый в `SendablePixelBuffer`.
final class ObjectHuntCameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Output

    private let (stream, continuation) = AsyncStream<SendablePixelBuffer>.makeStream()
    var pixelBufferStream: AsyncStream<SendablePixelBuffer> { stream }

    // MARK: - State

    private var session: AVCaptureSession?
    private var frameCounter: Int = 0
    private let lock = NSLock()

    // MARK: - Public API

    func startCapture() throws -> AVCaptureSession {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw ObjectHuntCameraError.deviceNotAvailable
        }

        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ru.happyspeech.objecthunt.capture", qos: .userInteractive))
        output.alwaysDiscardsLateVideoFrames = true
        captureSession.addOutput(output)

        self.session = captureSession

        // startRunning() должен вызываться не на Main Thread
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }

        HSLogger.ar.info("ObjectHuntCameraService: capture started")
        return captureSession
    }

    func stopCapture() {
        continuation.finish()
        session?.stopRunning()
        session = nil
        HSLogger.ar.info("ObjectHuntCameraService: capture stopped")
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    /// ~30fps capture → 1fps публикуем (каждый 30-й кадр).
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lock.lock()
        frameCounter += 1
        let shouldYield = frameCounter % 30 == 0
        lock.unlock()

        guard shouldYield else { return }
        continuation.yield(SendablePixelBuffer(buffer: pixelBuffer))
    }
}

// MARK: - ObjectHuntCameraError

enum ObjectHuntCameraError: LocalizedError {
    case deviceNotAvailable

    var errorDescription: String? {
        String(localized: "object_hunt.permission")
    }
}

// MARK: - AVCapturePreviewView

/// SwiftUI-обёртка для `AVCaptureVideoPreviewLayer`.
struct AVCapturePreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> AVPreviewUIView {
        let view = AVPreviewUIView()
        view.backgroundColor = .black
        view.setup(session: session)
        return view
    }

    func updateUIView(_ uiView: AVPreviewUIView, context: Context) {}
}

@MainActor
final class AVPreviewUIView: UIView {

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }  // swiftlint:disable:this static_over_final_class

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer  // swiftlint:disable:this force_cast
    }

    func setup(session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}

// MARK: - Preview

#Preview("ObjectHunt") {
    ObjectHuntView(
        activity: SessionActivity(
            id: "object-hunt-demo",
            gameType: .objectHunt,
            lessonId: "Ш-wordInit",
            soundTarget: "Ш",
            difficulty: 3,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
