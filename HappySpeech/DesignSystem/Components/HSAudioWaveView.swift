import SwiftUI

// MARK: - HSAudioWaveView

/// Real-time audio waveform visualisation for RepeatAfterModel and VisualAcousticGame.
/// Two styles: .bars (vertical columns) and .line (smooth curve).
/// Canvas-rendered for efficient GPU performance — no per-bar SwiftUI views.
/// Distinct from HSAudioWaveform (which uses HStack+ForEach for simpler cases).
public struct HSAudioWaveView: View {

    // MARK: - Style

    public enum WaveStyle {
        case bars   // vertical bar chart, kid-friendly
        case line   // smooth bezier curve, specialist/parent
    }

    // MARK: - Properties

    private let amplitudes: [Float]   // 0.0–1.0, most recent N frames
    private let accentColor: Color
    private let style: WaveStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayAmplitudes: [Float] = []

    private let barGap:    CGFloat = 3
    private let minBarH:   CGFloat = 4
    private let barRadius: CGFloat = 3

    // MARK: - Init

    public init(
        amplitudes: [Float],
        accentColor: Color = ColorTokens.Brand.primary,
        style: WaveStyle = .bars
    ) {
        self.amplitudes = amplitudes
        self.accentColor = accentColor
        self.style = style
    }

    // MARK: - Body

    public var body: some View {
        Canvas { context, size in
            switch style {
            case .bars: drawBars(in: context, size: size)
            case .line: drawLine(in: context, size: size)
            }
        }
        .onChange(of: amplitudes) { _, newValue in
            if reduceMotion {
                displayAmplitudes = newValue
            } else {
                withAnimation(.easeOut(duration: 0.06)) {
                    displayAmplitudes = newValue
                }
            }
        }
        .onAppear {
            displayAmplitudes = amplitudes.isEmpty
                ? idleAmplitudes(count: 40)
                : amplitudes
        }
        .accessibilityLabel(String(localized: "Звуковая волна"))
        .accessibilityHidden(true)
    }

    // MARK: - Bar Drawing

    private func drawBars(in context: GraphicsContext, size: CGSize) {
        let count  = max(1, displayAmplitudes.count)
        let barW   = max(3, (size.width - CGFloat(count - 1) * barGap) / CGFloat(count))
        let midY   = size.height / 2

        for (i, amp) in displayAmplitudes.enumerated() {
            let x     = CGFloat(i) * (barW + barGap)
            let halfH = max(minBarH / 2, CGFloat(amp) * midY * 0.9)
            let rect  = CGRect(x: x, y: midY - halfH, width: barW, height: halfH * 2)
            let path  = Path(roundedRect: rect,
                             cornerRadius: barRadius,
                             style: .continuous)

            let opacity = 0.35 + Double(amp) * 0.65
            context.fill(path, with: .color(accentColor.opacity(opacity)))
        }
    }

    // MARK: - Line Drawing

    private func drawLine(in context: GraphicsContext, size: CGSize) {
        guard displayAmplitudes.count > 1 else { return }

        let count = displayAmplitudes.count
        let midY  = size.height / 2
        let stepX = size.width / CGFloat(count - 1)

        func point(at index: Int) -> CGPoint {
            let amp = CGFloat(displayAmplitudes[index])
            return CGPoint(
                x: CGFloat(index) * stepX,
                y: midY - amp * midY * 0.85
            )
        }

        // Upper curve
        var upper = Path()
        upper.move(to: point(at: 0))
        for i in 1..<count {
            let prev = point(at: i - 1)
            let curr = point(at: i)
            let ctrl = CGPoint(x: (prev.x + curr.x) / 2, y: prev.y)
            let ctrl2 = CGPoint(x: (prev.x + curr.x) / 2, y: curr.y)
            upper.addCurve(to: curr, control1: ctrl, control2: ctrl2)
        }

        // Mirror for lower curve
        var full = upper
        for i in stride(from: count - 1, through: 0, by: -1) {
            let amp = CGFloat(displayAmplitudes[i])
            let x = CGFloat(i) * stepX
            let y = midY + amp * midY * 0.85
            if i == count - 1 {
                full.addLine(to: CGPoint(x: x, y: y))
            } else {
                full.addLine(to: CGPoint(x: x, y: y))
            }
        }
        full.closeSubpath()

        context.fill(full, with: .color(accentColor.opacity(0.20)))
        context.stroke(upper, with: .color(accentColor), lineWidth: 2.5)
    }

    // MARK: - Idle State

    private func idleAmplitudes(count: Int) -> [Float] {
        (0..<count).map { i in
            0.12 + 0.18 * Float(sin(Double(i) / Double(count) * .pi * 2))
        }
    }
}

// MARK: - Preview

#Preview("HSAudioWaveView") {
    let sampleAmps: [Float] = (0..<40).map { _ in Float.random(in: 0.1...0.9) }

    VStack(spacing: SpacingTokens.sp6) {
        Text("Bars — детский контур").font(TypographyTokens.caption())
        HSAudioWaveView(amplitudes: sampleAmps,
                        accentColor: ColorTokens.Brand.primary,
                        style: .bars)
            .frame(height: 64)
            .padding(.horizontal)

        Text("Line — родительский / специалист").font(TypographyTokens.caption())
        HSAudioWaveView(amplitudes: sampleAmps,
                        accentColor: ColorTokens.Parent.accent,
                        style: .line)
            .frame(height: 64)
            .padding(.horizontal)

        Text("Idle (пустые амплитуды)").font(TypographyTokens.caption())
        HSAudioWaveView(amplitudes: [],
                        accentColor: ColorTokens.Brand.sky,
                        style: .bars)
            .frame(height: 64)
            .padding(.horizontal)
    }
    .padding()
    .background(ColorTokens.Kid.bg)
}
