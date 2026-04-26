import OSLog
import SwiftUI

// MARK: - SessionCompleteView
//
// Финальный экран сессии (kid-контур). 4-фазный reveal с задержками:
//   .mascot   — маскот появляется (scale 0→1, spring) [0.0–0.5s]
//   .score    — count-up accuracy (0→N%)              [0.5–1.2s]
//   .stars    — 3 звезды последовательно              [1.2–2.0s]
//   .summary  — карточки stat + preview след. урока   [2.0–2.5s]
//
// CTA: "Играть ещё" (secondary) + "Продолжить" (primary).
// Сигнатура `init(result:onContinue:onReplay:)` сохранена для AppCoordinator.

struct SessionCompleteView: View {

    // MARK: - Inputs

    let result: SessionResult
    let onContinue: () -> Void
    let onReplay: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP State

    @State private var display = SessionCompleteDisplay()
    @State private var interactor: SessionCompleteInteractor?
    @State private var presenter: SessionCompletePresenter?
    @State private var router: SessionCompleteRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI

    @State private var animatedScore: Int = 0
    @State private var ringFraction: Double = 0
    @State private var sharePresented = false
    @State private var shareText: String = ""
    @State private var celebrationVisible = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionCompleteView")

    // Минимальный порог для показа CelebrationOverlay (точность ≥ 80%).
    private static let celebrationThreshold: Float = 0.80

    // MARK: - Init

