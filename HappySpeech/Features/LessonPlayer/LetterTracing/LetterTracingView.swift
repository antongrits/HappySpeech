import PencilKit
import SwiftUI
import UIKit

// MARK: - LetterTracingPhase

/// Фазы одного упражнения написания буквы.
enum LetterTracingPhase: Sendable, Equatable {
    case loading
    case drawing
    case feedback
    case complete
}

// MARK: - LetterTracingView

/// Шаблон «Напиши букву» (iPhone и iPad).
///
/// Поток:
///   1. `.loading` → `interactor.loadExercise()` → `.drawing`
///   2. Ребёнок рисует пальцем / Apple Pencil поверх dotted-guide.
///   3. Нажимает «Проверить» → `.feedback` (Vision распознаёт букву).
///   4. «Сбросить» → очищаем canvas, перезапускаем таймер.
///   5. «Подсказка» → 3 уровня: точка → стрелка → полный шаблон.
///   6. После всех раундов → `onComplete(score)`.
struct LetterTracingView: View {

    // MARK: - Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.exitGame) private var exitGame

    // MARK: - VIP

    @State private var interactor: LetterTracingInteractor?
    @State private var presenter: LetterTracingPresenter?
    @State private var router: LetterTracingRouter?
    @State private var displayAdapter: LetterTracingViewDisplayAdapter?

    // MARK: - View state

    @State private var phase: LetterTracingPhase = .loading
    @State private var exerciseVM: LetterTracingModels.LoadExercise.ViewModel?
    @State private var feedbackVM: LetterTracingModels.SubmitDrawing.ViewModel?
    @State private var hintVM: LetterTracingModels.RequestHint.ViewModel?
    @State private var isProcessing: Bool = false

    // MARK: - Canvas

    @State private var canvas = PKCanvasView()

    // MARK: - Body

    var body: some View {
        tracingCanvas
            .task {
                guard interactor == nil else { return }
                setupVIP()
                await interactor?.loadExercise(
                    LetterTracingModels.LoadExercise.Request(
                        targetLetter: activity.soundTarget.uppercased(),
                        difficulty: activity.difficulty
                    )
                )
            }
    }

    // MARK: - Tracing Canvas

