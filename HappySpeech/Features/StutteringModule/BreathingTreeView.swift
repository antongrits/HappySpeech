import SwiftUI

// MARK: - BreathingTreeView
//
// Упражнение 2 модуля заикания — «Длинный выдох».
// Reuses BreathingExtendedInteractor (composition of BreathingInteractor).
// Visual: a tree that fills with leaves as the child breathes.

struct BreathingTreeView: View {

    @State private var interactor = BreathingExtendedInteractor()
    private let difficulty: StutteringDifficulty = .easy

    var body: some View {
        ZStack {
            HSMeshGradientBackground(palette: .calm, animated: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.sp5) {
                Spacer(minLength: 0)
                breathingOrb
                Spacer(minLength: 0)
                waveformSection
                roundsSection
                mascotBubble
                controlButton
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp5)

            if interactor.display.showSuccess {
                successOverlay
            }
        }
        .navigationTitle(String(localized: "stuttering.exercise.breathing.title"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.circuitContext, .kid)
        .onDisappear {
            Task { await interactor.cancel() }
        }
    }

    // MARK: - Subviews

    /// Центральный дыхательный орб: растёт по мере длинного выдоха.
    private var breathingOrb: some View {
        let progress = CGFloat(interactor.display.treeProgress)
        return HSBreathingOrb(
            expansion: progress,
            ringProgress: progress,
            phaseTitle: interactor.display.isPlaying
                ? String(localized: "Выдох…")
                : String(localized: "Готов?"),
            phaseCount: nil,
            size: 240
        )
    }

    private var mascotBubble: some View {
        let state: LyalyaState = interactor.display.mascotMood == .celebrating
            ? .celebrating
            : (interactor.display.isPlaying ? .encouraging : .idle)
        return HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: state, size: 60)
                .accessibilityHidden(true)
            Text(interactor.display.isPlaying
                ? String(localized: "Выдыхай долго и плавно")
                : String(localized: "Дыши вместе со мной"))
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

    private var waveformSection: some View {
        HSAudioWaveform(
            amplitudes: interactor.display.waveformLevels,
            style: .recording,
            tint: ColorTokens.Brand.primary
        )
        .frame(height: 56)
        .accessibilityHidden(true)
    }

    private var roundsSection: some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(0..<interactor.display.roundsRequired, id: \.self) { i in
                Circle()
                    .fill(
                        i < interactor.display.roundsComplete
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Kid.surfaceAlt
                    )
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var controlButton: some View {
        HSButton(
            interactor.display.isPlaying
                ? String(localized: "Стоп")
                : String(localized: "Начать"),
            style: .primary,
            icon: interactor.display.isPlaying ? "stop.fill" : "play.fill",
            action: {
                if interactor.display.isPlaying {
                    Task { await interactor.cancel() }
                } else {
                    Task { await interactor.startSession(difficulty: difficulty) }
                }
            }
        )
        .frame(height: 56)
    }

    private var successOverlay: some View {
        VStack(spacing: SpacingTokens.sp4) {
            Image(systemName: "wind")
                .font(TypographyTokens.kidDisplay(48))
                .foregroundStyle(ColorTokens.Brand.primary)

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

// MARK: - Preview

#Preview("BreathingTreeView") {
    NavigationStack {
        BreathingTreeView()
    }
    .environment(\.circuitContext, .kid)
}
