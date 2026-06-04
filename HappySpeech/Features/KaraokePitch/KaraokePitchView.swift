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

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "Karaoke.View"
    )

    @State private var showConfetti: Bool = false
    @State private var mascotState: LyalyaState = .thinking
    @State private var cardAppeared: Bool = false

    // Snapshot-only: при `true` `bootstrap()` пропускается, чтобы
    // предзаготовленный holder (фраза + modelContour) не перетёрся async-загрузкой
    // и снимок ловил settled-кадр (фраза + pitch-Canvas), а не `ProgressView`.
    private let skipBootstrapForSnapshot: Bool

    init(childId: String) {
        self.childId = childId
        self.skipBootstrapForSnapshot = false
    }

    #if DEBUG
    /// Preview/snapshot-only init: инжектит уже-загруженный holder (фраза +
    /// эталонный контур + фаза `.ready`), показывает контент сразу
    /// (`cardAppeared = true`, без entrance-fade) и отключает async-bootstrap.
    /// Прод-путь (`init(childId:)`) не затрагивается.
    init(childId: String, previewState holder: KaraokePitchViewModelHolder) {
        self.childId = childId
        self._holder = State(initialValue: holder)
        self._cardAppeared = State(initialValue: true)
        self.skipBootstrapForSnapshot = true
    }
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                // Step 10 Batch E — Pattern 1: mesh .kidCool палитра для
                // музыкально-ритмического pitch-режима (прохладный resonance).
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidCool, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                VStack(spacing: SpacingTokens.sp4) {
                    mascotRow
                    headerSection
                    contourSection
                    controlsSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
                .opacity(cardAppeared ? 1 : 0)
                .scaleEffect(cardAppeared ? 1 : 0.94)
                .animation(reduceMotion ? .none : MotionTokens.settleSpring, value: cardAppeared)

                // Конфетти при победе
                HSConfettiView(preset: .celebration, isActive: $showConfetti)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .navigationTitle(Text("karaoke.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .onAppear {
                withAnimation(reduceMotion ? .none : MotionTokens.settleSpring) {
                    cardAppeared = true
                }
            }
            .onChange(of: holder.phase) { _, phase in
                switch phase {
                case .recording:
                    mascotState = .singing
                case .scored:
                    let gotScore = (holder.scoreVM?.starsEarned ?? 0) > 0
                    mascotState = gotScore ? .celebrating : .encouraging
                    if gotScore && !showConfetti {
                        showConfetti = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            showConfetti = false
                        }
                    }
                default:
                    mascotState = .thinking
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Mascot

    private var mascotRow: some View {
        HStack {
            Spacer()
            LyalyaMascotView(state: mascotState, size: 100)
                .animation(reduceMotion ? .none : MotionTokens.spring, value: mascotState)
                .accessibilityHidden(true)
            Spacer()
        }
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
                        // Step 10 Batch E — Pattern 5: intonation icon
                        // pulse при смене фразы.
                        .hsSymbolEffect(.pulse, value: phrase.currentIndex)
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
        // Step 10 Batch E — Pattern 2: contour hero на HSLiquidGlassCard(.elevated).
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.cardPad) {
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
                    RoundedRectangle(
                        cornerRadius: RadiusTokens.concentric(
                            outer: RadiusTokens.card,
                            inset: SpacingTokens.cardPad
                        )
                    )
                    .fill(ColorTokens.Kid.surfaceAlt)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: RadiusTokens.concentric(
                            outer: RadiusTokens.card,
                            inset: SpacingTokens.cardPad
                        )
                    )
                )
                .accessibilityElement()
                .accessibilityLabel(canvasAccessibilityLabel)

                if let scoreVM = holder.scoreVM {
                    scoreSection(scoreVM)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(reduceMotion ? .none : MotionTokens.rewardPop, value: holder.scoreVM != nil)
                }
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
                    // Step 10 Batch E — Pattern 5: mic/stop icon bounce
                    // при изменении фазы record/stop.
                    .hsSymbolEffect(.bounce, value: holder.phase)
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

    @State private var starsAnimated: [Bool] = [false, false, false]

    private func scoreSection(_ score: KaraokePitchModels.Score.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: idx < score.starsEarned ? "star.fill" : "star")
                        .foregroundStyle(idx < score.starsEarned
                                         ? ColorTokens.Brand.gold
                                         : ColorTokens.Kid.inkSoft)
                        .font(.title)
                        .scaleEffect(starsAnimated[safe: idx] == true ? 1.0 : 0.5)
                        .opacity(starsAnimated[safe: idx] == true ? 1.0 : 0.0)
                        .animation(
                            reduceMotion ? .none : MotionTokens.rewardPop.delay(Double(idx) * 0.12),
                            value: starsAnimated[safe: idx]
                        )
                }
            }
            .onAppear {
                guard !reduceMotion else {
                    starsAnimated = [true, true, true]
                    return
                }
                for idx in 0..<3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.15) {
                        starsAnimated[safe: idx] = true
                    }
                }
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
        #if DEBUG
        if skipBootstrapForSnapshot { return }
        #endif
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
        exitGame()
    }
}

