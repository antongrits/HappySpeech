import OSLog
import SwiftUI

// MARK: - KaraokePitchViewModelHolder

@MainActor
@Observable
final class KaraokePitchViewModelHolder: KaraokePitchDisplayLogic {

    var startVM: KaraokePitchModels.Start.ViewModel?
    var liveVM: KaraokePitchModels.LiveSample.ViewModel?
    var scoreVM: KaraokePitchModels.Score.ViewModel?
    var phase: Phase = .idle

    enum Phase: Equatable {
        case idle
        case ready
        case recording
        case scored
    }

    func displayStart(viewModel: KaraokePitchModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.liveVM = nil
        self.scoreVM = nil
        self.phase = .ready
    }

    func displayLiveSample(viewModel: KaraokePitchModels.LiveSample.ViewModel) async {
        self.liveVM = viewModel
        if self.phase == .ready { self.phase = .recording }
    }

    func displayScore(viewModel: KaraokePitchModels.Score.ViewModel) async {
        self.scoreVM = viewModel
        self.phase = .scored
    }
}

// MARK: - KaraokePitchView (Clean Swift View)
//
// v31 Wave E Ф.1 — Karaoke с pitch-контуром в реальном времени.
//
// Поведение:
//   • Top: фраза + символ интонации;
//   • Middle: Canvas с двумя SwiftUI Path линиями — эталон + live;
//   • Bottom: кнопка «Запиши» (нажата → recording → отпустить → score);
//   • При Reduce Motion live-линия отрисовывается ТОЛЬКО после остановки
//     записи (статическое сравнение, без анимации).
//
// Accessibility:
//   • Все элементы с VoiceOver-метками;
//   • Минимальная высота кнопки 64pt (Kid-circuit ≥ 56pt);
//   • Dynamic Type через TypographyTokens + minimumScaleFactor;
//   • Light + Dark через ColorTokens.

struct KaraokePitchView: View {

    let childId: String

