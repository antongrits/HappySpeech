import SwiftUI

// MARK: - HSProgressBar

/// Animated progress bar with kid/parent styles.
public struct HSProgressBar: View {

    public enum BarStyle {
        case kid        // tall, rounded, colourful with gradient
        case parent     // thin, clean
        case ring       // circular
    }

    private let value: Double       // 0.0–1.0
    private let style: BarStyle
    private let tint: Color?
    private let showLabel: Bool

    @Environment(\.circuitContext) private var circuit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue: Double = 0

    public init(
        value: Double,
        style: BarStyle = .kid,
        tint: Color? = nil,
        showLabel: Bool = false
    ) {
        self.value = max(0, min(1, value))
        self.style = style
        self.tint = tint
        self.showLabel = showLabel
    }

    public var body: some View {
        Group {
            switch style {
            case .kid:    kidBar
            case .parent: parentBar
            case .ring:   ringProgress
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.75)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newVal in
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75)) {
                animatedValue = newVal
            }
        }
        .accessibilityValue("\(Int(value * 100)) процентов")
    }

    // MARK: - Kid Bar

    private var kidBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: RadiusTokens.full, style: .continuous)
                    .fill(resolvedTint.opacity(0.15))
                    .frame(height: 14)

                // Fill
                RoundedRectangle(cornerRadius: RadiusTokens.full, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [resolvedTint.adjustingBrightness(by: 0.1), resolvedTint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * animatedValue, height: 14)

                // Star at the end
                if animatedValue > 0.05 {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .offset(x: geo.size.width * animatedValue - 16)
                        .frame(height: 14)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 14)
    }

    // MARK: - Parent Bar

    private var parentBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(resolvedTint.opacity(0.12))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(resolvedTint)
                    .frame(width: geo.size.width * animatedValue, height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Ring

    private var ringProgress: some View {
        ZStack {
            Circle()
                .stroke(resolvedTint.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: animatedValue)
                .stroke(
                    resolvedTint,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if showLabel {
                Text("\(Int(animatedValue * 100))%")
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(resolvedTint)
            }
        }
    }

    private var resolvedTint: Color {
        tint ?? (circuit == .kid ? ColorTokens.Brand.primary : ColorTokens.Parent.accent)
    }
}

// MARK: - Preview

#Preview("HSProgressBar") {
    VStack(spacing: 24) {
        HSProgressBar(value: 0.65)
        HSProgressBar(value: 0.40, style: .parent, tint: ColorTokens.Parent.accent)
        HSProgressBar(value: 0.80, style: .ring, showLabel: true)
            .frame(width: 80, height: 80)
    }
    .padding()
    .environment(\.circuitContext, .kid)
}
