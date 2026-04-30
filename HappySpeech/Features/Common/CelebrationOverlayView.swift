import SwiftUI

// MARK: - CelebrationOverlayView
//
// Полноэкранный overlay «отличная работа» — без видеофайлов, чистый SwiftUI.
//
// Состав:
//   1. Конфетти (ConfettiEmitterCanvas, TimelineView+Canvas, 60 fps)
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
    @State private var buttonVisible: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // confettiStyle определяет тип конфетти в зависимости от звёзд.
    private var confettiStyle: ConfettiEmitterView.Style {
        stars >= 3 ? .perfect : .celebration
    }

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

            // Конфетти слой через ConfettiEmitterView (только при reduceMotion == false)
            if !reduceMotion {
                ConfettiEmitterView(style: confettiStyle)
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

        // 3. Кнопка появляется в конце (конфетти запускается через ConfettiEmitterCanvas.onAppear)
        let delay2 = reduceMotion ? 0.1 : MotionTokens.Duration.slow + MotionTokens.Duration.standard
        DispatchQueue.main.asyncAfter(deadline: .now() + delay2) {
            withAnimation(reduceMotion ? .none : MotionTokens.spring) {
                buttonVisible = true
            }
        }
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
