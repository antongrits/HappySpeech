import SwiftUI

// MARK: - NoteEditorSheet

struct SessionHistoryNoteEditorSheet: View {

    @Environment(\.dismiss) private var dismiss
    let initialText: String
    let onSave: (String) -> Void

    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.regular) {
                TextEditor(text: $text)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .frame(minHeight: 120)
                    .padding(SpacingTokens.small)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .fill(ColorTokens.Parent.surface)
                    )
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .accessibilityLabel(String(localized: "sessionHistory.detail.noteEditor.a11y"))

                Spacer()

                HSButton(
                    String(localized: "sessionHistory.detail.noteSave"),
                    style: .primary,
                    size: .large,
                    icon: "checkmark"
                ) {
                    onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "sessionHistory.detail.noteNavTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "sessionHistory.filter.close")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear { text = initialText }
    }
}

// MARK: - MetricCard

struct SessionHistoryMetricCard: View {

    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        HSCard(style: .flat, padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Image(systemName: icon)
                    .font(TypographyTokens.subtitle(16))
                    .foregroundStyle(color)
                Text(value)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - AttemptRowCard

struct SessionHistoryAttemptRowCard: View {
    let row: AttemptDetailRowViewModel

    var body: some View {
        HSCard(style: .flat, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.regular) {
                Text("#\(row.index)")
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .frame(width: 28, alignment: .leading)

                Text(row.word)
                    .font(TypographyTokens.body(15).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: SpacingTokens.tiny)

                Text(row.durationText)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)

                SessionHistoryScoreBadge(text: "\(row.scorePercent)%", tier: row.scoreTier)

                Image(systemName: row.isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                    .font(TypographyTokens.subtitle(16))
                    .foregroundStyle(row.isCorrect
                                     ? ColorTokens.Semantic.success
                                     : ColorTokens.Semantic.error)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

// MARK: - ScoreBadge

struct SessionHistoryScoreBadge: View {
    let text: String
    let tier: ScoreTier

    var body: some View {
        Text(text)
            .font(TypographyTokens.mono(13).weight(.bold))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color)
            )
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch tier {
        case .excellent: return ColorTokens.Semantic.success
        case .ok:        return ColorTokens.Semantic.warning
        case .low:       return ColorTokens.Semantic.error
        }
    }
}

// MARK: - ExportSheet

struct SessionHistoryExportSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onPDF: () -> Void
    let onCSV: () -> Void
    let onJSON: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                Text(String(localized: "sessionHistory.export.title"))
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .padding(.top, SpacingTokens.regular)

                exportButton(
                    title: String(localized: "sessionHistory.export.pdf"),
                    subtitle: String(localized: "sessionHistory.export.pdf.subtitle"),
                    icon: "doc.richtext",
                    color: ColorTokens.Semantic.error,
                    action: { dismiss(); onPDF() }
                )
                exportButton(
                    title: String(localized: "sessionHistory.export.csv"),
                    subtitle: String(localized: "sessionHistory.export.csv.subtitle"),
                    icon: "tablecells",
                    color: ColorTokens.Semantic.success,
                    action: { dismiss(); onCSV() }
                )
                exportButton(
                    title: String(localized: "sessionHistory.export.json"),
                    subtitle: String(localized: "sessionHistory.export.json.subtitle"),
                    icon: "curlybraces",
                    color: ColorTokens.Parent.accent,
                    action: { dismiss(); onJSON() }
                )

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "sessionHistory.export.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "sessionHistory.filter.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func exportButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: icon)
                    .font(TypographyTokens.titleSmall(22))
                    .foregroundStyle(color)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TypographyTokens.body(15).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.labelRounded(14))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
            }
            .padding(SpacingTokens.regular)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Parent.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - ShareItem + ShareSheet

struct SessionHistoryShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SessionHistoryShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
