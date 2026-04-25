import SwiftUI

// MARK: - CelebrationOverlayView
//
// Полноэкранный overlay «отличная работа» — без видеофайлов, чистый SwiftUI.
//
// Состав:
//   1. Конфетти (Canvas particles, 60 fps, 50 частиц)
//   2. Пульсирующая звезда (scaleEffect 1.0 → 1.3 → 1.0)
//   3. Текст с bouncy spring
//   4. LyalyaMascotView (состояние .celebrating)
//   5. Кнопка «Продолжить»
//
// Reduced Motion: конфетти отключается; остаётся текст с fade-in и Ляля.

struct CelebrationOverlayView: View {

    // MARK: - API

    /// Количество звёзд (1–3) — влияет на заголовок и интенсивность праздника.
    let stars: Int

    /// Колбэк на кнопку «Продолжить».
    let onContinue: () -> Void

    // MARK: - Private state

    @State private var textVisible: Bool = false
    @State private var mascotVisible: Bool = false
    @State private var starScale: CGFloat = 0.7
    @State private var starPulse: Bool = false
    @State private var confettiTick: Int = 0
    @State private var buttonVisible: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Palette

    private let confettiPalette: [Color] = [
        .init(hex: "#FF6B6B"), .init(hex: "#FFD93D"),
        .init(hex: "#6BCB77"), .init(hex: "#4D96FF"),
        .init(hex: "#FF9E4F"), .init(hex: "#C77DFF")
    ]

    // MARK: - Init

