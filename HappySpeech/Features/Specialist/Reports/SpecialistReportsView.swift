import SwiftUI
import OSLog

// MARK: - SpecialistReportsView
//
// Specialist "Reports" tab. Lets the logopedist:
//   • pick a child and date range,
//   • see an aggregated summary (sessions count, minutes, overall accuracy),
//   • drill into per-sound breakdown rows,
//   • export PDF or CSV via the iOS share sheet.
//
// Wires into the existing Reports VIP cycle:
//   ReportsInteractor (fetch/aggregate) → ReportsPresenter → ReportsViewModelHolder
// Filtering by category is done client-side on the per-sound rows since the
// underlying `SoundBreakdownRow` is the natural pivot.

struct SpecialistReportsView: View {

    @Environment(AppContainer.self) private var container
    @State private var viewModel = ReportsViewModelHolder()

    @State private var range: ReportRange = .last30
    @State private var filter: ReportFilter = .all
    @State private var pendingShareItem: ShareItem?
    @State private var selectedSound: SoundBreakdownRow?

    private static let demoChildId = "preview-child-1"

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        rangePicker
                        filterChips

                        if viewModel.isLoading {
                            loadingView
                        } else {
                            summaryCard
                            soundBreakdownSection
                            exportSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp5)
                }
            }
            .navigationTitle(String(localized: "Отчёты"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(ColorTokens.Spec.accent)
                    }
                    .accessibilityLabel(String(localized: "reports.refresh"))
                }
            }
            .sheet(item: $pendingShareItem) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(item: $selectedSound) { row in
                SoundDetailSheet(row: row)
                    .presentationDetents([.medium])
            }
            .task {
                bootstrap()
                await reload()
            }
            .environment(\.circuitContext, .specialist)
        }
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(String(localized: "reports.range.title"))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .textCase(.uppercase)
                .tracking(0.8)

            Picker(String(localized: "reports.range.title"), selection: $range) {
                ForEach(ReportRange.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: range) { _, _ in
                Task { await reload() }
            }
        }
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(ReportFilter.allCases) { item in
                    FilterChip(
                        title: item.title,
                        icon: item.icon,
                        isSelected: filter == item
                    ) {
                        filter = item
                    }
                }
            }
            .padding(.vertical, SpacingTokens.sp1)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
                .tint(ColorTokens.Spec.accent)
            Text(String(localized: "reports.loading"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.titleText)
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Spec.ink)
                        Text(viewModel.rangeLabel)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    Spacer()
                    overallBadge
                }

                Divider()
                    .background(ColorTokens.Spec.line)

                HStack(spacing: SpacingTokens.sp4) {
                    SummaryMetric(
                        label: String(localized: "reports.summary.sessions"),
                        value: viewModel.totalSessionsText,
                        icon: "calendar.badge.clock"
                    )
                    SummaryMetric(
                        label: String(localized: "reports.summary.minutes"),
                        value: viewModel.totalMinutesText,
                        icon: "clock"
                    )
                    SummaryMetric(
                        label: String(localized: "reports.summary.accuracy"),
                        value: "\(viewModel.overallSuccessPercent)%",
                        icon: "checkmark.seal"
                    )
                }
            }
        }
        .environment(\.circuitContext, .specialist)
    }

    private var overallBadge: some View {
        let percent = viewModel.overallSuccessPercent
        let color: Color = percent >= 80
            ? ColorTokens.Semantic.success
            : (percent >= 60 ? ColorTokens.Brand.gold : ColorTokens.Semantic.warning)
        return Text("\(percent)%")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp1)
            .background(Capsule().fill(color))
    }

    // MARK: - Sound breakdown

    @ViewBuilder
    private var soundBreakdownSection: some View {
        let rows = filteredRows
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "reports.section.sounds"))
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Spec.ink)

            if rows.isEmpty {
                emptyRowsCard
            } else {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(rows) { row in
                        SoundBreakdownRowView(row: row) {
                            selectedSound = row
                        }
                    }
                }
            }
        }
    }

    private var emptyRowsCard: some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "tray")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Text(String(localized: "reports.empty.title"))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Spec.ink)
                Text(String(localized: "reports.empty.body"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp4)
        }
        .environment(\.circuitContext, .specialist)
    }

    private var filteredRows: [SoundBreakdownRow] {
        switch filter {
        case .all:
            return viewModel.rows
        case .improving:
            return viewModel.rows.filter { $0.weekOverWeekDelta >= 0.05 }
        case .struggling:
            return viewModel.rows.filter { $0.weekOverWeekDelta <= -0.05 }
        case .recommendations:
            return viewModel.rows.filter { $0.averageConfidence < 0.75 }
        }
    }

    // MARK: - Export section

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "reports.export.title"))
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Spec.ink)

            HStack(spacing: SpacingTokens.sp3) {
                exportButton(format: .pdf, icon: "doc.text", title: String(localized: "reports.export.pdf"))
                exportButton(format: .csv, icon: "tablecells", title: String(localized: "reports.export.csv"))
            }

            if let url = viewModel.exportedURL {
                lastExportRow(url: url)
            }
        }
    }

    private func exportButton(format: ReportsModels.ExportReport.Format, icon: String, title: String) -> some View {
        Button {
            Task { await export(format: format) }
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(TypographyTokens.cta())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                    .fill(ColorTokens.Spec.accent)
            )
            .foregroundStyle(.white)
        }
        .accessibilityLabel(title)
    }

    private func lastExportRow(url: URL) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.Semantic.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "reports.export.ready"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Spec.ink)
                Text(viewModel.exportedSizeText)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            }
            Spacer()
            Button {
                pendingShareItem = ShareItem(url: url)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(ColorTokens.Spec.accent)
            }
            .accessibilityLabel(String(localized: "reports.share"))
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Spec.surface)
        )
    }

    // MARK: - Wiring

    private func bootstrap() {
        guard viewModel.interactor == nil else { return }
        let interactor = ReportsInteractor(
            sessionRepository: container.sessionRepository,
            childRepository: container.childRepository
        )
        let presenter = ReportsPresenter()
        presenter.display = viewModel
        interactor.presenter = presenter
        viewModel.interactor = interactor
    }

    private func reload() async {
        viewModel.isLoading = true
        await viewModel.interactor?.fetchReport(.init(
            childId: Self.demoChildId,
            range: range.dateRange
        ))
        viewModel.isLoading = false
    }

    private func export(format: ReportsModels.ExportReport.Format) async {
        await viewModel.interactor?.exportReport(.init(
            childId: Self.demoChildId,
            range: range.dateRange,
            format: format
        ))
        if let url = viewModel.exportedURL {
            pendingShareItem = ShareItem(url: url)
        }
    }
}

