import SwiftUI

// MARK: - HSAudioWaveform

/// Real-time audio waveform visualiser. Driven by amplitude array.
/// Also supports playback mode (renders stored waveform).
public struct HSAudioWaveform: View {

    public enum WaveformStyle {
        case recording  // live bars, kid-friendly
        case playback   // mirrored waveform, parent/specialist
        case spectrogram // colour-mapped bars
    }

    private let amplitudes: [Float]  // 0.0–1.0 per bar
    private let style: WaveformStyle
    private let tint: Color?
    private let barCount: Int

    @Environment(\.circuitContext) private var circuit
    @State private var idleBars: [Float] = []
    @State private var idlePhase: Double = 0

    public init(
        amplitudes: [Float] = [],
        style: WaveformStyle = .recording,
        tint: Color? = nil,
        barCount: Int = 40
    ) {
        self.amplitudes = amplitudes
        self.style = style
        self.tint = tint
        self.barCount = barCount
    }

    public var body: some View {
        GeometryReader { geo in
            let barWidth = max(2, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))
            let bars = displayedBars

            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let amp = i < bars.count ? CGFloat(bars[i]) : 0.05
                    let height = max(4, amp * geo.size.height * 0.9)

                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(barColor(at: i, amplitude: Float(amp)))
                        .frame(width: barWidth, height: height)
                        .animation(.easeOut(duration: 0.06), value: amp)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear { startIdleAnimation() }
        .accessibilityLabel("Звуковая волна")
        .accessibilityHidden(true)
    }

    private var displayedBars: [Float] {
        if amplitudes.isEmpty {
            return idleBars.isEmpty ? Array(repeating: 0.1, count: barCount) : idleBars
        }
        if amplitudes.count >= barCount {
            return Array(amplitudes.prefix(barCount))
        }
        return amplitudes + Array(repeating: 0.05, count: barCount - amplitudes.count)
    }

    private func barColor(at index: Int, amplitude: Float) -> Color {
        let base = tint ?? resolvedTint
        switch style {
        case .recording:
            return base.opacity(0.3 + Double(amplitude) * 0.7)
        case .playback:
            return base.opacity(0.6)
        case .spectrogram:
            let hue = Double(index) / Double(barCount) * 0.4 + 0.55
            return Color(hue: hue, saturation: 0.7 + Double(amplitude) * 0.3, brightness: 0.8)
        }
    }

    private var resolvedTint: Color {
        switch circuit {
        case .kid:        return ColorTokens.Brand.primary
        case .parent:     return ColorTokens.Parent.accent
        case .specialist: return ColorTokens.Spec.waveform
        }
    }

    private func startIdleAnimation() {
        guard amplitudes.isEmpty else { return }
        idleBars = (0..<barCount).map { i in
            0.15 + 0.25 * Float(sin(Double(i) / Double(barCount) * .pi * 2))
        }
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            idlePhase += 0.15
            idleBars = (0..<barCount).map { i in
                0.15 + 0.25 * Float(sin(Double(i) / Double(barCount) * .pi * 2 + idlePhase))
            }
        }
    }
}

// MARK: - Preview

#Preview("HSAudioWaveform") {
    VStack(spacing: 24) {
        Text("Запись (анимированная)").font(TypographyTokens.caption())
        HSAudioWaveform(style: .recording)
            .frame(height: 60)
            .padding(.horizontal)

        Text("Спектрограмма").font(TypographyTokens.caption())
        HSAudioWaveform(
            amplitudes: (0..<40).map { _ in Float.random(in: 0.2...0.9) },
            style: .spectrogram
        )
        .frame(height: 60)
        .padding(.horizontal)
    }
    .padding()
}
