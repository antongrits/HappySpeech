import SwiftUI

// MARK: - SoftOnsetView

struct SoftOnsetView: View {

    @State private var interactor = SoftOnsetInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let difficulty: StutteringDifficulty = .easy

    var body: some View {
        ZStack {
            HSMeshGradientBackground(palette: .calm, animated: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.sp4) {
                wordLabel
                    .padding(.top, SpacingTokens.sp3)
                Spacer(minLength: 0)
                breathingOrb
                Spacer(minLength: 0)
                waveformSection
                feedbackLabel
                HStack(spacing: SpacingTokens.sp5) {
                    listenButton
                    recordButton
                }
                mascotBubble
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

    private var mascotBubble: some View {
        let phrase: String = {
            switch interactor.display.feedbackStyle {
            case .success: return String(localized: "Мягко и плавно — отлично!")
            case .error:   return String(localized: "Начни тихо, без толчка")
            default:
                return interactor.display.isRecording
                    ? String(localized: "Тяни звук мягко…")
                    : String(localized: "Начни слово плавно и тихо")
            }
        }()
        return HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: lyalyaState, size: 60)
                .accessibilityHidden(true)
            Text(phrase)
                .font(TypographyTokens.body(15).weight(.medium))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(SpacingTokens.sp3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .stroke(ColorTokens.Kid.line, lineWidth: 1)
                        )
                )
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
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

    /// Центральный дыхательный орб — мягко раскрывается по мере плавного,
    /// тихого начала голоса (lanternState: off → flicker → bright).
    private var breathingOrb: some View {
        HSBreathingOrb(
            expansion: orbExpansion,
            ringProgress: orbExpansion,
            phaseTitle: orbPhaseTitle,
            phaseCount: nil,
            size: 240
        )
    }

    private var orbExpansion: CGFloat {
        switch interactor.display.lanternState {
        case .off:     return 0.2
        case .flicker: return 0.6
        case .bright:  return 1.0
        }
    }

    private var orbPhaseTitle: String {
        switch interactor.display.lanternState {
        case .off:     return String(localized: "Тихо…")
        case .flicker: return String(localized: "Мягко…")
        case .bright:  return String(localized: "Голос!")
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
                .foregroundStyle(ColorTokens.Overlay.onAccent)
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
                .foregroundStyle(ColorTokens.Overlay.onAccent)
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
