import os.signpost
import SwiftUI

// MARK: - SplashView

/// Заставка приложения — первое впечатление. Тёплый кремовый бренд-канвас
/// (light) / глубокий тёмный фон (dark), маскот Ляля по центру, вордмарк
/// «HappySpeech» с коралловым акцентом, слоган и мягкий точечный лоадер.
///
/// Дизайн-эталон: `references/auth.html` (Splash · светлая/тёмная).
struct SplashView: View {
    @State private var mascotScale: CGFloat = 0.6
    @State private var titleOpacity: Double = 0
    @State private var loaderPhase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Тёплый монотонный бренд-фон (cream / dark) — без off-palette
            // градиентов. Лёгкий радиальный «купол» добавляет глубину,
            // оставаясь в кремовой палитре.
            backgroundLayer

            VStack(spacing: SpacingTokens.sp2) {
                Spacer()

                HSMascotView(mood: .waving, size: 132)
                    .scaleEffect(mascotScale)
                    .accessibilityHidden(true)

                wordmark
                    .opacity(titleOpacity)
                    .padding(.top, SpacingTokens.sp3)

                Text(String(localized: "auth.tagline"))
                    .font(TypographyTokens.body(14).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .opacity(titleOpacity)

                Spacer()

                loader
                    .opacity(titleOpacity)
                    .padding(.bottom, SpacingTokens.sp12)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
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
        .task {
            // .task авто-отменяется при исчезновении экрана — не утечёт.
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                loaderPhase = (loaderPhase + 1) % 3
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HappySpeech. " + String(localized: "Загрузка..."))
        .accessibilityIdentifier("SplashRoot")
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        ZStack {
            ColorTokens.Kid.bg
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    ColorTokens.Kid.bgSoft,
                    ColorTokens.Kid.bg,
                    ColorTokens.Kid.bgDeep
                ],
                center: .init(x: 0.5, y: 0.32),
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    private var wordmark: some View {
        (
            Text("Happy").foregroundStyle(ColorTokens.Kid.ink)
            + Text("Speech").foregroundStyle(ColorTokens.Brand.primary)
        )
        .font(TypographyTokens.kidDisplay(38))
        .tracking(-0.8)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .shadow(color: ColorTokens.Brand.primary.opacity(0.16), radius: 8, x: 0, y: 3)
    }

    // Три коралловые точки, мягко «подпрыгивающие» по очереди — повторяет
    // лоадер из эталона. Под Reduce Motion остаются статичными приглушёнными.
    private var loader: some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(ColorTokens.Brand.primary)
                    .frame(width: 9, height: 9)
                    .opacity(loaderPhase == index ? 1 : 0.3)
                    .scaleEffect(loaderPhase == index ? 1.0 : 0.78)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: loaderPhase)
        .accessibilityHidden(true)
    }

    // MARK: - Animation

    private func animateIn() {
        guard !reduceMotion else {
            mascotScale = 1.0
            titleOpacity = 1.0
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.62).delay(0.1)) {
            mascotScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.45)) {
            titleOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Splash — Light") {
    SplashView()
        .preferredColorScheme(.light)
}

#Preview("Splash — Dark") {
    SplashView()
        .preferredColorScheme(.dark)
}
