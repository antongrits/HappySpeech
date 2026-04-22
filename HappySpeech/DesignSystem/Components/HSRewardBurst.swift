import SwiftUI

// MARK: - HSRewardBurst

/// Confetti/particle burst shown on reward unlock.
public struct HSRewardBurst: View {
    let isShowing: Bool
    let color: Color
    let particleCount: Int

    @State private var particles: [BurstParticle] = []

    public init(isShowing: Bool, color: Color = ColorTokens.Brand.primary, particleCount: Int = 20) {
        self.isShowing = isShowing
        self.color = color
        self.particleCount = particleCount
    }

    public var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
                    .animation(
                        .easeOut(duration: particle.duration).delay(particle.delay),
                        value: isShowing
                    )
            }
        }
        .onChange(of: isShowing) { _, showing in
            if showing { triggerBurst() }
        }
        .allowsHitTesting(false)
    }

    private func triggerBurst() {
        particles = (0..<particleCount).map { i in
            let angle = Double(i) / Double(particleCount) * 2 * .pi
            let distance = Double.random(in: 60...120)
            return BurstParticle(
                id: i,
                color: [color, color.opacity(0.7), .yellow, .pink][i % 4],
                size: CGFloat.random(in: 6...14),
                x: cos(angle) * distance,
                y: sin(angle) * distance,
                opacity: 0,
                duration: Double.random(in: 0.5...0.9),
                delay: Double.random(in: 0...0.15)
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation { particles = particles.map { p in
                var copy = p; copy.opacity = 1; return copy
            }}
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.4)) {
                particles = particles.map { p in
                    var copy = p; copy.opacity = 0; return copy
                }
            }
        }
    }
}

private struct BurstParticle: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    var x: Double
    var y: Double
    var opacity: Double
    let duration: Double
    let delay: Double
}
