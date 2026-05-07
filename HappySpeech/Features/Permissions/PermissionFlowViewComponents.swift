import OSLog
import SwiftUI

// MARK: - PermissionFlowViewComponents
//
// Подкомпоненты permission-flow: ConfettiBurstView и Preview'ы.
// Извлечено из `PermissionFlowView.swift` (Block K.13 v16) для удержания LOC ≤700.
// Доступ к ConfettiBurstView — internal (был private).
// PermissionAccent/PermissionStepCard color-helpers оставлены в основном файле
// `PermissionFlowView.swift` как `private extension`, т.к. одноимённые
// расширения существуют в `PermissionsOverviewView.swift` — duplicate избегает
// invalid redeclaration на module-level.

// MARK: - ConfettiBurstView
//
// Простая SwiftUI-конфетти без сторонних либ. Используется только
// на финальном экране с `reduceMotion == false`.

struct ConfettiBurstView: View {

    let isActive: Bool

    @State private var animateParticles: Bool = false

    // Block D v16: эмодзи-частицы заменены на SF Symbol particles + tinted ColorTokens.
    private struct ConfettiParticle {
        let systemImage: String
        let tint: Color
        let xPosition: CGFloat
        let delay: Double
        let duration: Double
    }

    private let particles: [ConfettiParticle] = [
        ConfettiParticle(systemImage: "party.popper.fill", tint: ColorTokens.Brand.gold,
                         xPosition: 0.10, delay: 0.00, duration: 2.6),
        ConfettiParticle(systemImage: "star.fill", tint: ColorTokens.Brand.gold,
                         xPosition: 0.25, delay: 0.20, duration: 2.4),
        ConfettiParticle(systemImage: "sparkles", tint: ColorTokens.Brand.primary,
                         xPosition: 0.40, delay: 0.10, duration: 2.8),
        ConfettiParticle(systemImage: "star.fill", tint: ColorTokens.Brand.lilac,
                         xPosition: 0.55, delay: 0.30, duration: 2.5),
        ConfettiParticle(systemImage: "sparkle", tint: ColorTokens.Brand.sky,
                         xPosition: 0.70, delay: 0.05, duration: 2.7),
        ConfettiParticle(systemImage: "party.popper.fill", tint: ColorTokens.Brand.rose,
                         xPosition: 0.85, delay: 0.25, duration: 2.6),
        ConfettiParticle(systemImage: "star.fill", tint: ColorTokens.Brand.mint,
                         xPosition: 0.18, delay: 0.35, duration: 2.5),
        ConfettiParticle(systemImage: "sparkles", tint: ColorTokens.Brand.butter,
                         xPosition: 0.62, delay: 0.15, duration: 2.7)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles.indices, id: \.self) { idx in
                    let item = particles[idx]
                    Image(systemName: item.systemImage)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(item.tint)
                        .position(
                            x: proxy.size.width * item.xPosition,
                            y: animateParticles ? proxy.size.height + 40 : -40
                        )
                        .opacity(animateParticles ? 0.0 : 1.0)
                        .animation(
                            .easeIn(duration: item.duration).delay(item.delay),
                            value: animateParticles
                        )
                        .accessibilityHidden(true)
                }
            }
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            animateParticles = true
        }
        .onAppear {
            if isActive {
                animateParticles = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Permission - Microphone single") {
    NavigationStack {
        PermissionFlowView(type: .microphone)
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}

#Preview("Permission - Camera single") {
    NavigationStack {
        PermissionFlowView(type: .camera)
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}

#Preview("Permission - Sequential flow") {
    NavigationStack {
        PermissionFlowView(type: .microphone, sequential: true)
    }
    .environment(AppCoordinator())
    .environment(AppContainer.preview())
}
