import SwiftUI

// MARK: - SplashView

struct SplashView: View {
    @State private var mascotScale: CGFloat = 0.3
    @State private var titleOpacity: Double = 0
    @State private var progressWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background gradient matching tokens.jsx
            LinearGradient(
                colors: [
                    Color(hex: "#F4572A"),
                    Color(hex: "#C13818")
                ],
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
                        .foregroundStyle(.white)
                        .tracking(-1)

                    Text(String(localized: "Говорим волшебно"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(2.5)
                        .textCase(.uppercase)
                }
                .opacity(titleOpacity)

                Spacer()
                Spacer()

                // Loading bar
                VStack(spacing: SpacingTokens.sp3) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.25))
                            .frame(width: 80, height: 3)
                        Capsule()
                            .fill(.white)
                            .frame(width: progressWidth * 80, height: 3)
                    }

                    Text(String(localized: "Загрузка..."))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, SpacingTokens.sp16)
                .opacity(titleOpacity)
            }
        }
        .onAppear { animateIn() }
        .accessibilityLabel("HappySpeech. Загрузка...")
    }

    private var decorativeBackground: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 280, height: 280)
                .offset(x: -80, y: -200)

            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 200, height: 200)
                .offset(x: 120, y: 100)

            Circle()
                .fill(.white.opacity(0.05))
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
