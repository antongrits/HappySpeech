import OSLog
import SwiftUI

// MARK: - SessionReviewHelpers
//
// Вынесены из SessionReviewView.swift для соблюдения лимита 600 строк (SwiftLint).
// Содержит: ViewModelHolder, Game/Phoneme rows, вспомогательные view, Share helpers.

// MARK: - ViewModelHolder

@MainActor
@Observable
final class SessionReviewViewModelHolder: SessionReviewDisplayLogic {

    // Display state — full session details (B1)
    var titleText: String = ""
    var dateText: String = ""
    var durationText: String = ""
    var childNameText: String = ""
    var games: [GameResultViewModel] = []
    var phonemeChartData: [SoundAccuracy] = []
    var phonemeRows: [PhonemeRowViewModel] = []
    var llmRecommendation: String?
    var overallAccuracyPercent: Int = 0
    var totalAttemptsText: String = ""

    // Per-attempt state (legacy)
    var attemptRows: [AttemptReviewRow] = []
    var legacySummary: SessionReviewSummary?
    var saveConfirmation: String?

    // M6.15: Breakdown state
    var breakdownRows: [AttemptBreakdownViewModel] = []
    var breakdownStats: BreakdownStatsViewModel?
    var annotations: [AnnotationViewModel] = []
    var isBreakdownLoaded: Bool = false

    // Export state
    var lastExportURL: URL?
    var lastExportConfirmation: String?

    // Loading / error
    var isLoading: Bool = true
    var hasLoadedOnce: Bool = false
    var errorText: String?

    // Wiring
    var interactor: SessionReviewInteractor?
    var router: SessionReviewRouter?

    // MARK: - Display logic

    func displayLoadSession(_ vm: SessionReviewModels.LoadSession.ViewModel) {
        attemptRows = vm.rows
        legacySummary = vm.summary
        isLoading = false
        hasLoadedOnce = true
    }

    func displaySetManualScore(_ vm: SessionReviewModels.SetManualScore.ViewModel) {
        attemptRows = vm.rows
        legacySummary = vm.summary
    }

    func displayFinalizeReview(_ vm: SessionReviewModels.FinalizeReview.ViewModel) {
        saveConfirmation = vm.confirmationText
    }

    func displayLoadDetails(_ vm: SessionReviewModels.LoadDetails.ViewModel) {
        titleText = vm.titleText
        dateText = vm.dateText
        durationText = vm.durationText
        childNameText = vm.childNameText
        games = vm.games
        phonemeChartData = vm.phonemeChartData
        phonemeRows = vm.phonemeRows
        llmRecommendation = vm.llmRecommendation
        overallAccuracyPercent = vm.overallAccuracyPercent
        totalAttemptsText = vm.totalAttemptsText
        isLoading = false
        hasLoadedOnce = true
        errorText = nil
    }

    func displayExportPDF(_ vm: SessionReviewModels.ExportPDF.ViewModel) {
        lastExportURL = vm.shareableURL
        lastExportConfirmation = vm.confirmationText
    }

    func displayAttemptBreakdown(_ vm: SessionReviewModels.LoadAttemptBreakdown.ViewModel) {
        breakdownRows = vm.rows
        breakdownStats = vm.stats
        isBreakdownLoaded = true
    }

    func displayAnnotationUpdated(_ vm: SessionReviewModels.AnnotationUpdated.ViewModel) {
        annotations = vm.annotations
    }
}

// MARK: - Game Row

struct GameResultRow: View {
    let row: GameResultViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            ToneIndicator(tone: row.tone)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(row.detailText)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            }

            Spacer(minLength: SpacingTokens.tiny)

            AccuracyPill(percent: row.accuracyPercent, tone: row.tone)
        }
        .padding(.vertical, SpacingTokens.small)
        .padding(.horizontal, SpacingTokens.small)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(row.title), \(row.detailText), \(row.accuracyPercent)%"
        )
    }
}

// MARK: - Phoneme Row

struct PhonemeAccuracyRow: View {
    let row: PhonemeRowViewModel

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            phonemeBadge
            Text(localizedToneTitle(row.tone))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
            Spacer()
            AccuracyPill(percent: row.accuracyPercent, tone: row.tone)
        }
        .padding(.vertical, SpacingTokens.small)
        .padding(.horizontal, SpacingTokens.small)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: String(localized: "review.phoneme.a11y"),
                row.phoneme,
                row.accuracyPercent,
                localizedToneTitle(row.tone)
            )
        )
    }

    private var phonemeBadge: some View {
        ZStack {
            Circle()
                .fill(toneColor(row.tone).opacity(0.15))
                .frame(width: 36, height: 36)
            Text(row.phoneme)
                .font(TypographyTokens.kidDisplay(16))
                .foregroundStyle(toneColor(row.tone))
        }
    }

    private func toneColor(_ tone: AccuracyTone) -> Color {
        switch tone {
        case .good:   return ColorTokens.Semantic.success
        case .medium: return ColorTokens.Brand.gold
        case .poor:   return ColorTokens.Semantic.error
        }
    }

    private func localizedToneTitle(_ tone: AccuracyTone) -> String {
        switch tone {
        case .good:   return String(localized: "review.tone.good")
        case .medium: return String(localized: "review.tone.medium")
        case .poor:   return String(localized: "review.tone.poor")
        }
    }
}

// MARK: - Tone Indicator

struct ToneIndicator: View {
    let tone: AccuracyTone

    var body: some View {
        Circle()
            .fill(color)
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch tone {
        case .good:   return ColorTokens.Semantic.success
        case .medium: return ColorTokens.Brand.gold
        case .poor:   return ColorTokens.Semantic.error
        }
    }
}

// MARK: - Accuracy Pill

struct AccuracyPill: View {
    let percent: Int
    let tone: AccuracyTone

    var body: some View {
        Text("\(percent)%")
            .font(TypographyTokens.labelRounded(13))
            .foregroundStyle(.white)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, 4)
            .background(Capsule().fill(pillColor))
    }

    private var pillColor: Color {
        switch tone {
        case .good:   return ColorTokens.Semantic.success
        case .medium: return ColorTokens.Brand.gold
        case .poor:   return ColorTokens.Semantic.error
        }
    }
}

// MARK: - Share Helpers

struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
