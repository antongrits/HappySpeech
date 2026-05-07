import SwiftUI

// MARK: - HSSegmentedPicker
//
// Block O v16 — кастомный сегментированный контрол с capsule-индикатором.
//
// Generic-контрол на любые `CaseIterable & Hashable` enum'ы. Capsule-индикатор
// перелетает между сегментами через `matchedGeometryEffect`. Поддерживает три
// варианта оформления: `.capsule` (kid), `.underline` (parent), `.solid` (specialist).
//
// Usage:
// ```swift
// enum Mode: String, CaseIterable, Hashable {
//     case daily, weekly, monthly
//     var localizedTitle: LocalizedStringKey { ... }
// }
//
// @State private var mode: Mode = .daily
//
// HSSegmentedPicker(selection: $mode, items: Mode.allCases) { $0.localizedTitle }
// ```
//
// References:
// - nilcoalescing.com — matchedGeometryEffect segmented control
// - kavsoft.dev/animated_elastic_tab_bar
// - Apple Docs: Picker

@available(iOS 17.0, *)
public struct HSSegmentedPicker<Item: Hashable>: View {

    // MARK: - Style

    public enum Style {
        /// Capsule-индикатор поверх сегмента — kid и default.
        case capsule
        /// Тонкая underline-полоса под активным сегментом — parent.
        case underline
        /// Solid-фон, индикатор — outlined rounded rect, specialist.
        case solid
    }

    // MARK: - Public API

    @Binding public var selection: Item
    public let items: [Item]
    public let style: Style
    public let titleProvider: (Item) -> LocalizedStringKey

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.circuitContext) private var circuit
    @Environment(\.hapticService) private var hapticService

    // MARK: - State

    @Namespace private var indicatorNS

    public init(
        selection: Binding<Item>,
        items: [Item],
        style: Style = .capsule,
        titleProvider: @escaping (Item) -> LocalizedStringKey
    ) {
        self._selection = selection
        self.items = items
        self.style = style
        self.titleProvider = titleProvider
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                segment(for: item)
            }
        }
        .padding(style == .capsule ? SpacingTokens.micro : 0)
        .background(trackBackground)
        .clipShape(trackShape)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Segment

    @ViewBuilder
    private func segment(for item: Item) -> some View {
        let isSelected = selection == item

        Button {
            select(item)
        } label: {
            ZStack {
                if isSelected {
                    indicator
                        .matchedGeometryEffect(id: "indicator", in: indicatorNS)
                }

                Text(titleProvider(item))
                    .font(TypographyTokens.labelRounded(14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(isSelected ? selectedTextColor : inactiveTextColor)
                    .padding(.vertical, SpacingTokens.small)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titleProvider(item))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Indicator

    @ViewBuilder
    private var indicator: some View {
        switch style {
        case .capsule:
            Capsule(style: .continuous)
                .fill(accentColor)
                .shadow(color: accentColor.opacity(0.30), radius: 8, x: 0, y: 4)
        case .underline:
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(accentColor)
                    .frame(height: 2)
            }
        case .solid:
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .strokeBorder(accentColor, lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(accentColor.opacity(0.15))
                )
        }
    }

    // MARK: - Track Background

    @ViewBuilder
    private var trackBackground: some View {
        switch style {
        case .capsule:
            Capsule(style: .continuous)
                .fill(trackFill)
        case .underline:
            Rectangle()
                .fill(Color.clear)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(ColorTokens.Overlay.separator)
                        .frame(height: 1)
                }
        case .solid:
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(trackFill)
        }
    }

    private var trackShape: AnyShape {
        switch style {
        case .capsule:
            return AnyShape(Capsule(style: .continuous))
        case .underline:
            return AnyShape(Rectangle())
        case .solid:
            return AnyShape(RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func select(_ item: Item) {
        guard selection != item else { return }
        hapticService.selection()
        if reduceMotion {
            selection = item
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selection = item
            }
        }
    }

    private var accentColor: Color {
        switch circuit {
        case .kid:        return ColorTokens.Brand.primary
        case .parent:     return ColorTokens.Parent.accent
        case .specialist: return ColorTokens.Spec.accent
        }
    }

    private var trackFill: Color {
        switch circuit {
        case .kid:        return ColorTokens.Kid.surfaceAlt
        case .parent:     return ColorTokens.Parent.surface
        case .specialist: return ColorTokens.Spec.panel
        }
    }

    private var selectedTextColor: Color {
        switch style {
        case .capsule: return .white
        case .underline, .solid: return accentColor
        }
    }

    private var inactiveTextColor: Color {
        switch circuit {
        case .kid:        return ColorTokens.Kid.inkMuted
        case .parent:     return ColorTokens.Parent.inkMuted
        case .specialist: return ColorTokens.Spec.inkMuted
        }
    }
}

// MARK: - Preview

#Preview("HSSegmentedPicker") {
    PickerPreview()
        .padding()
}

@available(iOS 17.0, *)
private struct PickerPreview: View {
    enum DemoMode: String, CaseIterable, Hashable {
        case daily, weekly, monthly

        var title: LocalizedStringKey {
            switch self {
            case .daily:   return "День"
            case .weekly:  return "Неделя"
            case .monthly: return "Месяц"
            }
        }
    }

    @State private var mode: DemoMode = .daily

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Text("Стиль capsule (kid)").font(TypographyTokens.caption())
            HSSegmentedPicker(selection: $mode, items: DemoMode.allCases, style: .capsule) { $0.title }
                .environment(\.circuitContext, .kid)

            Text("Стиль underline (parent)").font(TypographyTokens.caption())
            HSSegmentedPicker(selection: $mode, items: DemoMode.allCases, style: .underline) { $0.title }
                .environment(\.circuitContext, .parent)

            Text("Стиль solid (specialist)").font(TypographyTokens.caption())
            HSSegmentedPicker(selection: $mode, items: DemoMode.allCases, style: .solid) { $0.title }
                .environment(\.circuitContext, .specialist)
        }
    }
}
