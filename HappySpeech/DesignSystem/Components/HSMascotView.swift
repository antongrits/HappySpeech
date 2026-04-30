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

/// 7-слойный рендер маскота Ляли: Rive + aura + particles + lip-sync.
///
/// `HSMascotView` — низкоуровневый рендер-компонент. На экранах фич используйте
/// ``LyalyaMascotView`` вместо прямого обращения к `HSMascotView`.
///
/// ### Архитектура слоёв (снизу вверх в ZStack)
///
/// 1. `lyalya.riv` через HSRiveView — Rive state machine "LyalyaSM"
/// 2. `.colorMultiply` tinting — warm / cool / nature / classic (кастомизация скина)
/// 3. `MoodAuraView` — ambient radial glow под маскотом, цвет зависит от настроения
/// 4. `EmotionParticlesView` — частицы: звёзды (.celebrating), сердечки (.happy),
///    знаки вопроса (.thinking), плюсы (.encouraging), ноты (.singing)
/// 5. Mouth bubble overlay — real-time lip-sync через ``MascotLipSyncState``
/// 6. SF Symbol decorative skin overlay — princess / scientist / athlete / artist
/// 7. Breathing motion `.scaleEffect 1.0 → 1.03` + shake при `.encouraging`
///
/// ### Fallback
/// Если `lyalya.riv` отсутствует в бандле — используется чистый SwiftUI `ButterflyShape`.
///
/// ### Lip-sync
/// При передаче `audioAmplitude` применяет low-pass фильтрацию (τ ≈ 50ms)
/// и передаёт нормализованное значение в Rive input `"mouthOpen"`.
///
/// ## Пример
/// ```swift
/// // Обычно используется через LyalyaMascotView:
/// LyalyaMascotView(state: .celebrating, size: 160)
///
/// // Прямое использование (только в компонентах DS):
/// HSMascotView(mood: .happy, size: 120, audioAmplitude: $amplitude)
/// ```
///
/// ## See Also
/// - ``LyalyaMascotView``
/// - ``MascotMood``
/// - ``MascotLipSyncState``
/// - ``MascotEyeContactState``
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

    // v12: entrance / transition animation
    @State private var entranceScale: CGFloat = 0.85
    @State private var entranceOpacity: Double = 0
    @State private var moodTransitionID: Int = 0

    // v12: encouraging shake
    @State private var shakeOffset: CGFloat = 0

    // v12: waving hand bounce
    @State private var wavingHandScale: CGFloat = 1.0

    // v12: pointing arrow pulse
    @State private var arrowPulse: CGFloat = 1.0

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
            // Layer 3: ambient mood aura (под маскотом)
            if !reduceMotion {
                MoodAuraView(mood: mood, size: size)
            }

            // Layer 1–2: Rive или SwiftUI fallback
            ZStack {
                if Self.riveAssetAvailable {
                    riveLayer
                } else {
                    swiftUIFallback
                }
            }
            .scaleEffect(entranceScale)
            .opacity(entranceOpacity)
            .id(moodTransitionID)

            // Layer 4: emotion particles
            if !reduceMotion {
                EmotionParticlesView(mood: mood, size: size)
                    .allowsHitTesting(false)
            }

            // Layer 6a: waving hand (только для waving)
            if mood == .waving, !reduceMotion {
                wavingHandOverlay
            }

            // Layer 6b: pointing arrow (только для pointing)
            if mood == .pointing, !reduceMotion {
                pointingArrowOverlay
            }
        }
        .frame(width: size, height: size)
        .offset(x: shakeOffset)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(false)
        .onAppear {
            riveMood = mood
            playEntrance()
            if !reduceMotion { startFallbackAnimation() }
        }
        .onChange(of: mood) { _, newMood in
            riveMood = newMood
            playMoodTransition()
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
        .offset(y: bodyBounce)
    }

    // MARK: - Waving Hand Overlay (v12)

    @ViewBuilder
    private var wavingHandOverlay: some View {
        Image(systemName: "hand.wave.fill")
            .font(.system(size: size * 0.28))
            .foregroundStyle(Color(hex: "#F97B50"))
            .offset(x: size * 0.36, y: -size * 0.1)
            .scaleEffect(wavingHandScale)
            .rotationEffect(.degrees(wavingHandScale > 1.05 ? 12 : -6))
            .onAppear {
                withAnimation(
                    MotionTokens.bounce.repeatCount(4, autoreverses: true)
                ) {
                    wavingHandScale = 1.18
                }
            }
            .accessibilityHidden(true)
    }

    // MARK: - Pointing Arrow Overlay (v12)

    @ViewBuilder
    private var pointingArrowOverlay: some View {
        let arrowAngle: Double = {
            switch pointingDirection {
            case .left:  return 180
            case .right: return 0
            case .up:    return -90
            }
        }()
        let arrowOffset: CGSize = {
            switch pointingDirection {
            case .left:  return CGSize(width: -size * 0.44, height: 0)
            case .right: return CGSize(width:  size * 0.44, height: 0)
            case .up:    return CGSize(width: 0, height: -size * 0.44)
            }
        }()

        Image(systemName: "arrowshape.right.fill")
            .font(.system(size: size * 0.22))
            .foregroundStyle(Color(hex: "#F97B50").opacity(0.9))
            .offset(arrowOffset)
            .rotationEffect(.degrees(arrowAngle))
            .scaleEffect(arrowPulse)
            .onAppear {
                withAnimation(
                    MotionTokens.bounce.repeatForever(autoreverses: true)
                ) {
                    arrowPulse = 1.22
                }
            }
            .accessibilityHidden(true)
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

    // MARK: - Entrance animation (v12)

    private func playEntrance() {
        guard !reduceMotion else {
            entranceScale = 1.0
            entranceOpacity = 1.0
            return
        }
        entranceScale = 0.82
        entranceOpacity = 0
        withAnimation(MotionTokens.bounce) {
            entranceScale = 1.0
            entranceOpacity = 1.0
        }
    }

    // MARK: - Mood transition (v12)

    private func playMoodTransition() {
        guard !reduceMotion else { return }
        moodTransitionID += 1

        if mood == .encouraging {
            playEncouragingShake()
        }

        withAnimation(MotionTokens.bounce) {
            entranceScale = 1.0
            entranceOpacity = 1.0
        }
    }

    // MARK: - Encouraging shake (v12 — мягкое покачивание вместо вспышек)

    private func playEncouragingShake() {
        let moves: [CGFloat] = [-6, 6, -4, 4, -2, 2, 0]
        var delay = 0.0
        for offset in moves {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: MotionTokens.Duration.instant)) {
                    shakeOffset = offset
                }
            }
            delay += MotionTokens.Duration.instant
        }
    }

    // MARK: - Lip-sync (low-pass filter τ ≈ 50ms @ 60fps → α ≈ 0.17)

    private func applyLipSync(rawAmplitude: Float) {
        let alpha: Float = 0.17
        let target = min(rawAmplitude * 2.5, 1.0)
        smoothedMouth += alpha * (target - smoothedMouth)
    }

    // MARK: - SwiftUI fallback animations

    private func startFallbackAnimation() {
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

// MARK: - MoodAuraView (v12 — ambient glow под маскотом)

/// Радиальный градиент-halo под маскотом — цвет и непрозрачность зависят от состояния.
/// Reduced Motion: не отображается.
private struct MoodAuraView: View {
    let mood: MascotMood
    let size: CGFloat

    @State private var auraScale: CGFloat = 0.8
    @State private var auraOpacity: Double = 0

    private var auraColor: Color {
        switch mood {
        case .idle:        return Color(hex: "#B0C4FF")
        case .happy:       return Color(hex: "#FFD700")
        case .celebrating: return Color(hex: "#FF9E70")
        case .thinking:    return Color(hex: "#C3B1E1")
        case .sad:         return Color(hex: "#A8C8FF")
        case .encouraging: return Color(hex: "#90EE90")
        case .waving:      return Color(hex: "#FFD700")
        case .explaining:  return Color(hex: "#FF9E70")
        case .singing:     return Color(hex: "#FFB6D9")
        case .pointing:    return Color(hex: "#FF9E70")
        }
    }

    private var targetOpacity: Double {
        switch mood {
        case .celebrating: return 0.35
        case .happy, .waving, .singing: return 0.25
        case .idle, .thinking: return 0.12
        case .encouraging: return 0.28
        case .sad: return 0.10
        default: return 0.18
        }
    }

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [auraColor.opacity(targetOpacity), auraColor.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.58
                )
            )
            .frame(width: size * 1.4, height: size * 0.55)
            .offset(y: size * 0.32)
            .scaleEffect(auraScale)
            .opacity(auraOpacity)
            .animation(MotionTokens.spring, value: mood)
            .onAppear {
                withAnimation(MotionTokens.idlePulse) {
                    auraScale = 1.08
                    auraOpacity = 1.0
                }
            }
    }
}

