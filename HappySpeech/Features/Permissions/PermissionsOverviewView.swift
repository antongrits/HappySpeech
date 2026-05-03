import OSLog
import SwiftUI

// MARK: - PermissionsOverviewView
//
// Экран «Разрешения» из Settings. Показывает статус всех 4 разрешений
// (микрофон, камера, уведомления, AR Face Tracking) в виде карточек.
//
// Логика:
// - Granted → зелёная галочка, без CTA.
// - Not Determined → кнопка «Разрешить» → системный prompt.
// - Denied / Restricted → кнопка «Открыть Настройки» → deeplink.
//
// Маскот Ляля сверху меняет состояние в зависимости от итогового статуса:
// - все выданы → celebrating
// - есть denied → encouraging
// - иначе → explaining
//
// VIP: View → Interactor → Presenter → Display.

struct PermissionsOverviewView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    // MARK: - VIP State

    @State private var display = PermissionsDisplay()
    @State private var interactor: PermissionsInteractor?
    @State private var presenter: PermissionsPresenter?
    @State private var router: PermissionsRouter?
    @State private var bootstrapped = false
    @State private var appeared = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PermissionsOverviewView")

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer.ignoresSafeArea()

            ScrollView {
                VStack(spacing: SpacingTokens.large) {
                    mascotSection
                    summaryCard
                    cardsSection
                    Spacer(minLength: SpacingTokens.xxLarge)
                }
                .padding(.top, SpacingTokens.medium)
                .padding(.bottom, SpacingTokens.xxLarge)
                .padding(.horizontal, SpacingTokens.screenEdge)
            }

            if let toast = display.toastMessage {
                HSToast(toast, type: .info)
                    .padding(.bottom, SpacingTokens.large)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            display.clearToast()
                        }
                    }
            }
        }
        .navigationTitle(String(localized: "permissions.overview.navTitle"))
        .navigationBarTitleDisplayMode(.large)
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
        .onAppear {
            refreshStatuses()
            withAnimation(reduceMotion ? nil : MotionTokens.spring.delay(0.15)) {
                appeared = true
            }
        }
        .onChange(of: display.pendingSettingsURL) { _, url in
            guard let url else { return }
            openURL(url)
            display.clearPendingSettings()
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                ColorTokens.Parent.bg,
                ColorTokens.Brand.mint.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Mascot

    private var mascotSection: some View {
        VStack(spacing: SpacingTokens.small) {
            LyalyaMascotView(state: mascotState, size: 100)
                .offset(y: appeared ? 0 : -16)
                .opacity(appeared ? 1 : 0)
                .accessibilityLabel(mascotAccessibilityLabel)

            Text(display.overviewSummaryLabel)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.large)
        }
    }

    private var mascotState: LyalyaState {
        if display.overviewAllGranted { return .celebrating }
        let hasDenied = display.overviewCards.contains { $0.state == .denied }
        return hasDenied ? .encouraging : .explaining
    }

    private var mascotAccessibilityLabel: String {
        if display.overviewAllGranted {
            return String(localized: "permissions.lyalya.a11y.celebrating")
        }
        return String(localized: "permissions.lyalya.a11y.explaining")
    }

    // MARK: - Summary card

    @ViewBuilder
    private var summaryCard: some View {
        if !display.overviewCards.isEmpty {
            HSLiquidGlassCard(
                style: display.overviewAllGranted
                    ? .tinted(ColorTokens.Semantic.success)
                    : .primary,
                padding: SpacingTokens.regular
            ) {
                HStack(spacing: SpacingTokens.regular) {
                    Image(systemName: display.overviewAllGranted
                          ? "checkmark.shield.fill"
                          : "shield.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(display.overviewAllGranted
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Brand.primary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(display.overviewAllGranted
                             ? String(localized: "permissions.overview.allGranted")
                             : String(
                                format: String(localized: "permissions.overview.partialGranted"),
                                display.overviewGrantedCount,
                                display.overviewTotalCount
                             ))
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        // Мини progress bar
                        if !display.overviewAllGranted {
                            HSProgressBar(
                                value: Double(display.overviewGrantedCount) / Double(max(1, display.overviewTotalCount)),
                                style: .parent,
                                tint: ColorTokens.Semantic.success
                            )
                            .frame(height: 5)
                            .accessibilityHidden(true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.overviewSummaryLabel)
        }
    }

    // MARK: - Permission cards list

    private var cardsSection: some View {
        VStack(spacing: SpacingTokens.listGap) {
            ForEach(display.overviewCards) { card in
                PermissionOverviewCardView(
                    card: card,
                    reduceMotion: reduceMotion,
                    onRequest: { handleRequest(card) },
                    onOpenSettings: { handleOpenSettings() }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82),
            value: display.overviewCards.map(\.state.rawValue)
        )
    }

    // MARK: - Actions

    private func handleRequest(_ card: PermissionOverviewCard) {
        container.hapticService.impact(.medium)
        // Запустить одиночный flow через PermissionFlowView — оно само вызовет системный диалог.
        coordinator.push(.permissionFlow(card.id))
    }

    private func handleOpenSettings() {
        container.hapticService.impact(.light)
        interactor?.openSettings(.init())
    }

    private func refreshStatuses() {
        interactor?.checkAllPermissions(.init())
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = PermissionsInteractor()
        let presenter = PermissionsPresenter()
        let router = PermissionsRouter()

        interactor.presenter = presenter
        presenter.display = display
        router.onDismiss = { [weak coordinator] in
            coordinator?.pop()
        }
        router.onFinished = { [weak coordinator] in
            coordinator?.pop()
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.checkAllPermissions(.init())
    }
}

// MARK: - PermissionOverviewCard (local component)

/// Компактная карточка одного разрешения для PermissionsOverviewView.
/// Более лаконична чем PermissionFlowView — без маскота и шагомера.
private struct PermissionOverviewCardView: View {

    let card: PermissionOverviewCard
    let reduceMotion: Bool
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
            HStack(alignment: .top, spacing: SpacingTokens.regular) {
                iconView
                contentView
                Spacer(minLength: 0)
                statusView
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityHint(card.accessibilityHint)
    }

    // MARK: Icon

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(card.accentColor.opacity(card.state == .granted ? 0.15 : 0.12))
                .frame(width: 48, height: 48)
            Image(systemName: card.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(card.state == .granted
                    ? ColorTokens.Semantic.success
                    : card.accentColor)
                .accessibilityHidden(true)
        }
    }

    // MARK: Content (title, description, CTA)

    private var contentView: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(card.title)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(card.description)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if card.canRequest {
                allowButton
                    .padding(.top, SpacingTokens.tiny)
            } else if card.showSettingsButton {
                settingsButton
                    .padding(.top, SpacingTokens.tiny)
            }
        }
    }

    private var allowButton: some View {
        Button(action: onRequest) {
            Text(String(localized: "permissions.overview.action.allow"))
                .font(TypographyTokens.body(13).weight(.semibold))
                .foregroundStyle(card.accentColor)
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(card.accentColor.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(String(localized: "permissions.overview.action.allow"))
        .accessibilityHint(card.title)
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: 4) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11))
                    .accessibilityHidden(true)
                Text(String(localized: "permissions.openSettings"))
                    .font(TypographyTokens.caption(13).weight(.medium))
            }
            .foregroundStyle(ColorTokens.Semantic.error)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(ColorTokens.Semantic.errorBg)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(String(localized: "permissions.openSettings"))
    }

    // MARK: Status badge

    private var statusView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            statusIcon
            Text(card.statusLabel)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: 70)
        }
    }

    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(statusColor)
            .accessibilityHidden(true)
    }

    private var statusIconName: String {
        switch card.state {
        case .granted:       return "checkmark.circle.fill"
        case .denied:        return "xmark.circle.fill"
        case .restricted:    return "minus.circle.fill"
        case .notDetermined: return "questionmark.circle"
        case .skipped:       return "arrow.forward.circle"
        }
    }

    private var statusColor: Color {
        switch card.state {
        case .granted:       return ColorTokens.Semantic.success
        case .denied:        return ColorTokens.Semantic.error
        case .restricted:    return ColorTokens.Semantic.warning
        case .notDetermined: return ColorTokens.Parent.inkSoft
        case .skipped:       return ColorTokens.Parent.inkSoft
        }
    }
}

// MARK: - Color helpers (View layer only)

private extension PermissionAccent {
    var color: Color {
        switch self {
        case .primary: return ColorTokens.Brand.primary
        case .lilac:   return ColorTokens.Brand.lilac
        case .butter:  return ColorTokens.Brand.butter
        case .mint:    return ColorTokens.Brand.mint
        }
    }
}

private extension PermissionOverviewCard {
    /// Удобный маппинг `accent → Color` для использования в View.
    var accentColor: Color { accent.color }
}

// MARK: - PermissionState + rawValue (for animation)

private extension PermissionState {
    var rawValue: String {
        switch self {
        case .granted:       return "granted"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "notDetermined"
        case .skipped:       return "skipped"
        }
    }
}

// MARK: - Preview

#Preview("PermissionsOverview") {
    NavigationStack {
        PermissionsOverviewView()
    }
    .environment(AppContainer.preview())
    .environment(AppCoordinator())
}