    @ViewBuilder
    private var tracingCanvas: some View {
        ZStack {
            KidGameCanvasScaffold(
                title: Text(exerciseVM?.instructionText ?? String(localized: "letter_tracing.canvas.accessibility_label")),
                subtitle: traceSubtitle,
                progress: traceProgress,
                stepDots: traceStepDots,
                palette: .kidWarm,
                onExit: { exitGame() }
            ) {
                canvasContent
            } toolbar: {
                KidGameToolButton(
                    systemImage: "arrow.uturn.backward",
                    label: String(localized: "letter_tracing.button.reset"),
                    isMuted: canvas.drawing.strokes.isEmpty
                ) {
                    handleReset()
                }

                if exerciseVM != nil {
                    KidGameToolButton(
                        systemImage: "lightbulb.fill",
                        label: String(localized: "letter_tracing.button.hint")
                    ) {
                        if let vm = exerciseVM {
                            interactor?.requestHint(
                                LetterTracingModels.RequestHint.Request(letter: vm.targetLetter)
                            )
                        }
                    }
                }

                KidGameCTAButton(
                    title: String(localized: "letter_tracing.button.check"),
                    systemImage: "checkmark",
                    isDisabled: isProcessing || canvas.drawing.strokes.isEmpty || phase == .feedback
                ) {
                    Task { await handleCheck() }
                }
            }

            if phase == .feedback, let vm = feedbackVM {
                feedbackOverlay(vm: vm)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.92))
                    )
                    .zIndex(10)
            }

            if phase == .complete {
                completeOverlay
                    .transition(
                        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
                    )
                    .zIndex(10)
            }
        }
        .onAppear(perform: setupToolPicker)
    }

    // MARK: - Canvas content (внутри холста)

    private var canvasContent: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) - SpacingTokens.regular
            ZStack {
                if let vm = exerciseVM {
                    LetterTemplateView(
                        letter: vm.targetLetter,
                        level: vm.tracingLevel,
                        showFullOverlay: hintVM?.showFullTemplate ?? false
                    )
                    .frame(width: side, height: side)
                    .accessibilityHidden(true)
                }

                CanvasViewRepresentable(canvas: $canvas, allowsFinger: true)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
                    .accessibilityLabel(
                        String(localized: "letter_tracing.canvas.accessibility_label")
                    )
                    .accessibilityHint(
                        String(localized: "letter_tracing.canvas.accessibility_hint")
                    )

                if let hint = hintVM {
                    hintOverlay(hint: hint, size: CGSize(width: side, height: side))
                        .allowsHitTesting(false)
                }

                // Маскот + реплика снизу-слева холста.
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        KidGameMascotBubble(
                            message: mascotMessage,
                            state: phase == .feedback ? .celebrating : .pointing
                        )
                        Spacer(minLength: 0)
                    }
                }
                .padding(SpacingTokens.small)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var mascotMessage: String {
        if let vm = exerciseVM, !vm.phonemeWord.isEmpty {
            return String(format: String(localized: "letter_tracing.phoneme_example %@"), vm.phonemeWord)
        }
        return inputHintText
    }

    private var traceSubtitle: String? {
        guard let vm = exerciseVM else { return nil }
        return vm.tracingLevel.localizedTitle
    }

    private var traceProgress: Double? {
        guard let vm = exerciseVM else { return nil }
        return Double(vm.roundIndex) / Double(max(vm.totalRounds, 1))
    }

    private var traceStepDots: (current: Int, total: Int)? {
        guard let vm = exerciseVM, vm.totalRounds > 1 else { return nil }
        return (current: min(vm.roundIndex, vm.totalRounds - 1), total: vm.totalRounds)
    }

    @ViewBuilder
    private func hintOverlay(
        hint: LetterTracingModels.RequestHint.ViewModel,
        size: CGSize
    ) -> some View {
        if hint.showStartDot {
            Circle()
                .fill(ColorTokens.Brand.mint.opacity(0.85))
                .frame(width: 20, height: 20)
                .position(x: size.width * 0.25, y: size.height * 0.25)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: hint.showStartDot
                )
                .accessibilityHidden(true)
        }
        if hint.showDirectionArrow {
            Image(systemName: "arrow.down.right.circle.fill")
                .font(TypographyTokens.display(36))
                .foregroundStyle(ColorTokens.Brand.lilac.opacity(0.85))
                .position(x: size.width * 0.3, y: size.height * 0.3)
                .accessibilityHidden(true)
        }
    }

    private func feedbackOverlay(vm: LetterTracingModels.SubmitDrawing.ViewModel) -> some View {
        HSLiquidGlassCard(
            style: vm.isCorrect
                ? .tinted(ColorTokens.Brand.mint)
                : .primary,
            padding: SpacingTokens.xLarge
        ) {
            VStack(spacing: SpacingTokens.medium) {
                LyalyaMascotView(state: vm.isCorrect ? .celebrating : .thinking, size: 100)

                Text(vm.feedbackText)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(vm.isCorrect ? ColorTokens.Brand.mint : ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)

                if let recognized = vm.recognizedText {
                    Text(recognized)
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }

                Text(
                    String(format: String(localized: "letter_tracing.score_percent %lld"), vm.scorePercent)
                )
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Kid.ink)

                if vm.attemptNumber > 1 {
                    Text(
                        String(
                            format: String(localized: "letter_tracing.attempt %lld %lld"),
                            vm.attemptNumber,
                            vm.bestScorePercent
                        )
                    )
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                }

                HSButton(
                    String(localized: "letter_tracing.button.next"),
                    style: .primary,
                    icon: "arrow.right.circle.fill"
                ) {
                    Task { await handleNext() }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.xLarge)
    }

    private var completeOverlay: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.xLarge) {
            VStack(spacing: SpacingTokens.medium) {
                LyalyaMascotView(state: .celebrating, size: 120)

                Text(String(localized: "letter_tracing.complete.title"))
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.xLarge)
    }

    // MARK: - Handlers

    private func handleReset() {
        canvas.drawing = PKDrawing()
        hintVM = nil
        interactor?.resetCanvas(LetterTracingModels.ResetCanvas.Request())
    }

    private func handleCheck() async {
        guard !isProcessing, !canvas.drawing.strokes.isEmpty else { return }
        guard let vm = exerciseVM else { return }
        isProcessing = true
        await interactor?.submitDrawing(
            LetterTracingModels.SubmitDrawing.Request(
                drawing: canvas.drawing,
                targetLetter: vm.targetLetter,
                drawingDuration: 0
            )
        )
        isProcessing = false
    }

    private func handleNext() async {
        phase = .drawing
        feedbackVM = nil
        hintVM = nil
        canvas.drawing = PKDrawing()

        guard let vm = exerciseVM, vm.roundIndex + 1 < vm.totalRounds else { return }
        await interactor?.loadExercise(
            LetterTracingModels.LoadExercise.Request(
                targetLetter: activity.soundTarget.uppercased(),
                difficulty: activity.difficulty
            )
        )
    }

    // MARK: - Input hint

    private var inputHintText: String {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return String(localized: "letter_tracing.hint.finger")
        }
        return String(localized: "letter_tracing.hint.pencil")
    }

    // MARK: - PKToolPicker

    private func setupToolPicker() {
        let picker = PKToolPicker()
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        canvas.becomeFirstResponder()
    }

    // MARK: - VIP Setup

    private func setupVIP() {
        let presenterInstance = LetterTracingPresenter()
        let routerInstance = LetterTracingRouter()
        let interactorInstance = LetterTracingInteractor()
        let adapter = LetterTracingViewDisplayAdapter(
            onLoadExercise: { vm in
                exerciseVM = vm
                phase = .drawing
            },
            onSubmitDrawing: { vm in
                feedbackVM = vm
                phase = .feedback
            },
            onResetCanvas: { _ in
                phase = .drawing
            },
            onRequestHint: { vm in
                hintVM = vm
            },
            onCompleteSession: { _ in
                phase = .complete
            }
        )

        interactorInstance.presenter = presenterInstance
        interactorInstance.router = routerInstance
        presenterInstance.display = adapter
        routerInstance.onComplete = { score in
            onComplete(score)
        }

        presenter = presenterInstance
        router = routerInstance
        displayAdapter = adapter
        interactor = interactorInstance
    }
}

