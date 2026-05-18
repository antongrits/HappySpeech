import SwiftUI

// MARK: - SpecialistHomeViewComponents
//
// Подкомпоненты `SpecialistHomeView`.
// Sheets и список сессий вынесены в `SpecialistHomeViewSheets.swift`.

// MARK: - SpecChildListView

struct SpecChildListView: View {
    @Environment(AppContainer.self) private var container
    @State private var children: [ChildProfileDTO] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOrder: SpecialistModels.Fetch.Request.SortOrder = .byLastActivity
    @State private var showSortSheet = false

    var filteredChildren: [ChildProfileDTO] {
        guard !searchText.isEmpty else { return children }
        return children.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(ColorTokens.Spec.accent)
                } else if filteredChildren.isEmpty && !isLoading {
                    // E v21: 3D Ляля в empty state SpecChildList (students list)
                    // — требование «3D героев на каждом экране».
                    VStack(spacing: SpacingTokens.regular) {
                        LyalyaHeroView(state: .thinking, mood: 0.5, size: 140)
                            .accessibilityHidden(true)
                        HSEmptyState(
                            icon: "person.2.fill",
                            title: String(localized: "spec.children.empty.title"),
                            message: String(localized: "spec.children.empty.message")
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(Array(filteredChildren.enumerated()), id: \.element.id) { index, child in
                                ZStack {
                                    NavigationLink(value: child.id) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                    SpecChildRow(child: child)
                                }
                                .listRowBackground(ColorTokens.Spec.surface)
                                .accessibilityIdentifier("specialistStudentRow_\(index)")
                            }
                        } header: {
                            Text(String(
                                format: String(localized: "spec.children.listHeader"),
                                filteredChildren.count
                            ))
                            .font(TypographyTokens.caption(12).weight(.semibold))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .textCase(.uppercase)
                        } footer: {
                            HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                                Image(systemName: "lightbulb.fill")
                                    .font(TypographyTokens.caption(12))
                                    .foregroundStyle(ColorTokens.Spec.accent)
                                    .accessibilityHidden(true)
                                Text(String(localized: "spec.children.hint"))
                                    .font(TypographyTokens.caption(12))
                                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, SpacingTokens.sp2)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .accessibilityIdentifier("specialistStudentList")
                }
            }
            .searchable(
                text: $searchText,
                prompt: String(localized: "spec.children.search.prompt")
            )
            .navigationTitle(String(localized: "spec.children.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSortSheet = true
                    } label: {
                        Label(
                            String(localized: "spec.sort.button"),
                            systemImage: "arrow.up.arrow.down"
                        )
                        .accessibilityHint(String(localized: "spec.sort.hint"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Add child — M7
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(String(localized: "spec.addChild.button"))
                    .accessibilityHint(String(localized: "spec.addChild.hint"))
                }
            }
            .confirmationDialog(
                String(localized: "spec.sort.title"),
                isPresented: $showSortSheet,
                titleVisibility: .visible
            ) {
                ForEach(SpecialistModels.Fetch.Request.SortOrder.allCases, id: \.self) { order in
                    Button(order.rawValue) {
                        sortOrder = order
                        applySort()
                    }
                }
            }
            .navigationDestination(for: String.self) { childId in
                SpecChildDashboardView(childId: childId)
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        do {
            let all = try await container.childRepository.fetchAll()
            children = sortChildren(all)
        } catch {
            HSLogger.app.error("SpecChildList reload: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    private func applySort() {
        children = sortChildren(children)
    }

    private func sortChildren(_ list: [ChildProfileDTO]) -> [ChildProfileDTO] {
        switch sortOrder {
        case .byLastActivity:
            return list.sorted {
                ($0.lastSessionAt ?? .distantPast) > ($1.lastSessionAt ?? .distantPast)
            }
        case .byName:
            return list.sorted { $0.name < $1.name }
        case .byProgress:
            return list.sorted { a, b in
                let rateA = a.progressSummary.values.reduce(0, +) / Double(max(1, a.progressSummary.count))
                let rateB = b.progressSummary.values.reduce(0, +) / Double(max(1, b.progressSummary.count))
                return rateA > rateB
            }
        }
    }
}

// MARK: - SpecChildRow

struct SpecChildRow: View {
    let child: ChildProfileDTO

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .full
        return f
    }()

    var lastSessionLabel: String {
        guard let date = child.lastSessionAt else {
            return String(localized: "spec.neverPracticed")
        }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    var overallProgressPercent: Int {
        guard !child.progressSummary.isEmpty else { return 0 }
        let avg = child.progressSummary.values.reduce(0, +) / Double(child.progressSummary.count)
        return Int((avg * 100).rounded())
    }

    var body: some View {
        HStack(spacing: SpacingTokens.sp4) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Spec.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(String(child.name.prefix(1)))
                    .font(TypographyTokens.titleSmall(20))
                    .foregroundStyle(ColorTokens.Spec.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(child.name)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: SpacingTokens.sp2) {
                    Text(ageLine)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("·")
                    ForEach(child.targetSounds, id: \.self) { sound in
                        HSBadge(sound, style: .filled(ColorTokens.Spec.accent))
                    }
                }
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Spec.inkMuted)

                SpecProgressBar(percent: overallProgressPercent)
                    .frame(height: 4)
                    .padding(.top, 2)
            }

            Spacer(minLength: SpacingTokens.sp1)

            VStack(alignment: .trailing, spacing: 2) {
                Text(lastSessionLabel)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, SpacingTokens.sp2)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(String(localized: "spec.child.row.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private var ageLine: String {
        let suffix: String
        switch child.age {
        case 1: suffix = "год"
        case 2, 3, 4: suffix = "года"
        default: suffix = "лет"
        }
        return "\(child.age) \(suffix)"
    }

    private var accessibilityLabel: String {
        let sounds = child.targetSounds.joined(separator: ", ")
        return "\(child.name), \(ageLine). Звуки: \(sounds). Прогресс \(overallProgressPercent)%. " +
               "Последнее занятие: \(lastSessionLabel)"
    }
}

// MARK: - SpecProgressBar

struct SpecProgressBar: View {
    let percent: Int

    private var fraction: Double { Double(min(max(percent, 0), 100)) / 100.0 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(ColorTokens.Spec.accent.opacity(0.15))
                RoundedRectangle(cornerRadius: 2)
                    .fill(progressColor)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .accessibilityLabel(String(format: String(localized: "spec.progress.a11y"), percent))
    }

    private var progressColor: Color {
        switch percent {
        case ..<50: return ColorTokens.Semantic.error
        case ..<80: return ColorTokens.Semantic.warning
        default: return ColorTokens.Semantic.success
        }
    }
}

// MARK: - SpecDashboardHeader

struct SpecDashboardHeader: View {
    let child: ChildProfileDTO
    let summary: ReportSummary?

    var body: some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp4) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Spec.accent.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Text(String(child.name.prefix(1)))
                            .font(TypographyTokens.titleMedium(24))
                            .foregroundStyle(ColorTokens.Spec.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name)
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Spec.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text("\(child.age) лет · звуки: \(child.targetSounds.joined(separator: ", "))")
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: SpacingTokens.sp1)
                }

                if let summary {
                    Divider()
                    HStack(spacing: SpacingTokens.sp4) {
                        SpecMetricTile(
                            value: "\(summary.totalSessions)",
                            label: String(localized: "spec.metric.sessions")
                        )
                        SpecMetricTile(
                            value: "\(summary.totalMinutes)",
                            label: String(localized: "spec.metric.minutes")
                        )
                        SpecMetricTile(
                            value: "\(Int(summary.overallSuccessRate * 100))%",
                            label: String(localized: "spec.metric.success")
                        )
                    }
                }
            }
            .padding(SpacingTokens.regular)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerA11yLabel)
    }

    private var headerA11yLabel: String {
        guard let summary else {
            return "\(child.name), \(child.age) лет"
        }
        return "\(child.name), \(child.age) лет. " +
               "Занятий: \(summary.totalSessions), минут: \(summary.totalMinutes), " +
               "успешность: \(Int(summary.overallSuccessRate * 100))%"
    }
}

