import ARKit
import OSLog
import RealityKit
import SwiftUI

// MARK: - ARFaceFilterDisplayLogic

@MainActor
protocol ARFaceFilterDisplayLogic: AnyObject {
    func displaySetMask(viewModel: ARFaceFilterModels.SetMask.ViewModel) async
    func displayTrigger(viewModel: ARFaceFilterModels.Trigger.ViewModel) async
}

// MARK: - ARFaceFilterViewModel

@MainActor
@Observable
final class ARFaceFilterViewModelHolder: ARFaceFilterDisplayLogic {
    var setMaskVM: ARFaceFilterModels.SetMask.ViewModel?
    var triggerVM: ARFaceFilterModels.Trigger.ViewModel?
    var glowState: FaceMaskState = .idle

    func displaySetMask(viewModel: ARFaceFilterModels.SetMask.ViewModel) async {
        self.setMaskVM = viewModel
        self.glowState = .idle
        self.triggerVM = nil
    }

    func displayTrigger(viewModel: ARFaceFilterModels.Trigger.ViewModel) async {
        self.triggerVM = viewModel
        self.glowState = viewModel.isMatched ? .glowing : .idle
        if viewModel.isMatched {
            // Вернуться в idle через 2.5 сек
            try? await Task.sleep(for: .seconds(2.5))
            self.glowState = .idle
            self.triggerVM = nil
        }
    }
}

// MARK: - SimpleARFaceView (UIViewRepresentable)
//
// Минимальный self-contained ARView. Сессия привязана к жизненному циклу
// этого View, без global ARSessionService.

struct SimpleARFaceView: UIViewRepresentable {

    let isSupported: Bool

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.backgroundColor = .black
        guard isSupported else { return view }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}

// MARK: - ARFaceFilterView (Clean Swift: View)
//
// Block S.4 v16 — карнавальные маски с речевыми триггерами.
//
// Layout (full-screen):
//   1. ARView fullscreen (z-bottom)
//   2. Mask emoji overlay поверх лица (offset зависит от mask kind)
//   3. Glow ring при isMatched
//   4. Mask picker — горизонтальный scroll внизу
//   5. Prompt label вверху: «Скажи "кот"!»
//   6. Close button top-trailing

struct ARFaceFilterView: View {