    @State private var holder = KaraokePitchViewModelHolder()
    @State private var interactor: KaraokePitchInteractor?
    @State private var presenter: KaraokePitchPresenter?
    @State private var router: KaraokePitchRouter?
    @State private var didBootstrap = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "Karaoke.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                VStack(spacing: SpacingTokens.sp4) {
                    headerSection
                    contourSection
                    controlsSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
            }
            .navigationTitle(Text("karaoke.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            if let phrase = holder.startVM {
                Text(phrase.phraseText)
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel(Text(phrase.accessibilityLabel))
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: phrase.intonationSymbol)
                        .font(.title3)
                        .foregroundStyle(ColorTokens.Brand.lilac)
                    Text("karaoke.progress \(phrase.currentIndex + 1) \(phrase.totalPhrases)")
                        .font(TypographyTokens.caption(13).monospacedDigit())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .accessibilityElement(children: .combine)
            } else {
                ProgressView().padding()
            }
        }
        .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Contour Canvas

    private var contourSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            legendRow
            Canvas(opaque: false) { ctx, size in
                drawGrid(ctx: ctx, size: size)
                if let modelContour = holder.startVM?.modelContour {
                    drawContour(modelContour,
                                in: ctx,
                                size: size,
                                color: ColorTokens.Brand.lilac,
                                isModel: true)
                }
                // Reduce Motion: live-линия только когда есть score.
                let shouldShowLive: Bool = {
                    if reduceMotion {
                        return holder.phase == .scored
                    }
                    return holder.phase == .recording || holder.phase == .scored
                }()
                if shouldShowLive {
                    let live: [PitchPoint] = holder.scoreVM?.liveContour
                        ?? holder.liveVM?.liveContour ?? []
                    if !live.isEmpty {
                        drawContour(live,
                                    in: ctx,
                                    size: size,
                                    color: ColorTokens.Brand.primary,
                                    isModel: false)
                    }
                }
            }
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
            )
            .accessibilityElement()
            .accessibilityLabel(canvasAccessibilityLabel)
            if let scoreVM = holder.scoreVM {
                scoreSection(scoreVM)
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: SpacingTokens.sp3) {
            legendDot(color: ColorTokens.Brand.lilac, key: "karaoke.legend.model")
            legendDot(color: ColorTokens.Brand.primary, key: "karaoke.legend.you")
            Spacer()
        }
        .accessibilityHidden(true)
    }

    private func legendDot(color: Color, key: LocalizedStringResource) -> some View {
        HStack(spacing: SpacingTokens.sp1) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(key)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsSection: some View {
        switch holder.phase {
        case .idle:
            ProgressView().padding()
        case .ready, .recording:
            recordButton
        case .scored:
            HStack(spacing: SpacingTokens.sp3) {
                tryAgainButton
                nextButton
            }
        }
    }

    private var recordButton: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: holder.phase == .recording
                                   ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title)
                Text(holder.phase == .recording
                     ? "karaoke.button.stop"
                     : "karaoke.button.record")
                    .font(TypographyTokens.headline(18))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(holder.phase == .recording
                          ? ColorTokens.Semantic.error
                          : ColorTokens.Brand.primary)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(holder.phase == .recording
                            ? Text("karaoke.button.stop.a11y")
                            : Text("karaoke.button.record.a11y"))
    }

    private var tryAgainButton: some View {
        Button {
            Task { await retryCurrentPhrase() }
        } label: {
            Text("karaoke.button.retry")
                .font(TypographyTokens.headline(17))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(ColorTokens.Kid.ink)
        .accessibilityLabel(Text("karaoke.button.retry.a11y"))
    }

    private var nextButton: some View {
        Button {
            Task { await goNext() }
        } label: {
            Text("karaoke.button.next")
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
        .accessibilityLabel(Text("karaoke.button.next.a11y"))
    }

    // MARK: - Score Section

    private func scoreSection(_ score: KaraokePitchModels.Score.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < score.starsEarned
                                  ? "star.fill" : "star")
                    .foregroundStyle(idx < score.starsEarned
                                     ? ColorTokens.Brand.gold
                                     : ColorTokens.Kid.inkSoft)
                    .font(.title2)
            }
            Spacer()
            Text("karaoke.score.percent \(score.similarityPercent)")
                .font(TypographyTokens.headline(15).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.ink)
        }
        .padding(.horizontal, SpacingTokens.sp1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(score.accessibilityLabel))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { dismissTapped() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text("karaoke.close.a11y"))
        }
    }

    // MARK: - Canvas Drawing

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        let rowCount = 4
        for i in 0...rowCount {
            let y = size.height * CGFloat(i) / CGFloat(rowCount)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(path,
                   with: .color(ColorTokens.Kid.line.opacity(0.25)),
                   lineWidth: 1)
    }

    private func drawContour(
        _ points: [PitchPoint],
        in ctx: GraphicsContext,
        size: CGSize,
        color: Color,
        isModel: Bool
    ) {
        let minF: Double = 80
        let maxF: Double = 500
        var path = Path()
        var didStart = false
        for point in points {
            guard let f = point.frequencyHz, f >= minF, f <= maxF else {
                didStart = false
                continue
            }
            let x = size.width * CGFloat(point.time)
            // Y инвертирован: высокая частота сверху.
            let normalised = (f - minF) / (maxF - minF)
            let y = size.height * (1.0 - CGFloat(normalised))
            if !didStart {
                path.move(to: CGPoint(x: x, y: y))
                didStart = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        let style = StrokeStyle(
            lineWidth: isModel ? 3 : 4,
            lineCap: .round,
            lineJoin: .round,
            dash: isModel ? [6, 4] : []
        )
        ctx.stroke(path, with: .color(color), style: style)
    }

    private var canvasAccessibilityLabel: Text {
        if let score = holder.scoreVM {
            return Text(score.accessibilityLabel)
        }
        return Text("karaoke.canvas.a11y")
    }

    // MARK: - Bootstrap & Actions

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = KaraokePitchPresenter(displayLogic: holder)
        let interactor = KaraokePitchInteractor(presenter: presenter)
        let router = KaraokePitchRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.startSession()
    }

    private func toggleRecording() async {
        guard let interactor else { return }
        if holder.phase == .recording {
            await interactor.stopRecording()
        } else {
            await interactor.startRecording()
        }
    }

    private func retryCurrentPhrase() async {
        // Просто перезаписываем — ту же фразу.
        holder.scoreVM = nil
        holder.liveVM = nil
        holder.phase = .ready
    }

    private func goNext() async {
        guard let interactor else { return }
        let hasMore = await interactor.advanceToNext()
        if !hasMore { dismissTapped() }
    }

    private func dismissTapped() {
        Task { await interactor?.stopRecording() }
        dismiss()
    }
}

// MARK: - Preview

#Preview("Karaoke — Light") {
    KaraokePitchView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("Karaoke — Dark") {
    KaraokePitchView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
