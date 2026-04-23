import SwiftUI

// MARK: - HSKidTabBar

/// Child-circuit tab bar rendered as a pill-shaped floating bar.
/// Does not use the system UITabBar — fully custom SwiftUI.
/// Height 72pt + bottom safe area inset.
/// Selected tab: coral fill with white icon.
/// Unselected tab: clear fill with muted grey icon.
public struct HSKidTabBar: View {

    // MARK: - Tab Definition

    public enum KidTab: String, CaseIterable, Identifiable {
        case home
        case arZone
        case rewards
        case settings

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .home:     return "house.fill"
            case .arZone:   return "camera.viewfinder"
            case .rewards:  return "star.fill"
            case .settings: return "gearshape.fill"
            }
        }

        public var label: String {
            switch self {
            case .home:     return String(localized: "Главная")
            case .arZone:   return String(localized: "АР-зона")
            case .rewards:  return String(localized: "Награды")
            case .settings: return String(localized: "Настройки")
            }
        }
    }

    // MARK: - Properties

    @Binding var selection: KidTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedSelection: KidTab

    private let barHeight:    CGFloat = 72
    private let iconSize:     CGFloat = 26
    private let labelSize:    CGFloat = 10
    private let itemMinWidth: CGFloat = 56  // minimum touch target

    // MARK: - Init

    public init(selection: Binding<KidTab>) {
        self._selection = selection
        self._animatedSelection = State(initialValue: selection.wrappedValue)
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()
                barContent
                    .padding(.bottom, geo.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .frame(height: barHeight + 34)  // 34 ≈ typical bottom safe area
    }

    private var barContent: some View {
        HStack(spacing: 0) {
            ForEach(KidTab.allCases) { tab in
                tabItem(for: tab)
            }
        }
        .frame(height: barHeight)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: -4)
        )
        .padding(.horizontal, SpacingTokens.sp5)
    }

    // MARK: - Tab Item

    private func tabItem(for tab: KidTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(reduceMotion ? nil : MotionTokens.spring) {
                selection = tab
                animatedSelection = tab
            }
        } label: {
            VStack(spacing: SpacingTokens.sp1) {
                ZStack {
                    // Pill background for selected tab
                    if isSelected {
                        Capsule()
                            .fill(ColorTokens.Brand.primary)
                            .frame(width: 52, height: 36)
                            .matchedGeometryEffect(id: "kidTabPill", in: Namespace().wrappedValue)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : ColorTokens.Kid.inkMuted)
                        .symbolEffect(.bounce, value: isSelected)
                        .frame(width: 52, height: 36)
                }

                Text(tab.label)
                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minWidth: itemMinWidth, minHeight: itemMinWidth)
        .contentShape(Rectangle())
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "" : String(localized: "Переключиться на \(tab.label)"))
    }
}

// MARK: - Preview

#Preview("HSKidTabBar") {
    @Previewable @State var tab = HSKidTabBar.KidTab.home

    ZStack(alignment: .bottom) {
        ColorTokens.Kid.bg.ignoresSafeArea()

        VStack {
            Text("Выбрана вкладка: \(tab.label)")
                .font(TypographyTokens.headline())
                .padding()
            Spacer()
        }

        HSKidTabBar(selection: $tab)
    }
    .environment(\.circuitContext, .kid)
}
