import SwiftUI

// MARK: - HSConfettiPreset

/// Пресеты конфетти / частиц для разных игровых событий.
public enum HSConfettiPreset {
    /// Разноцветное конфетти — завершение урока, победа.
    case celebration
    /// Золотые искры — стрик, подряд идущие правильные ответы.
    case streak
    /// Радиальный взрыв — медаль, ачивка.
    case medal
}

// MARK: - HSConfettiView

/// Оверлей конфетти / частиц на базе `Canvas + TimelineView`.
///
/// Реализован нативными SwiftUI-примитивами без сторонних библиотек.
/// `swiftui-particles` не имеет стабильного SPM-тега (только pre-release
/// `2.0-pre-x`) — выбран native fallback (ADR-V11-BIG-LIBS).
///
/// Пример:
/// ```swift
/// HSConfettiView(preset: .celebration, isActive: $showConfetti)
///     .ignoresSafeArea()
///     .allowsHitTesting(false)
/// ```
///
/// Supports `@Environment(\.accessibilityReduceMotion)`:
/// при Reduced Motion показывает статичное конфетти без анимации.
public struct HSConfettiView: View {

    public let preset: HSConfettiPreset
    @Binding public var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var particles: [ConfettiParticle] = []
    @State private var animationPhase: Double = 0

    public init(preset: HSConfettiPreset, isActive: Binding<Bool>) {
        self.preset = preset
        self._isActive = isActive
    }

    public var body: some View {
        GeometryReader { geo in
            if isActive {
                if reduceMotion {
                    staticConfetti(in: geo.size)
                } else {
                    animatedConfetti(in: geo.size)
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                particles = makeParticles(preset: preset)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Animated (TimelineView + Canvas)

    @ViewBuilder
    private func animatedConfetti(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0)
            Canvas { ctx, canvasSize in
                drawParticles(ctx: &ctx, size: canvasSize, elapsed: elapsed)
            }
        }
        .task {
            particles = makeParticles(preset: preset)
            try? await Task.sleep(for: .seconds(3.2))
            withAnimation(.easeOut(duration: 0.4)) {
                isActive = false
            }
        }
    }

    // MARK: - Static (Reduced Motion)

    @ViewBuilder
    private func staticConfetti(in size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            drawParticles(ctx: &ctx, size: canvasSize, elapsed: 0.5)
        }
        .onAppear {
            particles = makeParticles(preset: preset)
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            isActive = false
        }
    }

    // MARK: - Drawing

    private func drawParticles(ctx: inout GraphicsContext, size: CGSize, elapsed: Double) {
        for particle in particles {
            let progress = min(elapsed / particle.lifetime, 1.0)
            let opacity = progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2)
            let x = particle.startX + particle.velocityX * elapsed * size.width
            let y = particle.startY + particle.velocityY * elapsed * size.height
                + 0.5 * particle.gravity * elapsed * elapsed * size.height
            let rotation = Angle.degrees(particle.rotationSpeed * elapsed * 360)
            let particleSize = particle.size * (1.0 - progress * 0.3)

            var contextCopy = ctx
            contextCopy.opacity = opacity
            contextCopy.translateBy(x: x, y: y)
            contextCopy.rotate(by: rotation)

            let rect = CGRect(
                x: -particleSize / 2,
                y: -particleSize / 2,
                width: particleSize,
                height: particleSize * particle.aspectRatio
            )

            switch particle.shape {
            case .circle:
                contextCopy.fill(
                    Path(ellipseIn: rect),
                    with: .color(particle.color)
                )
            case .rectangle:
                contextCopy.fill(
                    Path(rect),
                    with: .color(particle.color)
                )
            case .triangle:
                var path = Path()
                path.move(to: CGPoint(x: 0, y: -particleSize / 2))
                path.addLine(to: CGPoint(x: particleSize / 2, y: particleSize / 2))
                path.addLine(to: CGPoint(x: -particleSize / 2, y: particleSize / 2))
                path.closeSubpath()
                contextCopy.fill(path, with: .color(particle.color))
            }
        }
    }

    // MARK: - Particle Factory

    private func makeParticles(preset: HSConfettiPreset) -> [ConfettiParticle] {
        switch preset {
        case .celebration:
            return makeCelebrationParticles()
        case .streak:
            return makeStreakParticles()
        case .medal:
            return makeMedalParticles()
        }
    }

