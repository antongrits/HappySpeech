import SwiftUI

// MARK: - OfflineStateView
//
// Fullscreen "no internet" state for the kid circuit.
// Shows the Lyalya butterfly mascot, a friendly headline,
// auto-retry countdown, manual retry and continue-offline actions.
//
// VIP wiring:
//   • OfflineStateInteractor — fetches the active child id and pending sync count
//   • OfflineStatePresenter  — formats the pending badge text
//   • OfflineStateRouter     — bridges to AppCoordinator (childHome / auth)
//
// Behaviour:
//   • On first appear, kicks off a 5-second auto-retry countdown.
//   • If connectivity returns mid-countdown, the screen dismisses to the active
//     child / auth route automatically.
//   • Tapping "Повторить" forces an immediate retry; the countdown restarts.
//   • Tapping "Продолжить офлайн" navigates to the active child and dismisses.

struct OfflineStateView: View {
    @State private var viewModel = OfflineStateViewModelHolder()
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Auto-retry state
    @State private var retryCountdown: Int = 5
    @State private var countdownTask: Task<Void, Never>?
    @State private var isMascotPulsing: Bool = false

    private static let autoRetrySeconds: Int = 5

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Spacer(minLength: SpacingTokens.sp10)

                illustrationSection

                infoSection
                    .padding(.top, SpacingTokens.sp6)

                Spacer()

                countdownSection
                    .padding(.bottom, SpacingTokens.sp4)

                actionsSection
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp16)
            }
        }
        .onAppear {
            bootstrap()
            startAutoRetryCountdown()
            startMascotPulse()
        }
        .onDisappear {
            cancelCountdown()
        }
        .task {
            await viewModel.interactor?.fetch(.init())
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ColorTokens.Kid.bg
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        ColorTokens.Brand.lilac.opacity(0.18),
                        ColorTokens.Kid.bg.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 320)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
    }

    // MARK: - Illustration

    private var illustrationSection: some View {
        ZStack {
            // Soft pulse halo
            Circle()
                .fill(ColorTokens.Brand.lilac.opacity(0.18))
                .frame(width: 240, height: 240)
                .scaleEffect(isMascotPulsing ? 1.06 : 0.98)
                .opacity(isMascotPulsing ? 0.85 : 0.55)

            // Inner soft circle
            Circle()
                .fill(ColorTokens.Kid.surface)
                .frame(width: 180, height: 180)
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)

            // wifi.slash icon
            Image(systemName: "wifi.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(ColorTokens.Semantic.warning.opacity(0.65))
                .offset(y: -8)

            // Lyalya butterfly mascot — sits beside the icon
            Text("\u{1F98B}") // butterfly emoji
                .font(.system(size: 48))
                .offset(x: 70, y: 38)
                .accessibilityHidden(true)

            // Pending sync badge
            if viewModel.pendingCount > 0 {
                pendingBadge
                    .offset(x: -78, y: -82)
            }
        }
        .frame(height: 240)
        .accessibilityLabel(String(localized: "offline.illustration.a11y"))
    }

    private var pendingBadge: some View {
        Text(viewModel.pendingBadgeText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp1)
            .background(Capsule().fill(ColorTokens.Semantic.warning))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            .accessibilityLabel(viewModel.pendingBadgeText)
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Text(String(localized: "offline.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            Text(String(localized: "offline.body"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.sp6)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Countdown

    @ViewBuilder
    private var countdownSection: some View {
        if viewModel.isRetrying {
            HStack(spacing: SpacingTokens.sp2) {
                ProgressView()
                    .controlSize(.small)
                    .tint(ColorTokens.Brand.primary)
                Text(String(localized: "offline.retrying"))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .accessibilityElement(children: .combine)
        } else if retryCountdown > 0 {
            Text(String(localized: "offline.auto_retry.\(retryCountdown)"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .accessibilityLabel(String(localized: "offline.auto_retry.\(retryCountdown)"))
        } else {
            Color.clear.frame(height: 16)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSButton(
                viewModel.isRetrying
                    ? String(localized: "offline.retrying")
                    : String(localized: "offline.retry"),
                style: .primary,
                icon: viewModel.isRetrying ? nil : "arrow.clockwise",
                isLoading: viewModel.isRetrying
            ) {
                retryConnection()
            }
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .accessibilityHint(String(localized: "offline.retry.a11y.hint"))

            HSButton(
                String(localized: "offline.continue"),
                style: .secondary,
                icon: "arrow.right"
            ) {
                continueOffline()
            }
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .accessibilityHint(String(localized: "offline.continue.a11y.hint"))
        }
    }

    // MARK: - Wiring

    private func bootstrap() {
        guard viewModel.interactor == nil else { return }
        let interactor = OfflineStateInteractor(
            childRepository: container.childRepository,
            syncService: container.syncService,
            networkMonitor: container.networkMonitor
        )
        let presenter = OfflineStatePresenter()
        let router = OfflineStateRouter()
        router.coordinator = coordinator
        interactor.presenter = presenter
        presenter.viewModel = viewModel
        viewModel.interactor = interactor
        viewModel.router = router
    }

    private func continueOffline() {
        cancelCountdown()
        if let childId = viewModel.activeChildId {
            viewModel.router?.routeToActiveChild(childId: childId)
        } else {
            viewModel.router?.routeToAuth()
        }
    }

    private func retryConnection() {
        cancelCountdown()
        viewModel.isRetrying = true
        Task { @MainActor [weak viewModel] in
            try? await Task.sleep(for: .seconds(1.5))
            viewModel?.isRetrying = false
            await viewModel?.interactor?.fetch(.init())
            // If still offline, restart countdown.
            await MainActor.run {
                if viewModel?.interactor != nil {
                    self.startAutoRetryCountdown()
                }
            }
        }
    }

    // MARK: - Auto-retry countdown

    private func startAutoRetryCountdown() {
        cancelCountdown()
        retryCountdown = Self.autoRetrySeconds
        countdownTask = Task { @MainActor in
            while retryCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                retryCountdown -= 1
            }
            if !Task.isCancelled {
                retryConnection()
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    // MARK: - Mascot pulse

    private func startMascotPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            isMascotPulsing = true
        }
    }
}

// MARK: - ViewModel holder

@MainActor
@Observable
final class OfflineStateViewModelHolder: OfflineStateDisplayLogic {
    var activeChildId: String?
    var pendingCount: Int = 0
    var pendingBadgeText: String = ""
    var isRetrying: Bool = false

    var interactor: OfflineStateInteractor?
    var router: OfflineStateRouter?

    func displayFetch(_ viewModel: OfflineStateModels.Fetch.ViewModel) {
        self.activeChildId = viewModel.activeChildId
        self.pendingCount = viewModel.pendingCount
        self.pendingBadgeText = viewModel.pendingBadgeText
    }

    func displayUpdate(_ viewModel: OfflineStateModels.Update.ViewModel) {
        self.isRetrying = viewModel.isRetrying
    }
}

// MARK: - Preview

#Preview("Offline State") {
    OfflineStateView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}