// MARK: - Array safe subscript (local)

private extension Array where Element == Bool {
    subscript(safe index: Int) -> Bool {
        get { indices.contains(index) ? self[index] : false }
        set { if indices.contains(index) { self[index] = newValue } }
    }
}

// MARK: - Preview

#if DEBUG
// MARK: Preview data

private extension KaraokePitchViewModelHolder {
    /// Статичные данные для Preview/snapshot: загруженная фраза + эталонный
    /// pitch-контур, фаза `.ready` — settled-кадр Canvas.
    /// Используется `init(childId:previewState:)` — спиннер не отображается.
    static func previewReady() -> KaraokePitchViewModelHolder {
        let holder = KaraokePitchViewModelHolder()
        let phrase = KaraokePhrase(
            id: "kr-preview-1",
            text: "Какой красивый день!",
            intonation: "exclamation",
            intonationSymbol: "exclamationmark.circle"
        )
        holder.startVM = KaraokePitchModels.Start.ViewModel(
            phraseText: phrase.text,
            intonationSymbol: phrase.intonationSymbol,
            modelContour: KaraokePitchCorpus.modelContour(for: phrase),
            totalPhrases: 20,
            currentIndex: 0,
            accessibilityLabel: "Фраза: \(phrase.text). Восклицание."
        )
        holder.phase = .ready
        return holder
    }

    /// Scored state: показывает три звезды и секцию с результатом.
    static func previewScored() -> KaraokePitchViewModelHolder {
        let holder = previewReady()
        let phrase = KaraokePhrase(
            id: "kr-preview-1",
            text: "Какой красивый день!",
            intonation: "exclamation",
            intonationSymbol: "exclamationmark.circle"
        )
        holder.scoreVM = KaraokePitchModels.Score.ViewModel(
            phraseText: phrase.text,
            similarityPercent: 87,
            starsEarned: 3,
            feedbackMessage: "Отлично! Ты попал в мелодику фразы!",
            modelContour: KaraokePitchCorpus.modelContour(for: phrase),
            liveContour: KaraokePitchCorpus.modelContour(for: phrase),
            accessibilityLabel: "Результат: 87%, три звезды"
        )
        holder.phase = .scored
        return holder
    }
}

#Preview("Karaoke — Ready (Light)") {
    KaraokePitchView(childId: "preview-child-1",
                     previewState: .previewReady())
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("Karaoke — Ready (Dark)") {
    KaraokePitchView(childId: "preview-child-1",
                     previewState: .previewReady())
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

#Preview("Karaoke — Scored") {
    KaraokePitchView(childId: "preview-child-1",
                     previewState: .previewScored())
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
#endif
