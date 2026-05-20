import OSLog
import PencilKit
import SwiftUI
import UIKit

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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LetterTrace.View"
    )

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                VStack(spacing: SpacingTokens.sp3) {
                    if let item = holder.currentItem {
                        promptHeader(item)
                        canvasArea(item)
                        feedbackBlock
                        actionButtons(item)
                    } else {
                        loadingState
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp3)
            }
            .navigationTitle(Text("letterTrace.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router?.dismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("letterTrace.close.a11y"))
                }
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .kid)
        .accessibilityIdentifier("LetterTraceRoot")
    }

    // MARK: - Prompt header

    private func promptHeader(
        _ item: LetterTraceModels.Load.ItemViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(item.progressText)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Text(item.promptText)
                .font(TypographyTokens.title(22).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Canvas area

    private func canvasArea(
        _ item: LetterTraceModels.Load.ItemViewModel
    ) -> some View {
        GeometryReader { proxy in
            ZStack {
                // Подложка
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                    )
                // Эталонный контур (faint)
                referenceContourOverlay(
                    item.referenceStrokes,
                    canvasWidth: proxy.size.width,
                    canvasHeight: proxy.size.height
                )
                // PencilKit canvas
                LetterTraceCanvas(
                    canvasView: $canvasView,
                    canvasSize: $canvasSize
                )
                .background(Color.clear)
                .cornerRadius(RadiusTokens.card)
                .accessibilityLabel(Text("letterTrace.canvas.a11y"))
                .accessibilityHint(Text("letterTrace.canvas.hint"))
            }
            .onAppear {
                canvasSize = proxy.size
            }
            .onChange(of: proxy.size) { _, newSize in
                canvasSize = newSize
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 320)
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
                    with: .color(ColorTokens.Brand.sky.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Feedback

    @ViewBuilder
    private var feedbackBlock: some View {
        if let feedback = holder.feedback {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: feedback.bandSymbol)
                    .font(.title2)
                    .foregroundStyle(
                        feedback.isSuccess
                        ? ColorTokens.Brand.mint
                        : ColorTokens.Brand.rose
                    )
                    .accessibilityHidden(true)
                Text(feedback.feedbackText)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(
                        feedback.isSuccess
                        ? ColorTokens.Brand.mint.opacity(0.12)
                        : ColorTokens.Brand.rose.opacity(0.10)
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(feedback.feedbackText))
        } else if !isPad {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "pencil.tip")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .accessibilityHidden(true)
                Text("letterTrace.toolPicker.notAvailable")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
            }
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp2)
        }
    }

    // MARK: - Action buttons

    private func actionButtons(
        _ item: LetterTraceModels.Load.ItemViewModel
    ) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Button {
                clearCanvas()
            } label: {
                Label {
                    Text("letterTrace.button.clear")
                        .font(TypographyTokens.headline(16))
                } icon: {
                    Image(systemName: "eraser.fill")
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(ColorTokens.Kid.ink)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Kid.surface)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("letterTrace.clearButton")

            Button {
                check(item)
            } label: {
                Label {
                    Text("letterTrace.button.check")
                        .font(TypographyTokens.headline(16))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(Color.white)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("letterTrace.checkButton")

            Button {
                next(item)
            } label: {
                Label {
                    Text("letterTrace.button.next")
                        .font(TypographyTokens.headline(16))
                } icon: {
                    Image(systemName: "arrow.right.circle.fill")
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(ColorTokens.Kid.ink)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.mint.opacity(0.18))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("letterTrace.nextButton")
        }
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
            self.router = LetterTraceRouter(dismissAction: { dismiss() })
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
