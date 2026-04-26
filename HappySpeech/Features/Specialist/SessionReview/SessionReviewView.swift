import Charts
import OSLog
import SwiftUI

// MARK: - SessionReviewView
//
// Экран детального просмотра одной завершённой сессии для специалиста (B1).
// Full Clean Swift VIP — данные приходят из `SessionReviewInteractor`,
// форматируются `SessionReviewPresenter`, отображаются здесь.
//
// Состав:
//   • header — имя ребёнка, дата, длительность, общий процент успеха,
//   • карточка «Игры в сессии» — список с цветными индикаторами,
//   • карточка «Точность по звукам» — Swift Charts bar chart,
//   • строки точности по фонемам с tone-индикаторами,
//   • карточка с рекомендацией (если есть),
//   • кнопка экспорта в PDF + share sheet.
//
// Темы: gradient синий→фиолетовый поверх `ColorTokens.Spec.bg`.
// A11y: VoiceOver labels на всех интерактивных элементах, поддержка
// Dynamic Type, Reduced Motion.

struct SessionReviewView: View {

    // MARK: - Inputs

    let sessionId: String

    // MARK: - Environment

    @Environment(AppContainer.self) var container
    @Environment(AppCoordinator.self) var coordinator
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - State

    @State var viewModel = SessionReviewViewModelHolder()
    @State var pendingShareURL: ShareableURL?
    @State var isExporting = false
    @State var isBreakdownExpanded: Bool = false
    @State var isAnnotationSheetPresented: Bool = false
    @State var annotationText: String = ""
    @State var pendingAnnotationAttemptId: String?

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            content
        }
        .navigationTitle(String(localized: "review.nav.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
        .sheet(item: $pendingShareURL) { item in
            ShareSheetView(items: [item.url])
        }
        .sheet(isPresented: $isAnnotationSheetPresented) {
            annotationSheet
        }
        .task {
            bootstrap()
            await viewModel.interactor?.loadDetails(.init(sessionId: sessionId))
            await viewModel.interactor?.loadAttemptBreakdown(.init(sessionId: sessionId))
        }
        .environment(\.circuitContext, .specialist)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                ColorTokens.Brand.sky.opacity(0.55),
                ColorTokens.Brand.lilac.opacity(0.55),
                ColorTokens.Spec.bg
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasLoadedOnce {
            loadingState
        } else if viewModel.errorText != nil {
            errorState
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    header
                    overallAccuracyCard
                    gamesSection
                    phonemeChartCard
                    phonemeListSection
                    attemptBreakdownSection
                    annotationsSection
                    recommendationSection
                    exportButton
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.medium)
                .padding(.bottom, SpacingTokens.xLarge)
            }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: SpacingTokens.regular) {
            ProgressView()
                .controlSize(.large)
                .tint(ColorTokens.Spec.accent)
            Text(String(localized: "review.loading"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private var errorState: some View {
        VStack(spacing: SpacingTokens.regular) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ColorTokens.Semantic.warning)
            Text(viewModel.errorText ?? String(localized: "review.error.unknown"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Spec.ink)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Back button

    private var backButton: some View {
        Button {
            viewModel.router?.routeBack()
            dismiss()
        } label: {
            HStack(spacing: SpacingTokens.tiny) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text(String(localized: "review.back"))
                    .font(TypographyTokens.body(15))
            }
            .foregroundStyle(ColorTokens.Spec.accent)
        }
        .accessibilityLabel(String(localized: "review.back.a11y"))
        .accessibilityHint(String(localized: "review.back.hint"))
    }

    // MARK: - Header

    private var header: some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                Text(viewModel.titleText.isEmpty
                     ? String(localized: "review.header.placeholder")
                     : viewModel.titleText)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                HStack(spacing: SpacingTokens.regular) {
                    headerMetric(
                        icon: "calendar",
                        value: viewModel.dateText,
                        label: String(localized: "review.header.date")
                    )
                    headerMetric(
                        icon: "clock",
                        value: viewModel.durationText,
                        label: String(localized: "review.header.duration")
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    private func headerMetric(icon: String, value: String, label: String) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.Spec.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(value.isEmpty ? "—" : value)
                    .font(TypographyTokens.body(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(label)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
        }
    }

    private var headerAccessibilityLabel: String {
        let parts = [
            viewModel.titleText,
            viewModel.dateText,
            viewModel.durationText
        ].filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    // MARK: - Overall accuracy

    private var overallAccuracyCard: some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.regular) {
                ZStack {
                    Circle()
                        .stroke(ColorTokens.Spec.line, lineWidth: 6)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.overallAccuracyPercent) / 100.0)
                        .stroke(
                            overallAccuracyColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.6),
                                   value: viewModel.overallAccuracyPercent)
                    Text("\(viewModel.overallAccuracyPercent)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorTokens.Spec.ink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "review.overall.title"))
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Spec.ink)
                    Text(viewModel.totalAttemptsText)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "review.overall.a11y"),
                   viewModel.overallAccuracyPercent,
                   viewModel.totalAttemptsText)
        )
    }

    private var overallAccuracyColor: Color {
        let tone = AccuracyTone.make(from: viewModel.overallAccuracyPercent)
        switch tone {
        case .good:   return ColorTokens.Semantic.success
        case .medium: return ColorTokens.Brand.gold
        case .poor:   return ColorTokens.Semantic.error
        }
    }

    // MARK: - Games

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            sectionHeader(String(localized: "review.section.games"))

            if viewModel.games.isEmpty {
                emptyCard(text: String(localized: "review.section.games.empty"))
            } else {
                HSLiquidGlassCard(style: .primary, padding: SpacingTokens.small) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.games.enumerated()), id: \.element.id) { index, row in
                            GameResultRow(row: row)
                            if index < viewModel.games.count - 1 {
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

    // MARK: - Phoneme chart

    @ViewBuilder
    private var phonemeChartCard: some View {
        if !viewModel.phonemeChartData.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                sectionHeader(String(localized: "review.section.chart"))

                HSLiquidGlassCard(style: .primary) {
                    Chart(viewModel.phonemeChartData) { point in
                        BarMark(
                            x: .value(String(localized: "review.chart.x"), point.label),
                            y: .value(String(localized: "review.chart.y"), point.value)
                        )
                        .foregroundStyle(point.color)
                        .cornerRadius(RadiusTokens.xs)
                        .accessibilityLabel(point.label)
                        .accessibilityValue("\(Int(point.value * 100))%")
                    }
                    .chartYScale(domain: 0...1)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0.0, 0.5, 1.0]) { value in
                            AxisGridLine()
                                .foregroundStyle(ColorTokens.Spec.grid.opacity(0.5))
                            AxisValueLabel {
                                if let percent = value.as(Double.self) {
                                    Text("\(Int(percent * 100))%")
                                        .font(TypographyTokens.caption(10))
                                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                    .accessibilityLabel(String(localized: "review.chart.a11y"))
                }
            }
        }
    }

    // MARK: - Phoneme list

    @ViewBuilder
    private var phonemeListSection: some View {
        if !viewModel.phonemeRows.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                sectionHeader(String(localized: "review.section.phonemes"))

                HSLiquidGlassCard(style: .primary, padding: SpacingTokens.small) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.phonemeRows.enumerated()), id: \.element.id) { index, row in
                            PhonemeAccuracyRow(row: row)
                            if index < viewModel.phonemeRows.count - 1 {
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

    // MARK: - Recommendation

    @ViewBuilder
    private var recommendationSection: some View {
        if let recommendation = viewModel.llmRecommendation, !recommendation.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                sectionHeader(String(localized: "review.section.recommendation"))

                HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.lilac)) {
                    HStack(alignment: .top, spacing: SpacingTokens.small) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(ColorTokens.Brand.gold)
                            .accessibilityHidden(true)
                        Text(recommendation)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Spec.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    String(format: String(localized: "review.recommendation.a11y"), recommendation)
                )
            }
        }
    }

    // MARK: - Export button

    private var exportButton: some View {
        HSButton(
            String(localized: "review.export.pdf"),
            style: .primary,
            size: .large,
            icon: "doc.text",
            isLoading: isExporting
        ) {
            Task { await runExport() }
        }
        .accessibilityHint(String(localized: "review.export.pdf.hint"))
    }

    // MARK: - Reusable

    func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(TypographyTokens.headline(15))
            .foregroundStyle(ColorTokens.Spec.ink)
            .accessibilityAddTraits(.isHeader)
    }

    func emptyCard(text: String) -> some View {
        HSLiquidGlassCard(style: .primary) {
            HStack {
                Spacer()
                Text(text)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Spacer()
            }
        }
    }

    // MARK: - Wiring

    private func bootstrap() {
        guard viewModel.interactor == nil else { return }
        let interactor = SessionReviewInteractor(
            sessionRepository: container.sessionRepository,
            childRepository: container.childRepository,
            exportService: SpecialistExportServiceLive()
        )
        let presenter = SessionReviewPresenter()
        let router = SessionReviewRouter()
        router.coordinator = coordinator
        router.onBack = { [weak coordinator] in
            coordinator?.pop()
        }

        presenter.display = viewModel
        interactor.presenter = presenter
        viewModel.interactor = interactor
        viewModel.router = router

        // Подписываемся на share-action из роутера.
        router.onShare = { url in
            Task { @MainActor in
                pendingShareURL = ShareableURL(url: url)
            }
        }
    }

    @MainActor
    private func runExport() async {
        isExporting = true
        defer { isExporting = false }
        await viewModel.interactor?.exportPDF(.init(sessionId: sessionId))
        if let url = viewModel.lastExportURL {
            pendingShareURL = ShareableURL(url: url)
        }
    }
}

// MARK: - Preview

#Preview("SessionReview") {
    NavigationStack {
        SessionReviewView(sessionId: "preview-session-1")
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
    }
}
