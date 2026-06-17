import SwiftUI

// MARK: - SpecialistScheduleView

struct SpecialistScheduleView: View {

    let specialistId: String

    @State private var interactor: SpecialistScheduleInteractor?
    @Environment(\.exitToSpecialistHome) private var exitToSpecialistHome
    @Environment(\.hapticService) private var hapticService
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // РЕДИЗАЙН specialist-home (2026-06-13): специалистский контур —
    // нейтрально-холодный статичный холст `Spec.bg` (эталон #ECEEF2), а не
    // тёплый kid-mesh. Поверх — едва заметный coral-radial в hero-зоне, чтобы
    // экран не был чисто системно-серым (паттерн SpecChildListView).
    @ViewBuilder
    private var specBackground: some View {
        ZStack(alignment: .top) {
            ColorTokens.Spec.bg
            RadialGradient(
                colors: [ColorTokens.Spec.accent.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                specBackground
                content
            }
            .navigationTitle(Text(String(localized: "specialistSchedule.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToSpecialistHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let worker = SpecialistScheduleWorker(
                        childRepository: container.childRepository
                    )
                    let new = SpecialistScheduleInteractor(
                        specialistId: specialistId,
                        worker: worker
                    )
                    interactor = new
                    await new.load()
                }
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if interactor.state.isLoading {
                ProgressView().controlSize(.large)
            } else if interactor.state.slots.isEmpty {
                emptyState
            } else {
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
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    /// Честный empty-state: реальных запланированных занятий нет.
    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp4) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.Spec.accent)
            Text(String(localized: "specialistSchedule.empty.title"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Spec.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Text(String(localized: "specialistSchedule.empty.subtitle"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            cta
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.sp6)
    }

    private func hero(state: SpecialistScheduleModels.ViewState) -> some View {
        HSLiquidGlassCard(style: .elevated) {
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
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "calendar.badge.clock")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                        .hsSymbolEffect(.bounce, value: state.slots.count)
                    Text(String(
                        format: String(localized: "specialistSchedule.totalSessions %lld"),
                        state.slots.count
                    ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                }
                .padding(.top, SpacingTokens.micro)
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
                .accessibilityLabel(Text(String(
                    format: String(localized: "specialistSchedule.weekday.a11y %@ %lld"),
                    day.shortTitle, count
                )))
                .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func daySlots(interactor: SpecialistScheduleInteractor) -> some View {
        let slots = interactor.state.slotsFor(interactor.state.selectedWeekday)
        return VStack(spacing: SpacingTokens.sp2) {
            if slots.isEmpty {
                HSCard(style: .flat) {
                    Text(String(localized: "specialistSchedule.day.empty"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, SpacingTokens.sp3)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
            } else {
                ForEach(slots) { slot in
                    slotRow(slot)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(
            reduceMotion ? nil : MotionTokens.settleSpring,
            value: slots.count
        )
    }

    private func slotRow(_ slot: SpecialistScheduleModels.Slot) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            // Coral time-accent rail (эталон: «ses» карточка занятия).
            RoundedRectangle(cornerRadius: 3)
                .fill(ColorTokens.Spec.accent)
                .frame(width: 4, height: 40)
                .accessibilityHidden(true)
            ZStack {
                Circle()
                    .fill(ColorTokens.Spec.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(String(slot.childName.prefix(1)))
                    .font(TypographyTokens.titleSmall(17))
                    .foregroundStyle(ColorTokens.Spec.accent)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.time)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(slot.childName)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: SpacingTokens.sp2)
            Text(slot.topic)
                .font(TypographyTokens.caption(11).weight(.semibold))
                .foregroundStyle(ColorTokens.Spec.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.sp2)
                .padding(.vertical, SpacingTokens.micro)
                .background(
                    Capsule().fill(ColorTokens.Spec.accent.opacity(0.14))
                )
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Spec.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .stroke(ColorTokens.Spec.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(slot.time), \(slot.childName), \(slot.topic)"))
    }

    private var cta: some View {
        HSButton(
            String(localized: "specialistSchedule.cta.action"),
            style: .primary,
            size: .large,
            icon: "plus"
        ) {
            // «Добавить занятие» = открыть конструктор задания: его срок (dueDate)
            // становится новым слотом расписания (`SpecialistScheduleWorker` строит
            // слоты из назначенных HomeworkAssignment). Раньше кнопка ошибочно
            // ЗАКРЫВАЛА экран вместо добавления.
            hapticService.impact(.light)
            coordinator.navigate(to: .assignedHomework(specialistId: specialistId))
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
