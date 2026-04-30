import SwiftUI

// MARK: - ConfettiEmitterView
//
// Нативный particle confetti через TimelineView + Canvas (iOS 15+).
// Используется в CelebrationOverlayView и любых feature-экранах.
//
// Стили (ConfettiEmitterView.Style):
//   .celebration  — сердца + звёзды + блёстки, тёплые цвета, 60 частиц, 3s
//   .perfect      — только звёзды, золото/жёлтый, 80 частиц, 4s
//   .achievement  — прямоугольники + круги, бренд-цвета, 100 частиц, 5s
//
// Физика: гравитация 220 px/s², начальная скорость 200–420 px/s, вращение ±2π rad/s.
// Reduced Motion: статический Image(systemName:"sparkles") вместо анимации.

// MARK: - ConfettiEmitterParticle

struct ConfettiEmitterParticle {

    enum Shape {
        case symbol(String)
        case rectangle
        case circle
    }

    let initialPosition: CGPoint
    let velocity: CGVector
    let initialRotation: Double
    let rotationSpeed: Double      // рад/сек
    let shape: Shape
    let color: Color
    let scale: Double
    let lifetime: TimeInterval

    // MARK: - Состояние в момент времени

    func position(at elapsed: TimeInterval, in size: CGSize) -> CGPoint {
        let gravity: CGFloat = 220
        let dt = CGFloat(elapsed)
        let rawX = initialPosition.x + CGFloat(velocity.dx) * dt
        let rawY = initialPosition.y + CGFloat(velocity.dy) * dt + 0.5 * gravity * dt * dt
        // Горизонтальный wrap
        let spanW = size.width + 40
        let wrappedX = rawX.truncatingRemainder(dividingBy: spanW)
        let finalX = wrappedX < -20 ? wrappedX + spanW : wrappedX
        return CGPoint(x: finalX, y: rawY)
    }

    func opacity(at elapsed: TimeInterval) -> Double {
        let t = elapsed / lifetime
        guard t <= 1.0 else { return 0 }
        if t < 0.08 { return t / 0.08 }
        if t > 0.70 { return max(0, (1.0 - t) / 0.30) }
        return 1.0
    }

    func rotation(at elapsed: TimeInterval) -> Double {
        initialRotation + rotationSpeed * elapsed
    }
}

// MARK: - ConfettiEmitterView (основной публичный компонент)

/// Particle confetti через TimelineView + Canvas. Reusable, performant.
/// Reduced Motion: статичный SF Symbol sparkles.
struct ConfettiEmitterView: View {

    // MARK: - Style

    enum Style {
        case celebration    // тёплые цвета, сердца + звёзды + блёстки
        case perfect        // золото, только звёзды
        case achievement    // бренд-цвета, прямоугольники + круги
    }

    // MARK: - Входные параметры

    let style: Style
    let particleCount: Int
    let duration: TimeInterval

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var particles: [ConfettiEmitterParticle] = []
    @State private var startDate: Date = .now
    @State private var active: Bool = false

    // MARK: - Init

    init(
        style: Style = .celebration,
        particleCount: Int? = nil,
        duration: TimeInterval? = nil
    ) {
        self.style = style
        switch style {
        case .celebration:
            self.particleCount = particleCount ?? 60
            self.duration = duration ?? 3.0
        case .perfect:
            self.particleCount = particleCount ?? 80
            self.duration = duration ?? 4.0
        case .achievement:
            self.particleCount = particleCount ?? 100
            self.duration = duration ?? 5.0
        }
    }

    // MARK: - Body

