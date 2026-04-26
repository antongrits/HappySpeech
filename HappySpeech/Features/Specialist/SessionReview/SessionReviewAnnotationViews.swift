import SwiftUI

// MARK: - SessionReviewAnnotationViews
//
// Вынесены из SessionReviewView.swift для соблюдения лимита 600 строк (SwiftLint).
// Extension на SessionReviewView: breakdown section, annotations section, annotation sheet.

extension SessionReviewView {

    // MARK: - Attempt Breakdown (M6.15)

    @ViewBuilder
    var attemptBreakdownSection: some View {
        if viewModel.isBreakdownLoaded && !viewModel.breakdownRows.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack {
                    sectionHeader(String(localized: "review.section.breakdown"))
                    Spacer()
                    breakdownToggleButton
                }

                if let stats = viewModel.breakdownStats {
                    BreakdownStatsCard(stats: stats)
                }

                if isBreakdownExpanded {
                    HSLiquidGlassCard(style: .primary, padding: SpacingTokens.small) {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.breakdownRows.enumerated()),
                                    id: \.element.id) { index, row in
                                AttemptBreakdownRowView(row: row) {
                                    pendingAnnotationAttemptId = row.id
                                    annotationText = ""
                                    isAnnotationSheetPresented = true
                                }
                                if index < viewModel.breakdownRows.count - 1 {
                                    Divider()
                                        .background(ColorTokens.Spec.line)
                                        .padding(.horizontal, SpacingTokens.small)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var breakdownToggleButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                isBreakdownExpanded.toggle()
            }
        } label: {
            Image(systemName: isBreakdownExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                .foregroundStyle(ColorTokens.Spec.accent)
                .font(.system(size: 18))
        }
        .accessibilityLabel(isBreakdownExpanded
            ? String(localized: "review.breakdown.collapse")
            : String(localized: "review.breakdown.expand"))
    }

    // MARK: - Annotations (M6.15)

    @ViewBuilder
    var annotationsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                sectionHeader(String(localized: "review.section.annotations"))
                Spacer()
                addAnnotationButton
            }

            if viewModel.annotations.isEmpty {
                emptyCard(text: String(localized: "review.annotation.empty"))
            } else {
                HSLiquidGlassCard(style: .primary, padding: SpacingTokens.small) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.annotations.enumerated()),
                                id: \.element.id) { index, ann in
                            AnnotationRowView(annotation: ann) {
                                Task {
                                    await viewModel.interactor?.deleteAnnotation(.init(
                                        sessionId: sessionId,
                                        annotationId: ann.id
                                    ))
                                }
                            }
                            if index < viewModel.annotations.count - 1 {
                                Divider()
                                    .background(ColorTokens.Spec.line)
                                    .padding(.horizontal, SpacingTokens.small)
                            }
                        }
                    }
                }
            }
        }
    }

    private var addAnnotationButton: some View {
        Button {
            pendingAnnotationAttemptId = nil
            annotationText = ""
            isAnnotationSheetPresented = true
        } label: {
            Label(String(localized: "review.annotation.add"),
                  systemImage: "plus.circle")
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Spec.accent)
        }
        .accessibilityHint(String(localized: "review.annotation.add.hint"))
    }

    // MARK: - Annotation Sheet

    var annotationSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                Text(pendingAnnotationAttemptId == nil
                     ? String(localized: "review.annotation.sheet.session")
                     : String(localized: "review.annotation.sheet.attempt"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)

                TextEditor(text: $annotationText)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .frame(minHeight: 120)
                    .padding(SpacingTokens.small)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .stroke(ColorTokens.Spec.line, lineWidth: 1)
                    )
                    .accessibilityLabel(String(localized: "review.annotation.field.label"))

                Spacer()
            }
            .padding(SpacingTokens.regular)
            .navigationTitle(String(localized: "review.annotation.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "review.annotation.cancel")) {
                        isAnnotationSheetPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "review.annotation.save")) {
                        let text = annotationText
                        let attemptId = pendingAnnotationAttemptId
                        isAnnotationSheetPresented = false
                        Task {
                            await viewModel.interactor?.addAnnotation(.init(
                                sessionId: sessionId,
                                targetAttemptId: attemptId,
                                text: text
                            ))
                        }
                    }
                    .disabled(annotationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .bold()
                }
            }
            .background(ColorTokens.Spec.bg.ignoresSafeArea())
        }
    }
}
