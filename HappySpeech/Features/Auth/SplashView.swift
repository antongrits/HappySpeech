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
    //
    // v27 visual modernization (#3): в light-режиме монотонный coral заменён
    // трёхцветным диагональным градиентом primary → primaryHi → rose —
    // задаёт современную планку с первого экрана.
    private var backgroundColors: [Color] {
        colorScheme == .dark
            ? [ColorTokens.Kid.bg, ColorTokens.Kid.bgDeep]
            : [ColorTokens.Brand.primary, ColorTokens.Brand.primaryHi, ColorTokens.Brand.rose]
    }

    var body: some View {
        ZStack {
            // Background gradient matching design tokens (Brand coral / dark).
            // v27: диагональный (topLeading → bottomTrailing) — даёт глубину.
            // Batch F: layered HSMeshGradientBackground (.calm softLight) на
            // диагональный gradient — даёт живой mesh-эффект под сплэшем.
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                .ignoresSafeArea()
                .blendMode(.softLight)
                .accessibilityHidden(true)

            // Decorative circles
            decorativeBackground

            // Diploma fix #13 — единый центрированный VStack для маскота +
            // заголовка + прогресс-бара (вместо тройной Spacer-mascot-Spacer-
            // Spacer-loading структуры, которая ломала вертикальную ось на
            // iPhone 17 Pro). Mascot всегда виден (через mascotScale), title
            // и loading появляются вместе через titleOpacity.
            VStack(alignment: .center, spacing: SpacingTokens.small) {
                HSMascotView(mood: .waving, size: 160)
                    .scaleEffect(mascotScale)
                    .padding(.bottom, SpacingTokens.sp6)

                Text("HappySpeech")
                    .font(TypographyTokens.kidDisplay(40))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .tracking(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .opacity(titleOpacity)

                Text(String(localized: "Говорим волшебно"))
                    .font(TypographyTokens.caption(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.bottom, SpacingTokens.sp8)
                    .opacity(titleOpacity)

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
                .opacity(titleOpacity)
            }
            .padding(.horizontal, SpacingTokens.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .depthShadow(ShadowTokens.kidDepth)
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
