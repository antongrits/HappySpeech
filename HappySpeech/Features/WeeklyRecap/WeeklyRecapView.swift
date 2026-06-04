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
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
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
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Parent.accent)
                .accessibilityHidden(true)
            Text(String(localized: "weeklyRecap.empty.title"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
            Text(String(localized: "weeklyRecap.empty.message"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.sp5)
        .accessibilityElement(children: .combine)
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
                Text(kpi.trend)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Semantic.success)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(kpi.title): \(kpi.value), тренд \(kpi.trend)"))
    }

    private var chartCard: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text("Активность по дням")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
                    ForEach(Array(interactor.state.chartValues.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.Parent.accent.opacity(0.7))
                            .frame(height: max(10, value * 8))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 110)
                .accessibilityHidden(true)
                Text("Пн Вт Ср Чт Пт Сб Вс")
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .frame(maxWidth: .infinity)
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
