import SwiftUI

// MARK: - AchievementCalendarView

struct AchievementCalendarView: View {

    let childId: String

    @State private var interactor: AchievementCalendarInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: SpacingTokens.sp1),
        count: 7
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "achievementCalendar.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToParentHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let new = AchievementCalendarInteractor(
                        childId: childId,
                        sessionRepository: container.sessionRepository
                    )
                    interactor = new
                    new.refresh()
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
                    if !interactor.state.hasAnyAchievements {
                        emptyState
                    }
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
        HSLiquidGlassCard(style: .elevated) {
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

    private var emptyState: some View {
        HSCard(style: .flat) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
                Text(String(localized: "achievementCalendar.empty.title"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                Text(String(localized: "achievementCalendar.empty.subtitle"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp2)
        }
        .accessibilityElement(children: .combine)
    }

    private func calendarGrid(interactor: AchievementCalendarInteractor) -> some View {
        // P1.4: контейнер сетки — celebrationGold (тёплый, золотой тон).
        HSCard(style: .gradientTinted(GradientTokens.cardGold)) {
            LazyVGrid(columns: columns, spacing: SpacingTokens.sp1) {
                ForEach(Array(interactor.state.days.enumerated()), id: \.element.id) { index, entry in
                    dayCell(entry, isSelected: entry.day == interactor.state.selectedDay) {
                        hapticService.impact(.light)
                        interactor.selectDay(entry.day)
                    }
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.9)
                    }
                    .hsParallaxTile(factor: 0.18)
                    .zIndex(Double(interactor.state.days.count - index))
                }
            }
        }
    }

    private func dayCell(
        _ entry: AchievementCalendarModels.DayEntry,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        // P1.4: achieved days → Brand.gold filled; current → Brand.primary ring.
        let hasAchievements = entry.achievementCount > 0
        return Button(action: action) {
            VStack(spacing: 2) {
                Text("\(entry.day)")
                    .font(TypographyTokens.caption(11).weight(hasAchievements ? .bold : .regular))
                    .foregroundStyle(
                        hasAchievements
                            ? Color.white
                            : ColorTokens.Parent.ink
                    )
                if hasAchievements {
                    Image(systemName: "star.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(Color.white.opacity(0.85))
                } else {
                    Color.clear.frame(width: 6, height: 6)
                }
            }
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        hasAchievements
                            ? ColorTokens.Brand.gold
                            : isSelected
                                ? ColorTokens.Brand.primary.opacity(0.15)
                                : ColorTokens.Parent.surface.opacity(0.70)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected && !hasAchievements
                            ? ColorTokens.Brand.primary.opacity(0.6)
                            : Color.clear,
                        lineWidth: 1.5
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
            exitToParentHome()
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
