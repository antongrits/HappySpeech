import ARKit
import SwiftUI

// MARK: - ARZoneViewComponents
//
// Основные подкомпоненты `ARZoneView`.
// Карточки и фильтры вынесены в `ARZoneViewCards.swift`.

// MARK: - Array safe subscript (используется в ARQuickTipsCarousel)

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - ARMascot2DFallback (iPhone SE и ошибки 3D-загрузки)

/// 2D эмодзи-фоллбэк маскота Ляли.
/// Используется на компактных устройствах (iPhone SE) и как визуальный placeholder.
struct ARMascot2DFallback: View {
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ColorTokens.Brand.lilac, ColorTokens.Brand.sky],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .shadow(color: ColorTokens.Brand.lilac.opacity(0.3), radius: 14, x: 0, y: 6)
            Image("mascot_lyalya_wave")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.7, height: size * 0.7)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .offset(y: bob)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(MotionTokens.idlePulse) {
                bob = -6
            }
        }
        .accessibilityLabel(Text("ar.zone.mascot.accessibility"))
    }
}

// MARK: - ARMascotLoadingPlaceholder

/// Пульсирующий круг — placeholder поверх 3D-вида пока USDZ загружается (~300 мс).
/// Автоматически скрывается через ARZonePhase == .ready.
struct ARMascotLoadingPlaceholder: View {
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0.6

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        ColorTokens.Brand.lilac.opacity(0.4),
                        ColorTokens.Brand.sky.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size * 0.85, height: size * 0.85)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    scale = 1.05
                    opacity = 0.35
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - ARHeroBanner

/// Hero-баннер на входе в AR-зону.
/// Содержит 3D Лялю (или 2D-фоллбэк), декоративные пульсирующие кольца и
/// gradient-фон sky → lilac (через `ColorTokens.Brand`).
/// Reduced Motion отключает кольца и тени.
struct ARHeroBanner: View {
    let isCompactDevice: Bool
    let mascotState: LyalyaAnimation
    let phase: ARZonePhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringScale: CGFloat = 0.9
    @State private var ringOpacity: Double = 0.55

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            ZStack {
                heroBackground
                pulseRings
                heroMascot
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
            .shadow(
                color: ColorTokens.Brand.sky.opacity(reduceMotion ? 0.0 : 0.25),
                radius: 16, x: 0, y: 8
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("ar.zone.mascot.accessibility"))

            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text("ar.zone.greeting")
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text("ar.zone.subtitle")
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, SpacingTokens.tiny)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                ringScale = 1.08
                ringOpacity = 0.25
            }
        }
    }

    private var heroBackground: some View {
        LinearGradient(
            colors: [
                ColorTokens.Brand.sky,
                ColorTokens.Brand.lilac
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var pulseRings: some View {
        if !reduceMotion {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 280, height: 280)
                    .scaleEffect(ringScale * 1.05)
                    .opacity(ringOpacity * 0.8)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var heroMascot: some View {
        ZStack {
            if isCompactDevice {
                ARMascot2DFallback(size: 160)
            } else {
                LyalyaRealityView(animation: mascotState, size: 220)
                if phase == .loading {
                    ARMascotLoadingPlaceholder(size: 220)
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - ARQuickTipsCarousel

/// Карусель «быстрых советов» — ротация раз в 4.5 сек.
/// При Reduced Motion смены не анимируются (резкая замена).
struct ARQuickTipsCarousel: View {
    let tips: [ARQuickTip]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var index: Int = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        let tip = tips[safe: index] ?? tips[0]
        HSLiquidGlassCard(
            style: .tinted(ColorTokens.Brand.sky.opacity(0.18)),
            padding: SpacingTokens.regular
        ) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: tip.icon)
                    .font(TypographyTokens.headline(20).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                Text(tip.text)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                tipDots
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .strokeBorder(
                    colorScheme == .light
                        ? ColorTokens.Brand.sky.opacity(0.40)
                        : Color.white.opacity(0.12),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(tip.text))
        .id(tip.id)
        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.97)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: index)
        .onAppear { startRotation() }
        .onDisappear { stopRotation() }
    }

    private var tipDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<tips.count, id: \.self) { i in
                Circle()
                    .fill(i == index
                          ? ColorTokens.Brand.primary
                          : ColorTokens.Brand.primary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func startRotation() {
        guard tips.count > 1 else { return }
        stopRotation()
        task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(4500))
                if Task.isCancelled { return }
                index = (index + 1) % tips.count
            }
        }
    }

    private func stopRotation() {
        task?.cancel()
        task = nil
    }
}

// MARK: - ARStartRecommendedButton

/// CTA «Начать AR-сессию» — стартует первую рекомендованную лёгкую игру.
/// Показывается только при `phase == .ready`.
struct ARStartRecommendedButton: View {
    let card: ARGameCard
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.regular) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Overlay.highlight)
                        .frame(width: 48, height: 48)
                    Image(systemName: "play.fill")
                        .font(TypographyTokens.headline(20).weight(.bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                .scaleEffect(pulse)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ar.zone.recommended.cta")
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(card.title)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(TypographyTokens.body(15).weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [ColorTokens.Brand.primary, ColorTokens.Brand.lilac],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(RadiusTokens.lg)
            .shadow(
                color: ColorTokens.Brand.primary.opacity(reduceMotion ? 0.0 : 0.32),
                radius: 12, x: 0, y: 6
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("ar.zone.recommended.cta"))
        .accessibilityHint(Text(card.title))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = 1.07
            }
        }
    }
}

// MARK: - InstructionStepCard

/// Карточка с одним шагом инструкции: номер + иконка + заголовок + текст.
/// Цветной индикатор слева — по `ARCardPalette` через `tintIndex`.
struct InstructionStepCard: View {
    let step: InstructionStep

    var body: some View {
        let palette = ARCardPalette.gradient(for: step.tintIndex)
        HSCard(style: .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.regular) {
                // Круглый бейдж с номером и иконкой
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: palette,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: step.icon)
                        .font(TypographyTokens.title(22).weight(.semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .topTrailing) {
                    Text("\(step.number)")
                        .font(TypographyTokens.body(11).weight(.bold))
                        .foregroundStyle(palette.first ?? ColorTokens.Brand.primary)
                        .padding(4)
                        .background(Circle().fill(Color.white))
                        .offset(x: 6, y: -6)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(step.title)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                    Text(step.body)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(step.number). \(step.title). \(step.body)"))
    }
}
