import OSLog
import Particles
import SwiftUI

// MARK: - RewardsView
//
// Kid-контур. Коллекция стикеров (24+ карточки в 4 коллекциях). Поддерживает:
//   – TabBar-фильтр коллекций (Все / Звёзды / Животные / Буквы / Праздники);
//   – LazyVGrid 3×N: locked (серый замок), unlocked (цветной), new (золотой ободок);
//   – Sheet с деталями стикера;
//   – Confetti-overlay при `claimReward`.
//
// Сигнатура `init(childId:)` сохранена для `AppCoordinator`.

struct RewardsView: View {

    // MARK: - Inputs

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP State

    @State private var display = RewardsDisplay()
    @State private var interactor: RewardsInteractor?
    @State private var presenter: RewardsPresenter?
    @State private var router: RewardsRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI

    @State private var detailViewModel: StickerDetailViewModel?
    @State private var unlockOverlay: StickerUnlockViewModel?

    // MARK: S12 Hero Transitions (Block S)
    // Namespace для matchedGeometryEffect: sticker cell emoji → unlock overlay emoji.
    @Namespace private var stickerNamespace
    // ID стикера, который сейчас в анимированном unlock-overlay.
    @State private var animatingStickerId: String?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RewardsView")

    // MARK: - Init

    init(childId: String) {
        self.childId = childId
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ColorTokens.Kid.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection
                    tabFilterSection
                    contentSection
                }

                if let toast = display.toastMessage {
                    HSToast(toast, type: .error)
                        .padding(.bottom, SpacingTokens.large)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2.4))
                            withAnimation(.easeInOut(duration: 0.25)) {
                                display.clearToast()
                            }
                        }
                }
            }
            .navigationTitle(String(localized: "rewards.navTitle"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $detailViewModel) { detail in
                StickerDetailSheet(detail: detail) {
                    detailViewModel = nil
                }
                .presentationDetents([.medium, .large])
            }
            .overlay {
                if let unlock = unlockOverlay {
                    // S12: передаём namespace и animatingStickerId в overlay для matchedGeometryEffect.
                    StickerUnlockOverlay(
                        unlock: unlock,
                        heroNamespace: reduceMotion ? nil : stickerNamespace,
                        heroSourceId: animatingStickerId
                    ) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
                            unlockOverlay = nil
                            animatingStickerId = nil
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .environment(\.circuitContext, .kid)
        .task { await bootstrap() }
        .onChange(of: display.pendingDetail) { _, value in
            guard let value else { return }
            detailViewModel = value
            display.consumeDetail()
        }
        .onChange(of: display.pendingUnlock) { _, value in
            guard let value else { return }
            withAnimation(reduceMotion ? nil : MotionTokens.bounce) {
                unlockOverlay = value
            }
            display.consumeUnlock()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            // Top row: Lyalya + counts + ring
            HStack(alignment: .center, spacing: SpacingTokens.medium) {
                LyalyaMascotView(state: lyalyaHeaderState, size: 56)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(display.progressLabel)
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .accessibilityAddTraits(.isHeader)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "rewards.progress"))
                        .font(TypographyTokens.body(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .textCase(.lowercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer()

                HSProgressBar(value: display.progress, style: .ring, showLabel: true)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.tiny)

            // Subtitle row
            Text(String(localized: "rewards.header.subtitle"))
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .padding(.bottom, SpacingTokens.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(display.progressLabel) \(String(localized: "rewards.progress"))"
        )
    }

    /// Маппинг прогресса коллекции → состояние маскота в header.
    private var lyalyaHeaderState: LyalyaState {
        switch display.progress {
        case 0.50...:    return .celebrating
        case 0.10..<0.50: return .happy
        default:          return .waving
        }
    }

    private var tabFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(display.collections) { tab in
                    Button {
                        interactor?.filterByCollection(.init(collection: tab.collection))
                    } label: {
                        HStack(spacing: 6) {
                            HSContentSymbol(tab.emoji, size: 16, tint: ColorTokens.Brand.primary)
                            Text(tab.title)
                                .font(TypographyTokens.body(14))
                                .lineLimit(1)
                            Text("\(tab.count)")
                                .font(TypographyTokens.mono(11))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(
                                        tab.isActive
                                            ? ColorTokens.Overlay.highlight
                                            : ColorTokens.Kid.surfaceAlt
                                    )
                                )
                        }
                        .foregroundStyle(tab.isActive ? .white : ColorTokens.Kid.ink)
                        .padding(.horizontal, SpacingTokens.medium)
                        .padding(.vertical, SpacingTokens.tiny)
                        .frame(minHeight: 56)
                        .background(
                            Capsule().fill(
                                tab.isActive
                                    ? ColorTokens.Brand.primary
                                    : ColorTokens.Kid.surface
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityValue("\(tab.count)")
                    .accessibilityAddTraits(tab.isActive ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(.bottom, SpacingTokens.small)
    }

    @ViewBuilder
    private var contentSection: some View {
        if display.isEmpty {
            HSEmptyStateView(
                icon: "sparkles",
                title: display.emptyTitle,
                message: display.emptyMessage
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            stickerGrid
        }
    }

    private var stickerGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: SpacingTokens.medium),
                    count: 3
                ),
                spacing: SpacingTokens.medium
            ) {
                ForEach(Array(display.cells.enumerated()), id: \.element.id) { index, cell in
                    // S12: matchedGeometryEffect на emoji стикера.
                    // StickerCellView получает namespace и флаг isAnimating для isSource.
                    StickerCellView(
                        cell: cell,
                        appearIndex: index,
                        heroNamespace: reduceMotion ? nil : stickerNamespace,
                        isHeroSource: animatingStickerId != cell.id
                    ) {
                        interactor?.openSticker(.init(id: cell.id))
                        if cell.isUnlocked && cell.isNew {
                            if !reduceMotion {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                                    animatingStickerId = cell.id
                                }
                            }
                            interactor?.claimReward(.init(id: cell.id))
                        }
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.small)
            .padding(.bottom, SpacingTokens.xLarge)
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let presenter = RewardsPresenter()
        presenter.display = display
        let interactor = RewardsInteractor()
        interactor.presenter = presenter
        let router = RewardsRouter()
        router.onDismiss = { dismiss() }

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        interactor.loadRewards(.init(childId: childId, forceReload: false))
    }
}

