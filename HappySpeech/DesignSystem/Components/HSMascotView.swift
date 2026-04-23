import SwiftUI

// MARK: - MascotMood
// 10 состояний маскота Ляли для Rive state machine "LyalyaSM".
// При добавлении нового состояния — обновить rivIndex в HSRiveView.swift.

public enum MascotMood: Sendable {
    case idle           // 0 — нежное парение, крылья медленно
    case happy          // 1 — радость, частые взмахи
    case celebrating    // 2 — кружение + sparkles
    case thinking       // 3 — наклон головы + вопросительный пузырь
    case sad            // 4 — опущенные антенны, сложенные крылья
    case encouraging    // 5 — поддержка (при ошибке ребёнка — НЕ ругать)
    case waving         // 6 — машет крылом «привет»
    case explaining     // 7 — жестикуляция + fallback lip-sync
    case singing        // 8 — ритмичный рот + покачивание
    case pointing       // 9 — указывает (используй pointingDirection для уточнения)
}

// MARK: - PointingDirection

public enum PointingDirection: Sendable {
    case left, right, up
}

// MARK: - HSMascotView
//
// Двухуровневая архитектура:
//   1. Primary: Rive state machine через HSRiveView (если lyalya.riv в бандле)
//   2. Fallback: pure SwiftUI ButterflyShape (всегда работает без ассета)
//
// Lip-sync: при передаче audioAmplitude применяет low-pass фильтрацию (τ ≈ 50ms)
// и передаёт нормализованное значение в Rive input "mouthOpen".
//
// Reduced Motion: все анимации отключаются, Rive показывает статичный первый кадр.

public struct HSMascotView: View {

    // MARK: - Public API

    public let mood: MascotMood
    public let size: CGFloat
    public let audioAmplitude: Binding<Float>?
    public let pointingDirection: PointingDirection

    // MARK: - Private state

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Rive binding
    @State private var riveMood: MascotMood
    @State private var smoothedMouth: Float = 0

    // SwiftUI fallback animation states
    @State private var isWingUp = false
    @State private var sparkleOffset: CGFloat = 0
    @State private var bodyBounce: CGFloat = 0
    @State private var bodyRotation: Double = 0
    @State private var antennaDroop: Double = 0
    @State private var wavingPhase: Double = 0

    // Rive asset availability check (once per launch)
    private static let riveAssetAvailable: Bool = {
        Bundle.main.url(forResource: "lyalya", withExtension: "riv") != nil
    }()

    // MARK: - Init

    public init(
        mood: MascotMood = .idle,
        size: CGFloat = 120,
        audioAmplitude: Binding<Float>? = nil,
        pointingDirection: PointingDirection = .up
    ) {
        self.mood = mood
        self.size = size
        self.audioAmplitude = audioAmplitude
        self.pointingDirection = pointingDirection
        self._riveMood = State(initialValue: mood)
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            if Self.riveAssetAvailable {
                riveLayer
            } else {
                swiftUIFallback
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(false)
        .onChange(of: mood) { _, newMood in
            riveMood = newMood
            if !reduceMotion { startFallbackAnimation() }
        }
        .onAppear {
            riveMood = mood
            if !reduceMotion { startFallbackAnimation() }
        }
        .onChange(of: audioAmplitude?.wrappedValue ?? 0) { _, amplitude in
            guard !reduceMotion else { return }
            applyLipSync(rawAmplitude: amplitude)
        }
    }

    // MARK: - Rive Layer

    @ViewBuilder
    private var riveLayer: some View {
        HSRiveView(
            fileName: "lyalya",
            stateMachine: "LyalyaSM",
            mood: $riveMood,
            mouthOpen: smoothedMouth
        )
        .frame(width: size, height: size)
    }

    // MARK: - SwiftUI Fallback

    @ViewBuilder
    private var swiftUIFallback: some View {
        ZStack {
            if mood == .celebrating || mood == .happy {
                SparklesView(size: size)
                    .offset(y: sparkleOffset)
            }

            if mood == .thinking {
                ThoughtBubble(size: size)
                    .offset(x: size * 0.35, y: -size * 0.35)
            }

            ButterflyShape(
                size: size,
                isWingUp: isWingUp,
                mood: mood,
                antennaDroop: antennaDroop,
                bodyRotation: bodyRotation,
                smoothedMouth: smoothedMouth
            )
            .offset(y: bodyBounce)
        }
    }

    // MARK: - Lip-sync (low-pass filter τ ≈ 50ms @ 60fps → α ≈ 0.17)

    private func applyLipSync(rawAmplitude: Float) {
        let alpha: Float = 0.17
        let target = min(rawAmplitude * 2.5, 1.0)
        smoothedMouth = smoothedMouth + alpha * (target - smoothedMouth)
    }

    // MARK: - SwiftUI fallback animations

    private func startFallbackAnimation() {
        // Сброс
        isWingUp = false
        sparkleOffset = 0
        bodyBounce = 0
        bodyRotation = 0
        antennaDroop = 0

        switch mood {
        case .idle:
            withAnimation(MotionTokens.idlePulse) {
                isWingUp = true
            }

        case .happy, .encouraging:
            withAnimation(MotionTokens.bounce.repeatCount(4, autoreverses: true)) {
                isWingUp = true
                bodyBounce = -8
            }

        case .celebrating:
            withAnimation(MotionTokens.bounce.repeatForever(autoreverses: true)) {
                isWingUp = true
                sparkleOffset = -12
            }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                bodyRotation = 360
            }

        case .thinking:
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                bodyBounce = 3
            }

        case .sad:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isWingUp = false
                bodyBounce = 4
                antennaDroop = 30
            }