    private func makeCelebrationParticles() -> [ConfettiParticle] {
        let colors: [Color] = [
            ColorTokens.Brand.primary,
            ColorTokens.Brand.rose,
            .yellow, .pink, .green, .orange, .cyan
        ]
        return (0..<60).map { i in
            ConfettiParticle(
                startX: CGFloat.random(in: 0.05...0.95),
                startY: CGFloat.random(in: -0.1...0.2),
                velocityX: CGFloat.random(in: -0.15...0.15),
                velocityY: CGFloat.random(in: 0.1...0.4),
                gravity: CGFloat.random(in: 0.05...0.15),
                color: colors[i % colors.count].opacity(Double.random(in: 0.75...1.0)),
                size: CGFloat.random(in: 6...14),
                aspectRatio: CGFloat.random(in: 0.4...1.0),
                rotationSpeed: Double.random(in: -2...2),
                lifetime: Double.random(in: 2.0...3.0),
                shape: [ConfettiShape.circle, .rectangle, .triangle][i % 3]
            )
        }
    }

    private func makeStreakParticles() -> [ConfettiParticle] {
        let goldColors: [Color] = [.yellow, ColorTokens.Confetti.gold, ColorTokens.Confetti.amber]
        return (0..<40).map { i in
            let angle = Double(i) / 40.0 * 2 * .pi
            return ConfettiParticle(
                startX: 0.5,
                startY: 0.4,
                velocityX: CGFloat(cos(angle)) * CGFloat.random(in: 0.08...0.25),
                velocityY: CGFloat(sin(angle)) * CGFloat.random(in: 0.08...0.25),
                gravity: CGFloat.random(in: 0.02...0.07),
                color: goldColors[i % goldColors.count].opacity(Double.random(in: 0.7...1.0)),
                size: CGFloat.random(in: 4...10),
                aspectRatio: 1.0,
                rotationSpeed: Double.random(in: -3...3),
                lifetime: Double.random(in: 1.5...2.5),
                shape: .circle
            )
        }
    }

    private func makeMedalParticles() -> [ConfettiParticle] {
        let burstColors: [Color] = [
            ColorTokens.Brand.primary,
            .yellow, ColorTokens.Confetti.gold,
            ColorTokens.Brand.gold, .white
        ]
        return (0..<50).map { i in
            let angle = Double(i) / 50.0 * 2 * .pi
            let speed = CGFloat.random(in: 0.12...0.32)
            return ConfettiParticle(
                startX: 0.5,
                startY: 0.45,
                velocityX: CGFloat(cos(angle)) * speed,
                velocityY: CGFloat(sin(angle)) * speed - 0.1,
                gravity: CGFloat.random(in: 0.04...0.12),
                color: burstColors[i % burstColors.count].opacity(Double.random(in: 0.8...1.0)),
                size: CGFloat.random(in: 5...12),
                aspectRatio: CGFloat.random(in: 0.5...1.0),
                rotationSpeed: Double.random(in: -2.5...2.5),
                lifetime: Double.random(in: 2.0...3.0),
                shape: [ConfettiShape.circle, .rectangle][i % 2]
            )
        }
    }
}

// MARK: - ConfettiParticle

private struct ConfettiParticle {
    let startX: CGFloat
    let startY: CGFloat
    let velocityX: CGFloat
    let velocityY: CGFloat
    let gravity: CGFloat
    let color: Color
    let size: CGFloat
    let aspectRatio: CGFloat
    let rotationSpeed: Double
    let lifetime: Double
    let shape: ConfettiShape
}

private enum ConfettiShape {
    case circle, rectangle, triangle
}

// MARK: - Preview

#Preview("HSConfettiView — celebration") {
    @Previewable @State var isActive = true
    ZStack {
        ColorTokens.Kid.bg.ignoresSafeArea()
        VStack {
            Text(verbatim: "Отлично!")
                .font(TypographyTokens.kidDisplay(40))
            Button("Запустить снова") { isActive = true }
                .buttonStyle(.borderedProminent)
        }
        HSConfettiView(preset: .celebration, isActive: $isActive)
            .ignoresSafeArea()
    }
}

#Preview("HSConfettiView — streak") {
    @Previewable @State var isActive = true
    ZStack {
        Color.black.ignoresSafeArea()
        HSConfettiView(preset: .streak, isActive: $isActive)
            .ignoresSafeArea()
    }
}

#Preview("HSConfettiView — medal") {
    @Previewable @State var isActive = true
    ZStack {
        ColorTokens.Kid.bg.ignoresSafeArea()
        HSConfettiView(preset: .medal, isActive: $isActive)
            .ignoresSafeArea()
    }
}
