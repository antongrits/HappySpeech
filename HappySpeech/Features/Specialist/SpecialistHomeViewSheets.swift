import SwiftUI

// MARK: - SpecialistHomeViewSheets
//
// Sheets, секции сессий и вспомогательные типы для `SpecialistHomeView`.

// MARK: - SpecSessionsPreviewSection

struct SpecSessionsPreviewSection: View {
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

// MARK: - SpecSessionMiniRow

struct SpecSessionMiniRow: View {
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
                        .font(TypographyTokens.kidDisplay(14))
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
                    .font(TypographyTokens.caption(12))
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

// MARK: - SpecAddNoteSheet

struct SpecAddNoteSheet: View {
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

// MARK: - SpecSendMessageSheet

struct SpecSendMessageSheet: View {
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

struct SpecSessionListView: View {
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

struct SpecSessionRow: View {
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
                    .font(TypographyTokens.kidDisplay(18))
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
                .font(TypographyTokens.caption(12))
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

// MARK: - SpecExportShareSheet (UIViewControllerRepresentable)

struct SpecExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ExportURLWrapper (Identifiable для sheet)

struct ExportURLWrapper: Identifiable {
    let url: URL
    var id: URL { url }
}

// MARK: - SpecDiagnosticsSection

struct SpecDiagnosticsSection: View {
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

// MARK: - SpecNotesSection

struct SpecNotesSection: View {
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

// MARK: - SpecNoteCard

struct SpecNoteCard: View {
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

// MARK: - SpecActionsSection

struct SpecActionsSection: View {
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
