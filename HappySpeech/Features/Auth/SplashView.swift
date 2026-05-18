import os.signpost
import SwiftUI

// MARK: - SplashView

struct SplashView: View {
    @State private var mascotScale: CGFloat = 0.3
    @State private var titleOpacity: Double = 0
    @State private var progressWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // D-7 v27 — splash-фон адаптируется к тёмной теме: в dark вместо
    // яркого кораллового градиента используется глубокий тёмный фон,
    // чтобы splash не «светил» оранжевым на тёмной системе.
    private var backgroundColors: [Color] {
        colorScheme == .dark
            ? [ColorTokens.Kid.bg, ColorTokens.Kid.bgDeep]
            : [ColorTokens.Brand.primary, ColorTokens.Brand.primaryHi]
    }

    var body: some View {
        ZStack {
            // Background gradient matching design tokens (Brand coral / dark).
            LinearGradient(
                colors: backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Decorative circles
            decorativeBackground

            VStack(spacing: 0) {
                Spacer()

                // Mascot
                HSMascotView(mood: .celebrating, size: 160)
                    .scaleEffect(mascotScale)
                    .padding(.bottom, SpacingTokens.sp8)

                // Title
                VStack(spacing: SpacingTokens.sp2) {
                    Text("HappySpeech")
                        .font(TypographyTokens.kidDisplay(40))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .tracking(-1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(String(localized: "Говорим волшебно"))
                        .font(TypographyTokens.caption(13).weight(.semibold))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, SpacingTokens.medium)
                .opacity(titleOpacity)

                Spacer()
                Spacer()

                // Loading bar
                VStack(spacing: SpacingTokens.sp3) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ColorTokens.Overlay.onAccent.opacity(0.25))
                            .frame(width: 80, height: 3)
                        Capsule()
                            .fill(ColorTokens.Overlay.onAccent)
                            .frame(width: progressWidth * 80, height: 3)
                    }

                    Text(String(localized: "Загрузка..."))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.5))
                }
                // sp16 = 64pt — специфичное расстояние до loading bar. Проверено визуально.
                .padding(.bottom, SpacingTokens.sp16)
                .opacity(titleOpacity)
            }
        }
        .onAppear {
            // Plan v22 Block 0.5 — Splash жизненный цикл (Instruments POI event).
            os_signpost(.event,
                        log: HSSignpost.pointsOfInterest,
                        name: "LaunchScreenAppear")
            animateIn()
        }
        .onDisappear {
            os_signpost(.event,
                        log: HSSignpost.pointsOfInterest,
                        name: "LaunchScreenDisappear")
        }
        .accessibilityLabel("HappySpeech. Загрузка...")
        .accessibilityIdentifier("SplashRoot")
    }

    private var decorativeBackground: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Overlay.glass)
                .frame(width: 280, height: 280)
                .offset(x: -80, y: -200)

            Circle()
                .fill(ColorTokens.Overlay.glass)
                .frame(width: 200, height: 200)
                .offset(x: 120, y: 100)

            Circle()
                .fill(ColorTokens.Overlay.glass)
                .frame(width: 160, height: 160)
                .offset(x: 100, y: -280)
        }
    }

    private func animateIn() {
        if reduceMotion {
            mascotScale = 1.0
            titleOpacity = 1.0
            progressWidth = 1.0
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.2)) {
            mascotScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            titleOpacity = 1.0
        }
        withAnimation(.linear(duration: 1.6).delay(0.8)) {
            progressWidth = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Splash") {
    SplashView()
}
