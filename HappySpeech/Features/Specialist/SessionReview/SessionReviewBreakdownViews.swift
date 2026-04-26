import SwiftUI

// MARK: - SessionReviewBreakdownViews
//
// M6.15: Sub-views для breakdown-секции специалистского обзора сессии.
// Вынесены из SessionReviewView.swift для соблюдения лимита 900 строк (SwiftLint).
// Все view — internal, вызываются из SessionReviewView.

// MARK: - BreakdownStatsCard

struct BreakdownStatsCard: View {
    let stats: BreakdownStatsViewModel

    var body: some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.regular) {
                statCell(
                    value: stats.averageEffectiveText,
                    label: String(localized: "review.breakdown.stat.effective")
                )
                Divider()
                    .frame(height: 36)
                    .background(ColorTokens.Spec.line)
                statCell(
                    value: stats.averageASRText,
                    label: String(localized: "review.breakdown.stat.asr")
                )
                if let pron = stats.averagePronunciationText {
                    Divider()
                        .frame(height: 36)
                        .background(ColorTokens.Spec.line)
                    statCell(value: pron, label: String(localized: "review.breakdown.stat.ml"))
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(stats.totalCorrectText)
                        .font(TypographyTokens.body(12))
                        .foregroundStyle(ColorTokens.Semantic.success)
                    if let manual = stats.manualOverrideText {
                        Text(manual)
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Brand.gold)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [stats.averageEffectiveText,
             stats.averageASRText,
             stats.totalCorrectText]
                .joined(separator: ", ")
        )
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.Spec.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(label)
                .font(TypographyTokens.caption(10))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
}

// MARK: - AttemptBreakdownRowView

struct AttemptBreakdownRowView: View {
    let row: AttemptBreakdownViewModel
    let onAnnotate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            HStack(spacing: SpacingTokens.small) {
                ZStack {
                    Circle()
                        .fill(toneColor(row.tone).opacity(0.12))
                        .frame(width: 32, height: 32)
                    Text("\(row.index)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(toneColor(row.tone))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SpacingTokens.tiny) {
                        Text(row.word)
                            .font(TypographyTokens.body(14).weight(.semibold))
                            .foregroundStyle(ColorTokens.Spec.ink)
                        if row.hasManualScore {
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTokens.Brand.gold)
                                .accessibilityLabel(String(localized: "review.breakdown.manual_label"))
                        }
                        Image(systemName: row.confidenceIconName)
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .accessibilityHidden(true)
                    }
                    if !row.asrTranscript.isEmpty {
                        Text("«\(row.asrTranscript)»")
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: SpacingTokens.tiny)

                VStack(alignment: .trailing, spacing: 2) {
                    AccuracyPill(
                        percent: Int(row.effectiveScoreText.dropLast()) ?? 0,
                        tone: row.tone
                    )
                    Text(row.timestampText)
                        .font(TypographyTokens.mono(10))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                }
            }

            HStack(spacing: SpacingTokens.regular) {
                scoreChip(
                    label: String(localized: "review.breakdown.chip.asr"),
                    value: row.asrScoreText
                )
                if let pron = row.pronunciationScoreText {
                    scoreChip(
                        label: String(localized: "review.breakdown.chip.ml"),
                        value: pron
                    )
                }
                Spacer(minLength: 0)
                Button {
                    onAnnotate()
                } label: {
                    Label(
                        String(localized: "review.breakdown.annotate"),
                        systemImage: "square.and.pencil"
                    )
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.accent)
                }
                .accessibilityHint(String(localized: "review.breakdown.annotate.hint"))
            }
            .padding(.leading, 40)
        }
        .padding(.vertical, SpacingTokens.small)
        .padding(.horizontal, SpacingTokens.small)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowA11yLabel)
    }

    private func scoreChip(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(TypographyTokens.caption(10))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
            Text(value)
                .font(TypographyTokens.caption(10).weight(.semibold))
                .foregroundStyle(ColorTokens.Spec.ink)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(ColorTokens.Spec.surface.opacity(0.7)))
    }

    private func toneColor(_ tone: AccuracyTone) -> Color {
        switch tone {
        case .good:   return ColorTokens.Semantic.success
        case .medium: return ColorTokens.Brand.gold
        case .poor:   return ColorTokens.Semantic.error
        }
    }

    private var rowA11yLabel: String {
        let correctStr = row.isCorrect
            ? String(localized: "review.attempt.correct")
            : String(localized: "review.attempt.incorrect")
        return "\(row.index). \(row.word), \(correctStr), \(row.effectiveScoreText)"
    }
}

// MARK: - AnnotationRowView

struct AnnotationRowView: View {
    let annotation: AnnotationViewModel
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            Image(systemName: annotation.isSessionLevel ? "doc.text" : "person.wave.2")
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.Spec.accent)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(annotation.text)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(annotation.dateText)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            }

            Spacer(minLength: SpacingTokens.tiny)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.Semantic.error)
            }
            .accessibilityLabel(String(localized: "review.annotation.delete"))
            .accessibilityHint(String(localized: "review.annotation.delete.hint"))
        }
        .padding(.vertical, SpacingTokens.small)
        .padding(.horizontal, SpacingTokens.small)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(annotation.text)
        .accessibilityHint(annotation.dateText)
    }
}