// MARK: - LetterTracingViewDisplayAdapter

@MainActor
final class LetterTracingViewDisplayAdapter: LetterTracingDisplayLogic {

    private let onLoadExercise: (LetterTracingModels.LoadExercise.ViewModel) -> Void
    private let onSubmitDrawing: (LetterTracingModels.SubmitDrawing.ViewModel) -> Void
    private let onResetCanvas: (LetterTracingModels.ResetCanvas.ViewModel) -> Void
    private let onRequestHint: (LetterTracingModels.RequestHint.ViewModel) -> Void
    private let onCompleteSession: (LetterTracingModels.CompleteSession.ViewModel) -> Void

    init(
        onLoadExercise: @escaping (LetterTracingModels.LoadExercise.ViewModel) -> Void,
        onSubmitDrawing: @escaping (LetterTracingModels.SubmitDrawing.ViewModel) -> Void,
        onResetCanvas: @escaping (LetterTracingModels.ResetCanvas.ViewModel) -> Void,
        onRequestHint: @escaping (LetterTracingModels.RequestHint.ViewModel) -> Void,
        onCompleteSession: @escaping (LetterTracingModels.CompleteSession.ViewModel) -> Void
    ) {
        self.onLoadExercise = onLoadExercise
        self.onSubmitDrawing = onSubmitDrawing
        self.onResetCanvas = onResetCanvas
        self.onRequestHint = onRequestHint
        self.onCompleteSession = onCompleteSession
    }

    func displayLoadExercise(_ viewModel: LetterTracingModels.LoadExercise.ViewModel) {
        onLoadExercise(viewModel)
    }

    func displaySubmitDrawing(_ viewModel: LetterTracingModels.SubmitDrawing.ViewModel) {
        onSubmitDrawing(viewModel)
    }

    func displayResetCanvas(_ viewModel: LetterTracingModels.ResetCanvas.ViewModel) {
        onResetCanvas(viewModel)
    }

    func displayRequestHint(_ viewModel: LetterTracingModels.RequestHint.ViewModel) {
        onRequestHint(viewModel)
    }

    func displayCompleteSession(_ viewModel: LetterTracingModels.CompleteSession.ViewModel) {
        onCompleteSession(viewModel)
    }
}

// MARK: - LetterTemplateView

/// Отображает большую полупрозрачную букву как guide для обводки.
/// Поведение зависит от уровня:
///   - overTemplate: полупрозрачная буква как guide.
///   - dotsOnly: только точечный контур.
///   - freeWrite: пустой фон (без guide).
struct LetterTemplateView: View {

    let letter: String
    var level: LetterTracingModels.TracingLevel = .overTemplate
    var showFullOverlay: Bool = false

    var body: some View {
        GeometryReader { geo in
            let fontSize = min(geo.size.width, geo.size.height) * 0.82
            ZStack {
                switch level {
                case .overTemplate:
                    Text(letter)
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorTokens.Kid.inkMuted.opacity(0.14))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    Text(letter)
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorTokens.Brand.primaryLo.opacity(0.55))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                case .dotsOnly:
                    // Только контур точками — имитируем через пунктирный stroke.
                    Text(letter)
                        .font(.system(size: fontSize, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(ColorTokens.Kid.inkMuted.opacity(0.10))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                case .freeWrite:
                    // Пустой фон — ребёнок пишет самостоятельно.
                    Color.clear
                }

                // Полный шаблон по запросу подсказки уровня 3.
                if showFullOverlay {
                    Text(letter)
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorTokens.Brand.mint.opacity(0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
