import OSLog
import SwiftUI

// MARK: - SessionShellViewComponents
//
// Подкомпоненты session-shell: HUD, feedback overlay, pause sheet,
// display adapter и GameType helpers. Извлечено из
// `SessionShellView.swift` (Block K.5 v16) для удержания LOC ≤700.

// MARK: - SessionHUDView

/// Верхняя session-bar над контентом занятия — перенос эталона
/// `session-shell.html` (.sessionbar):
///
///   [✕ выход] · [сегментированный прогресс + «шаг N из M»] · [⏱ mm:ss]
///
/// Обёрнуто в `HSLiquidGlassCard(.primary)` (glass-подложка эталона). Прогресс —
/// сегментированный (по одному сегменту на шаг, активный пульсирует), а не
/// плоский linear, как в дизайне. Таймер использует `TimelineView` и считает
/// живое время от `state.sessionStartReference`. Сердечки усталости вынесены из
/// bar'а в отдельный fatigue-chip под ней (см. `SessionFatigueChip`).
/// Кнопка паузы перенесена в `SessionFooterBar` (см. ниже) по эталону дизайна.
struct SessionHUDView: View {
    let state: SessionShellState
    let onExitTap: () -> Void

    private var stepIndex: Int { min(state.currentIndex, max(state.totalSteps - 1, 0)) }
    private var totalSteps: Int { max(state.totalSteps, 1) }

