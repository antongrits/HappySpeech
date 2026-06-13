import SwiftUI

// MARK: - ARCameraOverlay
//
// Тёплый HUD-«chrome» поверх живого камера-фида для AR-артикуляционных игр
// (эталон happyspeech-design/references/ar-camera). Состоит из переиспользуемых
// кусочков, которые накладываются на ARView/3D-сцену, НЕ закрывая её сплошным
// фоном:
//   • ARTaskPill        — верхняя инструкция-карточка с иконкой-Лялей и целью
//   • ARTrueDepthFallbackBanner — дружелюбная плашка «играем по обычной камере»
//   • ARMascotGuide     — Ляля + речевая подсказка в левом-нижнем углу
//   • ARControlPanel     — нижняя стеклянная панель с подсказкой удержания,
//                          кольцом-прогрессом и боковыми кнопками
//
// Все поверхности — `.ultraThinMaterial`/тёплый scrim, токены тёплой палитры,
// читаемый контраст в light/dark. Никаких off-palette крупных заливок.

// MARK: - ARTaskPill

/// Верхняя инструкция-карточка: иконка-Ляля в коралловом квадрате + цель урока +
/// опциональный счёт-звёзды справа. Лежит на стеклянной подложке поверх камеры.
struct ARTaskPill: View {

    let iconSystemName: String
    let title: String
    let subtitle: String?
    let scoreText: String?
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconBox: CGFloat = 32

    var body: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1))
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Circle())
            .accessibilityLabel(Text("common.close"))

            HStack(spacing: SpacingTokens.tiny) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(width: iconBox, height: iconBox)
                    .background(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryLo, ColorTokens.Brand.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, SpacingTokens.tiny)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(subtitle.map { "\(title), \($0)" } ?? title))

            if let scoreText {
                ARStarChip(text: scoreText)
            }
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.top, SpacingTokens.small)
    }
}

// MARK: - ARStarChip

/// Стеклянная плашка-счётчик звёзд справа в HUD.
private struct ARStarChip: View {
    let text: String

    var body: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)
            Text(text)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, SpacingTokens.small)
        .frame(height: 46)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("ar.hud.stars \(text)"))
    }
}

// MARK: - ARTrueDepthFallbackBanner

/// Дружелюбная плашка: TrueDepth недоступен — играем по обычной камере / в
/// тренировочном режиме. Не пугающая ошибка, а спокойное уведомление.
struct ARTrueDepthFallbackBanner: View {
    var body: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .accessibilityHidden(true)
            Text("ar.fallback.noTrueDepth")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.micro + 2)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(ColorTokens.Brand.lilac.opacity(0.45), lineWidth: 1))
        .padding(.horizontal, SpacingTokens.regular)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("ar.fallback.noTrueDepth"))
    }
}

// MARK: - ARMascotGuide

/// Маскот Ляля + речевая подсказка в нижнем-левом углу поверх камеры.
struct ARMascotGuide: View {

    let state: LyalyaState
    let message: String
    let detail: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.tiny) {
            LyalyaMascotView(state: state, size: 64)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, SpacingTokens.tiny)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
            )
        }
        .frame(maxWidth: 280, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(detail.map { "\(message). \($0)" } ?? message))
    }
}

// MARK: - ARControlPanel

/// Нижняя стеклянная панель управления: подсказка-удержание сверху, по центру —
/// большое кольцо-прогресс с центральной кнопкой, по бокам — вспомогательные
/// круглые кнопки (повторить звук / следующий-флип). Кольцо-прогресс показывает
/// `progress` (0…1); при `isSuccess` центр и кольцо переходят в мятный акцент.
struct ARControlPanel<Leading: View, Trailing: View>: View {

    let hintText: String
    let isSuccess: Bool
    let progress: Float
    /// Действие центральной кнопки. `nil` → кольцо-прогресс пассивное (hands-free
    /// режим: удержание лица оценивается автоматически, нажимать нечего).
    let centerAction: (() -> Void)?
    let centerAccessibilityLabel: String
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.micro + 2) {
                if isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .accessibilityHidden(true)
                } else if !reduceMotion {
                    PulseDot()
                }
                Text(hintText)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(isSuccess ? ColorTokens.Brand.mint : ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: SpacingTokens.large) {
                leading()
                ARCaptureRing(
                    progress: progress,
                    isSuccess: isSuccess,
                    action: centerAction,
                    accessibilityLabel: centerAccessibilityLabel
                )
                trailing()
            }
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.regular)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
        )
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.bottom, SpacingTokens.regular)
    }
}

// MARK: - ARCaptureRing

/// Центральная кнопка-кольцо с прогрессом удержания позы.
private struct ARCaptureRing: View {

    let progress: Float
    let isSuccess: Bool
    let action: (() -> Void)?
    let accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: CGFloat { CGFloat(min(max(progress, 0), 1)) }
    private var ringColor: Color { isSuccess ? ColorTokens.Brand.mint : ColorTokens.Brand.primary }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ColorTokens.Overlay.highlight, lineWidth: 6)
            Circle()
                .trim(from: 0, to: isSuccess ? 1 : clamped)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: clamped)

            if let action {
                Button(action: action) { core }
                    .accessibilityLabel(Text(accessibilityLabel))
            } else {
                core
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 100, height: 100)
    }

    private var core: some View {
        Group {
            if isSuccess {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            } else {
                Circle()
                    .fill(ColorTokens.Overlay.onAccent.opacity(0.95))
                    .frame(width: 28, height: 28)
            }
        }
        .frame(width: 76, height: 76)
        .background(
            RadialGradient(
                colors: isSuccess
                    ? [ColorTokens.Brand.mint.opacity(0.9), ColorTokens.Brand.mint]
                    : [ColorTokens.Brand.primaryLo, ColorTokens.Brand.primary],
                center: .topLeading,
                startRadius: 4,
                endRadius: 84
            ),
            in: Circle()
        )
    }
}

// MARK: - PulseDot

/// Мягко пульсирующая точка-индикатор «идёт удержание» (учитывает Reduce Motion
/// на уровне родителя — этот вид показывается только когда движение разрешено).
private struct PulseDot: View {
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(ColorTokens.Brand.primary)
            .frame(width: 9, height: 9)
            .overlay(
                Circle()
                    .stroke(ColorTokens.Brand.primary.opacity(0.5), lineWidth: 2)
                    .scaleEffect(animate ? 2.2 : 1)
                    .opacity(animate ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
            .accessibilityHidden(true)
    }
}