    var body: some View {
        if reduceMotion {
            // Статичный fallback
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700"), Color(hex: "#C77DFF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .accessibilityHidden(true)
        } else {
            GeometryReader { geo in
                TimelineView(
                    .animation(minimumInterval: 1.0 / 60.0, paused: !active)
                ) { timeline in
                    Canvas { ctx, size in
                        guard !particles.isEmpty else { return }
                        let elapsed = timeline.date.timeIntervalSince(startDate)
                        guard elapsed >= 0 else { return }
                        renderAll(ctx: ctx, size: size, elapsed: elapsed)
                    } symbols: {
                        symbolViews
                    }
                }
                .onAppear {
                    startDate = .now
                    particles = makeParticles(in: geo.size)
                    active = true
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Canvas Symbols

    @ViewBuilder
    private var symbolViews: some View {
        switch style {
        case .celebration:
            Image(systemName: "heart.fill")
                .foregroundStyle(Color(hex: "#FF6B6B"))
                .tag("heart.fill")
            Image(systemName: "star.fill")
                .foregroundStyle(Color(hex: "#FFD93D"))
                .tag("star.fill")
            Image(systemName: "sparkle")
                .foregroundStyle(Color(hex: "#C77DFF"))
                .tag("sparkle")
            Image(systemName: "circle.fill")
                .foregroundStyle(Color(hex: "#FF9E4F"))
                .tag("circle.fill")
        case .perfect:
            Image(systemName: "star.fill")
                .foregroundStyle(Color(hex: "#FFD700"))
                .tag("star.fill")
        case .achievement:
            Image(systemName: "star.fill")
                .foregroundStyle(Color(hex: "#4D96FF"))
                .tag("star.fill")
        }
    }

    // MARK: - Render

    private func renderAll(ctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        for particle in particles {
            guard elapsed < particle.lifetime else { continue }
            let alpha = particle.opacity(at: elapsed)
            guard alpha > 0.01 else { continue }

            let pos = particle.position(at: elapsed, in: size)
            guard pos.y < size.height + 80 else { continue }

            let rot = particle.rotation(at: elapsed)
            var copy = ctx
            copy.opacity = alpha

            switch particle.shape {
            case .symbol(let name):
                renderSymbol(ctx: copy, name: name, at: pos, rotation: rot, scale: particle.scale)
            case .rectangle:
                renderRect(ctx: copy, at: pos, rotation: rot, scale: particle.scale, color: particle.color)
            case .circle:
                renderCircle(ctx: copy, at: pos, scale: particle.scale, color: particle.color)
            }
        }
    }

    private func renderSymbol(
        ctx: GraphicsContext,
        name: String,
        at pos: CGPoint,
        rotation: Double,
        scale: Double
    ) {
        guard let resolved = ctx.resolveSymbol(id: name) else {
            let r = 5.0 * scale
            ctx.fill(
                Path(ellipseIn: CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.8))
            )
            return
        }
        let dim = 16.0 * scale
        let rect = CGRect(x: pos.x - dim / 2, y: pos.y - dim / 2, width: dim, height: dim)
        var copy = ctx
        copy.translateBy(x: pos.x, y: pos.y)
        copy.rotate(by: .radians(rotation))
        copy.translateBy(x: -pos.x, y: -pos.y)
        copy.draw(resolved, in: rect)
    }

    private func renderRect(
        ctx: GraphicsContext,
        at pos: CGPoint,
        rotation: Double,
        scale: Double,
        color: Color
    ) {
        let w = 12.0 * scale
        let h = 6.0 * scale
        var copy = ctx
        copy.translateBy(x: pos.x, y: pos.y)
        copy.rotate(by: .radians(rotation))
        copy.fill(Path(CGRect(x: -w / 2, y: -h / 2, width: w, height: h)), with: .color(color))
    }

    private func renderCircle(
        ctx: GraphicsContext,
        at pos: CGPoint,
        scale: Double,
        color: Color
    ) {
        let r = 5.0 * scale
        ctx.fill(
            Path(ellipseIn: CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)),
            with: .color(color)
        )
    }

    // MARK: - Particle Generation

    private func makeParticles(in size: CGSize) -> [ConfettiEmitterParticle] {
        var rng = SystemRandomNumberGenerator()
        var list: [ConfettiEmitterParticle] = []
        list.reserveCapacity(particleCount)

        let spawnW = max(size.width, 375)

        for _ in 0..<particleCount {
            let spawnX = CGFloat.random(in: -20...(spawnW + 20), using: &rng)
            let spawnY = CGFloat.random(in: -80...(-10), using: &rng)

            // Угол разлёта: преимущественно вниз (от top edge)
            let angle = Double.random(
                in: (Double.pi / 2 - Double.pi / 4)...(Double.pi / 2 + Double.pi / 4),
                using: &rng
            )
            let speed = Double.random(in: 200...420, using: &rng)

            list.append(ConfettiEmitterParticle(
                initialPosition: CGPoint(x: spawnX, y: spawnY),
                velocity: CGVector(dx: speed * cos(angle), dy: speed * sin(angle)),
                initialRotation: Double.random(in: 0...(2 * .pi), using: &rng),
                rotationSpeed: Double.random(in: -(2 * .pi)...(2 * .pi), using: &rng),
                shape: pickShape(using: &rng),
                color: pickColor(using: &rng),
                scale: Double.random(in: 0.6...1.5, using: &rng),
                lifetime: Double.random(in: 1.8...duration, using: &rng)
            ))
        }
        return list
    }

    private func pickShape(using rng: inout SystemRandomNumberGenerator) -> ConfettiEmitterParticle.Shape {
        switch style {
        case .celebration:
            let symbols = ["heart.fill", "star.fill", "sparkle", "circle.fill"]
            return .symbol(symbols[Int.random(in: 0..<symbols.count, using: &rng)])
        case .perfect:
            return .symbol("star.fill")
        case .achievement:
            switch Int.random(in: 0...2, using: &rng) {
            case 0:  return .rectangle
            case 1:  return .circle
            default: return .symbol("star.fill")
            }
        }
    }

    private func pickColor(using rng: inout SystemRandomNumberGenerator) -> Color {
        let palette = colorPalette
        return palette[Int.random(in: 0..<palette.count, using: &rng)]
    }

    private var colorPalette: [Color] {
        switch style {
        case .celebration:
            return [
                Color(hex: "#FF6B6B"),
                Color(hex: "#FFD93D"),
                Color(hex: "#FF9E4F"),
                Color(hex: "#C77DFF"),
                Color(hex: "#FF69B4"),
                Color(hex: "#FFA07A")
            ]
        case .perfect:
            return [
                Color(hex: "#FFD700"),
                Color(hex: "#FFF176"),
                Color(hex: "#FFCA28"),
                Color(hex: "#FFE082"),
                Color(hex: "#FF8F00")
            ]
        case .achievement:
            return [
                Color(hex: "#4D96FF"),
                Color(hex: "#6BCB77"),
                Color(hex: "#C77DFF"),
                Color(hex: "#FF6B6B"),
                Color(hex: "#FFD93D"),
                Color(hex: "#FF9E4F")
            ]
        }
    }
}

// MARK: - Preview

#Preview("Celebration — Normal") {
    ZStack {
        Color(hex: "#1A0A3B").ignoresSafeArea()
        ConfettiEmitterView(style: .celebration)
    }
}

#Preview("Perfect — Normal") {
    ZStack {
        Color(hex: "#1A2A1A").ignoresSafeArea()
        ConfettiEmitterView(style: .perfect)
    }
}

#Preview("Achievement — Normal") {
    ZStack {
        Color(hex: "#0A1A3B").ignoresSafeArea()
        ConfettiEmitterView(style: .achievement)
    }
}

#Preview("Reduce Motion Fallback") {
    ZStack {
        Color(hex: "#1A0A3B").ignoresSafeArea()
        // Fallback отображается при включённом Accessibility > Reduce Motion в Settings
        ConfettiReduceMotionPreview()
    }
}

private struct ConfettiReduceMotionPreview: View {
    var body: some View {
        Image(systemName: "sparkles")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "#FFD700"), Color(hex: "#C77DFF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
