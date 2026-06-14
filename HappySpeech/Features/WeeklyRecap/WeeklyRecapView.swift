import Charts
import SwiftUI

// MARK: - WeeklyRecapView

struct WeeklyRecapView: View {

    @Environment(AppContainer.self) private var container
    @State private var interactor = WeeklyRecapInteractor()
    @State private var bootstrapped = false
    @State private var shareItem: WeeklyRecapShareItem?
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 2)

    var body: some View {
        NavigationStack {
            ZStack {
                // Чистый тёплый статичный фон Parent-контура (без декоративной
                // mesh-подложки) — единый паттерн с ParentHome / ProgressDashboard.
                ColorTokens.Parent.bg.ignoresSafeArea()

                content
            }
            .navigationTitle(Text(String(localized: "weeklyRecap.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToParentHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .sheet(item: $shareItem) { item in
                WeeklyRecapShareSheet(items: [item.text])
            }
        }
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
    }

    @ViewBuilder
    private var content: some View {
        if interactor.state.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    hero
                    kpiGrid
                    chartCard
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // Дружелюбное пустое состояние (эталон states-empty-error-loading):
    // маскот Ляля + тёплый заголовок + пояснение + CTA «Начать занятие»,
    // ведущая на родительскую главную. Не «дыра сверху» — центрировано,
    // CTA даёт выход из тупика.
    private var emptyState: some View {
        HSEmptyStateView(
            mascot: .thinking,
            title: String(localized: "weeklyRecap.empty.title"),
            subtitle: String(localized: "weeklyRecap.empty.message"),
            actionTitle: String(localized: "weeklyRecap.empty.cta", defaultValue: "Начать занятие"),
            action: {
                hapticService.impact(.light)
                exitToParentHome()
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.circuitContext, .parent)
    }

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true
        let worker = ProgressDashboardWorker(
            sessionRepository: container.sessionRepository,
            childRepository: container.childRepository
        )
        interactor = WeeklyRecapInteractor(worker: worker)
        await interactor.load(childId: container.currentChildId)
    }

    private var hero: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "weeklyRecap.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(String(localized: "weeklyRecap.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.state.kpis.enumerated()), id: \.element.id) { index, kpi in
                kpiTile(kpi)
                    .hsParallaxTile(factor: 0.3)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.94)
                    }
                    .zIndex(Double(interactor.state.kpis.count - index))
            }
        }
    }

    private func kpiTile(_ kpi: WeeklyRecapModels.KPI) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: kpi.icon)
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .hsSymbolEffect(.pulse, value: kpi.value)
                    Text(kpi.title)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                    Spacer()
                }
                Text(kpi.value)
                    .font(TypographyTokens.titleLarge(28))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !kpi.trend.isEmpty {
                    Text(kpi.trend)
                        .font(TypographyTokens.caption(11).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                kpi.trend.isEmpty
                    ? "\(kpi.title): \(kpi.value)"
                    : "\(kpi.title): \(kpi.value), \(String(localized: "weeklyRecap.kpi.trend.a11y")) \(kpi.trend)"
            )
        )
    }

    // MARK: - Weekly chart
    //
    // 7-дневный бар-чарт активности (тёплые коралл/butter столбцы),
    // подписи дней Пн–Вс — без off-palette зелёного/синего.

    private struct DayBar: Identifiable {
        let id: Int
        let day: String
        let value: Double
        let isPeak: Bool
    }

    private var weekdayLabels: [String] {
        [
            String(localized: "day.mon"), String(localized: "day.tue"),
            String(localized: "day.wed"), String(localized: "day.thu"),
            String(localized: "day.fri"), String(localized: "day.sat"),
            String(localized: "day.sun")
        ]
    }

    private var dayBars: [DayBar] {
        let values = interactor.state.chartValues
        let peak = values.max() ?? 0
        return values.enumerated().map { index, value in
            DayBar(
                id: index,
                day: index < weekdayLabels.count ? weekdayLabels[index] : "\(index + 1)",
                value: value,
                isPeak: value == peak && peak > 0
            )
        }
    }

    private var chartCard: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "chart.bar.fill")
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                    Text(String(localized: "weeklyRecap.chart.title"))
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Spacer()
                    Text(String(localized: "weeklyRecap.chart.unit"))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                }

                Chart(dayBars) { bar in
                    BarMark(
                        x: .value(String(localized: "weeklyRecap.chart.day.axis"), bar.day),
                        y: .value(String(localized: "weeklyRecap.chart.value.axis"), bar.value),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(
                        bar.isPeak ? ColorTokens.Brand.primary : ColorTokens.Brand.primaryLo
                    )
                    .cornerRadius(6)
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(TypographyTokens.caption(11).weight(.medium))
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                        }
                    }
                }
                .frame(height: 124)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.45),
                    value: interactor.state.chartValues
                )
                .accessibilityLabel(Text(String(localized: "weeklyRecap.chart.title")))
                .accessibilityValue(Text(String(localized: "weeklyRecap.chart.unit")))
            }
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "weeklyRecap.cta.share"),
            style: .primary,
            size: .large,
            icon: "square.and.arrow.up"
        ) {
            hapticService.impact(.light)
            shareItem = WeeklyRecapShareItem(text: interactor.share())
        }
    }
}

// MARK: - Share helpers

private struct WeeklyRecapShareItem: Identifiable {
    let id = UUID()
    let text: String
}

private struct WeeklyRecapShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("WeeklyRecap — Light") {
    let container = AppContainer.preview()
    container.currentChildId = "preview-child-1"
    return WeeklyRecapView()
        .environment(AppCoordinator())
        .environment(container)
}

#Preview("WeeklyRecap — Dark") {
    let container = AppContainer.preview()
    container.currentChildId = "preview-child-1"
    return WeeklyRecapView()
        .environment(AppCoordinator())
        .environment(container)
        .preferredColorScheme(.dark)
}