// MARK: - EmotionParticlesView (v12 — state-specific floating particles)

/// Частицы-оверлей поверх маскота — только при активных состояниях.
/// Reduced Motion: не отображается.
private struct EmotionParticlesView: View {
    let mood: MascotMood
    let size: CGFloat

    var body: some View {
        ZStack {
            switch mood {
            case .celebrating:
                CelebrationStarsView(size: size)
            case .happy:
                FloatingHeartsView(size: size)
            case .thinking:
                ThinkingDotsView(size: size)
            case .encouraging:
                EncouragingPlusView(size: size)
            case .singing:
                MusicNotesView(size: size)
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - CelebrationStarsView

private struct CelebrationStarsView: View {
    let size: CGFloat
    @State private var phase: Double = 0

    private let count = 8
    private var scale: CGFloat { size / 120 }
    private let symbols = ["star.fill", "sparkle", "star.fill", "sparkle",
                           "star.fill", "sparkle", "star.fill", "sparkle"]
    private let colors: [Color] = [
        Color(hex: "#FFD700"), Color(hex: "#FF9E70"),
        Color(hex: "#B0C4FF"), Color(hex: "#FFD700"),
        Color(hex: "#FFB6D9"), Color(hex: "#FF9E70"),
        Color(hex: "#90EE90"), Color(hex: "#C3B1E1")
    ]

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = Double(i) * (.pi * 2 / Double(count)) + phase
                let radius = size * 0.58
                Image(systemName: symbols[i])
                    .font(.system(size: 9 * scale))
                    .foregroundStyle(colors[i])
                    .offset(
                        x: CGFloat(cos(angle)) * radius,
                        y: CGFloat(sin(angle)) * radius * 0.7
                    )
                    .scaleEffect(0.6 + 0.4 * sin(phase * 2.5 + Double(i) * 0.8))
                    .opacity(0.7 + 0.3 * sin(phase * 2 + Double(i)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - FloatingHeartsView

private struct FloatingHeartsView: View {
    let size: CGFloat
    @State private var phase: Double = 0

    private let count = 5
    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let baseX = CGFloat(i - count / 2) * size * 0.22
                let riseY = -size * 0.5 * CGFloat(phase / (.pi * 2))
                let delay = Double(i) * 0.4
                let adjustedPhase = (phase + delay * .pi).truncatingRemainder(dividingBy: .pi * 2)
                let y = -size * 0.4 * CGFloat(adjustedPhase / (.pi * 2))

                Image(systemName: "heart.fill")
                    .font(.system(size: 8 * scale))
                    .foregroundStyle(Color(hex: "#FFB6D9").opacity(0.75))
                    .offset(x: baseX + CGFloat(sin(adjustedPhase * 1.3)) * size * 0.1, y: y)
                    .scaleEffect(0.5 + 0.5 * (1 - adjustedPhase / (.pi * 2)))
                    .opacity(0.9 - adjustedPhase / (.pi * 2))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - ThinkingDotsView

private struct ThinkingDotsView: View {
    let size: CGFloat
    @State private var dotScales: [CGFloat] = [1, 1, 1]

    private var scale: CGFloat { size / 120 }

    var body: some View {
        HStack(spacing: 4 * scale) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#C3B1E1").opacity(0.8))
                    .frame(width: 5 * scale, height: 5 * scale)
                    .scaleEffect(dotScales[i])
            }
        }
        .offset(y: -size * 0.54)
        .onAppear {
            for i in 0..<3 {
                let delay = Double(i) * 0.22
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(MotionTokens.bounce.repeatForever(autoreverses: true)) {
                        dotScales[i] = 1.5
                    }
                }
            }
        }
    }
}

// MARK: - EncouragingPlusView

private struct EncouragingPlusView: View {
    let size: CGFloat
    @State private var phase: Double = 0

    private let count = 4
    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = Double(i) * (.pi / 2) + phase * 0.5
                let radius = size * 0.48
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 10 * scale))
                    .foregroundStyle(Color(hex: "#90EE90").opacity(0.8))
                    .offset(
                        x: CGFloat(cos(angle)) * radius,
                        y: CGFloat(sin(angle)) * radius * 0.65
                    )
                    .scaleEffect(0.7 + 0.3 * cos(phase * 1.5 + Double(i)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - MusicNotesView

private struct MusicNotesView: View {
    let size: CGFloat
    @State private var phase: Double = 0

    private let notes = ["music.note", "music.quarternote.3", "music.note"]
    private let offsets: [CGSize] = [
        CGSize(width: -0.32, height: -0.45),
        CGSize(width:  0.05, height: -0.52),
        CGSize(width:  0.34, height: -0.40)
    ]
    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            ForEach(0..<notes.count, id: \.self) { i in
                let delay = Double(i) * 0.55
                let adjustedPhase = (phase + delay).truncatingRemainder(dividingBy: .pi * 2)
                let riseY = -size * 0.18 * CGFloat(adjustedPhase / (.pi * 2))

                Image(systemName: notes[i])
                    .font(.system(size: 9 * scale))
                    .foregroundStyle(Color(hex: "#FFB6D9").opacity(0.85))
                    .offset(
                        x: offsets[i].width * size,
                        y: offsets[i].height * size + riseY
                    )
                    .opacity(0.9 - 0.6 * (adjustedPhase / (.pi * 2)))
                    .scaleEffect(0.8 + 0.2 * sin(adjustedPhase))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
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
            Path { p in
                p.move(to: CGPoint(x: -4 * scale, y: mouthY))
                p.addQuadCurve(
                    to: CGPoint(x: 4 * scale, y: mouthY),
                    control: CGPoint(x: 0, y: mouthY + 4 * scale)
                )
            }
            .stroke(Color(hex: "#3A2820"), lineWidth: 1.2 * scale)
        } else if smoothedMouth > 0.05 || mood == .singing || mood == .explaining {
            Capsule()
                .fill(Color(hex: "#3A2820"))
                .frame(width: 6 * scale, height: max(2 * scale, openHeight + 2 * scale))
                .offset(y: mouthY)
        } else {
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

#Preview("v12 — частицы и аура") {
    @Previewable @State var selectedMood: MascotMood = .celebrating

    VStack(spacing: 20) {
        HSMascotView(mood: selectedMood, size: 180)
            .frame(height: 220)

        Picker("Настроение", selection: $selectedMood) {
            ForEach(MascotMood.allCases, id: \.description) { mood in
                Text(mood.description).tag(mood)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 100)
    }
    .padding()
}
