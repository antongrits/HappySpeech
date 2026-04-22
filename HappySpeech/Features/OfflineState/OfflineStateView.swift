import SwiftUI

// MARK: - OfflineStateView

struct OfflineStateView: View {
    @State private var viewModel = OfflineStateViewModelHolder()
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                illustrationSection

                Spacer()

                infoSection

                actionsSection
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp16)
            }
        }
        .onAppear { bootstrap() }
        .task {
            await viewModel.interactor?.fetch(.init())
        }
    }

    // MARK: - Sections

    private var illustrationSection: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Semantic.warning.opacity(0.08))
                .frame(width: 200, height: 200)

            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(ColorTokens.Semantic.warning.opacity(0.6))

                if viewModel.pendingCount > 0 {
                    Text(viewModel.pendingBadgeText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, SpacingTokens.sp3)
                        .padding(.vertical, SpacingTokens.sp1)
                        .background(Capsule().fill(ColorTokens.Semantic.warning))
                        .accessibilityLabel(viewModel.pendingBadgeText)
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            Text(String(localized: "offline.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            Text(String(localized: "offline.body"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.sp6)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var actionsSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSButton(
                String(localized: "offline.continue"),
                style: .primary,
                icon: "arrow.right"
            ) {
                continueOffline()
            }
            .lineLimit(nil)
            .minimumScaleFactor(0.85)

            HSButton(
                viewModel.isRetrying
                    ? String(localized: "offline.retrying")
                    : String(localized: "offline.retry"),
                style: .secondary,
                icon: viewModel.isRetrying ? nil : "arrow.clockwise",
                isLoading: viewModel.isRetrying
            ) {
                retryConnection()
            }
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
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
        if let childId = viewModel.activeChildId {
            viewModel.router?.routeToActiveChild(childId: childId)
        } else {
            viewModel.router?.routeToAuth()
        }
    }

    private func retryConnection() {
        viewModel.isRetrying = true
        Task { [weak viewModel] in
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                viewModel?.isRetrying = false
                Task { await viewModel?.interactor?.fetch(.init()) }
            }
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
