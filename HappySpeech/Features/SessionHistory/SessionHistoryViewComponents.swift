import SwiftUI

// MARK: - SessionHistoryViewComponents
//
// Подкомпоненты `SessionHistoryView`. Все типы — `internal`.
// `SessionHistoryDetailView` вынесен в `SessionHistoryDetailView.swift`.

// MARK: - SessionDetailRoute

struct SessionDetailRoute: Hashable {
    let detail: SessionDetailViewModel
}

// MARK: - SessionHistoryRowContent

struct SessionHistoryRowContent: View {

    let row: SessionHistoryRowViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.regular) {
            // Дата-плитка
            VStack(spacing: 2) {
                Text(row.dayNumber)
                    .font(TypographyTokens.mono(15).weight(.bold))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(row.monthAbbr)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            .frame(width: 40, alignment: .center)

            // Цветной dot — тип игры
            Circle()
                .fill(Color(row.gameAccentColorName))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(row.title)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(row.metaLine)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: SpacingTokens.tiny)

            SessionHistoryScoreBadge(text: row.scoreText, tier: row.scoreTier)

            Image(systemName: "chevron.right")
                .font(TypographyTokens.labelRounded(13))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 56)
        .padding(.vertical, SpacingTokens.tiny)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint(row.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SessionHistoryFilterChipBadge

struct SessionHistoryFilterChipBadge: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: icon)
                .font(TypographyTokens.caption(10))
            Text(label)
                .font(TypographyTokens.caption(12).weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(ColorTokens.Parent.accent)
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(ColorTokens.Parent.accent.opacity(0.12))
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - SessionHistoryFilterSheet

struct SessionHistoryFilterSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let initialFilter: SessionHistoryFilter
    let onApply: (SessionHistoryFilter) -> Void
    let onClear: () -> Void

    @State private var fromDate: Date?
    @State private var toDate: Date?
    @State private var selectedSounds: Set<String> = []
    @State private var selectedScoreRange: SessionHistoryFilter.ScoreRange = .all
    @State private var datePeriod: DatePeriodChoice = .all

    private let allSounds: [String] = ["С", "З", "Ц", "Ш", "Ж", "Ч", "Щ", "Р", "Л", "К", "Г", "Х"]

    enum DatePeriodChoice: String, CaseIterable, Identifiable {
        case week, month, quarter, all
        var id: String { rawValue }

        var label: String {
            switch self {
            case .week:    return String(localized: "sessionHistory.filter.period.week")
            case .month:   return String(localized: "sessionHistory.filter.period.month")
            case .quarter: return String(localized: "sessionHistory.filter.period.quarter")
            case .all:     return String(localized: "sessionHistory.filter.period.all")
            }
        }

        var daysBack: Int? {
            switch self {
            case .week:    return 7
            case .month:   return 30
            case .quarter: return 90
            case .all:     return nil
            }
        }
    }

    init(
        initialFilter: SessionHistoryFilter,
        onApply: @escaping (SessionHistoryFilter) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.initialFilter = initialFilter
        self.onApply = onApply
        self.onClear = onClear
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    Text(String(localized: "sessionHistory.filter.title"))
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .padding(.top, SpacingTokens.tiny)

                    periodSection
                    customDateSection
                    soundsSection
                    scoreRangeSection

                    Spacer(minLength: SpacingTokens.large)

                    applyAndClearButtons
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.xLarge)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "sessionHistory.filter.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "sessionHistory.filter.close")) {
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "sessionHistory.filter.close"))
                }
            }
        }
        .onAppear {
            fromDate = initialFilter.fromDate
            toDate = initialFilter.toDate
            selectedSounds = initialFilter.sounds
            selectedScoreRange = initialFilter.scoreRange
        }
    }

    // MARK: Period

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "sessionHistory.filter.periodHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.tiny) {
                    ForEach(DatePeriodChoice.allCases) { period in
                        SessionFilterChipButton(
                            title: period.label,
                            isSelected: datePeriod == period
                        ) {
                            datePeriod = period
                            applyPeriod(period)
                        }
                    }
                }
            }
        }
    }

    private func applyPeriod(_ period: DatePeriodChoice) {
        guard let days = period.daysBack else {
            fromDate = nil
            toDate = nil
            return
        }
        let calendar = Calendar.current
        let now = Date()
        toDate = now
        fromDate = calendar.date(byAdding: .day, value: -days, to: now)
    }

    // MARK: Custom date

    private var customDateSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "sessionHistory.filter.dateHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)

            HStack(spacing: SpacingTokens.regular) {
                DateFieldButton(
                    title: String(localized: "sessionHistory.filter.from"),
                    date: fromDate
                ) { newDate in
                    fromDate = newDate
                    datePeriod = .all
                }
                DateFieldButton(
                    title: String(localized: "sessionHistory.filter.to"),
                    date: toDate
                ) { newDate in
                    toDate = newDate
                    datePeriod = .all
                }
            }
        }
    }

    // MARK: Sounds

    private var soundsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "sessionHistory.filter.soundsHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.tiny), count: 4),
                spacing: SpacingTokens.tiny
            ) {
                ForEach(allSounds, id: \.self) { sound in
                    SessionFilterChipButton(
                        title: sound,
                        isSelected: selectedSounds.contains(sound)
                    ) {
                        toggleSound(sound)
                    }
                }
            }
        }
    }

    private func toggleSound(_ sound: String) {
        if selectedSounds.contains(sound) {
            selectedSounds.remove(sound)
        } else {
            selectedSounds.insert(sound)
        }
    }

    // MARK: Score range

    private var scoreRangeSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "sessionHistory.filter.scoreHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(SessionHistoryFilter.ScoreRange.allCases, id: \.rawValue) { range in
                    SessionFilterChipButton(
                        title: scoreLabelShort(range),
                        isSelected: selectedScoreRange == range
                    ) {
                        selectedScoreRange = range
                    }
                }
            }
        }
    }

    private func scoreLabelShort(_ range: SessionHistoryFilter.ScoreRange) -> String {
        switch range {
        case .all:    return String(localized: "sessionHistory.filter.period.all")
        case .high:   return String(localized: "sessionHistory.filter.scoreHigh")
        case .medium: return String(localized: "sessionHistory.filter.scoreMedium")
        case .low:    return String(localized: "sessionHistory.filter.scoreLow")
        }
    }

    // MARK: Buttons

    private var applyAndClearButtons: some View {
        VStack(spacing: SpacingTokens.small) {
            HSButton(
                String(localized: "sessionHistory.filter.apply"),
                style: .primary,
                size: .large,
                icon: "checkmark"
            ) {
                let filter = SessionHistoryFilter(
                    fromDate: fromDate,
                    toDate: toDate,
                    sounds: selectedSounds,
                    gameTypes: [],
                    scoreRange: selectedScoreRange
                )
                onApply(filter)
            }
            HSButton(
                String(localized: "sessionHistory.filter.clear"),
                style: .ghost,
                size: .medium,
                icon: "trash"
            ) {
                fromDate = nil
                toDate = nil
                selectedSounds = []
                selectedScoreRange = .all
                datePeriod = .all
                onClear()
            }
        }
    }
}

