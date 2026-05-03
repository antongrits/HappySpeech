import SwiftUI

// MARK: - SpecialistHomeView

struct SpecialistHomeView: View {
    @State private var selectedTab: SpecTab = .children
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container

    enum SpecTab: String, CaseIterable {
        case children  = "Дети"
        case sessions  = "Занятия"
        case reports   = "Отчёты"
        case settings  = "Настройки"

        var icon: String {
            switch self {
            case .children: return "person.2.fill"
            case .sessions: return "waveform.path"
            case .reports:  return "doc.text.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(SpecTab.allCases, id: \.self) { tab in
                specTabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(ColorTokens.Spec.accent)
        .environment(\.circuitContext, .specialist)
    }

    @ViewBuilder
    private func specTabContent(for tab: SpecTab) -> some View {
        switch tab {
        case .children: SpecChildListView()
        case .sessions: SpecSessionListView()
        case .reports:  SpecialistReportsView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - SpecChildListView

private struct SpecChildListView: View {
    @Environment(AppContainer.self) private var container
    @State private var children: [ChildProfileDTO] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOrder: SpecialistModels.Fetch.Request.SortOrder = .byLastActivity
    @State private var selectedChildId: String?
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
                    HSEmptyState(
                        icon: "person.2.fill",
                        title: String(localized: "spec.children.empty.title"),
                        message: String(localized: "spec.children.empty.message")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredChildren) { child in
                            ZStack {
                                NavigationLink(value: child.id) {
                                    EmptyView()
                                }
                                .opacity(0)
                                SpecChildRow(child: child)
                            }
                            .listRowBackground(ColorTokens.Spec.surface)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
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

private struct SpecChildRow: View {
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ColorTokens.Spec.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(child.name)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Spec.ink)

                HStack(spacing: SpacingTokens.sp2) {
                    Text(ageLine)
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

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(lastSessionLabel)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
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

private struct SpecProgressBar: View {
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

// MARK: - SpecChildDashboardView

struct SpecChildDashboardView: View {
    let childId: String

    @Environment(AppContainer.self) private var container
    @State private var child: ChildProfileDTO?
    @State private var sessions: [SessionDTO] = []
    @State private var breakdown: [SoundBreakdownRow] = []
    @State private var summary: ReportSummary?
    @State private var isLoading = true
    @State private var noteText = ""
    @State private var notes: [SpecialistNote] = []
    @State private var showNoteSheet = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var errorMessage: String?
    @State private var showMessageSheet = false
    @State private var messageText = ""

    var body: some View {
        ZStack {
            ColorTokens.Spec.bg.ignoresSafeArea()
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(ColorTokens.Spec.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        if let child {
                            SpecDashboardHeader(child: child, summary: summary)
                        }
                        SpecSoundBreakdownSection(rows: breakdown)
                        SpecSessionsPreviewSection(sessions: sessions) { _ in
                            // Navigation is handled by parent NavigationStack
                        }
                        SpecDiagnosticsSection(breakdown: breakdown)
                        SpecNotesSection(
                            notes: notes,
                            onAddNote: { showNoteSheet = true },
                            onDeleteNote: deleteNote
                        )
                        SpecActionsSection(
                            onExportPDF: { Task { await performExport(.pdf) } },
                            onExportCSV: { Task { await performExport(.csv) } },
                            onMessage: { showMessageSheet = true }
                        )
                    }
                    .padding(.horizontal, SpacingTokens.regular)
                    .padding(.bottom, SpacingTokens.sp8)
                }
            }
        }
        .navigationTitle(child?.name ?? String(localized: "spec.dashboard.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNoteSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(String(localized: "spec.note.addButton"))
            }
        }
        .sheet(isPresented: $showNoteSheet) {
            SpecAddNoteSheet(text: $noteText, onSave: saveNote, onCancel: {
                showNoteSheet = false
                noteText = ""
            })
        }
        .sheet(isPresented: $showMessageSheet) {
            SpecSendMessageSheet(text: $messageText, onSend: sendMessage, onCancel: {
                showMessageSheet = false
                messageText = ""
            })
        }
        .sheet(item: Binding(
            get: { exportURL.map { ExportURLWrapper(url: $0) } },
            set: { exportURL = $0?.url }
        )) { wrapper in
            ShareSheet(url: wrapper.url)
        }
        .task { await reload() }
    }

    private func reload() async {
        isLoading = true
        do {
            async let childTask = container.childRepository.fetch(id: childId)
            async let sessionsTask = container.sessionRepository.fetchRecent(childId: childId, limit: 50)
            let (dto, recent) = try await (childTask, sessionsTask)
            child = dto
            sessions = Array(recent.sorted { $0.date > $1.date }.prefix(10))
            let last30 = recent.filter { $0.date >= Date().addingTimeInterval(-30 * 24 * 3600) }
            summary = ReportsAggregator.summarize(sessions: last30)
            breakdown = ReportsAggregator.soundBreakdown(sessions: last30)
        } catch {
            errorMessage = error.localizedDescription
            HSLogger.app.error("SpecChildDashboard reload: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    private func saveNote() {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = SpecialistNote(
            id: UUID().uuidString,
            childId: childId,
            specialistId: "current-specialist",
            text: text,
            createdAt: Date()
        )
        notes.insert(note, at: 0)
        showNoteSheet = false
        noteText = ""
    }

    private func deleteNote(_ noteId: String) {
        notes.removeAll { $0.id == noteId }
    }

    private func performExport(_ format: SpecialistModels.RequestExport.ExportFormat) async {
        do {
            let allSessions = try await container.sessionRepository.fetchRecent(
                childId: childId, limit: 500
            )
            let exportService = SpecialistExportServiceLive()
            switch format {
            case .pdf:
                exportURL = try await exportService.generatePDF(childId: childId, sessions: allSessions)
            case .csv:
                exportURL = try await exportService.generateCSV(childId: childId, sessions: allSessions)
            }
        } catch {
            errorMessage = error.localizedDescription
            HSLogger.app.error("Export failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func sendMessage() {
        showMessageSheet = false
        messageText = ""
    }
}

// MARK: - Dashboard Subviews

private struct SpecDashboardHeader: View {
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
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(ColorTokens.Spec.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name)
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Spec.ink)
                        Text("\(child.age) лет · звуки: \(child.targetSounds.joined(separator: ", "))")
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    Spacer()
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

private struct SpecMetricTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
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

private struct SpecSoundBreakdownSection: View {
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

private struct SpecSoundRow: View {
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
                        .font(.system(size: 16, weight: .black, design: .rounded))
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

private struct SpecSessionsPreviewSection: View {
    let sessions: [SessionDTO]
    let onOpen: (String) -> Void

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        if sessions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(String(localized: "spec.section.recentSessions"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.ink)

                ForEach(sessions.prefix(5)) { session in
                    NavigationLink(value: session.id) {
                        SpecSessionMiniRow(session: session, formatter: Self.formatter)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SpecSessionMiniRow: View {
    let session: SessionDTO
    let formatter: DateFormatter

    var body: some View {
        HSCard {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Spec.accent.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(session.targetSound)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.Spec.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatter.string(from: session.date))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.ink)
                    Text(
                        String(
                            format: String(localized: "spec.session.mini.score"),
                            Int((session.successRate * 100).rounded()),
                            session.durationSeconds / 60
                        )
                    )
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.regular)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Занятие \(formatter.string(from: session.date)), звук \(session.targetSound), " +
            "результат \(Int((session.successRate * 100).rounded()))%"
        )
        .accessibilityHint(String(localized: "spec.session.row.hint"))
        .accessibilityAddTraits(.isButton)
    }
}

private struct SpecDiagnosticsSection: View {
    let breakdown: [SoundBreakdownRow]

    var strugglingRows: [SoundBreakdownRow] {
        breakdown.filter { $0.averageConfidence < 0.5 }
    }

    var body: some View {
        if strugglingRows.isEmpty {
            EmptyView()
        } else {
            HSCard {
                VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                    Label(
                        String(localized: "spec.section.diagnostics"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Semantic.error)

                    ForEach(strugglingRows) { row in
                        HStack(spacing: SpacingTokens.sp3) {
                            Image(systemName: "speaker.wave.1")
                                .foregroundStyle(ColorTokens.Semantic.error)
                                .accessibilityHidden(true)
                            Text(
                                String(
                                    format: String(localized: "spec.diagnostics.weakSound"),
                                    row.sound,
                                    Int((row.averageConfidence * 100).rounded())
                                )
                            )
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Spec.ink)
                        }
                        .accessibilityLabel(
                            "Проблемный звук \(row.sound): \(Int((row.averageConfidence * 100).rounded()))%"
                        )
                    }
                }
                .padding(SpacingTokens.regular)
            }
        }
    }
}

private struct SpecNotesSection: View {
    let notes: [SpecialistNote]
    let onAddNote: () -> Void
    let onDeleteNote: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                Text(String(localized: "spec.section.notes"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.ink)
                Spacer()
                Button {
                    onAddNote()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(ColorTokens.Spec.accent)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(String(localized: "spec.note.addButton"))
                .frame(minWidth: 44, minHeight: 44)
            }

            if notes.isEmpty {
                Text(String(localized: "spec.notes.empty"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, SpacingTokens.sp3)
            } else {
                ForEach(notes) { note in
                    SpecNoteCard(note: note, onDelete: { onDeleteNote(note.id) })
                }
            }
        }
    }
}

private struct SpecNoteCard: View {
    let note: SpecialistNote
    let onDelete: () -> Void

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HSCard {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Image(systemName: "note.text")
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(note.text)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(4)
                    Text(Self.formatter.string(from: note.createdAt))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                }
                Spacer()
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(ColorTokens.Semantic.error)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(String(localized: "spec.note.delete"))
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(SpacingTokens.regular)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Заметка: \(note.text). Дата: \(Self.formatter.string(from: note.createdAt))")
    }
}

private struct SpecActionsSection: View {
    let onExportPDF: () -> Void
    let onExportCSV: () -> Void
    let onMessage: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Text(String(localized: "spec.section.actions"))
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Spec.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: SpacingTokens.sp3) {
                HSButton(
                    String(localized: "spec.action.exportPDF"),
                    style: .secondary,
                    size: .medium
                ) {
                    onExportPDF()
                }
                .accessibilityHint(String(localized: "spec.action.exportPDF.hint"))

                HSButton(
                    String(localized: "spec.action.exportCSV"),
                    style: .secondary,
                    size: .medium
                ) {
                    onExportCSV()
                }
                .accessibilityHint(String(localized: "spec.action.exportCSV.hint"))
            }

            HSButton(
                String(localized: "spec.action.messageParent"),
                style: .primary,
                size: .medium
            ) {
                onMessage()
            }
            .accessibilityHint(String(localized: "spec.action.messageParent.hint"))
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Sheets

private struct SpecAddNoteSheet: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.regular) {
                TextEditor(text: $text)
                    .frame(minHeight: 140)
                    .padding(SpacingTokens.sp3)
                    .background(ColorTokens.Spec.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                    .font(TypographyTokens.body(15))
                    .accessibilityLabel(String(localized: "spec.note.editor.a11y"))
                Spacer()
            }
            .padding(SpacingTokens.regular)
            .background(ColorTokens.Spec.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "spec.note.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "spec.cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "spec.save")) { onSave() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
        }
    }
}

private struct SpecSendMessageSheet: View {
    @Binding var text: String
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.regular) {
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding(SpacingTokens.sp3)
                    .background(ColorTokens.Spec.surface)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card))
                    .font(TypographyTokens.body(15))
                    .accessibilityLabel(String(localized: "spec.message.editor.a11y"))
                Spacer()
            }
            .padding(SpacingTokens.regular)
            .background(ColorTokens.Spec.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "spec.message.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "spec.cancel")) { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "spec.send")) { onSend() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
        }
    }
}

// MARK: - SpecSessionListView

private struct SpecSessionListView: View {
    @Environment(AppContainer.self) private var container
    @State private var sessions: [SessionDTO] = []
    @State private var isLoading: Bool = true

    private static let demoChildId = "preview-child-1"

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(ColorTokens.Spec.accent)
                } else if sessions.isEmpty {
                    HSEmptyState(
                        icon: "waveform.path",
                        title: String(localized: "spec.sessions.empty.title"),
                        message: String(localized: "spec.sessions.empty.message")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sessions) { session in
                            ZStack {
                                NavigationLink(value: session.id) {
                                    EmptyView()
                                }
                                .opacity(0)
                                SpecSessionRow(session: session)
                            }
                            .listRowBackground(ColorTokens.Spec.surface)
                            .listRowInsets(EdgeInsets(
                                top: SpacingTokens.tiny,
                                leading: SpacingTokens.regular,
                                bottom: SpacingTokens.tiny,
                                trailing: SpacingTokens.regular
                            ))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(String(localized: "spec.sessions.navTitle"))
            .navigationDestination(for: String.self) { sessionId in
                SessionReviewView(sessionId: sessionId)
            }
            .task { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        do {
            let result = try await container.sessionRepository.fetchAll(childId: Self.demoChildId)
            sessions = result.sorted { $0.date > $1.date }
        } catch {
            HSLogger.app.error("SpecSessionList reload: \(error.localizedDescription, privacy: .public)")
            sessions = []
        }
        isLoading = false
    }
}

// MARK: - SpecSessionRow

private struct SpecSessionRow: View {
    let session: SessionDTO

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: SpacingTokens.regular) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Spec.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(session.targetSound)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(ColorTokens.Spec.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(SessionReviewInteractor.gameName(for: session.templateType))
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)

                HStack(spacing: SpacingTokens.tiny) {
                    Text(Self.dateFormatter.string(from: session.date))
                    Text("·")
                    Text(
                        String(
                            format: String(localized: "review.row.score"),
                            Int((session.successRate * 100).rounded())
                        )
                    )
                }
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, SpacingTokens.tiny)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(String(localized: "review.row.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private var rowAccessibilityLabel: String {
        let percent = Int((session.successRate * 100).rounded())
        let date = Self.dateFormatter.string(from: session.date)
        let game = SessionReviewInteractor.gameName(for: session.templateType)
        return String(
            format: String(localized: "review.row.a11y"),
            game,
            session.targetSound,
            date,
            percent
        )
    }
}

// MARK: - ShareSheet (UIViewControllerRepresentable)

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ExportURLWrapper (Identifiable для sheet)

private struct ExportURLWrapper: Identifiable {
    let url: URL
    var id: URL { url }
}

// MARK: - Preview

#Preview("Specialist Home") {
    SpecialistHomeView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
