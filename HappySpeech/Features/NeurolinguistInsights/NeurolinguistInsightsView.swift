import SwiftUI

// MARK: - NeurolinguistInsightsView
//
// Parent / Specialist contour. «Insights от Ляли» — структурированная
// аналитика прогресса ребёнка из последних 7 дней сессий.
//
// Состав:
// 1. Hero (Ляля + заголовок «Что говорит Ляля»).
// 2. Trend badge + дата генерации.
// 3. Metric chips (sessions / accuracy / minutes / streak / sounds).
// 4. Markdown summary (5–7 параграфов на русском).
// 5. Recommendation card.
// 6. CTA — «Посмотреть прогресс» / «История занятий».
//
// Доступ: ParentHome → «Insights от Ляли», Specialist → «Аналитика».
// Кэшируется на 24 часа в InsightObject (Realm).

struct NeurolinguistInsightsView: View {

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var viewModel = NeurolinguistInsightsViewModel()
    @State private var interactor: NeurolinguistInsightsInteractor?
    @State private var presenter: NeurolinguistInsightsPresenter?
    @State private var router: NeurolinguistInsightsRouter?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Parent.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sectionGap) {
                    heroSection
                    contentSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
            }
            .refreshable {
                await refresh(force: true)
            }
        }
        .navigationTitle(String(localized: "insights.nav_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbar }
        .task { await bootstrap() }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(String(localized: "insights.hero.title"))
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "insights.hero.subtitle"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: SpacingTokens.sp2)

            // E v21: 3D Ляля в hero NeurolinguistInsights (требование «3D героев на каждом экране»).
            LyalyaHeroView(state: .happy, size: 100)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.sp3)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, SpacingTokens.sp4)

        case .empty:
            HSEmptyState(
                icon: "chart.line.flattrend.xyaxis",
                title: String(localized: "insights.empty.title"),
                message: String(localized: "insights.empty.message"),
                actionTitle: String(localized: "insights.empty.cta")
            ) {
                router?.routeToProgressDashboard(childId: childId)
            }

        case .ready:
            if let card = viewModel.card {
                VStack(spacing: SpacingTokens.sp4) {
                    insightCardView(card)
                    metricsRow
                    recommendationCard(card)
                    actionButtons
                }
            }

        case .error(let message):
            HSEmptyState(
                icon: "exclamationmark.triangle",
                title: String(localized: "insights.error.title"),
                message: message,
                actionTitle: String(localized: "insights.error.retry")
            ) {
                Task { await refresh(force: true) }
            }
        }
    }

    // MARK: - Insight card

    private func insightCardView(_ card: NeurolinguistInsights.InsightCard) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "sparkles")
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)

                    Text(card.title)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    trendBadge(text: card.trendBadge, colorToken: card.trendColorToken)
                }

                // Markdown summary — отрисовываем как Text() с Markdown поддержкой.
                Text(LocalizedStringKey(card.summaryMarkdown))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(card.summaryMarkdown)

                HStack(spacing: SpacingTokens.sp1) {
                    Image(systemName: "clock")
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                    Text(card.generatedAtText)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                }
            }
        }
    }

    private func trendBadge(text: String, colorToken: String) -> some View {
        let tint: Color = {
            switch colorToken {
            case "success": return ColorTokens.Semantic.success
            case "warning": return ColorTokens.Semantic.warning
            case "info":    return ColorTokens.Brand.sky
            default:        return ColorTokens.Parent.inkMuted
            }
        }()

        return Text(text)
            .font(TypographyTokens.caption(11).weight(.bold))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint))
            .accessibilityLabel(text)
    }

    // MARK: - Metrics row

    private var metricsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp3) {
                ForEach(viewModel.metricChips) { chip in
                    metricChipView(chip)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func metricChipView(_ chip: NeurolinguistInsights.MetricChip) -> some View {
        let tint: Color = {
            switch chip.colorToken {
            case "primary": return ColorTokens.Brand.primary
            case "success": return ColorTokens.Semantic.success
            case "warning": return ColorTokens.Semantic.warning
            case "info":    return ColorTokens.Brand.sky
            default:        return ColorTokens.Parent.inkMuted
            }
        }()

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: chip.icon)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(chip.label)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            Text(chip.value)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(SpacingTokens.sp3)
        .frame(minWidth: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(tint.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(chip.label): \(chip.value)")
    }

    // MARK: - Recommendation

    private func recommendationCard(_ card: NeurolinguistInsights.InsightCard) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.18))) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Image(systemName: "lightbulb.fill")
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "insights.reco.title"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(card.recommendation)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "insights.reco.title") + ". " + card.recommendation
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSButton(
                String(localized: "insights.action.progress"),
                style: .primary,
                size: .large,
                icon: "chart.line.uptrend.xyaxis"
            ) {
                router?.routeToProgressDashboard(childId: childId)
            }
            HSButton(
                String(localized: "insights.action.history"),
                style: .secondary,
                size: .large,
                icon: "clock.arrow.circlepath"
            ) {
                router?.routeToSessionHistory(childId: childId)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task { await refresh(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(ColorTokens.Parent.accent)
            }
            .accessibilityLabel(String(localized: "insights.toolbar.refresh"))
        }
    }

    // MARK: - VIP bootstrap

    private func bootstrap() async {
        if interactor == nil {
            let presenter = NeurolinguistInsightsPresenter()
            let interactor = NeurolinguistInsightsInteractor(
                childRepository: container.childRepository,
                sessionRepository: container.sessionRepository,
                realmActor: container.realmActor
            )
            let router = NeurolinguistInsightsRouter(coordinator: coordinator)
            presenter.viewModel = viewModel
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = router
        }
        await refresh(force: false)
    }

    private func refresh(force: Bool) async {
        viewModel.state = .loading
        await interactor?.load(NeurolinguistInsights.LoadRequest(
            childId: childId,
            forceRefresh: force
        ))
    }
}

// MARK: - Preview

#Preview("Neurolinguist Insights") {
    let container = AppContainer.preview()
    return NavigationStack {
        NeurolinguistInsightsView(childId: "preview-child-1")
            .environment(container)
            .environment(AppCoordinator())
    }
}
