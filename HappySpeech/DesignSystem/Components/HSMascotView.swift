import SwiftUI

// MARK: - HSMascotView
// Lyalya the butterfly mascot — rendered in pure SwiftUI (no external assets needed for MVP).
// Animations adapt to reduceMotion. Moods: idle, happy, celebrating, thinking, sad, encouraging.

public enum MascotMood: Sendable {
    case idle
    case happy
    case celebrating
    case thinking
    case sad
    case encouraging
}

public struct HSMascotView: View {
    public let mood: MascotMood
    public let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isWingUp = false
    @State private var sparkleOffset: CGFloat = 0
    @State private var bodyBounce: CGFloat = 0

    public init(mood: MascotMood = .idle, size: CGFloat = 120) {
        self.mood = mood
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Sparkles for celebrating mood
            if mood == .celebrating || mood == .happy {
                SparklesView(size: size)
                    .offset(y: sparkleOffset)
            }

            // Butterfly body
            ButterflyShape(size: size, isWingUp: isWingUp)
        }
        .frame(width: size, height: size)
        .onAppear { startAnimation() }
        .onChange(of: mood) { _, _ in startAnimation() }
        .accessibilityLabel("Ляля — маскот HappySpeech")
        .accessibilityHidden(true)
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        switch mood {
        case .idle:
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isWingUp = true
            }
        case .happy, .encouraging:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).repeatCount(4, autoreverses: true)) {
                isWingUp = true
                bodyBounce = -8
            }
        case .celebrating:
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45).repeatForever(autoreverses: true)) {
                isWingUp = true
                sparkleOffset = -12
            }
        case .thinking:
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isWingUp = false
                bodyBounce = 3
            }
        case .sad:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isWingUp = false
                bodyBounce = 4
            }
        }
    }
}

// MARK: - ButterflyShape (Pure SwiftUI)

private struct ButterflyShape: View {
    let size: CGFloat
    let isWingUp: Bool

    private var wingAngle: Angle { isWingUp ? .degrees(-25) : .degrees(25) }
    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            // Left lower wing
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#F97B50"), Color(hex: "#E85D35")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40 * scale, height: 30 * scale)
                .offset(x: -22 * scale, y: 14 * scale)
                .opacity(0.85)

            // Right lower wing
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#F97B50"), Color(hex: "#E85D35")],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: 40 * scale, height: 30 * scale)
                .offset(x: 22 * scale, y: 14 * scale)
                .opacity(0.85)

            // Left upper wing
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FF9E70"), Color(hex: "#F97B50")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 50 * scale, height: 44 * scale)
                .offset(x: -20 * scale, y: -8 * scale)
                .rotationEffect(wingAngle, anchor: .trailing)

            // Right upper wing
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FF9E70"), Color(hex: "#F97B50")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 50 * scale, height: 44 * scale)
                .offset(x: 20 * scale, y: -8 * scale)
                .rotationEffect(-wingAngle, anchor: .leading)

            // Body
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#3A2820"), Color(hex: "#5C3A28")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 12 * scale, height: 36 * scale)

            // Eyes
            HStack(spacing: 8 * scale) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 7 * scale, height: 7 * scale)
                    .overlay(Circle().fill(Color(hex: "#3A2820")).frame(width: 4 * scale, height: 4 * scale))
                Circle()
                    .fill(Color.white)
                    .frame(width: 7 * scale, height: 7 * scale)
                    .overlay(Circle().fill(Color(hex: "#3A2820")).frame(width: 4 * scale, height: 4 * scale))
            }
            .offset(y: -14 * scale)

            // Antennae
            Group {
                Path { p in
                    p.move(to: CGPoint(x: -3 * scale, y: -18 * scale))
                    p.addQuadCurve(
                        to: CGPoint(x: -16 * scale, y: -38 * scale),
                        control: CGPoint(x: -12 * scale, y: -28 * scale)
                    )
                }
                .stroke(Color(hex: "#3A2820"), lineWidth: 1.5 * scale)
                Circle().fill(Color(hex: "#F97B50"))
                    .frame(width: 5 * scale, height: 5 * scale)
                    .offset(x: -16 * scale, y: -38 * scale)

                Path { p in
                    p.move(to: CGPoint(x: 3 * scale, y: -18 * scale))
                    p.addQuadCurve(
                        to: CGPoint(x: 16 * scale, y: -38 * scale),
                        control: CGPoint(x: 12 * scale, y: -28 * scale)
                    )
                }
                .stroke(Color(hex: "#3A2820"), lineWidth: 1.5 * scale)
                Circle().fill(Color(hex: "#F97B50"))
                    .frame(width: 5 * scale, height: 5 * scale)
                    .offset(x: 16 * scale, y: -38 * scale)
            }
        }
    }
}

// MARK: - SparklesView

private struct SparklesView: View {
    let size: CGFloat
    @State private var phase: Double = 0

    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 10 * scale))
                    .foregroundStyle(Color(hex: "#FFD700").opacity(0.85))
                    .offset(
                        x: CGFloat(cos(Double(i) * .pi / 3 + phase)) * 45 * scale,
                        y: CGFloat(sin(Double(i) * .pi / 3 + phase)) * 40 * scale
                    )
                    .scaleEffect(0.7 + 0.3 * sin(phase * 2 + Double(i)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Preview

#Preview("Mascot Moods") {
    ScrollView(.horizontal) {
        HStack(spacing: 24) {
            ForEach([MascotMood.idle, .happy, .celebrating, .thinking, .sad, .encouraging], id: \.description) { mood in
                VStack {
                    HSMascotView(mood: mood, size: 100)
                    Text(mood.description)
                        .font(TypographyTokens.caption())
                }
            }
        }
        .padding()
    }
}

extension MascotMood: CustomStringConvertible {
    public var description: String {
        switch self {
        case .idle:        return "Покой"
        case .happy:       return "Радость"
        case .celebrating: return "Праздник"
        case .thinking:    return "Думает"
        case .sad:         return "Грустит"
        case .encouraging: return "Поддержка"
        }
    }
}