    @State private var holder = ARFaceFilterViewModelHolder()
    @State private var interactor: ARFaceFilterInteractor?
    @State private var presenter: ARFaceFilterPresenter?
    @State private var renderer = FaceMaskRenderer()
    @State private var asrLoop: Task<Void, Never>?
    @State private var isListening = false

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "ARFaceFilter.View")

    init() {}

    var body: some View {
        ZStack {
            arBackground
            maskOverlay
            VStack {
                topBar
                Spacer()
                if let setMaskVM = holder.setMaskVM {
                    promptCard(viewModel: setMaskVM)
                }
                maskPicker
                    .padding(.bottom, SpacingTokens.sp4)
            }
            .padding(SpacingTokens.sp4)
        }
        .ignoresSafeArea()
        .task { await setupAndStart() }
        .onDisappear { stopListening() }
    }

    // MARK: - AR Background

    @ViewBuilder
    private var arBackground: some View {
        if FaceMaskRenderer.isFaceTrackingSupported {
            SimpleARFaceView(isSupported: true)
        } else {
            // Fallback: 2D градиент-фон, fun mode без AR.
            ZStack {
                LinearGradient(
                    colors: [ColorTokens.Brand.primary.opacity(0.4), ColorTokens.Brand.lilac.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .overlay {
                ContentUnavailableView(
                    String(localized: "facefilter.fallback.title"),
                    systemImage: "faceid",
                    description: Text("facefilter.fallback.body")
                )
            }
        }
    }

    // MARK: - Mask overlay

    @ViewBuilder
    private var maskOverlay: some View {
        if let setMaskVM = holder.setMaskVM {
            let offset = renderer.overlayOffset(for: setMaskVM.mask)
            Image(systemName: setMaskVM.mask.symbolName)
                .font(.system(size: 90))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .shadow(color: holder.glowState == .glowing
                        ? renderer.glowColor(for: setMaskVM.mask)
                        : .black.opacity(0.4),
                        radius: holder.glowState == .glowing ? 30 : 8)
                .offset(x: offset.width, y: offset.height)
                .scaleEffect(holder.glowState == .glowing && !reduceMotion ? 1.15 : 1.0)
                .animation(reduceMotion ? nil : .spring(duration: 0.4), value: holder.glowState)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .background(Circle().fill(ColorTokens.Overlay.dimmerHeavy))
            }
            .accessibilityLabel(Text("facefilter.close.a11y"))
        }
    }

    // MARK: - Prompt card

    @ViewBuilder
    private func promptCard(viewModel: ARFaceFilterModels.SetMask.ViewModel) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp1) {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .hsSymbolEffect(.variableColor, value: holder.glowState == .glowing)
                        .accessibilityHidden(true)
                    Text(viewModel.promptText)
                        .font(.title2.bold())
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(Text(viewModel.promptText))
                }
                if let triggerVM = holder.triggerVM, triggerVM.isMatched {
                    Text(triggerVM.celebrationText)
                        .font(.title3)
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .transition(.opacity)
                }
                if isListening {
                    // Реальный речевой триггер активен: распознаём слово ребёнка.
                    Label(String(localized: "facefilter.listening"), systemImage: "mic.fill")
                        .font(.caption)
                        .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.85))
                } else {
                    // ASR недоступен (нет разрешения / симулятор): честная ручная
                    // кнопка-подтверждение — НЕ имитация распознавания речи.
                    Button {
                        Task {
                            await interactor?.processTranscription(
                                request: .init(recognizedText: viewModel.mask.triggerWord)
                            )
                        }
                    } label: {
                        Label(String(localized: "facefilter.iSaidIt"), systemImage: "checkmark.circle")
                            .font(.callout.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTokens.Brand.primary)
                    .accessibilityHint(Text(String(localized: "facefilter.iSaidIt.hint")))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .animation(reduceMotion ? nil : .easeInOut, value: holder.triggerVM?.isMatched)
    }

    // MARK: - Mask picker

    private var maskPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp3) {
                ForEach(Array(FaceMaskKind.allCases.enumerated()), id: \.element.id) { _, mask in
                    maskButton(mask: mask)
                        .scrollTransition(.animated(
                            reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85)
                        )) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                        }
                        .hsParallaxTile(factor: 0.18)
                }
            }
            .padding(.horizontal, SpacingTokens.sp4)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func maskButton(mask: FaceMaskKind) -> some View {
        let isSelected = holder.setMaskVM?.mask == mask
        Button {
            Task { await interactor?.setMask(request: .init(mask: mask)) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: mask.symbolName)
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                Text(mask.localizedTitle)
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? ColorTokens.Overlay.highlight : ColorTokens.Overlay.dimmerHeavy)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? .white : .clear, lineWidth: 2)
            )
        }
        .accessibilityLabel(Text(mask.localizedTitle))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Wiring + simulated trigger

    private func setupAndStart() async {
        if interactor == nil {
            let presenter = ARFaceFilterPresenter(displayLogic: holder)
            let interactor = ARFaceFilterInteractor()
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
        }
        await interactor?.setMask(request: .init(mask: .kitten))

        // Реальный речевой триггер: периодически записываем короткий аудио-чанк
        // и распознаём через ASRService (kid-safe tier). Результат подаётся в
        // processTranscription. Если ASR/микрофон недоступны — остаётся честная
        // ручная кнопка-подтверждение в prompt-карточке (без имитации речи).
        await startListeningIfPossible()
    }

    private func startListeningIfPossible() async {
        let audio = container.audioService
        let asr = container.asrService
        guard asr.isReady else {
            isListening = false
            return
        }
        if !audio.isPermissionGranted {
            let granted = await audio.requestPermission()
            guard granted else {
                isListening = false
                return
            }
        }
        isListening = true
        asrLoop?.cancel()
        asrLoop = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await audio.startRecording()
                    try? await Task.sleep(for: .milliseconds(1500))
                    guard !Task.isCancelled else {
                        if audio.isRecording { _ = try? await audio.stopRecording() }
                        break
                    }
                    let url = try await audio.stopRecording()
                    let result = try await asr.transcribe(url: url)
                    await interactor?.processTranscription(request: .init(recognizedText: result.transcript))
                } catch {
                    Self.logger.error("ASR loop: \(error.localizedDescription, privacy: .public)")
                    isListening = false
                    break
                }
            }
        }
    }

    private func stopListening() {
        asrLoop?.cancel()
        asrLoop = nil
        isListening = false
        let audio = container.audioService
        if audio.isRecording {
            Task { _ = try? await audio.stopRecording() }
        }
    }
}

#if DEBUG
#Preview("ARFaceFilter / kitten") {
    ARFaceFilterView()
        .environment(AppContainer.preview())
}
#endif
