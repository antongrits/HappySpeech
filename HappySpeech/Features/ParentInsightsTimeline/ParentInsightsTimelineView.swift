import OSLog
import SwiftUI

// MARK: - ParentInsightsTimelineViewModelHolder

@MainActor
@Observable
final class ParentInsightsTimelineViewModelHolder: ParentInsightsTimelineDisplayLogic {

    var loadVM: ParentInsightsTimelineModels.Load.ViewModel?
    var selectedDayVM: ParentInsightsTimelineModels.SelectDay.ViewModel?
    var toastMessage: String?
    var showToast: Bool = false

    func displayLoad(viewModel: ParentInsightsTimelineModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displaySelectDay(viewModel: ParentInsightsTimelineModels.SelectDay.ViewModel) async {
        self.selectedDayVM = viewModel
    }

    func displayRefresh(viewModel: ParentInsightsTimelineModels.Refresh.ViewModel) async {
        self.toastMessage = viewModel.toastMessage
        self.showToast = true
    }
}

// MARK: - ParentInsightsTimelineView (Clean Swift: View)
//
// Block AE batch 2 v21 — Weekly LLM Insights Timeline.
//
// Layout:
//   1. Hero — «Неделя <имя>» + диапазон дат + источник (LLM A / эвристика)
//   2. Summary block — 4 stat-карточки (LazyVGrid 2x2)
//   3. Timeline — 7 строк (LazyVStack), каждая по дню
//   4. Detail sheet — paragraph + recommendation
//
// Accessibility:
//   • VoiceOver: каждая dayCell — combined element с готовой a11y-меткой.
//   • Dynamic Type: ScrollView root + `.minimumScaleFactor(0.85)` на ключевых текстах.
//   • Reduced Motion: убираем cross-dissolve у sheet (.transaction).

struct ParentInsightsTimelineView: View {

    let childId: String

    @State private var holder = ParentInsightsTimelineViewModelHolder()
    @State private var interactor: ParentInsightsTimelineInteractor?
    @State private var presenter: ParentInsightsTimelinePresenter?
    @State private var router: ParentInsightsTimelineRouter?
    @State private var showDetailSheet: Bool = false
    @State private var isRefreshing: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentInsightsTimeline.View"
    )