        case .waving:
            withAnimation(MotionTokens.bounce.repeatCount(3, autoreverses: true)) {
                isWingUp = true
                bodyBounce = -6
            }

        case .explaining, .singing:
            withAnimation(MotionTokens.spring.repeatForever(autoreverses: true)) {
                isWingUp = true
                bodyBounce = -4
            }

        case .pointing:
            withAnimation(MotionTokens.outQuick) {
                isWingUp = true
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch mood {
        case .idle:        return "Ляля отдыхает"
        case .happy:       return "Ляля радуется"
        case .celebrating: return "Ляля празднует победу"
        case .thinking:    return "Ляля думает"
        case .sad:         return "Ляля грустит"
        case .encouraging: return "Ляля поддерживает"
        case .waving:      return "Ляля машет крылышком"
        case .explaining:  return "Ляля объясняет"
        case .singing:     return "Ляля поёт"
        case .pointing:    return "Ляля показывает направление"
        }
    }
}

// MARK: - ButterflyShape (Pure SwiftUI fallback)

private struct ButterflyShape: View {
    let size: CGFloat
    let isWingUp: Bool
    let mood: MascotMood
    let antennaDroop: Double
    let bodyRotation: Double
    let smoothedMouth: Float

    private var wingAngle: Angle { isWingUp ? .degrees(-25) : .degrees(25) }
    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            // Lower wings
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(hex: "#F97B50"), Color(hex: "#E85D35")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 40 * scale, height: 30 * scale)
                .offset(x: -22 * scale, y: 14 * scale)
                .opacity(0.85)

            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(hex: "#F97B50"), Color(hex: "#E85D35")],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                ))
                .frame(width: 40 * scale, height: 30 * scale)
                .offset(x: 22 * scale, y: 14 * scale)
                .opacity(0.85)

            // Upper wings
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(hex: "#FF9E70"), Color(hex: "#F97B50")],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 50 * scale, height: 44 * scale)
                .offset(x: -20 * scale, y: -8 * scale)
                .rotationEffect(wingAngle, anchor: .trailing)

            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(hex: "#FF9E70"), Color(hex: "#F97B50")],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 50 * scale, height: 44 * scale)
                .offset(x: 20 * scale, y: -8 * scale)
                .rotationEffect(-wingAngle, anchor: .leading)

            // Body
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(hex: "#3A2820"), Color(hex: "#5C3A28")],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 12 * scale, height: 36 * scale)

            // Eyes
            HStack(spacing: 8 * scale) {
                eyeView
                eyeView
            }
            .offset(y: -14 * scale)

            // Mouth (lip-sync / mood)
            mouthView

            // Antennae
            antennaeView(droop: antennaDroop)
        }
        .rotationEffect(.degrees(bodyRotation))
    }

    @ViewBuilder
    private var eyeView: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 7 * scale, height: 7 * scale)
            .overlay(
                Circle()
                    .fill(Color(hex: "#3A2820"))
                    .frame(width: 4 * scale, height: 4 * scale)
            )
    }

    @ViewBuilder
    private var mouthView: some View {
        let openHeight = CGFloat(smoothedMouth) * 4 * scale
        let mouthY: CGFloat = -8 * scale

        if mood == .sad {
            // Грустный рот — дуга вниз
            Path { p in
                p.move(to: CGPoint(x: -4 * scale, y: mouthY))
                p.addQuadCurve(
                    to: CGPoint(x: 4 * scale, y: mouthY),
                    control: CGPoint(x: 0, y: mouthY + 4 * scale)
                )
            }
            .stroke(Color(hex: "#3A2820"), lineWidth: 1.2 * scale)
        } else if smoothedMouth > 0.05 || mood == .singing || mood == .explaining {
            // Открытый рот (lip-sync / singing)
            Capsule()
                .fill(Color(hex: "#3A2820"))
                .frame(width: 6 * scale, height: max(2 * scale, openHeight + 2 * scale))
                .offset(y: mouthY)
        } else {
            // Нейтральная улыбка
            Path { p in
                p.move(to: CGPoint(x: -4 * scale, y: mouthY))
                p.addQuadCurve(
                    to: CGPoint(x: 4 * scale, y: mouthY),
                    control: CGPoint(x: 0, y: mouthY - 3 * scale)
                )
            }
            .stroke(Color(hex: "#3A2820"), lineWidth: 1.2 * scale)
        }
    }

    @ViewBuilder
    private func antennaeView(droop: Double) -> some View {
        let droopAngle = Angle.degrees(droop)
        Group {
            // Left antenna
            Path { p in
                p.move(to: CGPoint(x: -3 * scale, y: -18 * scale))
                p.addQuadCurve(
                    to: CGPoint(x: -16 * scale, y: -38 * scale),
                    control: CGPoint(x: -12 * scale, y: -28 * scale)
                )
            }
            .stroke(Color(hex: "#3A2820"), lineWidth: 1.5 * scale)
            .rotationEffect(droopAngle, anchor: UnitPoint(x: 0.5, y: 1.0))

            Circle()
                .fill(Color(hex: "#F97B50"))
                .frame(width: 5 * scale, height: 5 * scale)
                .offset(x: -16 * scale, y: -38 * scale)
                .rotationEffect(droopAngle, anchor: UnitPoint(x: 0.5, y: 1.0))

            // Right antenna
            Path { p in
                p.move(to: CGPoint(x: 3 * scale, y: -18 * scale))
                p.addQuadCurve(
                    to: CGPoint(x: 16 * scale, y: -38 * scale),
                    control: CGPoint(x: 12 * scale, y: -28 * scale)
                )
            }
            .stroke(Color(hex: "#3A2820"), lineWidth: 1.5 * scale)
            .rotationEffect(-droopAngle, anchor: UnitPoint(x: 0.5, y: 1.0))

            Circle()
                .fill(Color(hex: "#F97B50"))
                .frame(width: 5 * scale, height: 5 * scale)
                .offset(x: 16 * scale, y: -38 * scale)
                .rotationEffect(-droopAngle, anchor: UnitPoint(x: 0.5, y: 1.0))
        }
    }
}