// MARK: - SpecMetricTile

struct SpecMetricTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(TypographyTokens.kidDisplay(20))
                .foregroundStyle(ColorTokens.Spec.accent)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SpecSoundBreakdownSection

struct SpecSoundBreakdownSection: View {
    let rows: [SoundBreakdownRow]

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(String(localized: "spec.section.soundBreakdown"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.ink)

                ForEach(rows) { row in
                    SpecSoundRow(row: row)
                }
            }
        }
    }
}

// MARK: - SpecSoundRow

struct SpecSoundRow: View {
    let row: SoundBreakdownRow

    private var confidence: Double { max(0, min(1, row.averageConfidence)) }
    private var percent: Int { Int((confidence * 100).rounded()) }
    private var deltaSign: String { row.weekOverWeekDelta >= 0 ? "+" : "" }
    private var deltaText: String { "\(deltaSign)\(Int((row.weekOverWeekDelta * 100).rounded()))%" }
    private var barColor: Color {
        switch percent {
        case ..<50: return ColorTokens.Semantic.error
        case ..<80: return ColorTokens.Semantic.warning
        default: return ColorTokens.Semantic.success
        }
    }

    var body: some View {
        HSLiquidGlassCard(style: .primary, padding: 0) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(barColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Text(row.sound)
                        .font(TypographyTokens.kidDisplay(16))
                        .foregroundStyle(barColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(percent)%")
                            .font(TypographyTokens.headline(14))
                            .foregroundStyle(ColorTokens.Spec.ink)
                        Text(deltaText)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(
                                row.weekOverWeekDelta >= 0
                                    ? ColorTokens.Semantic.success
                                    : ColorTokens.Semantic.error
                            )
                        Spacer()
                        Text(row.currentStageTitle)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(1)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor.opacity(0.15))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor)
                                .frame(width: geo.size.width * confidence)
                        }
                    }
                    .frame(height: 5)

                    Text(
                        String(
                            format: String(localized: "spec.sound.attempts"),
                            row.attempts, row.successes
                        )
                    )
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                }
            }
            .padding(SpacingTokens.regular)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Звук \(row.sound): \(percent)%, изменение \(deltaText). \(row.currentStageTitle)"
        )
    }
}
