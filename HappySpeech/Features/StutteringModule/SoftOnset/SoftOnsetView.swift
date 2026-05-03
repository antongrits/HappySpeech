import SwiftUI

// MARK: - SoftOnsetView

struct SoftOnsetView: View {

    @State private var interactor = SoftOnsetInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let difficulty: StutteringDifficulty = .easy

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.sp5) {
                mascotHeader
                wordLabel
                lanternView
                waveformSection
                listenButton
                recordButton
                feedbackLabel
                attemptCounter
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp5)
        }
        .navigationTitle(String(localized: "stuttering.exercise.soft_start.title"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.circuitContext, .kid)
        .task {
            await interactor.startSession(difficulty: difficulty)
        }
        .onDisappear {
            interactor.stopListening()
        }
    }

    // MARK: - Subviews

    private var mascotHeader: some View {
        LyalyaMascotView(state: lyalyaState, size: 100)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var lyalyaState: LyalyaState {
        switch interactor.display.feedbackStyle {
        case .success:  return .celebrating
        case .error:    return .encouraging
        default:
            return interactor.display.isRecording ? .explaining : .idle
        }
    }

    private var wordLabel: some View {
        Text(interactor.display.currentWord)
            .font(TypographyTokens.kidDisplay(40))
            .foregroundStyle(ColorTokens.Kid.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel(String(format: String(localized: "stuttering.soft_start.word_accessibility"), interactor.display.currentWord))
    }

    private var lanternView: some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.butter), padding: SpacingTokens.medium) {
            ZStack {
                // Lantern body
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(lanternBodyColor)
                    .frame(width: 60, height: 90)

                // Light glow
                Circle()
                    .fill(lanternGlowColor)
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                    .opacity(lanternGlowOpacity)
                    .animation(
                        reduceMotion ? nil : lanternAnimation,
                        value: interactor.display.lanternState
                    )

                Image(systemName: "lamp.table.fill")
                    .font(TypographyTokens.kidDisplay(48))
                    .foregroundStyle(lanternIconColor)
                    .animation(MotionTokens.spring, value: interactor.display.lanternState)
            }
            .frame(width: 120, height: 120)
        }
        .accessibilityHidden(true)
    }

    private var lanternBodyColor: Color {
        switch interactor.display.lanternState {
        case .off:     return ColorTokens.Kid.surfaceAlt
        case .flicker: return ColorTokens.Brand.butter.opacity(0.5)
        case .bright:  return ColorTokens.Brand.butter
        }
    }

    private var lanternIconColor: Color {
        switch interactor.display.lanternState {
        case .off:     return ColorTokens.Kid.inkMuted
        case .flicker: return ColorTokens.Brand.butter.opacity(0.7)
        case .bright:  return ColorTokens.Brand.butter
        }
    }

    private var lanternGlowColor: Color {
        switch interactor.display.lanternState {
        case .off:     return .clear
        case .flicker: return ColorTokens.Brand.butter.opacity(0.3)
        case .bright:  return ColorTokens.Brand.butter.opacity(0.6)
        }
    }

    private var lanternGlowOpacity: Double {
        switch interactor.display.lanternState {
        case .off:     return 0
        case .flicker: return 0.5
        case .bright:  return 1.0
        }
    }

    private var lanternAnimation: Animation {
        switch interactor.display.lanternState {
        case .flicker:
            return .easeInOut(duration: 0.15)
                .repeatCount(4, autoreverses: true)
        default:
            return MotionTokens.spring
        }
    }

    private var waveformSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.small) {
            HSAudioWaveform(
                amplitudes: interactor.display.waveformLevels,
                style: .recording,
                tint: waveformTint
            )
            .frame(height: 64)
        }
        .accessibilityHidden(true)
    }

    private var waveformTint: Color {
        switch interactor.display.waveformColorMode {
        case .soft:       return ColorTokens.Brand.mint
        case .borderline: return ColorTokens.Brand.butter
        case .hard:       return ColorTokens.Semantic.error
        case .neutral:    return ColorTokens.Brand.primary
        }
    }

    private var listenButton: some View {
        Button(action: {}) {
            Image(systemName: "speaker.wave.2.fill")
                .font(TypographyTokens.headline(22))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(ColorTokens.Brand.sky)
                )
        }
        .accessibilityLabel(String(localized: "stuttering.soft_start.listen_button"))
    }

    private var recordButton: some View {
        Button(action: {
            if interactor.display.isRecording {
                interactor.stopListening()
            } else {
                Task { await interactor.startListening() }
            }
        }) {
            Image(systemName: interactor.display.isRecording ? "stop.fill" : "mic.fill")
                .font(TypographyTokens.title(28))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(
                    Circle().fill(recordButtonColor)
                )
        }
        .accessibilityLabel(
            interactor.display.isRecording
                ? String(localized: "Остановить запись, кнопка")
                : String(localized: "Записать ответ, кнопка")
        )
    }

    private var recordButtonColor: Color {
        interactor.display.isRecording
            ? ColorTokens.Semantic.error
            : ColorTokens.Brand.primary
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if let feedback = interactor.display.feedbackText {
            Text(feedback)
                .font(TypographyTokens.title(24))
                .foregroundStyle(feedbackColor)
                .multilineTextAlignment(.center)
                .scaleEffect(1.0)
                .animation(reduceMotion ? nil : MotionTokens.bounce, value: feedback)
        } else {
            Color.clear.frame(height: 36)
        }
    }

    private var feedbackColor: Color {
        switch interactor.display.feedbackStyle {
        case .success: return ColorTokens.Semantic.success
        case .error:   return ColorTokens.Semantic.error
        case .warning: return ColorTokens.Brand.butter
        case .neutral: return ColorTokens.Kid.ink
        }
    }

    private var attemptCounter: some View {
        Text(
            String(
                format: String(localized: "stuttering.soft_start.attempt_counter"),
                interactor.display.attemptNumber,
                interactor.display.maxAttempts
            )
        )
        .font(TypographyTokens.caption(12))
        .foregroundStyle(ColorTokens.Kid.inkMuted)
    }
}

// MARK: - Preview

#Preview("SoftOnsetView") {
    NavigationStack {
        SoftOnsetView()
    }
    .environment(\.circuitContext, .kid)
}
