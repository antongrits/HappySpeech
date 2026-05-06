import SwiftUI

// MARK: - FamilyCalendarViewSheets
//
// Sheet-компоненты для `FamilyCalendarView`:
// `DayDetailSheet`, `ScheduleLessonSheet`, `WeekSummarySheet`, `WeekSummaryRow`.

// MARK: - DayDetailSheet

struct DayDetailSheet: View {
    let detail: DayDetailViewModel
    let onSchedule: (Date) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    if detail.isEmpty {
                        Text(String(localized: "family_calendar.detail.empty"))
                            .font(TypographyTokens.body())
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(SpacingTokens.large)
                    }

                    if !detail.sessionItems.isEmpty {
                        VStack(alignment: .leading, spacing: SpacingTokens.small) {
                            Text(String(localized: "family_calendar.detail.sessions_header"))
                                .font(TypographyTokens.headline())
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(detail.sessionItems) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.childName)
                                            .font(TypographyTokens.headline())
                                            .foregroundStyle(ColorTokens.Parent.ink)
                                        Text(String(format: String(localized: "family_calendar.detail.day_format"),
                                                    item.childName, item.sessionCount, item.accuracyPercent))
                                            .font(TypographyTokens.body())
                                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                                    }
                                    Spacer()
                                    Text("\(item.accuracyPercent)%")
                                        .font(TypographyTokens.headline())
                                        .foregroundStyle(item.accuracyPercent >= 70
                                            ? ColorTokens.Semantic.success : ColorTokens.Semantic.warning)
                                }
                                .padding(SpacingTokens.medium)
                                .background(ColorTokens.Parent.surface)
                                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                            }
                        }
                        .padding(.horizontal, SpacingTokens.regular)
                    }

                    if !detail.dayPlans.isEmpty {
                        VStack(alignment: .leading, spacing: SpacingTokens.small) {
                            Text(String(localized: "family_calendar.detail.plans_header"))
                                .font(TypographyTokens.headline())
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(detail.dayPlans) { plan in
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(ColorTokens.Semantic.warning)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plan.childName)
                                            .font(TypographyTokens.headline())
                                            .foregroundStyle(ColorTokens.Parent.ink)
                                        Text("\(plan.lessonTemplate) • \(plan.timeText)")
                                            .font(TypographyTokens.caption())
                                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                                    }
                                    Spacer()
                                }
                                .padding(SpacingTokens.medium)
                                .background(ColorTokens.Semantic.warning.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                            }
                        }
                        .padding(.horizontal, SpacingTokens.regular)
                    }

                    if let visit = detail.specialistVisit {
                        VStack(alignment: .leading, spacing: SpacingTokens.small) {
                            Text(String(localized: "family_calendar.detail.visit_header"))
                                .font(TypographyTokens.headline())
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .accessibilityAddTraits(.isHeader)

                            HStack {
                                Image(systemName: "stethoscope")
                                    .foregroundStyle(ColorTokens.Semantic.success)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visit.specialistName)
                                        .font(TypographyTokens.headline())
                                        .foregroundStyle(ColorTokens.Parent.ink)
                                    if !visit.notes.isEmpty {
                                        Text(visit.notes)
                                            .font(TypographyTokens.caption())
                                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                                    }
                                }
                                Spacer()
                            }
                            .padding(SpacingTokens.medium)
                            .background(ColorTokens.Semantic.success.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                        }
                        .padding(.horizontal, SpacingTokens.regular)
                    }

                    HSButton(String(localized: "family_calendar.detail.schedule_button"), style: .secondary) {
                        onSchedule(detail.date)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .padding(.horizontal, SpacingTokens.regular)
                }
                .padding(.vertical, SpacingTokens.large)
            }
            .navigationTitle(detail.dateText)
            .navigationBarTitleDisplayMode(.inline)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - ScheduleLessonSheet

struct ScheduleLessonSheet: View {
    let date: Date
    let children: [ChildAvatarViewModel]
    let onConfirm: (String, String, Date, String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedChildIdx = 0
    @State private var selectedTemplate = "repeat-after-model"
    @State private var reminderEnabled = true
    @State private var selectedTime: Date

    private let templates = [
        "repeat-after-model",
        "listen-and-choose",
        "drag-and-match",
        "sound-hunter",
        "articulation-imitation"
    ]

    init(date: Date, children: [ChildAvatarViewModel], onConfirm: @escaping (String, String, Date, String, Bool) -> Void) {
        self.date = date
        self.children = children
        self.onConfirm = onConfirm
        _selectedTime = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "family_calendar.schedule.child_section")) {
                    if !children.isEmpty {
                        Picker(String(localized: "family_calendar.schedule.child_picker"), selection: $selectedChildIdx) {
                            ForEach(0..<children.count, id: \.self) { idx in
                                Text(children[idx].name).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Text(String(localized: "family_calendar.schedule.no_children"))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                }

                Section(String(localized: "family_calendar.schedule.template_section")) {
                    Picker(String(localized: "family_calendar.schedule.template_picker"), selection: $selectedTemplate) {
                        ForEach(templates, id: \.self) { tpl in
                            Text(tpl).tag(tpl)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(String(localized: "family_calendar.schedule.time_section")) {
                    DatePicker(
                        String(localized: "family_calendar.schedule.time_label"),
                        selection: $selectedTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                Section {
                    Toggle(String(localized: "family_calendar.schedule.reminder_toggle"), isOn: $reminderEnabled)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "family_calendar.schedule.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "common.save")) {
                        guard !children.isEmpty else { return }
                        let child = children[selectedChildIdx]
                        onConfirm(child.id, child.name, selectedTime, selectedTemplate, reminderEnabled)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .disabled(children.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - WeekSummarySheet

struct WeekSummarySheet: View {
    let summary: WeekSummaryViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.weekRangeText)
                                .font(TypographyTokens.caption())
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                            Text(String(format: String(localized: "family_calendar.week_summary.total_sessions"),
                                        summary.familyTotalSessions))
                                .font(TypographyTokens.headline())
                                .foregroundStyle(ColorTokens.Parent.ink)
                        }
                        Spacer()
                        if summary.allGoalsReached {
                            Image(systemName: "star.circle.fill")
                                .font(TypographyTokens.display(40))
                                .foregroundStyle(ColorTokens.Brand.gold)
                                .accessibilityLabel(String(localized: "family_calendar.week_summary.all_goals_reached"))
                        }
                    }
                    .padding(.horizontal, SpacingTokens.regular)

                    VStack(spacing: SpacingTokens.small) {
                        ForEach(summary.childRows) { row in
                            WeekSummaryRow(row: row)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.regular)
                }
                .padding(.vertical, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "family_calendar.week_summary.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - WeekSummaryRow

struct WeekSummaryRow: View {
    let row: WeekSummaryRowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(row.initials)
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.childName)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text("\(row.sessionsText) • \(row.durationText) • \(row.accuracyPercent)%")
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                }
                Spacer()
                if row.goalReached {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.Semantic.success)
                        .accessibilityLabel(String(localized: "family_calendar.a11y.goal_reached"))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorTokens.Parent.inkSoft.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(row.goalReached ? ColorTokens.Semantic.success : ColorTokens.Brand.primary)
                        .frame(width: geo.size.width * row.progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(SpacingTokens.medium)
        .background(ColorTokens.Parent.surface)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
        .accessibilityElement(children: .combine)
    }
}