// MARK: - ViewModel holder (Display logic + observable state)

@MainActor
@Observable
final class ReportsViewModelHolder: ReportsDisplayLogic {
    var titleText: String = String(localized: "reports.title")
    var rangeLabel: String = ""
    var totalSessionsText: String = ""
    var totalMinutesText: String = ""
    var overallSuccessPercent: Int = 0
    var rows: [SoundBreakdownRow] = []
    var timeline: [SessionTimelineEntry] = []
    var isLoading: Bool = false

    var exportedURL: URL?
    var exportedSizeText: String = ""

    var interactor: ReportsInteractor?

    func displayFetchReport(_ viewModel: ReportsModels.FetchReport.ViewModel) {
        self.titleText = viewModel.titleText
        self.rangeLabel = viewModel.rangeLabel
        self.totalSessionsText = viewModel.totalSessionsText
        self.totalMinutesText = viewModel.totalMinutesText
        self.overallSuccessPercent = viewModel.overallSuccessPercent
        self.rows = viewModel.rows
        self.timeline = viewModel.timeline
    }

    func displayExportReport(_ viewModel: ReportsModels.ExportReport.ViewModel) {
        self.exportedURL = viewModel.shareableURL
        self.exportedSizeText = viewModel.sizeText
    }
}

// MARK: - Filter & Range options

