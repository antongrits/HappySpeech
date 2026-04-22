import SwiftUI

// MARK: - HSMiniSpark

/// Small particle burst shown on correct answers and reward moments.
/// Uses Canvas for efficient GPU rendering of 6 star particles.
/// Reduced Motion: particles fade in place without movement.
public struct HSMiniSpark: View {

    public let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [SparkParticle] = HSMiniSpark.makeParticles()
    @State private var progress: Double = 0

    private let particleCount = 6
    private let burstRadius:  CGFloat = 44
    private let particleSize: CGFloat = 8

    public init(isActive: Bool) {
        self.isActive = isActive
    }

    public var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)

            for particle in particles {
                let t        = progress
                let ease     = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
                let distance = burstRadius * ease
                let fade     = 1.0 - t

                let x = centre.x + (reduceMotion ? 0 : cos(particle.angle) * distance)
                let y = centre.y + (reduceMotion ? 0 : sin(particle.angle) * distance)
                let size = particleSize * particle.scale * (reduceMotion ? 1.0 : (1.0 - t * 0.4))

                var ctx = context
                ctx.opacity = fade * particle.opacity

                let rect = CGRect(
                    x: x - size / 2,
                    y: y - size / 2,
                    width: size,
                    height: size
                )

                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(particle.color)
                )

                // Draw a small 4-point star shape
                let star = starPath(centre: CGPoint(x: x, y: y), outerRadius: size / 2, innerRadius: size / 4)
                ctx.fill(star, with: .color(particle.color.opacity(fade)))
            }
        }
        .frame(width: burstRadius * 2 + particleSize,
               height: burstRadius * 2 + particleSize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isActive) { _, newValue in
            if newValue { triggerBurst() }
        }
        .onAppear {
            if isActive { triggerBurst() }
        }
    }

    // MARK: - Animation

    private func triggerBurst() {
        particles = HSMiniSpark.makeParticles()
        progress = 0
        withAnimation(.easeOut(duration: 0.7)) {
            progress = 1.0
        }
    }

    // MARK: - Helpers

    private func starPath(centre: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) -> Path {
        var path = Path()
        let points = 4
        for i in 0..<points * 2 {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = centre.x + cos(angle) * radius
            let y = centre.y + sin(angle) * radius
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    private static func makeParticles() -> [SparkParticle] {
        let colors: [Color] = [
            ColorTokens.Brand.gold,
            ColorTokens.Brand.primary,
            ColorTokens.Brand.mint,
            ColorTokens.Brand.lilac,
            ColorTokens.Brand.butter,
            ColorTokens.Brand.sky
        ]
        return (0..<6).map { i in
            SparkParticle(
                angle: Double(i) * .pi / 3 + Double.random(in: -0.2...0.2),
                scale: CGFloat.random(in: 0.7...1.2),
                opacity: Double.random(in: 0.8...1.0),
                color: colors[i % colors.count]
            )
        }
    }
}

// MARK: - SparkParticle

private struct SparkParticle {
    let angle:   Double
    let scale:   CGFloat
    let opacity: Double
    let color:   Color
}

// MARK: - Preview

#Preview("HSMiniSpark") {
    @Previewable @State var active = false

    VStack(spacing: SpacingTokens.sp8) {
        ZStack {
            HSMiniSpark(isActive: active)
            Image(systemName: "star.fill")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.Brand.gold)
        }
        .frame(width: 120, height: 120)

        HSButton("Взорвать!", style: .primary) {
            active = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                active = true
            }
        }
        .frame(width: 200)
    }
    .padding()
    .background(ColorTokens.Kid.bg)
}
