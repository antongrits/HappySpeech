import SwiftUI

// MARK: - HSParentTabBar

/// Parent-circuit tab bar. Uses system-style compact design
/// (no pill, icon+label, neutral colours) suited to the structured parent contour.
/// Height 56pt + bottom safe area. Touch targets ≥ 56pt (standard).
public struct HSParentTabBar: View {

    // MARK: - Tab Definition

    public enum ParentTab: String, CaseIterable, Identifiable {
        case home
        case soundMap
        case history
        case settings

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .home:     return "house"
            case .soundMap: return "map"
            case .history:  return "clock"
            case .settings: return "gearshape"
            }
        }

        public var selectedIcon: String {
            switch self {
            case .home:     return "house.fill"
            case .soundMap: return "map.fill"
            case .history:  return "clock.fill"
            case .settings: return "gearshape.fill"
            }
        }

        public var label: String {
            switch self {
            case .home:     return String(localized: "Главная")
            case .soundMap: return String(localized: "Карта звуков")
            case .history:  return String(localized: "История")
            case .settings: return String(localized: "Настройки")
            }
        }
    }

    // MARK: - Properties

    @Binding var selection: ParentTab
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barHeight: CGFloat = 56

    // MARK: - Init

    public init(selection: Binding<ParentTab>) {
        self._selection = selection
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(ColorTokens.Parent.line)

            HStack(spacing: 0) {
                ForEach(ParentTab.allCases) { tab in
                    tabItem(for: tab)
                }
            }
            .frame(height: barHeight)
            .background(ColorTokens.Parent.bg)
        }
        .safeAreaPadding(.bottom)
    }

    // MARK: - Tab Item

    private func tabItem(for tab: ParentTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(reduceMotion ? nil : MotionTokens.outQuick) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ColorTokens.Parent.accent : ColorTokens.Parent.inkMuted)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ColorTokens.Parent.accent : ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "" : String(localized: "Переключиться на \(tab.label)"))
    }
}

// MARK: - Preview

#Preview("HSParentTabBar") {
    @Previewable @State var tab = HSParentTabBar.ParentTab.home

    ZStack(alignment: .bottom) {
        ColorTokens.Parent.bg.ignoresSafeArea()

        VStack {
            Text("Выбрана: \(tab.label)")
                .font(TypographyTokens.body())
                .padding()
            Spacer()
        }

        HSParentTabBar(selection: $tab)
    }
    .environment(\.circuitContext, .parent)
}
