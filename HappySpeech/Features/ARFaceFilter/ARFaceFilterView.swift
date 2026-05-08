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
    }

    // MARK: - AR Background

    @ViewBuilder
    private var arBackground: some View {
        if FaceMaskRenderer.isFaceTrackingSupported {
            SimpleARFaceView(isSupported: true)
        } else {
            // Fallback: 2D градиент-фон, fun mode без AR.
            LinearGradient(
                colors: [ColorTokens.Brand.primary.opacity(0.4), ColorTokens.Brand.lilac.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        VStack(spacing: SpacingTokens.sp1) {
            Text(viewModel.promptText)
                .font(.title2.bold())
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .multilineTextAlignment(.center)
                .accessibilityLabel(Text(viewModel.promptText))
            if let triggerVM = holder.triggerVM, triggerVM.isMatched {
                Text(triggerVM.celebrationText)
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .transition(.opacity)
            }
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ColorTokens.Overlay.dimmerHeavy)
        )
        .padding(.horizontal, SpacingTokens.sp3)
        .animation(reduceMotion ? nil : .easeInOut, value: holder.triggerVM?.isMatched)
    }

    // MARK: - Mask picker

    private var maskPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp3) {
                ForEach(FaceMaskKind.allCases) { mask in
                    maskButton(mask: mask)
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

        // MVP: speech trigger через WhisperKit polling — отложено в Block Q.
        // Сейчас просто принимаем tap по prompt-card как simulated trigger
        // (см. comment в processTranscription). Реальный ASR-pipeline
        // подключается позже.
    }
}

// NOTE deferred to Block Q (test coverage): WhisperKit polling integration test,
// snapshot tests, fallback на устройствах без TrueDepth.

#if DEBUG
#Preview("ARFaceFilter / kitten") {
    ARFaceFilterView()
}
#endif
