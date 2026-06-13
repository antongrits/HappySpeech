import PencilKit
import SwiftUI

// MARK: - LetterTraceViewModelHolder

@MainActor
@Observable
final class LetterTraceViewModelHolder: LetterTraceDisplayLogic {

    var totalCount: Int = 0
    var currentItem: LetterTraceModels.Load.ItemViewModel?
    var feedback: LetterTraceModels.Score.ViewModel?

    func displayLoad(viewModel: LetterTraceModels.Load.ViewModel) async {
        totalCount = viewModel.totalCount
        currentItem = viewModel.firstItem
        feedback = nil
    }

    func displayAdvance(viewModel: LetterTraceModels.Advance.ViewModel) async {
        currentItem = viewModel.item
        feedback = nil
    }

    func displayScore(viewModel: LetterTraceModels.Score.ViewModel) async {
        feedback = viewModel
    }
}

// MARK: - LetterTraceView (Clean Swift: View)
//
// v31 Волна C Ф.2 «Пиши пальчиком/пером».
//
// Кид-фича: PencilKit canvas с эталонным контуром буквы. Дет учится
// обводить буквы из русского алфавита (33) и проблемные слоги (10).
// Apple Pencil — если есть, палец — иначе. Финальный score 0–100%
// возвращается через простую Hausdorff-подобную метрику.
//
// Accessibility:
//   • VoiceOver: PencilKit canvas помечен hint + label
//   • Dynamic Type: ScrollView + lineLimit(nil), .accessibilityLargeText
//   • Reduced Motion: эталонный контур — статика
//   • Touch targets: кнопки 56pt high
//   • Light + Dark: ColorTokens.Kid

struct LetterTraceView: View {

    let childId: String

    @State private var holder = LetterTraceViewModelHolder()
    @State private var interactor: LetterTraceInteractor?
    @State private var presenter: LetterTracePresenter?
    @State private var router: LetterTraceRouter?
    @State private var canvasView = PKCanvasView()
    @State private var canvasSize: CGSize = .zero

    @Environment(\.exitGame) private var exitGame
    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
            if let item = holder.currentItem {
                KidGameCanvasScaffold(
                    title: Text(item.promptText),
                    subtitle: item.progressText,
                    palette: .kidWarm,
                    onExit: { exitGame() }
                ) {
                    canvasContent(item)
                } toolbar: {
                    KidGameToolButton(
                        systemImage: "eraser.fill",
                        label: String(localized: "letterTrace.button.clear"),
                        accessibilityID: "letterTrace.clearButton"
                    ) {
                        clearCanvas()
                    }
                    KidGameToolButton(
                        systemImage: "arrow.right",
                        label: String(localized: "letterTrace.button.next"),
                        isMuted: true,
                        accessibilityID: "letterTrace.nextButton"
                    ) {
                        next(item)
                    }
                    KidGameCTAButton(
                        title: String(localized: "letterTrace.button.check"),
                        systemImage: "checkmark",
                        accessibilityID: "letterTrace.checkButton"
                    ) {
                        check(item)
                    }
                }
            } else {
                ZStack {
                    KidGameCanvasBackground(palette: .kidWarm)
                    loadingState
                }
            }
        }
        .task { await setupAndLoad() }
        .environment(\.circuitContext, .kid)
        .accessibilityIdentifier("LetterTraceRoot")
    }

    // MARK: - Canvas content (внутри холста)

    private func canvasContent(
        _ item: LetterTraceModels.Load.ItemViewModel
    ) -> some View {
        GeometryReader { proxy in
            ZStack {
                // Эталонный контур (faint guide).
                referenceContourOverlay(
                    item.referenceStrokes,
                    canvasWidth: proxy.size.width,
                    canvasHeight: proxy.size.height
                )
                // PencilKit canvas.
                LetterTraceCanvas(
                    canvasView: $canvasView,
                    canvasSize: $canvasSize
                )
                .background(Color.clear)
                .accessibilityLabel(Text("letterTrace.canvas.a11y"))
                .accessibilityHint(Text("letterTrace.canvas.hint"))

                // Фидбэк-плашка / маскот снизу холста.
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        canvasFeedback
                        Spacer(minLength: 0)
                    }
                }
                .padding(SpacingTokens.small)
                .allowsHitTesting(false)
            }
            .onAppear { canvasSize = proxy.size }
            .onChange(of: proxy.size) { _, newSize in canvasSize = newSize }
        }
    }

    @ViewBuilder
    private var canvasFeedback: some View {
        if let feedback = holder.feedback {
            KidGameMascotBubble(
                message: feedback.feedbackText,
                state: feedback.isSuccess ? .celebrating : .encouraging
            )
        } else {
            KidGameMascotBubble(
                message: String(localized: "letterTrace.canvas.hint"),
                state: .pointing
            )
        }
    }

    private func referenceContourOverlay(
        _ strokes: [[TracePoint]],
        canvasWidth: CGFloat,
        canvasHeight: CGFloat
    ) -> some View {
        Canvas { context, _ in
            for stroke in strokes {
                guard stroke.count > 1 else { continue }
                var path = Path()
                let first = stroke[0]
                path.move(to: CGPoint(
                    x: CGFloat(first.x) * canvasWidth,
                    y: CGFloat(first.y) * canvasHeight
                ))
                for point in stroke.dropFirst() {
                    path.addLine(to: CGPoint(
                        x: CGFloat(point.x) * canvasWidth,
                        y: CGFloat(point.y) * canvasHeight
                    ))
                }
                context.stroke(
                    path,
                    with: .color(ColorTokens.Brand.primaryLo.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
                .tint(ColorTokens.Brand.primary)
            Text("letterTrace.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        holder.feedback = nil
    }

    private func check(_ item: LetterTraceModels.Load.ItemViewModel) {
        let strokes = LetterTraceCanvasExtractor.normalizedStrokes(
            from: canvasView.drawing,
            canvasSize: canvasSize
        )
        if strokes.allSatisfy(\.isEmpty) {
            holder.feedback = .init(
                feedbackText: String(localized: "letterTrace.feedback.empty"),
                bandSymbol: "exclamationmark.circle.fill",
                isSuccess: false,
                percent: 0
            )
            return
        }
        Task {
            await interactor?.score(
                request: .init(itemId: item.id, userStrokes: strokes)
            )
        }
    }

    private func next(_ item: LetterTraceModels.Load.ItemViewModel) {
        canvasView.drawing = PKDrawing()
        Task {
            await interactor?.advance(request: .init(currentItemId: item.id))
        }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = LetterTracePresenter(displayLogic: holder)
            let worker = LiveLetterTraceWorker()
            let interactor = LetterTraceInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = LetterTraceRouter(dismissAction: { exitGame() })
        }
        await interactor?.load(request: .init(childId: childId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("LetterTrace / kid") {
    LetterTraceView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