    init(stars: Int = 3, onContinue: @escaping () -> Void) {
        self.stars = max(1, min(3, stars))
        self.onContinue = onContinue
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Полупрозрачный фон
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            // Конфетти слой (только при reduceMotion == false)
            if !reduceMotion {
                ConfettiCanvas(
                    tick: confettiTick,
                    palette: confettiPalette,
                    particleCount: 50
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            VStack(spacing: 24) {
                // Ляля
                LyalyaMascotView(state: .celebrating, size: 150)
                    .scaleEffect(mascotVisible ? 1 : 0.6)
                    .opacity(mascotVisible ? 1 : 0)

                // Звезды
                starsRow
                    .scaleEffect(starScale)

                // Заголовок
                VStack(spacing: 8) {
                    Text(titleText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                    if stars == 3 {
                        Text(String(localized: "celebration.perfect_subtitle"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                }
                .opacity(textVisible ? 1 : 0)
                .offset(y: textVisible ? 0 : 16)

                // Кнопка
                Button {
                    onContinue()
                } label: {
                    Text(String(localized: "celebration.continue_button"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#4D96FF").opacity(0.9))
                        )
                        .shadow(color: Color(hex: "#4D96FF").opacity(0.5), radius: 12, x: 0, y: 6)
                }
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .opacity(buttonVisible ? 1 : 0)
                .scaleEffect(buttonVisible ? 1 : 0.85)
                .accessibilityLabel(String(localized: "celebration.continue_button.accessibility"))
            }
            .padding(.horizontal, 32)
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Stars row

    private var starsRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        index < stars
                            ? Color(hex: "#FFD93D")
                            : Color.white.opacity(0.3)
                    )
                    .shadow(
                        color: index < stars
                            ? Color(hex: "#FFD93D").opacity(0.6)
                            : .clear,
                        radius: 8, x: 0, y: 2
                    )
                    .scaleEffect(starPulse && index < stars ? 1.25 : 1.0)
                    .animation(
                        reduceMotion
                            ? .none
                            : MotionTokens.bounce.delay(Double(index) * 0.08),
                        value: starPulse
                    )
            }
        }
    }

    // MARK: - Computed

    private var titleText: String {
        switch stars {
        case 1: return String(localized: "celebration.title_star1")
        case 2: return String(localized: "celebration.title_star2")
        default: return String(localized: "celebration.title_star3")
        }
    }

    // MARK: - Animations sequence

    private func startAnimations() {
        // 1. Ляля влетает
        withAnimation(reduceMotion ? .none : MotionTokens.bounce) {
            mascotVisible = true
        }

        // 2. Текст и звёзды с небольшой задержкой
        let delay1 = reduceMotion ? 0.0 : MotionTokens.Duration.moderate
        DispatchQueue.main.asyncAfter(deadline: .now() + delay1) {
            withAnimation(reduceMotion ? .none : MotionTokens.spring) {
                textVisible = true
                starScale = 1.0
            }
            // Пульс звезды
            if !reduceMotion {
                withAnimation(
                    MotionTokens.bounce
                        .repeatCount(2, autoreverses: true)
                ) {
                    starPulse = true
                }
            }
        }

        // 3. Запуск конфетти через таймер
        if !reduceMotion {
            let timer = Timer.scheduledTimer(
                withTimeInterval: 1.0 / 60.0,
                repeats: true
            ) { t in
                confettiTick += 1
                if confettiTick > 180 { t.invalidate() }
            }
            RunLoop.main.add(timer, forMode: .common)
        }

        // 4. Кнопка появляется в конце
        let delay2 = reduceMotion ? 0.1 : MotionTokens.Duration.slow + MotionTokens.Duration.standard
        DispatchQueue.main.asyncAfter(deadline: .now() + delay2) {
            withAnimation(reduceMotion ? .none : MotionTokens.spring) {
                buttonVisible = true
            }
        }
    }
}

// MARK: - ConfettiCanvas

/// Canvas-конфетти: 50 частиц случайного цвета, физика свободного падения.
/// Обновляется через `tick` (каждый кадр).
private struct ConfettiCanvas: View {

    let tick: Int
    let palette: [Color]
    let particleCount: Int

    // Заранее сгенерированные параметры частиц (случайные, но детерминированные)
    private struct Particle {
        let startX: CGFloat
        let startY: CGFloat
        let vx: CGFloat   // скорость по X
        let vy: CGFloat   // начальная скорость по Y
        let size: CGFloat
        let colorIndex: Int
        let rotation: Double
        let rotationSpeed: Double
        let shape: Int    // 0=circle, 1=rect, 2=triangle
    }

    private let particles: [Particle]

    init(tick: Int, palette: [Color], particleCount: Int) {
        self.tick = tick
        self.palette = palette
        self.particleCount = particleCount

        var rng = SystemRandomNumberGenerator()
        var list: [Particle] = []
        for _ in 0..<particleCount {
            list.append(Particle(
                startX: CGFloat.random(in: 0...1, using: &rng),
                startY: CGFloat.random(in: -0.3...0, using: &rng),
                vx: CGFloat.random(in: -0.4...0.4, using: &rng),
                vy: CGFloat.random(in: 0.3...0.9, using: &rng),
                size: CGFloat.random(in: 6...12, using: &rng),
                colorIndex: Int.random(in: 0..<palette.count, using: &rng),
                rotation: Double.random(in: 0...360, using: &rng),
                rotationSpeed: Double.random(in: -6...6, using: &rng),
                shape: Int.random(in: 0...2, using: &rng)
            ))
        }
        self.particles = list
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let t = CGFloat(tick) / 60.0  // время в секундах

            Canvas { ctx, _ in
                for p in particles {
                    let x = (p.startX + p.vx * t).truncatingRemainder(dividingBy: 1) * w
                    let rawY = p.startY * h + p.vy * t * h + 0.5 * 0.3 * t * t * h
                    let y = rawY.truncatingRemainder(dividingBy: h + 40)

                    let alpha = max(0, 1 - max(0, t - 2.0) / 1.0)
                    let color = palette[p.colorIndex].opacity(alpha)

                    ctx.withCGContext { cgCtx in
                        cgCtx.saveGState()
                        cgCtx.translateBy(x: x, y: y)
                        cgCtx.rotate(by: CGFloat(
                            (p.rotation + p.rotationSpeed * Double(tick)).truncatingRemainder(dividingBy: 360)
                        ) * .pi / 180)
                        cgCtx.setFillColor(UIColor(color).cgColor)

                        switch p.shape {
                        case 0:
                            cgCtx.fillEllipse(in: CGRect(
                                x: -p.size / 2, y: -p.size / 2,
                                width: p.size, height: p.size
                            ))
                        case 1:
                            cgCtx.fill(CGRect(
                                x: -p.size / 2, y: -p.size / 4,
                                width: p.size, height: p.size / 2
                            ))
                        default:
                            let path = CGMutablePath()
                            path.move(to: CGPoint(x: 0, y: -p.size / 2))
                            path.addLine(to: CGPoint(x: p.size / 2, y: p.size / 2))
                            path.addLine(to: CGPoint(x: -p.size / 2, y: p.size / 2))
                            path.closeSubpath()
                            cgCtx.addPath(path)
                            cgCtx.fillPath()
                        }
                        cgCtx.restoreGState()
                    }
                }
            }
        }
    }
}

// MARK: - CGFloat.random(in:using:) helper

private extension CGFloat {
    static func random(in range: ClosedRange<CGFloat>, using rng: inout SystemRandomNumberGenerator) -> CGFloat {
        CGFloat(Double.random(in: Double(range.lowerBound)...Double(range.upperBound), using: &rng))
    }
}

// MARK: - Preview

#Preview("3 звезды") {
    ZStack {
        Color(hex: "#2C1A6B").ignoresSafeArea()
        CelebrationOverlayView(stars: 3) { }
    }
}

#Preview("1 звезда") {
    ZStack {
        Color(hex: "#1A3A2B").ignoresSafeArea()
        CelebrationOverlayView(stars: 1) { }
    }
}
