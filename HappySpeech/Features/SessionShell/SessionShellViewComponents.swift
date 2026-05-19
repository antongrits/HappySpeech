import OSLog
import SwiftUI

// MARK: - SessionShellViewComponents
//
// Подкомпоненты session-shell: HUD, feedback overlay, pause sheet,
// display adapter и GameType helpers. Извлечено из
// `SessionShellView.swift` (Block K.5 v16) для удержания LOC ≤700.

// MARK: - SessionHUDView

/// HUD строка над контентом сессии:
///   [Прогресс-бар] [mm:ss таймер] [♥♥♥] [⏸]
/// Обёрнуто в `HSLiquidGlassCard(.primary)`. Таймер использует `TimelineView`
/// и считает живое время от `state.sessionStartReference`.
struct SessionHUDView: View {
    let state: SessionShellState
    let onPauseTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.regular) {
                progressBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                timerBlock
                fatigueBlock
                pauseButton
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Progress

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(String(
                localized: "session.hud.step_format \(state.currentIndex + 1) \(max(state.totalSteps, 1))"
            ))
            .font(TypographyTokens.caption())
            .foregroundStyle(ColorTokens.Kid.inkMuted)

            ProgressView(
                value: max(0, min(progressFraction, 1))
            )
            .progressViewStyle(.linear)
            .tint(ColorTokens.Brand.primary)
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "session.hud.progress.a11y \(state.currentIndex + 1) \(max(state.totalSteps, 1))"
        ))
        // UI-тест: стабильный identifier + value со строкой "step/total" для
        // отслеживания продвижения сессии без знания внутренней игры.
        .accessibilityIdentifier("sessionHUDProgress")
        .accessibilityValue("\(state.currentIndex + 1)/\(max(state.totalSteps, 1))")
    }

    private var progressFraction: Double {
        guard state.totalSteps > 0 else { return 0 }
        return Double(state.currentIndex) / Double(state.totalSteps)
    }

    // MARK: Timer

    private var timerBlock: some View {
        TimelineView(.periodic(from: state.sessionStartReference, by: 1.0)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(state.sessionStartReference))
            Text(Self.formatElapsed(elapsed))
                .font(TypographyTokens.caption(13).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.ink)
                .frame(minWidth: 44, alignment: .trailing)
                .accessibilityLabel(String(
                    localized: "session.hud.timer.a11y \(Int(elapsed / 60)) \(Int(elapsed) % 60)"
                ))
        }
    }

    private static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: Fatigue (3 hearts)

    private var fatigueBlock: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < state.fatigueHearts ? "heart.fill" : "heart")
                    .font(TypographyTokens.caption(13).weight(.semibold))
                    .foregroundStyle(idx < state.fatigueHearts
                        ? ColorTokens.Semantic.error
                        : ColorTokens.Kid.line)
                    .scaleEffect(reduceMotion ? 1.0 : (idx < state.fatigueHearts ? 1.0 : 0.85))
                    .animation(reduceMotion ? nil : .spring(duration: 0.4), value: state.fatigueHearts)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            localized: "session.hud.fatigue.a11y \(state.fatigueHearts)"
        ))
    }

    // MARK: Pause

    private var pauseButton: some View {
        Button(action: onPauseTap) {
            Image(systemName: "pause.circle.fill")
                .font(TypographyTokens.title(28).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sessionPauseButton")
        .accessibilityLabel(String(localized: "session.hud.pause"))
        .accessibilityAddTraits(.isButton)
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
                ColorTokens.Semantic.success.opacity(0.18)
            case .incorrect:
                ColorTokens.Semantic.error.opacity(0.12)
            case .none:
                Color.clear
            }
        }
    }

    private var feedbackBubble: some View {
        HStack(spacing: SpacingTokens.small) {
            HSMascotView(mood: mascotMood(for: mascotState), size: 56)
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
        guard !reduceMotion else { return }
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

    private func mascotMood(for state: SessionShellModels.MascotState) -> MascotMood {
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
