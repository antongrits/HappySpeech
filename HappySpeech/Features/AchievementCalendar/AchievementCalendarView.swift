import SwiftUI

// MARK: - AchievementCalendarView

struct AchievementCalendarView: View {

    let childId: String

    @State private var interactor: AchievementCalendarInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: SpacingTokens.sp1),
        count: 7
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "achievementCalendar.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = AchievementCalendarInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .parent)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    calendarGrid(interactor: interactor)
                    if let entry = interactor.selectedEntry, entry.achievementCount > 0 {
                        selectedDayCard(entry)
                    }
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: AchievementCalendarModels.ViewState) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "achievementCalendar.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "achievementCalendar.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                HStack {
                    Text(state.month)
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Parent.accent)
                    Spacer()
                    Text("Всего: \(state.totalAchievements)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                .padding(.top, 4)
            }
        }
    }

    private func calendarGrid(interactor: AchievementCalendarInteractor) -> some View {
        HSCard(style: .flat) {
            LazyVGrid(columns: columns, spacing: SpacingTokens.sp1) {
                ForEach(interactor.state.days) { entry in
                    dayCell(entry, isSelected: entry.day == interactor.state.selectedDay) {
                        hapticService.impact(.light)
                        interactor.selectDay(entry.day)
                    }
                }
            }
        }
    }

    private func dayCell(
        _ entry: AchievementCalendarModels.DayEntry,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(entry.day)")
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.ink)
                if entry.achievementCount > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<min(entry.achievementCount, 4), id: \.self) { _ in
                            Circle()
                                .fill(ColorTokens.Brand.primary)
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? ColorTokens.Parent.accent.opacity(0.20)
                            : ColorTokens.Parent.surface
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("День \(entry.day), \(entry.achievementCount) достижений"))
        .accessibilityAddTraits(.isButton)
    }

    private func selectedDayCard(_ entry: AchievementCalendarModels.DayEntry) -> some View {
        HSCard(style: .tinted(ColorTokens.Parent.accent.opacity(0.10))) {
            VStack(alignment: .leading, spacing: 6) {
                Text("День \(entry.day)")
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.accent)
                Text(entry.topAchievement ?? "—")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text("Всего: \(entry.achievementCount)")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "achievementCalendar.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("AchievementCalendar — Light") {
    AchievementCalendarView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("AchievementCalendar — Dark") {
    AchievementCalendarView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
