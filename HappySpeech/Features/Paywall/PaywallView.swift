import OSLog
import SwiftUI

// MARK: - PaywallView
//
// Контур: parent / specialist. Открывается ТОЛЬКО за ParentalGate (Kids Category).
// Терапевтика бесплатна — paywall продаёт только premium-надстройки.
//
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.

struct PaywallView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP State

    @State private var display = PaywallDisplay()
    @State private var interactor: PaywallInteractor?
    @State private var presenter: PaywallPresenter?
    @State private var router: PaywallRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI state

    @State private var selectedPlanID: String?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PaywallView")

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.large) {
                        headerSection
                        featureListSection
                        if display.productsUnavailable {
                            unavailableSection
                        } else {
                            plansSection
                            purchaseButton
                        }
                        restoreButton
                        footnoteSection
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.large)
                    .padding(.bottom, SpacingTokens.xxLarge)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("PaywallRoot")

                toastOverlay
            }
            .navigationTitle(String(localized: "paywall.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(String(localized: "paywall.close.a11y"))
                }
            }
        }
        .environment(\.circuitContext, .parent)
        .onChange(of: display.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .onAppear { bootstrap() }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: SpacingTokens.small) {
            LyalyaHeroView(state: .happy, size: 110)
                .accessibilityHidden(true)

            Text(String(localized: "paywall.header.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            Text(String(localized: "paywall.header.subtitle"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if !display.statusLine.isEmpty {
                Text(display.statusLine)
                    .font(TypographyTokens.caption(13).weight(.semibold))
                    .foregroundStyle(display.isPremium ? ColorTokens.Semantic.success : ColorTokens.Parent.inkSoft)
                    .padding(.top, SpacingTokens.micro)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "paywall.header.title")). \(String(localized: "paywall.header.subtitle"))")
    }

    // MARK: - Feature list

    @ViewBuilder
    private var featureListSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.large) {
            VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                ForEach(display.features) { feature in
                    HStack(alignment: .top, spacing: SpacingTokens.regular) {
                        Image(systemName: feature.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                            Text(feature.title)
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(ColorTokens.Parent.ink)
                            Text(feature.subtitle)
                                .font(TypographyTokens.body(13))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(feature.title). \(feature.subtitle)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Plans

    @ViewBuilder
    private var plansSection: some View {
        VStack(spacing: SpacingTokens.regular) {
            ForEach(display.plans) { plan in
                planCard(plan)
            }
        }
    }

    @ViewBuilder
    private func planCard(_ plan: PlanVM) -> some View {
        let isSelected = selectedPlanID == plan.id
        Button {
            selectedPlanID = plan.id
        } label: {
            HSLiquidGlassCard(
                style: isSelected ? .tinted(ColorTokens.Brand.primary) : .primary,
                padding: SpacingTokens.large
            ) {
                HStack(spacing: SpacingTokens.regular) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        HStack(spacing: SpacingTokens.small) {
                            Text(plan.title)
                                .font(TypographyTokens.headline(17))
                                .foregroundStyle(ColorTokens.Parent.ink)
                            if let badge = plan.badge {
                                HSBadge(badge, style: plan.isBestValue
                                        ? .filled(ColorTokens.Brand.gold)
                                        : .info)
                            }
                        }
                        Text(plan.periodText)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }

                    Spacer()

                    Text(plan.priceText)
                        .font(TypographyTokens.headline(18).weight(.bold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plan.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(String(localized: "paywall.plan.select.hint"))
    }

    // MARK: - Purchase button

    @ViewBuilder
    private var purchaseButton: some View {
        HSButton(
            display.isPremium
                ? String(localized: "paywall.cta.alreadyPremium")
                : String(localized: "paywall.cta.subscribe"),
            style: .primary,
            size: .large,
            icon: display.isPremium ? "checkmark" : "sparkles"
        ) {
            guard let planID = selectedPlanID ?? display.plans.first?.id else { return }
            logger.info("purchase tapped: \(planID, privacy: .public)")
            interactor?.purchase(.init(productID: planID))
        }
        .disabled(display.isPremium || display.plans.isEmpty)
        .opacity((display.isPremium || display.plans.isEmpty) ? 0.6 : 1.0)
        .accessibilityHint(String(localized: "paywall.cta.subscribe.hint"))
    }

    // MARK: - Restore button

    @ViewBuilder
    private var restoreButton: some View {
        HSButton(
            display.restoreTitle,
            style: .ghost,
            size: .medium,
            icon: "arrow.clockwise"
        ) {
            logger.info("restore tapped")
            interactor?.restore(.init())
        }
        .accessibilityLabel(display.restoreTitle)
        .accessibilityHint(String(localized: "paywall.restore.hint"))
    }

    // MARK: - Unavailable state

    @ViewBuilder
    private var unavailableSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.large) {
            VStack(spacing: SpacingTokens.small) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
                Text(String(localized: "paywall.unavailable.title"))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                Text(String(localized: "paywall.unavailable.subtitle"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HSButton(
                    String(localized: "paywall.unavailable.retry"),
                    style: .secondary,
                    size: .medium,
                    icon: "arrow.clockwise"
                ) {
                    interactor?.loadOfferings(.init())
                }
                .padding(.top, SpacingTokens.tiny)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "paywall.unavailable.title"))
    }

    // MARK: - Footnote

    @ViewBuilder
    private var footnoteSection: some View {
        Text(String(localized: "paywall.footnote"))
            .font(TypographyTokens.caption(11))
            .foregroundStyle(ColorTokens.Parent.inkSoft)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, SpacingTokens.small)
    }

    // MARK: - Toast overlay

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = display.toastMessage {
            HSToast(toast, type: display.toastIsError ? .error : .success)
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.bottom, SpacingTokens.large)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2.6))
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        display.clearToast()
                    }
                }
        }
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = PaywallInteractor(storeService: container.storeService)
        let presenter = PaywallPresenter()
        let router = PaywallRouter()

        interactor.presenter = presenter
        presenter.display = display
        router.dismiss = { [weak display] in display?.shouldDismiss = true }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadOfferings(.init())
    }
}

// MARK: - Preview

#Preview("Paywall — free user (Light)") {
    PaywallView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}

#Preview("Paywall — free user (Dark)") {
    PaywallView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
        .preferredColorScheme(.dark)
}
