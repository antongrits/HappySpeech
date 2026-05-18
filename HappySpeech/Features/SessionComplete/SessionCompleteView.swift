import OSLog
import Particles
import SwiftUI

// MARK: - SessionCompleteView
//
// Финальный экран сессии (kid-контур). 7-стадийный reward reveal с задержками:
//   .celebration  — Ляля появляется (scale 0→1, spring)    [0.0–0.5s]
//   .scoreReveal  — count-up score (0→N)                    [0.5–1.2s]
//   .stars        — 3 звезды последовательно                [1.2–2.0s]
//   .achievement  — разблокированные достижения              [2.0–2.8s]
//   .sticker      — новая наклейка с flip animation          [2.8–3.4s]
//   .streak       — серия дней + milestone                   [3.4–4.0s]
//   .nextPreview  — карточки stat + preview след. сессии     [4.0–4.5s]
//
// CTA: "Играть ещё" (secondary) + "Продолжить" (primary) + "Поделиться" (ghost).
// Сигнатура `init(result:onContinue:onReplay:)` сохранена для AppCoordinator.

struct SessionCompleteView: View {

    // MARK: - Inputs

    let result: SessionResult
    let onContinue: () -> Void
    let onReplay: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - VIP State

    @State private var display = SessionCompleteDisplay()
    @State private var interactor: SessionCompleteInteractor?
    @State private var presenter: SessionCompletePresenter?
    @State private var router: SessionCompleteRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI state

