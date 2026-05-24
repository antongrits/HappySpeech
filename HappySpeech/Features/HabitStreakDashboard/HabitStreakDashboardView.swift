import SwiftUI

// MARK: - HabitStreakDashboardView

struct HabitStreakDashboardView: View {

    let childId: String

    @State private var interactor: HabitStreakDashboardInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 4

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "habitStreak.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = HabitStreakDashboardInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    heatMap(interactor: interactor)
                    legend
                    if let day = interactor.state.selected {
                        detailCard(day: day)
                    }
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: HabitStreakDashboardModels.ViewState) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: SpacingTokens.tiny) {
                        Image(systemName: "flame.fill")
                            .font(TypographyTokens.title(20))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .hsSymbolEffect(.variableColor, value: state.currentStreak)
                            .accessibilityHidden(true)
                        Text(String(localized: "habitStreak.hero.title"))
                            .font(TypographyTokens.title(20))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    Text(String(localized: "habitStreak.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Text("Серия: \(state.currentStreak) дн · всего \(state.totalMinutes) мин")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func heatMap(interactor: HabitStreakDashboardInteractor) -> some View {
        HSCard(style: .elevated) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(0..<HabitStreakDashboardModels.ViewState.weeks, id: \.self) { week in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<HabitStreakDashboardModels.ViewState.daysPerWeek, id: \.self) { row in
                                let index = week * HabitStreakDashboardModels.ViewState.daysPerWeek + row
                                if index < interactor.state.days.count {
                                    cell(day: interactor.state.days[index], interactor: interactor)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func cell(
        day: HabitStreakDashboardModels.Day,
        interactor: HabitStreakDashboardInteractor
    ) -> some View {
        let isSelected = interactor.state.selected?.id == day.id
        return Button {
            hapticService.impact(.light)
            interactor.select(day)
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(intensityColor(day.intensity))
                .frame(width: cellSize, height: cellSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? ColorTokens.Brand.primary : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("День \(day.id), \(day.minutes) минут"))
        .accessibilityAddTraits(.isButton)
    }

    private func intensityColor(_ intensity: Int) -> Color {
        switch intensity {
        case 0:  return ColorTokens.Kid.surfaceAlt
        case 1:  return ColorTokens.Brand.mint.opacity(0.30)
        case 2:  return ColorTokens.Brand.mint.opacity(0.55)
        case 3:  return ColorTokens.Brand.mint.opacity(0.80)
        default: return ColorTokens.Brand.mint
        }
    }

    private var legend: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Text("Меньше")
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            ForEach(0..<5, id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 3)
                    .fill(intensityColor(intensity))
                    .frame(width: 14, height: 14)
            }
            Text("Больше")
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private func detailCard(day: HabitStreakDashboardModels.Day) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.10))) {
            VStack(alignment: .leading, spacing: 4) {
                Text("День \(day.id + 1) из \(HabitStreakDashboardModels.ViewState.weeks * HabitStreakDashboardModels.ViewState.daysPerWeek)")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(day.minutes > 0 ? "Практика: \(day.minutes) минут" : "Без практики")
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
    }

    private func cta(interactor: HabitStreakDashboardInteractor) -> some View {
        HSButton(
            String(localized: "habitStreak.cta.action"),
            style: .secondary,
            size: .large,
            icon: "arrow.uturn.left"
        ) {
            hapticService.impact(.light)
            interactor.clearSelection()
        }
    }
}

// MARK: - Preview

#Preview("HabitStreakDashboard — Light") {
    HabitStreakDashboardView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("HabitStreakDashboard — Dark") {
    HabitStreakDashboardView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
