import OSLog
import PencilKit
import SwiftUI
import UIKit

// MARK: - LetterTracingPhase

/// Фазы одного упражнения написания буквы.
enum LetterTracingPhase: Sendable, Equatable {
    /// Загрузка задания.
    case loading
    /// Ребёнок рисует букву.
    case drawing
    /// Показываем результат распознавания.
    case feedback
    /// Все раунды завершены.
    case complete
}

// MARK: - LetterTracingView

/// 18-й шаблон игры — «Напиши букву» (iPad-primary, finger fallback).
///
/// Поток:
///   1. `.loading` → `interactor.loadExercise()` → `.drawing`
///   2. Ребёнок рисует Apple Pencil / пальцем поверх dotted-guide.
///   3. Нажимает «Проверить» → `.feedback` (Vision распознаёт букву).
///   4. «Сбросить» → очищаем canvas, перезапускаем таймер.
///   5. После всех раундов → `onComplete(score)`.
///
/// На iPhone: показываем fallback-заглушку (письмо недоступно на iPhone).
struct LetterTracingView: View {

    // MARK: - Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var interactor: LetterTracingInteractor?
    @State private var presenter: LetterTracingPresenter?
    @State private var router: LetterTracingRouter?
    @State private var displayAdapter: LetterTracingViewDisplayAdapter?

    // MARK: - View state

    @State private var phase: LetterTracingPhase = .loading
    @State private var exerciseVM: LetterTracingModels.LoadExercise.ViewModel?
    @State private var feedbackVM: LetterTracingModels.SubmitDrawing.ViewModel?
    @State private var isProcessing: Bool = false

    // MARK: - Canvas

    @State private var canvas = PKCanvasView()

    // MARK: - Body

    var body: some View {
        Group {
            if LetterTracingInteractor.isAvailable() {
                iPadCanvas
            } else {
                iPhoneFallback
            }
        }
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

    // MARK: - iPad Canvas

    @ViewBuilder
    private var iPadCanvas: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Background
                ColorTokens.Kid.bg.ignoresSafeArea()

                VStack(spacing: SpacingTokens.medium) {
                    // HUD: прогресс + инструкция
                    if let vm = exerciseVM {
                        exerciseHeader(vm: vm)
                            .padding(.horizontal, SpacingTokens.screenEdge)
                    }

                    // Canvas + template
                    ZStack {
                        // 1. Dotted letter template
                        if let vm = exerciseVM {
                            LetterTemplateView(letter: vm.targetLetter)
                                .frame(
                                    width: canvasSize(geo).width,
                                    height: canvasSize(geo).height
                                )
                                .accessibilityHidden(true)
                        }

                        // 2. Drawing canvas поверх template
                        CanvasViewRepresentable(
                            canvas: $canvas,
                            allowsFinger: true
                        )
                        .frame(
                            width: canvasSize(geo).width,
                            height: canvasSize(geo).height
                        )
                        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
                        .accessibilityLabel(
                            String(localized: "letter_tracing.canvas.accessibility_label")
                        )
                        .accessibilityHint(
                            String(localized: "letter_tracing.canvas.accessibility_hint")
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)

                    // Controls
                    controlsRow
                        .padding(.horizontal, SpacingTokens.screenEdge)

                    Spacer(minLength: 0)
                }
                .padding(.top, SpacingTokens.regular)

                // Feedback overlay
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
        }
        .onAppear(perform: setupToolPicker)
    }

    // MARK: - iPhone Fallback

