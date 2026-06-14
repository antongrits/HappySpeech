import SwiftUI

// MARK: - MetronomeView

struct MetronomeView: View {

    @State private var interactor = MetronomeInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let difficulty: StutteringDifficulty = .easy

    var body: some View {
        ZStack {
            // Спокойный однотонный тёплый фон (cream), статичный.
            HSMeshGradientBackground(palette: .calm, animated: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: SpacingTokens.sp5) {
                    mascotHeader
                    beatRingHero
                    targetWordSection
                    trackSection
                    waveformSection
                    progressSection
                    controlButton
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

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
            // Fix #9 — единый канонический маскот LyalyaMascotView.
            let state: LyalyaState = interactor.display.showReward
                ? .celebrating
                : (interactor.display.isRunning ? .happy : .idle)
            LyalyaMascotView(state: state, size: 80)
        }
    }

    // MARK: - Beat Ring Hero
    //
    // Центральный пульсирующий индикатор удара с реальным BPM из interactor
    // (display.bpm — адаптивный темп). Пульс гейтится reduceMotion и работает
    // только когда метроном запущен; коралловый акцент, тёплый круг.

    private var beatRingHero: some View {
        MetronomeBeatRing(
            bpm: interactor.display.bpm,
            isRunning: interactor.display.isRunning,
            reduceMotion: reduceMotion
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp2)
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
        VStack(spacing: SpacingTokens.sp2) {
            Text(String(localized: "stuttering.metronome.read_in_beat"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)

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
                        .font(TypographyTokens.kidDisplay(32))
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

// MARK: - MetronomeBeatRing
//
// Тёплый коралловый круг с числом BPM в центре и двумя расходящимися
// кольцами-пульсами. Пульс синхронизирован с реальным темпом (display.bpm),
// работает только при isRunning и отключается при reduceMotion (HIG).

private struct MetronomeBeatRing: View {

    let bpm: Int
    let isRunning: Bool
    let reduceMotion: Bool

    @State private var pulse = false

    /// Длительность одного удара в секундах (60 / BPM), с защитой от деления.
    private var beatDuration: Double {
        bpm > 0 ? 60.0 / Double(bpm) : 1.0
    }

    private var animating: Bool {
        isRunning && !reduceMotion
    }

    var body: some View {
        ZStack {
            // Расходящиеся кольца-пульсы (только во время хода).
            if animating {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(ColorTokens.Brand.primary.opacity(0.5), lineWidth: 2)
                        .scaleEffect(pulse ? 1.18 : 0.7)
                        .opacity(pulse ? 0 : 0.55)
                        .animation(
                            .easeOut(duration: beatDuration)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * beatDuration / 2),
                            value: pulse
                        )
                }
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                        center: .init(x: 0.5, y: 0.3),
                        startRadius: 6,
                        endRadius: 120
                    )
                )
                .frame(width: 132, height: 132)
                .scaleEffect(animating && pulse ? 1.05 : 1.0)
                .animation(
                    animating
                        ? .easeInOut(duration: beatDuration).repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )
                .overlay {
                    VStack(spacing: SpacingTokens.sp1) {
                        Text("\(bpm)")
                            .font(TypographyTokens.kidDisplay(42))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(String(localized: "stuttering.metronome.bpm.unit"))
                            .font(TypographyTokens.caption(12).weight(.bold))
                            .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .shadow(color: ColorTokens.Brand.primary.opacity(0.35), radius: 16, y: 8)

            // Спокойный мудлейбл под кольцом, привязан к нижнему краю стека.
            VStack {
                Spacer()
                Text(String(localized: "stuttering.metronome.mood.calm"))
                    .font(TypographyTokens.caption(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .padding(.top, SpacingTokens.sp2)
            }
        }
        .frame(width: 196, height: 220)
        .onAppear { if animating { pulse = true } }
        .onChange(of: isRunning) { _, running in
            pulse = running && !reduceMotion
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(format: String(localized: "stuttering.metronome.bpm.a11y"), bpm)
        )
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
                        .font(TypographyTokens.body(16))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
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