// MARK: - ThoughtBubble

private struct ThoughtBubble: View {
    let size: CGFloat
    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8 * scale)
                .fill(Color.white.opacity(0.9))
                .frame(width: 24 * scale, height: 20 * scale)
                .overlay(
                    RoundedRectangle(cornerRadius: 8 * scale)
                        .stroke(Color(hex: "#F97B50"), lineWidth: 1.5 * scale)
                )
            Text("?")
                .font(.system(size: 10 * scale, weight: .bold))
                .foregroundStyle(Color(hex: "#F97B50"))
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

// MARK: - MascotMood + helpers

extension MascotMood: CustomStringConvertible {
    public var description: String {
        switch self {
        case .idle:        return "Покой"
        case .happy:       return "Радость"
        case .celebrating: return "Праздник"
        case .thinking:    return "Думает"
        case .sad:         return "Грустит"
        case .encouraging: return "Поддержка"
        case .waving:      return "Привет"
        case .explaining:  return "Объясняет"
        case .singing:     return "Поёт"
        case .pointing:    return "Указывает"
        }
    }
}

// Conformance for ForEach stability
extension MascotMood: CaseIterable {
    public static var allCases: [MascotMood] {
        [.idle, .happy, .celebrating, .thinking, .sad,
         .encouraging, .waving, .explaining, .singing, .pointing]
    }
}

// MARK: - Preview

#Preview("Все настроения Ляли") {
    ScrollView(.horizontal) {
        HStack(spacing: 24) {
            ForEach(MascotMood.allCases, id: \.description) { mood in
                VStack(spacing: 8) {
                    HSMascotView(mood: mood, size: 100)
                    Text(mood.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview("Lip-sync демо") {
    @Previewable @State var amplitude: Float = 0

    VStack(spacing: 24) {
        HSMascotView(
            mood: .explaining,
            size: 160,
            audioAmplitude: $amplitude
        )
        Slider(value: $amplitude, in: 0...1) {
            Text("Амплитуда")
        }
        .padding(.horizontal)
    }
    .padding()
}
