import SwiftUI

// MARK: - MetronomeView

struct MetronomeView: View {

    @State private var interactor = MetronomeInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let difficulty: StutteringDifficulty = .easy

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.sp6) {
                mascotHeader
                targetWordSection
                trackSection
                waveformSection
                progressSection
                controlButton
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp5)

            if interactor.display.showReward {
                rewardOverlay
            }
        }
        .navigationTitle(String(localized: "stuttering.exercise.metronome.title"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.circuitContext, .kid)
        .onDisappear { interactor.stopSession() }
    }

    // MARK: - Subviews

    private var mascotHeader: some View {
        HStack {
            Spacer()
            let mood: MascotMood = interactor.display.showReward
                ? .celebrating
                : (interactor.display.isRunning ? .happy : .idle)
            HSMascotView(mood: mood)
                .frame(width: 80, height: 80)
        }
    }

    private var targetWordSection: some View {
        let syllables = interactor.display.syllables
        let activeIdx = interactor.display.currentSyllableIndex
        let syllableText = syllables.enumerated().map { idx, syl -> String in
            idx == activeIdx ? "[\(syl.accessibilityLabel)]" : syl.accessibilityLabel
        }.joined(separator: "-")

        return Text(syllableText.isEmpty ? interactor.display.currentWord : syllableText)
            .font(TypographyTokens.kidDisplay(36))
            .foregroundStyle(ColorTokens.Kid.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private var trackSection: some View {
        HStack(spacing: SpacingTokens.sp3) {
            ForEach(interactor.display.syllables) { syllable in
                SyllableCell(
                    syllable: syllable,
                    isActive: syllable.index == interactor.display.currentSyllableIndex,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var waveformSection: some View {
        HSAudioWaveform(
            amplitudes: interactor.display.waveformLevels,
            style: .recording,
            tint: ColorTokens.Brand.primary
        )
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTokens.Semantic.success)
                .frame(height: 1.5)
                .opacity(interactor.display.isRunning ? 0.6 : 0)
        }
        .accessibilityHidden(true)
    }

    private var progressSection: some View {
        Text(interactor.display.progressLabel)
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
    }

    private var controlButton: some View {
        HSButton(
            interactor.display.isRunning
                ? String(localized: "stuttering.exercise.control.stop")
                : String(localized: "stuttering.exercise.control.start"),
            style: .primary,
            icon: interactor.display.isRunning ? "stop.fill" : "play.fill",
            action: {
                if interactor.display.isRunning {
                    interactor.stopSession()
                } else {
                    Task { await interactor.startSession(difficulty: difficulty) }
                }
            }
        )
        .frame(height: 56)
    }

    private var rewardOverlay: some View {
        VStack(spacing: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(ColorTokens.Brand.butter)
                        .scaleEffect(1.0)
                        .animation(
                            reduceMotion
                                ? nil
                                : MotionTokens.bounce.delay(Double(i) * 0.1),
                            value: interactor.display.showReward
                        )
                }
            }
            Text(String(localized: "stuttering.feedback.complete"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
        }
        .padding(SpacingTokens.sp6)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - SyllableCell

private struct SyllableCell: View {

    let syllable: SyllableViewModel
    let isActive: Bool
    let reduceMotion: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
            .fill(backgroundColor)
            .overlay {
                if syllable.state == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 48, height: 48)
            .overlay {
                if syllable.state == .waiting {
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                }
            }
            .scaleEffect(isActive && !reduceMotion ? 1.15 : 1.0)
            .shadow(
                color: isActive ? ColorTokens.Brand.primary.opacity(0.3) : .clear,
                radius: isActive ? 8 : 0
            )
            .animation(MotionTokens.spring, value: syllable.state)
            .animation(MotionTokens.spring, value: isActive)
            .accessibilityLabel(syllable.accessibilityLabel)
            .accessibilityHint(isActive ? String(localized: "Произнеси следующий слог") : "")
    }

    private var backgroundColor: Color {
        switch syllable.state {
        case .waiting:   return ColorTokens.Kid.surfaceAlt
        case .active:    return ColorTokens.Brand.primary
        case .completed: return ColorTokens.Brand.mint
        }
    }
}

// MARK: - Preview

#Preview("MetronomeView") {
    NavigationStack {
        MetronomeView()
    }
    .environment(\.circuitContext, .kid)
}