    init(
        result: SessionResult,
        onContinue: @escaping () -> Void,
        onReplay: @escaping () -> Void
    ) {
        self.result = result
        self.onContinue = onContinue
        self.onReplay = onReplay
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background: gradient + glass overlay (iOS 26) / plain bg (iOS <26)
            backgroundLayer.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.xLarge) {
                    mascotPhase
                    scorePhase
                    starsPhase
                    summaryPhase
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.xLarge)
                .padding(.bottom, 220)
                .frame(maxWidth: .infinity)
            }

            actionButtons
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.large)
                .background(
                    LinearGradient(
                        colors: [ColorTokens.Kid.bg.opacity(0), ColorTokens.Kid.bg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )

            if let toast = display.toastMessage {
                HSToast(toast, type: .error)
                    .padding(.bottom, 180)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            display.clearToast()
                        }
                    }
            }

            // Праздничный overlay при accuracy ≥ 80%.
            if celebrationVisible {
                CelebrationOverlayView(stars: max(1, result.starsEarned)) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        celebrationVisible = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
                .accessibilityAddTraits(.isModal)
            }
        }
        .navigationBarBackButtonHidden()
        .environment(\.circuitContext, .kid)
        .accessibilityElement(children: .contain)
        .task { await bootstrap() }
        .sheet(isPresented: $sharePresented) {
            SessionCompleteShareSheet(text: shareText)
        }
        .onChange(of: display.pendingShareText) { _, text in
            guard let text else { return }
            shareText = text
            sharePresented = true
            display.consumeShare()
        }
        .onChange(of: display.pendingPlayAgain) { _, value in
            guard value else { return }
            display.consumePlayAgain()
            onReplay()
        }
        .onChange(of: display.pendingProceed) { _, value in
            guard value else { return }
            display.consumeProceed()
            onContinue()
        }
        .onChange(of: display.scoreInt) { _, target in
            animateScoreCountUp(to: target)
        }
    }

    // MARK: - Phases

    @ViewBuilder
    private var mascotPhase: some View {
        let visible = display.isPhaseVisible(.mascot)
        VStack(spacing: SpacingTokens.medium) {
            LyalyaMascotView(state: lyalyaResultState, size: 140)
                .scaleEffect(visible ? 1 : 0.2)
                .opacity(visible ? 1 : 0)
                .accessibilityHidden(true)

            Text(display.mascotTagline)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .opacity(visible ? 1 : 0)
                .padding(.horizontal, SpacingTokens.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.mascotTagline)
    }

    /// Маппинг результата сессии → состояние маскота.
    /// ≥80%: празднует, 50–79%: машет, <50%: подбадривает.
    private var lyalyaResultState: LyalyaState {
        switch result.score {
        case 0.80...:    return .celebrating
        case 0.50..<0.80: return .waving
        default:          return .encouraging
        }
    }

    @ViewBuilder
    private var scorePhase: some View {
        let visible = display.isPhaseVisible(.score)
        ZStack {
            // Track ring
            Circle()
                .stroke(ColorTokens.Kid.surfaceAlt, style: StrokeStyle(lineWidth: 14, lineCap: .round))

            // Animated progress ring (count-up via ringFraction)
            Circle()
                .trim(from: 0, to: ringFraction)
                .stroke(
                    scoreColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: scoreColor.opacity(0.35), radius: 8, x: 0, y: 0)

            VStack(spacing: SpacingTokens.micro) {
                Text("\(animatedScore)%")
                    .font(TypographyTokens.kidDisplay(48))
                    .foregroundStyle(scoreColor)
                    .monospacedDigit()
                    .accessibilityHidden(true)

                Text(String(localized: "sessionComplete.accuracy"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.lowercase)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 180, height: 180)
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.85)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "sessionComplete.summaryRing.a11y"), animatedScore)
        )
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var starsPhase: some View {
        let visible = display.isPhaseVisible(.stars)
        HStack(spacing: SpacingTokens.medium) {
            ForEach(0..<display.starsTotal, id: \.self) { index in
                let earned = index < display.starsEarned
                Image(systemName: earned ? "star.fill" : "star")
                    .font(TypographyTokens.display(44).weight(.semibold))
                    .foregroundStyle(earned ? ColorTokens.Brand.gold : ColorTokens.Kid.line)
                    .scaleEffect(visible ? 1 : 0.2)
                    .opacity(visible ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : MotionTokens.bounce.delay(Double(index) * 0.18),
                        value: visible
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "sessionComplete.a11y.stars"),
                display.starsEarned,
                display.starsTotal
            )
        )
    }

    @ViewBuilder
    private var summaryPhase: some View {
        let visible = display.isPhaseVisible(.summary)
        VStack(spacing: SpacingTokens.medium) {
            // Staggered row 1
            HStack(spacing: SpacingTokens.medium) {
                statCard(
                    icon: "music.note.list",
                    title: display.gameTitle,
                    caption: String(localized: "sessionComplete.summary.gameCaption")
                )
                .modifier(StaggeredAppear(visible: visible, index: 0, reduceMotion: reduceMotion))

                statCard(
                    icon: "speaker.wave.2.fill",
                    title: display.soundLabel,
                    caption: String(localized: "sessionComplete.summary.soundCaption")
                )
                .modifier(StaggeredAppear(visible: visible, index: 1, reduceMotion: reduceMotion))
            }
            // Staggered row 2
            HStack(spacing: SpacingTokens.medium) {
                statCard(
                    icon: "checkmark.seal.fill",
                    title: display.attemptsLabel,
                    caption: String(localized: "sessionComplete.summary.attemptsCaption")
                )
                .modifier(StaggeredAppear(visible: visible, index: 2, reduceMotion: reduceMotion))

                statCard(
                    icon: "clock.fill",
                    title: display.durationLabel,
                    caption: String(localized: "sessionComplete.summary.durationCaption")
                )
                .modifier(StaggeredAppear(visible: visible, index: 3, reduceMotion: reduceMotion))
            }
            if let next = display.nextLessonTitle {
                nextLessonCard(title: next)
                    .modifier(StaggeredAppear(visible: visible, index: 4, reduceMotion: reduceMotion))
            }
        }
    }

    private func statCard(icon: String, title: String, caption: String) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.medium) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: icon)
                        .font(TypographyTokens.caption(14).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                    Text(caption)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .textCase(.uppercase)
                        .tracking(0.4)
                }
                Text(title)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(title)")
    }

    private func nextLessonCard(title: String) -> some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.lilac), padding: SpacingTokens.medium) {
            HStack(spacing: SpacingTokens.medium) {
                Image(systemName: "sparkles")
                    .font(TypographyTokens.title(22).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "sessionComplete.nextLesson.label"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(title)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: SpacingTokens.small) {
            HSButton(
                String(localized: "sessionComplete.cta.continue"),
                style: .primary,
                icon: "arrow.right.circle.fill"
            ) {
                interactor?.proceedToNext(.init())
            }

            HStack(spacing: SpacingTokens.small) {
                HSButton(
                    String(localized: "sessionComplete.cta.playAgain"),
                    style: .secondary,
                    size: .medium,
                    icon: "arrow.counterclockwise"
                ) {
                    interactor?.playAgain(.init())
                }
                HSButton(
                    String(localized: "sessionComplete.cta.share"),
                    style: .ghost,
                    size: .medium,
                    icon: "square.and.arrow.up"
                ) {
                    interactor?.shareResult(.init())
                }
            }
        }
        .opacity(display.isPhaseVisible(.summary) ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: display.currentPhase)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        let gradient = LinearGradient(
            colors: [ColorTokens.Kid.bg, ColorTokens.Brand.lilac.opacity(0.18)],
            startPoint: .top,
            endPoint: .bottom
        )
        if #available(iOS 26.0, *) {
            gradient
                .overlay(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.35)
                )
        } else {
            ColorTokens.Kid.bg
        }
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        switch result.score {
        case 0.9...:    return ColorTokens.Feedback.excellent
        case 0.7..<0.9: return ColorTokens.Feedback.correct
        case 0.5..<0.7: return ColorTokens.Brand.butter
        default:        return ColorTokens.Feedback.incorrect
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let presenter = SessionCompletePresenter()
        presenter.display = display
        let interactor = SessionCompleteInteractor()
        interactor.presenter = presenter
        let router = SessionCompleteRouter()
        router.onContinue = onContinue
        router.onReplay = onReplay
        router.onDismiss = { dismiss() }

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        interactor.loadResult(.init(result: result))

        await runPhaseSchedule()
    }

    private func runPhaseSchedule() async {
        guard let interactor else { return }
        let useReducedMotion = reduceMotion

        // Phase delays (in seconds). Reduced-motion: stack instantly to .summary.
        let plan: [(SessionCompletePhase, Double)] = useReducedMotion
            ? [(.score, 0), (.stars, 0), (.summary, 0)]
            : [(.score, 0.50), (.stars, 0.70), (.summary, 0.80)]

        for (phase, delay) in plan {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            withAnimation(useReducedMotion ? nil : MotionTokens.spring) {
                interactor.advancePhase(.init(to: phase))
            }
        }

        // После всех фаз — показываем праздничный overlay при высокой точности.
        if result.score >= Self.celebrationThreshold {
            try? await Task.sleep(for: .seconds(useReducedMotion ? 0.1 : 0.6))
            withAnimation(useReducedMotion ? nil : .easeIn(duration: 0.35)) {
                celebrationVisible = true
            }
        }
    }

    private func animateScoreCountUp(to target: Int) {
        guard target > 0 else {
            animatedScore = 0
            ringFraction = 0
            return
        }
        let targetFraction = Double(target) / 100.0
        if reduceMotion {
            animatedScore = target
            ringFraction = targetFraction
            return
        }
        // Параллельно: tween дуги кольца (1.1s) + count-up счётчика.
        withAnimation(.easeOut(duration: 1.1)) {
            ringFraction = targetFraction
        }
        let steps = max(8, target / 4)
        let stepDelay: UInt64 = 22_000_000  // 22 ms per step
        Task { @MainActor in
            for i in 1...steps {
                let value = Int(Double(target) * Double(i) / Double(steps))
                animatedScore = value
                try? await Task.sleep(nanoseconds: stepDelay)
            }
            animatedScore = target
        }
    }
}

// MARK: - StaggeredAppear

/// Появление с задержкой 0.10s × index. Reduced-motion: мгновенное появление.
private struct StaggeredAppear: ViewModifier {
    let visible: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.45, dampingFraction: 0.78)
                        .delay(Double(index) * 0.10),
                value: visible
            )
    }
}

// MARK: - Share Sheet

private struct SessionCompleteShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("SessionComplete — Excellent") {
    SessionCompleteView(
        result: .sample,
        onContinue: {},
        onReplay: {}
    )
}

#Preview("SessionComplete — Encouraging") {
    SessionCompleteView(
        result: SessionResult(
            score: 0.42,
            starsEarned: 1,
            gameTitle: "Свистящие S",
            soundTarget: "С",
            attempts: 8,
            durationSec: 360,
            nextLessonTitle: nil
        ),
        onContinue: {},
        onReplay: {}
    )
}
