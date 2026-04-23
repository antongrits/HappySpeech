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

    @State private var session: LiveARSessionService?
    @State private var mockSession: MockARSessionService?
    @State private var interactor: ARMirrorInteractor?
    @State private var presenter: ARMirrorPresenter?
    @State private var router: ARMirrorRouter?
    @State private var display = ARMirrorDisplay()

    @State private var isSessionStarted = false
    @State private var startError: String?

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
                        .background(.black.opacity(0.45), in: Capsule())
                        .accessibilityAddTraits(.updatesFrequently)
                }

                symmetryBar

                progressBar
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.xLarge)
        }

        if let startError {
            Color.black.opacity(0.6).ignoresSafeArea()
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
                    Capsule().fill(.white.opacity(0.25))
                    Capsule()
                        .fill(ColorTokens.Brand.mint)
                        .frame(width: proxy.size.width * CGFloat(display.lipSymmetry))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: display.lipSymmetry)
                }
            }
            .frame(height: 8)
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text("ar.mirror.holdProgress")
                .font(TypographyTokens.body(12))
                .foregroundStyle(.white.opacity(0.85))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
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
    }

    private func teardown() {
        session?.stopSession()
        mockSession?.stopSession()
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
