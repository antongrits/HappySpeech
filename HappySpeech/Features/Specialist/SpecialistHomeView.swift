import SwiftUI

// MARK: - SpecialistHomeView
//
// Компоненты вынесены в `SpecialistHomeViewComponents.swift`.
// Sheets и список сессий — в `SpecialistHomeViewSheets.swift`.

struct SpecialistHomeView: View {
    @State private var selectedTab: SpecTab = .children
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme

    enum SpecTab: String, CaseIterable {
        // Block H v21 — labels хранят русские raw values для LocalizedStringKey lookup.
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

        /// D-11 v27 — короткая подпись для таб-бара: 4 таба должны помещаться
        /// целиком на iPhone SE 3 (320pt). Полное название («Настройки») — это
        /// заголовок экрана, в таб-баре используется компактный вариант.
        var tabTitle: LocalizedStringKey {
            switch self {
            case .children: return "Дети"
            case .sessions: return "Занятия"
            case .reports:  return "Отчёты"
            case .settings: return "Ещё"
            }
        }
    }

    var body: some View {
        // Block J v18 — заменён системный TabView на HSAnimatedTabBar
        // (kavsoft-style capsule indicator).
        ZStack(alignment: .bottom) {
            specTabContent(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HSAnimatedTabBar(
                selection: $selectedTab,
                items: SpecTab.allCases,
                alwaysShowsLabels: true
            ) { tab in
                (tab.icon, tab.tabTitle)
            }
            // P1-03 v25: fixedSize по вертикали — внутри ZStack(.bottom) на iOS 26
            // SE3 matchedGeometryEffect-капсула выбранного таба растягивалась на
            // всю высоту экрана (623pt). Фиксируем intrinsic-высоту строки.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp2)
        }
        .tint(ColorTokens.Spec.accent)
        .environment(\.circuitContext, .specialist)
        .accessibilityIdentifier("SpecialistHomeRoot")
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

// MARK: - SpecChildDashboardView

struct SpecChildDashboardView: View {
    let childId: String

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var colorScheme
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
                // Block J v18 — skeleton shimmer вместо ProgressView spinner.
                VStack(spacing: SpacingTokens.regular) {
                    ForEach(0..<5, id: \.self) { _ in
                        HSSkeletonCard()
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .redacted(reason: .placeholder)
                .hsShimmer(active: true)
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        // E v21: 3D Ляля на главном экране специалиста
                        // (требование «3D героев на каждом экране»).
                        LyalyaHeroView(state: .thinking, size: 120)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                            .padding(.top, SpacingTokens.sp2)
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
                        // v29 Фаза 8 Ф.4 — «Домашнее задание от логопеда».
                        assignedHomeworkCard
                            .modifier(SpecialistAssignmentsTipModifier())

                        // v31 Волна D Ф.3 — «Первичная оценка».
                        specialistAssessmentCard
                    }
                    .padding(.horizontal, SpacingTokens.regular)
                    .padding(.bottom, SpacingTokens.sp8)
                }
            }
        }
        .navigationTitle(child?.name ?? String(localized: "spec.dashboard.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                LyalyaMascotView(state: .thinking, size: 32)
                    // F.tier1 v21: mascot мягче в dark, чтобы не «бликовал» в toolbar.
                    .opacity(colorScheme == .dark ? 0.9 : 1.0)
                    .accessibilityHidden(true)
            }
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
            SpecExportShareSheet(url: wrapper.url)
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

    // MARK: - v29 Фаза 8: Ф.4 «Домашнее задание от логопеда»

    /// Карточка-вход в конструктор домашних заданий специалиста.
    private var assignedHomeworkCard: some View {
        Button {
            coordinator.navigate(to: .assignedHomework(specialistId: "current-specialist"))
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "tray.and.arrow.up.fill")
                    .font(.title2)
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "assignedHomework.entry.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "assignedHomework.entry.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Spec.panel)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(String(localized: "assignedHomework.entry.title") + ". " +
                 String(localized: "assignedHomework.entry.subtitle"))
        )
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - v31 Волна D Ф.3 «Первичная оценка специалиста»

    /// Карточка-вход в 10-вопросную анкету.
    private var specialistAssessmentCard: some View {
        Button {
            coordinator.navigate(to: .specialistAssessment(
                childId: childId,
                specialistId: "current-specialist"
            ))
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "list.clipboard.fill")
                    .font(.title2)
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "specAssessment.entry.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "specAssessment.entry.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Spec.panel)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(String(localized: "specAssessment.entry.title") + ". " +
                 String(localized: "specAssessment.entry.subtitle"))
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("specAssessment.entryCard")
    }
}

// MARK: - Preview

#Preview("Specialist Home") {
    SpecialistHomeView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
