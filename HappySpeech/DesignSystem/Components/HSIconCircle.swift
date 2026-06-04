import SwiftUI

// MARK: - HSIconCircle

/// Тёплый кружок-иконка (v32 design-modernisation, P4).
///
/// Заменяет серые SF Symbols в детском контуре: кружок с тёплой заливкой
/// `color.opacity(fillOpacity)` + SF Symbol поверх в `color`.
///
/// Используется в:
/// - `RoleSelectView` — иконка роли
/// - `SoundExplorerMapView` — чип звука
/// - `ProgressDashboardView` — иконки summary-карточек
/// - `DailyStreakView` — иконки milestone
/// - Настройках — иконки секций
/// - `HSEmptyStateView` — символ в варианте `.symbol`
///
/// ## Пример
/// ```swift
/// HSIconCircle(systemName: "flame.fill", size: 56, color: ColorTokens.Brand.gold)
///
/// HSIconCircle(
///     systemName: "person.2.fill",
///     size: 72,
///     color: ColorTokens.Brand.sky,
///     iconScale: 0.42
/// )
/// ```
///
/// ## See Also
/// - ``HSCard``
/// - ``ColorTokens``
public struct HSIconCircle: View {

    // MARK: - Properties

    let systemName: String
    /// Диаметр внешнего круга в pt. По умолчанию 44.
    let size: CGFloat
    /// Цвет иконки и основа для fill (opacity задаётся через `fillOpacity`).
    let color: Color
    /// Размер иконки как доля диаметра круга. По умолчанию 0.50.
    let iconScale: CGFloat
    /// Прозрачность заливки фона. По умолчанию 0.18 (spec P4).
    let fillOpacity: Double

    // MARK: - Init

    public init(
        systemName: String,
        size: CGFloat = 44,
        color: Color = ColorTokens.Brand.primary,
        iconScale: CGFloat = 0.50,
        fillOpacity: Double = 0.18
    ) {
        self.systemName = systemName
        self.size = size
        self.color = color
        self.iconScale = iconScale
        self.fillOpacity = fillOpacity
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(fillOpacity))
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .font(.system(size: size * iconScale, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("HSIconCircle") {
    VStack(spacing: SpacingTokens.regular) {
        HStack(spacing: SpacingTokens.regular) {
            HSIconCircle(
                systemName: "star.fill",
                size: 56,
                color: ColorTokens.Brand.primary
            )
            HSIconCircle(
                systemName: "flame.fill",
                size: 56,
                color: ColorTokens.Brand.gold
            )
            HSIconCircle(
                systemName: "sparkles",
                size: 56,
                color: ColorTokens.Brand.lilac
            )
        }

        HStack(spacing: SpacingTokens.regular) {
            HSIconCircle(
                systemName: "person.2.fill",
                size: 72,
                color: ColorTokens.Brand.sky,
                iconScale: 0.42
            )
            HSIconCircle(
                systemName: "stethoscope",
                size: 72,
                color: ColorTokens.Brand.lilac,
                iconScale: 0.45
            )
            HSIconCircle(
                systemName: "star.fill",
                size: 72,
                color: ColorTokens.Brand.primary,
                iconScale: 0.45
            )
        }

        HStack(spacing: SpacingTokens.regular) {
            HSIconCircle(systemName: "calendar", size: 44, color: ColorTokens.Brand.rose)
            HSIconCircle(systemName: "chart.bar.fill", size: 44, color: ColorTokens.Brand.butter)
            HSIconCircle(systemName: "clock.fill", size: 44, color: ColorTokens.Brand.gold)
            HSIconCircle(systemName: "waveform", size: 44, color: ColorTokens.Brand.lilac)
        }
    }
    .padding(SpacingTokens.screenEdge)
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}