// MARK: - SessionFilterChipButton

struct SessionFilterChipButton: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.body(14).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? ColorTokens.Overlay.onAccent : ColorTokens.Parent.ink)
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, SpacingTokens.small)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().fill(
                        isSelected
                            ? ColorTokens.Parent.accent
                            : ColorTokens.Parent.surface
                    )
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : ColorTokens.Parent.line,
                        lineWidth: 1
                    )
                )
                .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - DateFieldButton

struct DateFieldButton: View {

    let title: String
    let date: Date?
    let onPick: (Date?) -> Void

    @State private var showPicker = false
    @State private var pickerDate: Date = Date()

    var body: some View {
        Button {
            pickerDate = date ?? Date()
            showPicker = true
        } label: {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(title)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Text(date.map(formatted) ?? String(localized: "sessionHistory.filter.notSet"))
                    .font(TypographyTokens.body(15).weight(.semibold))
                    .foregroundStyle(date == nil ? ColorTokens.Parent.inkMuted : ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SpacingTokens.regular)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(date.map(formatted) ?? String(localized: "sessionHistory.filter.notSet"))")
        .sheet(isPresented: $showPicker) {
            VStack {
                DatePicker(
                    title,
                    selection: $pickerDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .accessibilityHint(String(localized: "sessionHistory.filter.datePicker.hint"))

                HStack(spacing: SpacingTokens.regular) {
                    HSButton(
                        String(localized: "sessionHistory.filter.notSet"),
                        style: .ghost,
                        size: .medium
                    ) {
                        onPick(nil)
                        showPicker = false
                    }
                    HSButton(
                        String(localized: "sessionHistory.filter.confirm"),
                        style: .primary,
                        size: .medium
                    ) {
                        onPick(pickerDate)
                        showPicker = false
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.large)
            }
            .presentationDetents([.medium])
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}
