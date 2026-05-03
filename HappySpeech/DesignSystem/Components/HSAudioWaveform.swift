import SwiftUI

// MARK: - HSAudioWaveform

/// Real-time audio waveform visualiser. Driven by amplitude array.
/// Also supports playback mode (renders stored waveform).
///
/// Idle анимация реализована через `TimelineView + Canvas` — нет Timer,
/// нет Sendable-мутации @State из closure, нет утечек памяти.
/// Reduced Motion: статические bars без анимации.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            if amplitudes.isEmpty && !reduceMotion {
                // Idle: анимированные bars через TimelineView + Canvas (Swift 6 Sendable safe)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { ctx, size in
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate
                        drawBars(ctx: ctx, size: size, elapsed: elapsed)
                    }
                }
            } else {
                // Live amplitudes или Reduced Motion: статические bars
                staticBars(geo: geo)
            }
        }
        .accessibilityLabel(String(localized: "waveform.accessibility.label"))
        .accessibilityHidden(true)
    }

    // MARK: - Canvas idle animation (TimelineView)

    private func drawBars(ctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let totalWidth = size.width
        let spacing: CGFloat = 2
        let barWidth = max(2, (totalWidth - spacing * CGFloat(barCount - 1)) / CGFloat(barCount))
        let base = tint ?? resolvedTint

        for i in 0..<barCount {
            let phase = Double(i) / Double(barCount) * .pi * 2
            let amplitude = Float(0.15 + 0.25 * sin(phase + elapsed * 1.8))
            let height = max(4, CGFloat(amplitude) * size.height * 0.9)
            let x = CGFloat(i) * (barWidth + spacing)
            let y = (size.height - height) / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: height)

            let alpha = 0.3 + Double(amplitude) * 0.7
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
            ctx.fill(path, with: .color(base.opacity(alpha)))
        }
    }

    // MARK: - Static bars (live amplitudes or Reduced Motion)

    @ViewBuilder
    private func staticBars(geo: GeometryProxy) -> some View {
        let barWidth = max(2, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))
        let bars = displayedBars

        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let amp = i < bars.count ? CGFloat(bars[i]) : 0.05
                let height = max(4, amp * geo.size.height * 0.9)

                RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                    .fill(barColor(at: i, amplitude: Float(amp)))
                    .frame(width: barWidth, height: height)
                    .animation(
                        reduceMotion ? .none : .easeOut(duration: MotionTokens.Duration.instant),
                        value: amp
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Helpers

    private var displayedBars: [Float] {
        if amplitudes.isEmpty {
            return Array(repeating: 0.1, count: barCount)
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