    private let statColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: SpacingTokens.sp3),
        count: 2
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel: viewModel)
                            statsSection(viewModel: viewModel)
                            timelineSection(viewModel: viewModel)
                            footerNote(viewModel: viewModel)
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
                .refreshable {
                    await refreshAction()
                }
            }
            .navigationTitle(Text("parentInsightsTimeline.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                    }
                    .accessibilityLabel(Text("parentInsightsTimeline.back.a11y"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshAction() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                    .accessibilityLabel(Text("parentInsightsTimeline.refresh.a11y"))
                    .disabled(isRefreshing)
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                if let detail = holder.selectedDayVM {
                    detailSheet(viewModel: detail)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast, let toast = holder.toastMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: holder.showToast)
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(viewModel: ParentInsightsTimelineModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text(viewModel.heroTitle)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.heroSubtitle)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HSBadge(viewModel.llmSourceLabel, style: .info, icon: "sparkles")
                .padding(.top, SpacingTokens.sp1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Stats

    @ViewBuilder
    private func statsSection(viewModel: ParentInsightsTimelineModels.Load.ViewModel) -> some View {
        LazyVGrid(columns: statColumns, spacing: SpacingTokens.sp3) {
            ForEach(viewModel.summaryStats) { stat in
                statCard(stat)
            }
        }
    }

    @ViewBuilder
    private func statCard(_ stat: ParentInsightsTimelineModels.Load.SummaryStat) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: stat.symbolName)
                .font(.title3)
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.value)
                    .font(TypographyTokens.headline(16).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(stat.label)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(stat.label), \(stat.value)"))
    }

    // MARK: - Timeline

    @ViewBuilder
    private func timelineSection(viewModel: ParentInsightsTimelineModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text("parentInsightsTimeline.section.timeline.title")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)
                .padding(.top, SpacingTokens.sp3)

            LazyVStack(spacing: SpacingTokens.sp2) {
                ForEach(viewModel.cells) { cell in
                    dayCell(cell)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ cell: ParentInsightsTimelineModels.Load.DayCellViewModel) -> some View {
        Button {
            Task { await selectDay(id: cell.id) }
        } label: {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                VStack(spacing: 2) {
                    Text(cell.weekdayShort)
                        .font(TypographyTokens.caption(11).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                    Text(cell.dateLabel)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(1)
                }
                .frame(width: 56)

                Image(systemName: cell.severitySymbol)
                    .font(.title3)
                    .foregroundStyle(severityColor(cell.severityColorName))
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(cell.metricsLine)
                        .font(TypographyTokens.body(13).monospacedDigit())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(cell.comment)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if cell.isToday {
                    Text("parentInsightsTimeline.cell.today.badge")
                        .font(TypographyTokens.caption(10).weight(.semibold))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .padding(.horizontal, SpacingTokens.sp2)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(ColorTokens.Brand.primary)
                        )
                }
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(
                        cell.isToday ? ColorTokens.Brand.primary : ColorTokens.Parent.line,
                        lineWidth: cell.isToday ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(cell.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    private func severityColor(_ name: String) -> Color {
        switch name {
        case "positive":  return ColorTokens.Semantic.success
        case "attention": return ColorTokens.Semantic.warning
        default:          return ColorTokens.Parent.inkMuted
        }
    }

    // MARK: - Detail sheet

    @ViewBuilder
    private func detailSheet(viewModel: ParentInsightsTimelineModels.SelectDay.ViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                Text(viewModel.titleLabel)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, SpacingTokens.sp4)

                Text(viewModel.metricsLabel)
                    .font(TypographyTokens.body(14).monospacedDigit())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)

                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text("parentInsightsTimeline.detail.section.note")
                        .font(TypographyTokens.caption(11))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(ColorTokens.Parent.inkMuted)

                    Text(viewModel.detailParagraph)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.sp4)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .fill(ColorTokens.Parent.bg)
                )

                if let rec = viewModel.recommendationLabel {
                    HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(ColorTokens.Brand.gold)
                            .accessibilityHidden(true)
                        Text(rec)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(SpacingTokens.sp3)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .fill(ColorTokens.Brand.gold.opacity(0.10))
                    )
                }

                Button {
                    showDetailSheet = false
                    router?.routeToProgressDashboard()
                } label: {
                    Label {
                        Text("parentInsightsTimeline.detail.cta.dashboard")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } icon: {
                        Image(systemName: "chart.bar.fill")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, SpacingTokens.sp2)
                .accessibilityHint(Text("parentInsightsTimeline.detail.cta.dashboard.hint"))

                Spacer(minLength: SpacingTokens.sp4)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .background(ColorTokens.Parent.surface.ignoresSafeArea())
    }

    // MARK: - Footer note

    @ViewBuilder
    private func footerNote(viewModel: ParentInsightsTimelineModels.Load.ViewModel) -> some View {
        Text("parentInsightsTimeline.footer.note")
            .font(TypographyTokens.caption(11))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, SpacingTokens.sp4)
            .padding(.horizontal, SpacingTokens.sp4)
            .accessibilityHint(Text(viewModel.llmSourceLabel))
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("parentInsightsTimeline.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Brand.primary)
            )
            .depthShadow(ShadowTokens.parentDepth)
            .task {
                try? await Task.sleep(for: .seconds(2.0))
                holder.showToast = false
            }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = ParentInsightsTimelinePresenter(displayLogic: holder)
            let aggregator = InsightAggregatorWorker(
                sessionRepository: container.sessionRepository
            )
            let llmWorker = LLMInsightWorker(localLLM: container.localLLMService)
            let interactor = ParentInsightsTimelineInteractor(
                aggregator: aggregator,
                llmWorker: llmWorker,
                childRepository: container.childRepository
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = ParentInsightsTimelineRouter(
                dismissAction: { [self] in dismiss() },
                openProgressDashboardAction: { [self] in
                    coordinator.navigate(to: .progressDashboard(childId: childId))
                }
            )
        }
        await interactor?.load(
            request: .init(childId: childId, weekEndingOn: Date())
        )
    }

    private func selectDay(id: String) async {
        await interactor?.selectDay(request: .init(dayId: id))
        showDetailSheet = true
    }

    private func refreshAction() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await interactor?.refresh(request: .init(childId: childId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ParentInsightsTimeline / Parent") {
    ParentInsightsTimelineView(childId: "preview-child-1")
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
#endif