    @State private var animatedScore: Int = 0
    @State private var ringFraction: Double = 0
    @State private var sharePresented = false
    @State private var shareText: String = ""
    @State private var confettiVisible = false
    @State private var stickerFlipped = false
    @State private var achievementPopVisible = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionCompleteView")

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
            backgroundLayer.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.xLarge) {
                    celebrationPhase
                    scoreRevealPhase
                    starsPhase
                    achievementPhase
                    stickerPhase
                    streakPhase
                    summaryPhase
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.xLarge)
                .padding(.bottom, 240)
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

            if achievementPopVisible, let achievement = display.pendingAchievements.first {
                AchievementPopupView(info: achievement) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        achievementPopVisible = false
                    }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(12)
                .accessibilityAddTraits(.isModal)
            }

            if confettiVisible {
                ConfettiCanvasView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(11)
                    .task {
                        try? await Task.sleep(for: .seconds(3.0))
                        withAnimation(.easeOut(duration: 0.4)) {
                            confettiVisible = false
                        }
                    }
            }

            // Block J v18 — HSConfettiView layered поверх existing ConfettiCanvasView.
            // Pattern .celebration (разноцветное), HSRewardBurst остаётся в score reveal.
            // Per Block J одобрение #9: keep BOTH layered.
            HSConfettiView(preset: .celebration, isActive: $confettiVisible)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(12)
                .accessibilityHidden(true)
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
        .onChange(of: display.currentPhase) { _, phase in
            // Подстраховка: если scoreInt был выставлен до регистрации onChange,
            // count-up не стартует. Запускаем его при появлении кольца счёта.
            guard phase >= .scoreReveal, animatedScore == 0, display.scoreInt > 0 else { return }
            animateScoreCountUp(to: display.scoreInt)
        }
    }

    // MARK: - Stage 1: Celebration (маскот)

    @ViewBuilder
    private var celebrationPhase: some View {
        let visible = display.isPhaseVisible(.celebration)
        VStack(spacing: SpacingTokens.medium) {
            // Block I v19: scaleEffect убран с 2D Ляли — только opacity fade-in.
            // F.tier1 v21: hero — мягче в dark.
            // E v21: 3D hero на SessionComplete (celebration phase).
            LyalyaHeroView(state: lyalyaResultState, mood: 1.0, size: 160)
                .opacity(visible ? (colorScheme == .dark ? 0.92 : 1.0) : 0)
                .animation(
                    reduceMotion ? nil : MotionTokens.spring,
                    value: visible
                )
                .accessibilityHidden(true)

            Text(display.mascotTagline)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .opacity(visible ? 1 : 0)
                .padding(.horizontal, SpacingTokens.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.mascotTagline)
    }

    // MARK: - Stage 2: Score reveal (кольцо + счёт)

    @ViewBuilder
    private var scoreRevealPhase: some View {
        let visible = display.isPhaseVisible(.scoreReveal)
        VStack(spacing: SpacingTokens.medium) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.Kid.surfaceAlt, style: StrokeStyle(lineWidth: 14, lineCap: .round))

                Circle()
                    .trim(from: 0, to: ringFraction)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: scoreColor.opacity(0.35), radius: 8, x: 0, y: 0)

                VStack(spacing: SpacingTokens.micro) {
                    Text("\(animatedScore)")
                        .font(TypographyTokens.kidDisplay(48))
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                        .accessibilityHidden(true)

                    Text(String(localized: "sessionComplete.score.label"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 180, height: 180)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.85)
            .animation(
                reduceMotion ? nil : MotionTokens.spring,
                value: visible
            )

            // Breakdown detail (появляется вместе с кольцом)
            if visible {
                scoreBreakdownRow
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "sessionComplete.summaryRing.a11y"), animatedScore)
        )
    }

    @ViewBuilder
    private var scoreBreakdownRow: some View {
        HStack(spacing: SpacingTokens.small) {
            breakdownChip(label: display.baseScoreLabel, color: ColorTokens.Feedback.correct)
            if !display.streakBonusLabel.isEmpty {
                breakdownChip(label: display.streakBonusLabel, color: ColorTokens.Brand.gold)
            }
            if display.hintPenaltyLabel.contains("-") || display.hintPenaltyLabel.contains("штраф") {
                breakdownChip(label: display.hintPenaltyLabel, color: ColorTokens.Feedback.incorrect)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: display.baseScoreLabel)
    }

    private func breakdownChip(label: String, color: Color) -> some View {
        Text(label)
            .font(TypographyTokens.caption(11).weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, SpacingTokens.micro)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityLabel(label)
    }

    // MARK: - Stage 3: Stars

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
                    .shadow(color: earned ? ColorTokens.Brand.gold.opacity(0.5) : .clear, radius: 8, x: 0, y: 2)
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

    // MARK: - Stage 4: Achievement unlock

    @ViewBuilder
    private var achievementPhase: some View {
        let visible = display.isPhaseVisible(.achievement) && display.hasNewAchievements
        if visible && !display.pendingAchievements.isEmpty {
            VStack(spacing: SpacingTokens.small) {
                ForEach(display.pendingAchievements.indices, id: \.self) { idx in
                    let ach = display.pendingAchievements[idx]
                    achievementCard(info: ach, index: idx)
                }
            }
            .transition(reduceMotion ? .identity : .scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private func achievementCard(info: UnlockedAchievementInfo, index: Int) -> some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.gold), padding: SpacingTokens.medium) {
            HStack(spacing: SpacingTokens.medium) {
                Image(systemName: info.iconName)
                    .font(TypographyTokens.title(26).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .frame(width: 44, height: 44)
                    .background(ColorTokens.Brand.gold.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "sessionComplete.achievement.newLabel"))
                        .font(TypographyTokens.caption(11).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(info.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(info.description)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(TypographyTokens.body(18))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
            }
        }
        .modifier(StaggeredAppear(visible: true, index: index, reduceMotion: reduceMotion))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "sessionComplete.achievement.newLabel")): \(info.title). \(info.description)")
    }

    // MARK: - Stage 5: Sticker reveal

    @ViewBuilder
    private var stickerPhase: some View {
        let visible = display.isPhaseVisible(.sticker)
        if visible, let sticker = display.pendingSticker {
            stickerRevealCard(sticker: sticker)
                .transition(reduceMotion ? .identity : .scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private func stickerRevealCard(sticker: StickerRevealInfo) -> some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.lilac), padding: SpacingTokens.medium) {
            HStack(spacing: SpacingTokens.medium) {
                HSContentSymbol(sticker.emoji, size: 44, tint: ColorTokens.Brand.gold)
                    .rotation3DEffect(
                        .degrees(stickerFlipped ? 0 : 180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.65).delay(0.1),
                        value: stickerFlipped
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "sessionComplete.sticker.newLabel"))
                        .font(TypographyTokens.caption(11).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.lilac)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(sticker.name)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                    Text(sticker.collectionName)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(TypographyTokens.body(18))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "sessionComplete.sticker.newLabel")): \(sticker.name)")
        .onAppear {
            guard !reduceMotion else {
                stickerFlipped = true
                return
            }
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation { stickerFlipped = true }
            }
        }
    }

    // MARK: - Stage 6: Streak

    @ViewBuilder
    private var streakPhase: some View {
        let visible = display.isPhaseVisible(.streak)
        if visible, let streak = display.streakInfo, streak.currentStreak > 0 {
            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.medium) {
                HStack(spacing: SpacingTokens.medium) {
                    Image(systemName: display.streakIconName)
                        .font(TypographyTokens.title(26).weight(.semibold))
                        .foregroundStyle(
                            streak.isMilestone ? ColorTokens.Brand.gold : ColorTokens.Brand.primary
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            (streak.isMilestone ? ColorTokens.Brand.gold : ColorTokens.Brand.primary)
                                .opacity(0.15),
                            in: Circle()
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(display.streakLabel)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        if let milestone = display.streakMilestoneLabel {
                            Text(milestone)
                                .font(TypographyTokens.body(13).weight(.semibold))
                                .foregroundStyle(ColorTokens.Brand.gold)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    Spacer()
                    Text("\(streak.currentStreak)")
                        .font(TypographyTokens.kidDisplay(34))
                        .foregroundStyle(
                            streak.isMilestone ? ColorTokens.Brand.gold : ColorTokens.Brand.primary
                        )
                        .monospacedDigit()
                        .accessibilityHidden(true)
                }
            }
            .modifier(StaggeredAppear(visible: visible, index: 0, reduceMotion: reduceMotion))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.streakLabel)
        }
    }

    // MARK: - Stage 7: Summary (stat cards + next lesson)

    @ViewBuilder
    private var summaryPhase: some View {
        let visible = display.isPhaseVisible(.nextPreview)
        VStack(spacing: SpacingTokens.medium) {
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

            if display.hintsLabel != String(localized: "sessionComplete.summary.noHints") {
                statCard(
                    icon: "lightbulb.fill",
                    title: display.hintsLabel,
                    caption: String(localized: "sessionComplete.summary.hintsCaption")
                )
                .modifier(StaggeredAppear(visible: visible, index: 4, reduceMotion: reduceMotion))
            }

            if let next = display.nextLessonTitle {
                nextLessonCard(title: next)
                    .modifier(StaggeredAppear(visible: visible, index: 5, reduceMotion: reduceMotion))
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
                        .minimumScaleFactor(0.85)
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
        .opacity(display.isPhaseVisible(.nextPreview) ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: display.currentPhase)
    }

    // MARK: - Background

    // v27 visual modernization (#2) — celebration screen получает фон
    // HSMeshGradientBackground(palette: .rewards, animated: false): золотое
    // сияние под reward-reveal. Static (animated: false), т.к. поверх —
    // конфетти и stage-анимации; статика бережёт кадры.
    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            ColorTokens.Kid.bg
            HSMeshGradientBackground(palette: .rewards, animated: false)
                .opacity(colorScheme == .dark ? 0.40 : 0.78)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private var lyalyaResultState: LyalyaState {
        switch result.score {
        case 0.80...:     return .celebrating
        case 0.50..<0.80: return .waving
        default:          return .encouraging
        }
    }

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
        let interactor = SessionCompleteInteractor.makePreview()
        interactor.presenter = presenter
        let router = SessionCompleteRouter()
        router.onContinue = onContinue
        router.onReplay = onReplay
        router.onDismiss = { dismiss() }

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        interactor.loadResult(.init(result: result))

        await runStageSchedule()
    }

    private func runStageSchedule() async {
        guard let interactor else { return }

        // Задержки стадий. Reduced Motion: всё мгновенно в .nextPreview.
        let plan: [(RewardStage, Double)] = reduceMotion
            ? [(.scoreReveal, 0), (.stars, 0), (.achievement, 0), (.sticker, 0), (.streak, 0), (.nextPreview, 0)]
            : [(.scoreReveal, 0.50), (.stars, 0.70), (.achievement, 0.60), (.sticker, 0.60), (.streak, 0.60), (.nextPreview, 0.60)]

        // Немедленно: стадии до .achievement идут последовательно с задержками
        for (stage, delay) in plan.prefix(3) {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            withAnimation(reduceMotion ? nil : MotionTokens.spring) {
                interactor.advancePhase(.init(to: stage))
            }
        }

        // Стадии .achievement, .sticker, .streak, .nextPreview — после persistence pipeline
        // Ждём чуть дольше, чтобы persistence успела вернуть данные
        if !reduceMotion {
            try? await Task.sleep(for: .seconds(1.2))
        }

        for (stage, delay) in plan.dropFirst(3) {
            if delay > 0 && !reduceMotion {
                try? await Task.sleep(for: .seconds(delay))
            }
            withAnimation(reduceMotion ? nil : MotionTokens.spring) {
                interactor.advancePhase(.init(to: stage))
            }
        }

        // Confetti при высокой точности
        if display.showConfetti {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.1 : 0.5))
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) {
                confettiVisible = true
            }
        }

        // Achievement popup при наличии новых ачивок
        if display.hasNewAchievements && !display.pendingAchievements.isEmpty {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.1 : 0.8))
            withAnimation(reduceMotion ? nil : MotionTokens.bounce) {
                achievementPopVisible = true
            }
        }
    }

    // MARK: - Score count-up animation

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
        withAnimation(.easeOut(duration: 1.1)) {
            ringFraction = targetFraction
        }
        let steps = max(8, target / 4)
        let stepDelay: UInt64 = 22_000_000
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