    var body: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.small) {
                exitButton
                progressBlock
                    .frame(maxWidth: .infinity)
                timerBlock
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Exit

    private var exitButton: some View {
        Button(action: onExitTap) {
            Image(systemName: "xmark")
                .font(TypographyTokens.body(16).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .frame(width: 46, height: 46)
                .background(ColorTokens.Kid.surface, in: Circle())
                .overlay(Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                .contentShape(Circle())
                .shadow(color: ColorTokens.Overlay.shadow, radius: 6, y: 2)
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sessionExitButton")
        .accessibilityLabel(String(localized: "session.hud.exit"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Progress (segmented — эталон .segs)

    private var progressBlock: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { idx in
                    Capsule(style: .continuous)
                        .fill(segmentColor(idx))
                        .frame(height: 7)
                        .overlay(activeGlow(idx))
                }
            }
            Text(String(
                localized: "session.hud.step_format \(stepIndex + 1) \(totalSteps)"
            ))
            .font(TypographyTokens.caption(13).weight(.bold))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "session.hud.progress.a11y \(stepIndex + 1) \(totalSteps)"
        ))
        // UI-тест: стабильный identifier + value "step/total" для отслеживания
        // продвижения сессии без знания внутренней игры.
        .accessibilityIdentifier("sessionHUDProgress")
        .accessibilityValue("\(stepIndex + 1)/\(totalSteps)")
    }

    private func segmentColor(_ idx: Int) -> Color {
        idx <= stepIndex ? ColorTokens.Brand.primary : ColorTokens.Kid.line
    }

    @ViewBuilder
    private func activeGlow(_ idx: Int) -> some View {
        if idx == stepIndex {
            // Glow-ring вокруг активного сегмента (эталон .segs .now pulseSeg).
            // Статичная версия без анимации-«дыхания» (стандинг-ордер: фон не движется).
            Capsule(style: .continuous)
                .strokeBorder(ColorTokens.Brand.primary.opacity(0.32), lineWidth: 3)
        }
    }

    // MARK: Timer

    private var timerBlock: some View {
        TimelineView(.periodic(from: state.sessionStartReference, by: 1.0)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(state.sessionStartReference))
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(TypographyTokens.caption(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .accessibilityHidden(true)
                Text(Self.formatElapsed(elapsed))
                    .font(TypographyTokens.caption(14).weight(.heavy).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(minWidth: 52, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                localized: "session.hud.timer.a11y \(Int(elapsed / 60)) \(Int(elapsed) % 60)"
            ))
        }
    }

    private static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - SessionFooterBar

/// Нижняя полоса занятия — перенос эталона `session-shell.html` (.footer):
///
///   [⏸ пауза 60×60] · [Дальше / CTA flex]
///
/// Кнопка «Дальше» появляется только когда есть активность (`showNextCTA == true`).
/// Пауза-кнопка — скруглённый квадрат (radius md), тёплая подложка, коралловый цвет.
struct SessionFooterBar: View {
    let onPauseTap: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            pauseButton
            // Растяжимый плейсхолдер — место для CTA «Дальше»,
            // которую выставляет сама игра поверх через safeAreaInset.
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.small)
        .background(
            LinearGradient(
                colors: [ColorTokens.Kid.bg.opacity(0), ColorTokens.Kid.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var pauseButton: some View {
        Button(action: onPauseTap) {
            Image(systemName: "pause.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(ColorTokens.Brand.primary, lineWidth: 1.5)
                )
                .shadow(color: ColorTokens.Brand.primary.opacity(0.16), radius: 10, y: 4)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sessionPauseButton")
        .accessibilityLabel(String(localized: "session.hud.pause"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SessionFatigueChip

/// Тёплая «пилюля» под session-bar — перенос эталона `session-shell.html`
/// (.fatigue): warning-tinted капсула «Сделаем паузу?». Видимость гейтится
/// родителем (`state.fatigueHearts < 3`), чтобы при скрытии не оставался зазор.
/// Заменяет ряд из 3 сердец в bar'е — для детей понятнее мягкая
/// подсказка-приглашение, чем «потерянные жизни».
struct SessionFatigueChip: View {
    let fatigueHearts: Int

    var body: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "cup.and.saucer.fill")
                .font(TypographyTokens.caption(13).weight(.bold))
                .accessibilityHidden(true)
            Text(String(localized: "session.fatigue.chip"))
                .font(TypographyTokens.caption(13).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(ColorTokens.Semantic.warning)
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.tiny)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Semantic.warningBg)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(ColorTokens.Semantic.warning.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            localized: "session.hud.fatigue.a11y \(fatigueHearts)"
        ))
        .accessibilityIdentifier("sessionFatigueChip")
    }
}

// MARK: - FeedbackOverlayView

/// Полупрозрачный overlay поверх игрового контента.
///
///  • `.correct`   — мягкая зелёная вспышка + scale-pulse 1.0→1.02→1.0;
///  • `.incorrect` — красная рамка + horizontal shake (3 tap'а ±8pt);
///  • Reduced Motion: только цвет, без scale/shake.
///
/// Auto-dismiss 0.8s управляется снаружи (`onChange(feedbackState)` в Binder).
struct FeedbackOverlayView: View {
    let state: SessionShellModels.FeedbackState
    let mascotState: SessionShellModels.MascotState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // A-08 «Спокойный режим» — без shake/pulse и с более мягкой цвето-вспышкой.
    @Environment(\.calmMode) private var calmMode
    @State private var pulseScale: CGFloat = 1.0
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            tintLayer
                .ignoresSafeArea()
                .scaleEffect(pulseScale)

            VStack {
                Spacer()
                feedbackBubble
                    .offset(x: shakeOffset)
                    .padding(.bottom, SpacingTokens.xxLarge)
            }
        }
        .onAppear { runEntryAnimation() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var tintLayer: some View {
        Group {
            switch state {
            case .correct:
                // A-08: мягче вспышка в спокойном режиме (без резкой заливки).
                ColorTokens.Semantic.success.opacity(calmMode ? 0.08 : 0.18)
            case .incorrect:
                ColorTokens.Semantic.error.opacity(calmMode ? 0.06 : 0.12)
            case .none:
                Color.clear
            }
        }
    }

    private var feedbackBubble: some View {
        HStack(spacing: SpacingTokens.small) {
            // Fix #10/9 — единый канонический маскот LyalyaMascotView
            // вместо legacy HSMascotView (как в AR-зоне и StutteringView).
            LyalyaMascotView(state: lyalyaState(for: mascotState), size: 56)
                .accessibilityHidden(true)
            Text(bubbleText)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.vertical, SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .strokeBorder(borderColor, lineWidth: state == .incorrect ? 2 : 0)
        )
        .shadow(color: ColorTokens.Overlay.shadow, radius: 14, y: 4)
    }

    private var borderColor: Color {
        switch state {
        case .correct:   return ColorTokens.Semantic.success
        case .incorrect: return ColorTokens.Semantic.error
        case .none:      return .clear
        }
    }

    private var bubbleText: String {
        switch state {
        case .correct:   return String(localized: "session.feedback.correct")
        case .incorrect: return String(localized: "session.feedback.incorrect")
        case .none:      return ""
        }
    }

    private var accessibilityText: String { bubbleText }

    private func runEntryAnimation() {
        // A-08: в спокойном режиме не запускаем pulse/shake — только мягкий fade
        // самой overlay-вьюхи (управляется снаружи).
        guard !reduceMotion, !calmMode else { return }
        switch state {
        case .correct:
            withAnimation(.easeOut(duration: 0.18)) { pulseScale = 1.02 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000) // 0.18s
                withAnimation(.easeIn(duration: 0.18)) { pulseScale = 1.0 }
            }
        case .incorrect:
            performShake()
        case .none:
            break
        }
    }

    private func performShake() {
        let amplitude: CGFloat = 8
        let step: TimeInterval = 0.07
        let sequence: [CGFloat] = [amplitude, -amplitude, amplitude, -amplitude, 0]
        Task { @MainActor in
            for (idx, value) in sequence.enumerated() {
                if Task.isCancelled { break }
                if idx > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
                }
                withAnimation(.easeInOut(duration: step)) {
                    shakeOffset = value
                }
            }
        }
    }

    /// Fix #9 — маппинг session mascot state → LyalyaState для
    /// канонического LyalyaMascotView. Заменяет legacy HSMascotView/MascotMood
    /// pipeline в feedback overlay.
    private func lyalyaState(for state: SessionShellModels.MascotState) -> LyalyaState {
        switch state {
        case .idle:        return .idle
        case .encouraging: return .encouraging
        case .celebrating: return .celebrating
        case .thinking:    return .thinking
        case .explaining:  return .explaining
        case .waving:      return .waving
        }
    }
}

// MARK: - PauseSheetView

/// Сheet с мотивационной фразой и двумя действиями: «Продолжить», «Выйти».
/// Подложка — `HSLiquidGlassCard(.elevated)`.
struct PauseSheetView: View {
    let motivationalPhrase: String
    let onResume: () -> Void
    let onExitTap: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            ScrollView {
                HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.large) {
                    VStack(spacing: SpacingTokens.large) {
                        // E v21: 3D Ляля в pause sheet (требование пользователя).
                        LyalyaHeroView(state: .encouraging, size: 140)
                            .accessibilityHidden(true)

                        Text(motivationalPhrase.isEmpty
                            ? String(localized: "session.pause.motivational")
                            : motivationalPhrase)
                            .font(TypographyTokens.title(22))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, SpacingTokens.regular)

                        VStack(spacing: SpacingTokens.small) {
                            HSButton(
                                String(localized: "session.hud.resume"),
                                style: .primary,
                                icon: "play.fill"
                            ) {
                                onResume()
                                dismiss()
                            }

                            HSButton(
                                String(localized: "session.hud.exit"),
                                style: .secondary,
                                icon: "xmark"
                            ) {
                                onExitTap()
                            }
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.large)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - SessionShellDisplayAdapter

/// Bridges the presenter (class, `AnyObject`) into SwiftUI `@State`.
@MainActor
final class SessionShellDisplayAdapter: SessionShellDisplayLogic {
    @Binding var state: SessionShellState

    init(state: Binding<SessionShellState>) {
        _state = state
    }

    func displayStartSession(_ viewModel: SessionShellModels.StartSession.ViewModel) {
        state.activities = viewModel.activities
        state.totalSteps = viewModel.totalSteps
        state.currentIndex = 0
        state.fatigueHearts = 3
        state.feedbackState = .none
        state.mascotState = .waving
        state.sessionStartReference = viewModel.sessionStartTime
    }

    func displayCompleteActivity(_ viewModel: SessionShellModels.CompleteActivity.ViewModel) {
        state.feedbackState = viewModel.feedbackState
        state.fatigueHearts = viewModel.fatigueHearts
        state.mascotState = viewModel.mascotState

        if viewModel.shouldShowReward, let reward = viewModel.reward {
            state.rewardVM = reward
            state.isShowingReward = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.6))
                self?.state.isShowingReward = false
            }
        }
        if viewModel.shouldShowFatigueAlert {
            state.isShowingFatigueAlert = true
            return
        }
        if viewModel.shouldAdvance {
            state.currentIndex += 1
        } else {
            state.currentIndex = state.totalSteps
        }
    }

    func displayPauseSession(_ viewModel: SessionShellModels.PauseSession.ViewModel) {
        state.motivationalPhrase = viewModel.motivationalPhrase
        // Sheet visibility управляется вручную из Binder.handlePauseTap, чтобы
        // не зависеть от async-доставки от Presenter.
    }
}

// MARK: - GameType helpers

extension GameType {
    var localizedTitle: String {
        switch self {
        case .listenAndChoose:       return String(localized: "game.listen_and_choose")
        case .repeatAfterModel:      return String(localized: "game.repeat_after_model")
        case .minimalPairs:          return String(localized: "game.minimal_pairs")
        case .dragAndMatch:          return String(localized: "game.drag_and_match")
        case .memory:                return String(localized: "game.memory")
        case .bingo:                 return String(localized: "game.bingo")
        case .breathing:             return String(localized: "game.breathing")
        case .rhythm:                return String(localized: "game.rhythm")
        case .sorting:               return String(localized: "game.sorting")
        case .puzzleReveal:          return String(localized: "game.puzzle_reveal")
        case .soundHunter:           return String(localized: "game.sound_hunter")
        case .narrativeQuest:        return String(localized: "game.narrative_quest")
        case .visualAcoustic:        return String(localized: "game.visual_acoustic")
        case .storyCompletion:       return String(localized: "game.story_completion")
        case .articulationImitation: return String(localized: "game.articulation_imitation")
        case .arActivity:            return String(localized: "game.ar_activity")
        case .objectHunt:            return String(localized: "game.object_hunt")
        case .letterTracing:         return String(localized: "game.letter_tracing")
        }
    }
}
