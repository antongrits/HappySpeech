import SwiftUI

// MARK: - SpecialistScheduleView

struct SpecialistScheduleView: View {

    let specialistId: String

    @State private var interactor: SpecialistScheduleInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "specialistSchedule.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = SpecialistScheduleInteractor(specialistId: specialistId)
                }
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero(state: interactor.state)
                    weekStrip(interactor: interactor)
                    daySlots(interactor: interactor)
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

    private func hero(state: SpecialistScheduleModels.ViewState) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "specialistSchedule.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "specialistSchedule.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Text("Всего сессий: \(state.slots.count)")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .padding(.top, 4)
            }
        }
    }

    private func weekStrip(interactor: SpecialistScheduleInteractor) -> some View {
        HStack(spacing: 6) {
            ForEach(SpecialistScheduleModels.Weekday.allCases) { day in
                let count = interactor.state.slotsFor(day).count
                let isActive = interactor.state.selectedWeekday == day
                Button {
                    hapticService.impact(.light)
                    interactor.select(day)
                } label: {
                    VStack(spacing: 4) {
                        Text(day.shortTitle)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(isActive ? .white : ColorTokens.Spec.ink)
                        Text("\(count)")
                            .font(TypographyTokens.headline(14))
                            .foregroundStyle(isActive ? .white : ColorTokens.Spec.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isActive ? ColorTokens.Spec.accent : ColorTokens.Spec.surface)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(day.shortTitle), \(count) сессий"))
                .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func daySlots(interactor: SpecialistScheduleInteractor) -> some View {
        let slots = interactor.state.slotsFor(interactor.state.selectedWeekday)
        return VStack(spacing: SpacingTokens.sp2) {
            if slots.isEmpty {
                HSCard(style: .flat) {
                    Text("Сессий не запланировано")
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, SpacingTokens.sp3)
                }
            } else {
                ForEach(slots) { slot in
                    slotRow(slot)
                }
            }
        }
    }

    private func slotRow(_ slot: SpecialistScheduleModels.Slot) -> some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.time)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Spec.accent)
                    Text(slot.childName)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Spec.ink)
                }
                Spacer()
                Text(slot.topic)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(ColorTokens.Spec.bg)
                    )
            }
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "specialistSchedule.cta.action"),
            style: .primary,
            size: .large,
            icon: "plus"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("SpecialistSchedule — Light") {
    SpecialistScheduleView(specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SpecialistSchedule — Dark") {
    SpecialistScheduleView(specialistId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
