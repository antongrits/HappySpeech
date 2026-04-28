import SwiftUI

// MARK: - BreathingTreeView
//
// Упражнение 2 модуля заикания — «Длинный выдох».
// Reuses BreathingExtendedInteractor (composition of BreathingInteractor).
// Visual: a tree that fills with leaves as the child breathes.

struct BreathingTreeView: View {

    @State private var interactor = BreathingExtendedInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let difficulty: StutteringDifficulty = .easy

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.sp6) {
                mascotHeader
                treeIllustration
                waveformSection
                roundsSection
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

    private var mascotHeader: some View {
        HSMascotView(mood: interactor.display.mascotMood == .celebrating ? .celebrating : .idle)
            .frame(width: 100, height: 100)
            .frame(maxWidth: .infinity)
    }

    private var treeIllustration: some View {
        ZStack {
            // Tree trunk (static)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.brown.opacity(0.6))
                .frame(width: 16, height: 80)
                .offset(y: 50)

            // Tree canopy: circular clipping with leaf fill
            Circle()
                .fill(leafColor)
                .scaleEffect(0.5 + Double(interactor.display.treeProgress) * 0.5)
                .frame(width: 160, height: 160)
                .overlay {
                    Circle()
                        .strokeBorder(ColorTokens.Brand.mint.opacity(0.4), lineWidth: 2)
                }
                .animation(
                    reduceMotion ? .linear(duration: 0.2) : MotionTokens.spring,
                    value: interactor.display.treeProgress
                )
        }
        .frame(height: 220)
    }

    private var leafColor: Color {
        let progress = Double(interactor.display.treeProgress)
        return Color(
            hue: 0.35,
            saturation: 0.4 + progress * 0.4,
            brightness: 0.5 + progress * 0.3
        )
    }

    private var waveformSection: some View {
        HSAudioWaveform(
            amplitudes: interactor.display.waveformLevels,
            style: .recording,
            tint: ColorTokens.Brand.mint
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
                            ? ColorTokens.Brand.mint
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
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.Brand.mint)

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
