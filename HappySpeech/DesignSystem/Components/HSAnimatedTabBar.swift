import SwiftUI

// MARK: - HSAnimatedTabBar
//
// Block O v16 — kavsoft-style анимированный tab bar.
//
// Кастомный tab bar с capsule-индикатором, который перелетает между табами
// через `matchedGeometryEffect`. Иконки SF Symbols на активном табе анимируются
// `.symbolEffect(.bounce)`. Поддерживает 2–5 табов, badge-уведомления.
//
// Usage:
// ```swift
// enum AppTab: String, CaseIterable {
//     case home, lessons, progress, settings
//     var icon: String { ... }
//     var title: LocalizedStringKey { ... }
// }
//
// @State private var selected: AppTab = .home
//
// HSAnimatedTabBar(selection: $selected, items: AppTab.allCases) { tab in
//     (tab.icon, tab.title)
// }
// ```
//
// References:
// - kavsoft.dev/matched_geometry_tabbar (matchedGeometryEffect pattern)
// - Apple Docs: matchedGeometryEffect
// - WWDC23: Build SwiftUI navigation hierarchies

@available(iOS 17.0, *)
public struct HSAnimatedTabBar<Item: Hashable>: View {

    // MARK: - Public API

    /// Текущее выбранное значение.
    @Binding public var selection: Item

    /// Список табов в порядке отображения (2–5 элементов).
    public let items: [Item]

    /// Конвертер таба в (SF Symbol, локализованный заголовок).
    public let labelProvider: (Item) -> (icon: String, title: LocalizedStringKey)

    /// Опциональное число badge-уведомлений на табе (например, новые домашние задания).
    public var badgeProvider: ((Item) -> Int?)?

    /// Показывать текстовую подпись у всех табов (а не только у выбранного).
    /// По умолчанию `false` — kavsoft-стиль (подпись только у активного таба).
    public var alwaysShowsLabels: Bool

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.circuitContext) private var circuit

    // MARK: - State

    @Namespace private var indicatorNamespace

    public init(
        selection: Binding<Item>,
        items: [Item],
        badgeProvider: ((Item) -> Int?)? = nil,
        alwaysShowsLabels: Bool = false,
        labelProvider: @escaping (Item) -> (icon: String, title: LocalizedStringKey)
    ) {
        self._selection = selection
        self.items = items
        self.badgeProvider = badgeProvider
        self.alwaysShowsLabels = alwaysShowsLabels
        self.labelProvider = labelProvider
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(items, id: \.self) { item in
                tabButton(for: item)
            }
        }
        .padding(.horizontal, SpacingTokens.tiny)
        .padding(.vertical, SpacingTokens.tiny)
        .background(barBackground)
        .clipShape(Capsule(style: .continuous))
        .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 18, x: 0, y: 8)
    }

    // MARK: - Tab Button

    @ViewBuilder
    private func tabButton(for item: Item) -> some View {
        let label = labelProvider(item)
        let isSelected = selection == item
        let badge = badgeProvider?(item) ?? 0

        Button {
            select(item)
        } label: {
            ZStack {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(accentColor)
                        .matchedGeometryEffect(id: "indicator", in: indicatorNamespace)
                }

                HStack(spacing: SpacingTokens.micro) {
                    Image(systemName: label.icon)
                        .font(.system(size: alwaysShowsLabels ? 16 : 18, weight: .semibold))
                        .symbolEffect(.bounce, value: isSelected)
                        .layoutPriority(1)
                        .overlay(alignment: .topTrailing) {
                            if badge > 0 {
                                badgeView(count: badge)
                                    .offset(x: 8, y: -6)
                            }
                        }

                    if isSelected || alwaysShowsLabels {
                        Text(label.title)
                            .font(TypographyTokens.labelRounded(
                                alwaysShowsLabels ? 12 : 14,
                                weight: .semibold
                            ))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .foregroundStyle(isSelected ? Color.white : inactiveTint)
                .padding(.horizontal, alwaysShowsLabels ? SpacingTokens.micro : SpacingTokens.regular)
                .padding(.vertical, SpacingTokens.small)
                // alwaysShowsLabels: все табы делят ширину поровну, чтобы на узком
                // экране (iPhone SE 3, 320pt) подпись помещалась целиком.
                .frame(maxWidth: alwaysShowsLabels ? .infinity : nil)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(badge > 0 ? Text("\(badge) новых") : Text(""))
    }

    // MARK: - Badge

    @ViewBuilder
    private func badgeView(count: Int) -> some View {
        ZStack {
            Capsule()
                .fill(ColorTokens.Semantic.error)
                .frame(minWidth: 16, idealHeight: 16)
            Text(count > 9 ? "9+" : "\(count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
        }
        .frame(height: 16)
    }

    // MARK: - Helpers

    private func select(_ item: Item) {
        guard selection != item else { return }
        if reduceMotion {
            selection = item
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
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

    private var inactiveTint: Color {
        switch circuit {
        case .kid:        return ColorTokens.Kid.inkMuted
        case .parent:     return ColorTokens.Parent.inkMuted
        case .specialist: return ColorTokens.Spec.inkMuted
        }
    }

    @ViewBuilder
    private var barBackground: some View {
        if #available(iOS 26.0, *) {
            // iOS 26 Liquid Glass — мягкий стеклянный bar.
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Preview

#Preview("HSAnimatedTabBar") {
    PreviewWrapper()
        .padding()
        .background(ColorTokens.Kid.bg)
}

@available(iOS 17.0, *)
private struct PreviewWrapper: View {
    enum DemoTab: String, CaseIterable, Hashable {
        case home, lessons, progress, settings

        var icon: String {
            switch self {
            case .home:     return "house.fill"
            case .lessons:  return "book.fill"
            case .progress: return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .home:     return "Дом"
            case .lessons:  return "Уроки"
            case .progress: return "Прогресс"
            case .settings: return "Настройки"
            }
        }
    }

    @State private var tab: DemoTab = .home

    var body: some View {
        VStack(spacing: 32) {
            Text("Выбран: \(String(describing: tab))")
                .font(TypographyTokens.body())

            HSAnimatedTabBar(
                selection: $tab,
                items: DemoTab.allCases,
                badgeProvider: { $0 == .progress ? 3 : nil }
            ) { tab in
                (tab.icon, tab.title)
            }
        }
        .environment(\.circuitContext, .kid)
    }
}