    private var iPhoneFallback: some View {
        VStack(spacing: SpacingTokens.large) {
            HSMascotView(mood: .thinking, size: 120)

            Text(String(localized: "letter_tracing.iphone_fallback.title"))
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            Text(String(localized: "letter_tracing.iphone_fallback.subtitle"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)

            HSButton(
                String(localized: "general.done"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                onComplete(0.8)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
        }
        .padding()
    }

    // MARK: - Sub-views

    private func exerciseHeader(vm: LetterTracingModels.LoadExercise.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.small) {
            HSProgressBar(
                value: Double(vm.roundIndex) / Double(max(vm.totalRounds, 1))
            )
            Text(vm.instructionText)
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
    }

    private var controlsRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            // Сброс
            HSButton(
                String(localized: "letter_tracing.button.reset"),
                style: .secondary,
                icon: "arrow.counterclockwise"
            ) {
                handleReset()
            }
            .accessibilityLabel(String(localized: "letter_tracing.button.reset"))

            // Проверить
            HSButton(
                String(localized: "letter_tracing.button.check"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                Task { await handleCheck() }
            }
            .disabled(isProcessing || canvas.drawing.strokes.isEmpty || phase == .feedback)
            .accessibilityLabel(String(localized: "letter_tracing.button.check"))
        }
    }

    private func feedbackOverlay(vm: LetterTracingModels.SubmitDrawing.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.medium) {
            HSMascotView(mood: vm.isCorrect ? .celebrating : .thinking, size: 100)

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
                String(
                    localized: "letter_tracing.score_percent \(vm.scorePercent)"
                )
            )
            .font(TypographyTokens.headline())
            .foregroundStyle(ColorTokens.Kid.ink)

            HSButton(
                String(localized: "letter_tracing.button.next"),
                style: .primary,
                icon: "arrow.right.circle.fill"
            ) {
                Task { await handleNext() }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(SpacingTokens.xLarge)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.xLarge)
    }

    private var completeOverlay: some View {
        VStack(spacing: SpacingTokens.medium) {
            HSMascotView(mood: .celebrating, size: 120)

            Text(String(localized: "letter_tracing.complete.title"))
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.xLarge)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.xLarge)
    }

    // MARK: - Handlers

    private func handleReset() {
        canvas.drawing = PKDrawing()
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
        canvas.drawing = PKDrawing()

        guard let vm = exerciseVM, vm.roundIndex + 1 < vm.totalRounds else { return }
        await interactor?.loadExercise(
            LetterTracingModels.LoadExercise.Request(
                targetLetter: activity.soundTarget.uppercased(),
                difficulty: activity.difficulty
            )
        )
    }

    // MARK: - Canvas size helper

    private func canvasSize(_ geo: GeometryProxy) -> CGSize {
        let side = min(geo.size.width - SpacingTokens.screenEdge * 2, geo.size.height * 0.55)
        return CGSize(width: side, height: side)
    }

    // MARK: - PKToolPicker

    private func setupToolPicker() {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
        guard let window else { return }
        let picker = PKToolPicker.shared(for: window)
        picker?.setVisible(true, forFirstResponder: canvas)
        picker?.addObserver(canvas)
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

/// Мост между протоколом `LetterTracingDisplayLogic` и SwiftUI-колбэками.
@MainActor
final class LetterTracingViewDisplayAdapter: LetterTracingDisplayLogic {

    private let onLoadExercise: (LetterTracingModels.LoadExercise.ViewModel) -> Void
    private let onSubmitDrawing: (LetterTracingModels.SubmitDrawing.ViewModel) -> Void
    private let onResetCanvas: (LetterTracingModels.ResetCanvas.ViewModel) -> Void
    private let onCompleteSession: (LetterTracingModels.CompleteSession.ViewModel) -> Void

    init(
        onLoadExercise: @escaping (LetterTracingModels.LoadExercise.ViewModel) -> Void,
        onSubmitDrawing: @escaping (LetterTracingModels.SubmitDrawing.ViewModel) -> Void,
        onResetCanvas: @escaping (LetterTracingModels.ResetCanvas.ViewModel) -> Void,
        onCompleteSession: @escaping (LetterTracingModels.CompleteSession.ViewModel) -> Void
    ) {
        self.onLoadExercise = onLoadExercise
        self.onSubmitDrawing = onSubmitDrawing
        self.onResetCanvas = onResetCanvas
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

    func displayCompleteSession(_ viewModel: LetterTracingModels.CompleteSession.ViewModel) {
        onCompleteSession(viewModel)
    }
}

// MARK: - LetterTemplateView

/// Отображает большую полупрозрачную букву как guide для обводки.
/// Шрифт: rounded bold, размером 85% короткой стороны холста.
struct LetterTemplateView: View {

    let letter: String

    var body: some View {
        GeometryReader { geo in
            let fontSize = min(geo.size.width, geo.size.height) * 0.82
            ZStack {
                // Основная буква как guide
                Text(letter)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        ColorTokens.Kid.inkMuted.opacity(0.14)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                // Пунктирная обводка для визуального guide
                Text(letter)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.clear)
                    .overlay(
                        Text(letter)
                            .font(.system(size: fontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                ColorTokens.Brand.sky.opacity(0.22)
                            )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .allowsHitTesting(false)
    }
}