private enum ReportRange: String, CaseIterable, Identifiable, Hashable {
    case last7
    case last30
    case last90

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7:  return String(localized: "reports.range.7")
        case .last30: return String(localized: "reports.range.30")
        case .last90: return String(localized: "reports.range.90")
        }
    }

    var dateRange: DateRange {
        switch self {
        case .last7:  return DateRange.lastNDays(7)
        case .last30: return DateRange.lastNDays(30)
        case .last90: return DateRange.lastNDays(90)
        }
    }
}

private enum ReportFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case improving
    case struggling
    case recommendations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:             return String(localized: "reports.filter.all")
        case .improving:       return String(localized: "reports.filter.improving")
        case .struggling:      return String(localized: "reports.filter.struggling")
        case .recommendations: return String(localized: "reports.filter.recommendations")
        }
    }

    var icon: String {
        switch self {
        case .all:             return "list.bullet"
        case .improving:       return "arrow.up.right"
        case .struggling:      return "arrow.down.right"
        case .recommendations: return "lightbulb"
        }
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(TypographyTokens.caption(13).bold())
            }
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp2)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(isSelected ? ColorTokens.Spec.accent : ColorTokens.Spec.surface)
            )
            .foregroundStyle(isSelected ? Color.white : ColorTokens.Spec.ink)
            .overlay(
                Capsule()
                    .stroke(ColorTokens.Spec.line, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - SummaryMetric

private struct SummaryMetric: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ColorTokens.Spec.accent)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.Spec.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(TypographyTokens.caption(10))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - SoundBreakdownRowView

private struct SoundBreakdownRowView: View {
    let row: SoundBreakdownRow
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Spec.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text(row.sound)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.Spec.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.currentStageTitle)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(1)
                    HStack(spacing: SpacingTokens.sp2) {
                        Text(String(localized: "reports.row.attempts.\(row.attempts)"))
                        Text("·")
                        Text(String(localized: "reports.row.success.\(row.successes)"))
                    }
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                }

                Spacer()

                deltaPill
            }
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Spec.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.sound): \(Int(row.averageConfidence * 100)) процентов уверенности")
    }

    private var deltaPill: some View {
        let delta = row.weekOverWeekDelta
        let percent = String(format: "%+.0f", delta * 100)
        let color: Color = delta >= 0.05
            ? ColorTokens.Semantic.success
            : (delta <= -0.05 ? ColorTokens.Semantic.warning : ColorTokens.Spec.inkMuted)
        let iconName = delta >= 0.05
            ? "arrow.up.right"
            : (delta <= -0.05 ? "arrow.down.right" : "minus")
        return HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
            Text("\(percent)pp")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, SpacingTokens.sp2)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - SoundDetailSheet

private struct SoundDetailSheet: View {
    let row: SoundBreakdownRow

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp3) {
                Text(row.sound)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(ColorTokens.Spec.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.currentStageTitle)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Spec.ink)
                    Text(String(localized: "reports.detail.subtitle"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                }
                Spacer()
            }

            VStack(spacing: SpacingTokens.sp3) {
                detailRow(
                    label: String(localized: "reports.detail.attempts"),
                    value: "\(row.attempts)"
                )
                detailRow(
                    label: String(localized: "reports.detail.successes"),
                    value: "\(row.successes)"
                )
                detailRow(
                    label: String(localized: "reports.detail.confidence"),
                    value: "\(Int(row.averageConfidence * 100))%"
                )
                detailRow(
                    label: String(localized: "reports.detail.wow"),
                    value: String(format: "%+.1fpp", row.weekOverWeekDelta * 100)
                )
            }

            Spacer()
        }
        .padding(SpacingTokens.sp5)
        .background(ColorTokens.Spec.bg.ignoresSafeArea())
        .environment(\.circuitContext, .specialist)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
            Spacer()
            Text(value)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Spec.ink)
        }
    }
}

// MARK: - Share helpers

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Specialist Reports") {
    SpecialistReportsView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
