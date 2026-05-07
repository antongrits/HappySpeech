import SwiftUI

// MARK: - SessionHistoryDetailView
//
// Детальный просмотр сессии. Навигация через `SessionDetailRoute`
// в `NavigationStack` из `SessionHistoryView`.

struct SessionHistoryDetailView: View {

    let detail: SessionDetailViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @State private var isEditingNote: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                headerCard
                metricsRow
                if detail.hasAudioRecording {
                    audioRow
                }
                attemptsSection
                parentNoteSection
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.large)
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .navigationTitle(detail.titleLine)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .onAppear {
            noteText = detail.parentNote ?? ""
        }
    }

    // MARK: Audio row

    private var audioRow: some View {
        HSCard(style: .flat, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: "waveform")
                    .font(TypographyTokens.titleSmall(20))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "sessionHistory.detail.audioTitle"))
                        .font(TypographyTokens.body(15).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text(String(localized: "sessionHistory.detail.audioSubtitle"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(TypographyTokens.display(32))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .frame(width: 44, height: 44)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "sessionHistory.detail.audio.a11y"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Parent note

    private var parentNoteSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                Text(String(localized: "sessionHistory.detail.noteTitle"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Spacer()
                if !noteText.isEmpty {
                    Button {
                        isEditingNote = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(TypographyTokens.subtitle(16))
                            .foregroundStyle(ColorTokens.Parent.accent)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(String(localized: "sessionHistory.detail.noteEdit"))
                }
            }

            if noteText.isEmpty {
                Button {
                    isEditingNote = true
                } label: {
                    HStack(spacing: SpacingTokens.small) {
                        Image(systemName: "plus.circle")
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Parent.accent)
                        Text(String(localized: "sessionHistory.detail.noteAdd"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Parent.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.regular)
                    .frame(minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .strokeBorder(ColorTokens.Parent.accent.opacity(0.4), lineWidth: 1.5, antialiased: true)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "sessionHistory.detail.noteAdd"))
            } else {
                HSCard(style: .flat, padding: SpacingTokens.regular) {
                    Text(noteText)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "sessionHistory.detail.noteA11yPrefix") + noteText)
            }
        }
        .sheet(isPresented: $isEditingNote) {
            SessionHistoryNoteEditorSheet(initialText: noteText) { saved in
                noteText = saved
                isEditingNote = false
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Header

    private var headerCard: some View {
        HSCard(style: .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.regular) {
                LyalyaMascotView(
                    state: detail.scorePercent >= 70 ? .celebrating : .encouraging,
                    size: 60
                )
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(detail.titleLine)
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(detail.dateLine)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(detail.scorePercent)%")
                    .font(TypographyTokens.display(36))
                    .foregroundStyle(scoreColor)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.accessibilityHeader)
    }

    // MARK: Metrics — 3 карточки

    private var metricsRow: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            Text(String(localized: "sessionHistory.detail.metricsTitle"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)

            HStack(spacing: SpacingTokens.regular) {
                SessionHistoryMetricCard(
                    title: String(localized: "sessionHistory.detail.metric.accuracy"),
                    value: "\(detail.scorePercent)%",
                    color: scoreColor,
                    icon: "target"
                )
                SessionHistoryMetricCard(
                    title: String(localized: "sessionHistory.detail.metric.attempts"),
                    value: "\(detail.attemptsCount)",
                    color: ColorTokens.Parent.accent,
                    icon: "list.number"
                )
                SessionHistoryMetricCard(
                    title: String(localized: "sessionHistory.detail.metric.duration"),
                    value: detail.durationText,
                    color: ColorTokens.Brand.butter,
                    icon: "clock"
                )
            }
        }
    }

    // MARK: Attempts list

    private var attemptsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            Text(String(localized: "sessionHistory.detail.attemptsTitle"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)

            VStack(spacing: SpacingTokens.tiny) {
                ForEach(detail.attemptRows) { attempt in
                    SessionHistoryAttemptRowCard(row: attempt)
                }
            }
        }
    }

    private var scoreColor: Color {
        switch detail.scoreTier {
        case .excellent: return ColorTokens.Semantic.success
        case .ok:        return ColorTokens.Semantic.warning
        case .low:       return ColorTokens.Semantic.error
        }
    }
}
