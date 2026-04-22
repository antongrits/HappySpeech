import SwiftUI

// MARK: - HSSpeechBubble

/// Speech bubble for Lyalya mascot and hint overlays.
/// Includes a directional tail rendered via Path.
/// Appears with a spring scale+opacity animation.
public struct HSSpeechBubble: View {

    // MARK: - Types

    public enum BubbleDirection {
        case left   // tail points to the left (Lyalya is on the left)
        case right  // tail points to the right (Lyalya is on the right)
    }

    public enum BubbleStyle {
        case lyalya     // coral — mascot speech
        case hint       // lilac — helper hint
        case question   // teal — question prompt

        var fillColor: Color {
            switch self {
            case .lyalya:   return ColorTokens.Brand.primary
            case .hint:     return ColorTokens.Brand.lilac
            case .question: return ColorTokens.Games.listenAndChoose
            }
        }

        var textColor: Color { .white }

        var shadowColor: Color {
            fillColor.opacity(0.30)
        }
    }

    // MARK: - Properties

    private let text: String
    private let direction: BubbleDirection
    private let style: BubbleStyle
    private let maxWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let tailWidth:  CGFloat = 18
    private let tailHeight: CGFloat = 14
    private let cornerRadius: CGFloat = RadiusTokens.md

    // MARK: - Init

    public init(
        _ text: String,
        direction: BubbleDirection = .left,
        style: BubbleStyle = .lyalya,
        maxWidth: CGFloat = 260
    ) {
        self.text = text
        self.direction = direction
        self.style = style
        self.maxWidth = maxWidth
    }

    // MARK: - Body

    public var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if direction == .right {
                tailShape
                    .frame(width: tailWidth, height: tailHeight)
                    .padding(.bottom, cornerRadius)
            }

            bubbleBody

            if direction == .left {
                tailShape
                    .frame(width: tailWidth, height: tailHeight)
                    .padding(.bottom, cornerRadius)
                    .scaleEffect(x: -1, anchor: .center)
            }
        }
        .frame(maxWidth: maxWidth, alignment: direction == .left ? .trailing : .leading)
        .scaleEffect(appeared ? 1.0 : 0.82, anchor: direction == .left ? .bottomTrailing : .bottomLeading)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(MotionTokens.spring) {
                    appeared = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    // MARK: - Subviews

    private var bubbleBody: some View {
        Text(text)
            .font(TypographyTokens.headline())
            .foregroundStyle(style.textColor)
            .lineLimit(3)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(style.fillColor)
                    .shadow(color: style.shadowColor, radius: 8, x: 0, y: 4)
            )
    }

    /// Triangle tail rendered via Path, points downward (toward mascot).
    private var tailShape: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                // Triangle: base at top, tip at bottom-right
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
            }
            .fill(style.fillColor)
        }
    }
}

// MARK: - Preview

#Preview("HSSpeechBubble") {
    VStack(spacing: SpacingTokens.sp6) {
        HStack(alignment: .bottom, spacing: SpacingTokens.sp3) {
            HSMascotView(mood: .happy, size: 80)
            HSSpeechBubble("Привет! Сегодня мы будем учиться говорить звук Р!", direction: .left, style: .lyalya)
        }

        HStack(alignment: .bottom, spacing: SpacingTokens.sp3) {
            HSSpeechBubble("Подсказка: прижми язычок к верхним зубам", direction: .right, style: .hint)
            HSMascotView(mood: .thinking, size: 80)
        }

        HStack(alignment: .bottom, spacing: SpacingTokens.sp3) {
            HSMascotView(mood: .idle, size: 80)
            HSSpeechBubble("Что ты слышишь в начале слова?", direction: .left, style: .question)
        }
    }
    .padding(SpacingTokens.sp6)
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}
