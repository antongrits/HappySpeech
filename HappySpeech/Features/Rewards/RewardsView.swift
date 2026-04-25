import SwiftUI
import OSLog

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
                    StickerUnlockOverlay(unlock: unlock) {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                            unlockOverlay = nil
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
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            HStack {
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(display.progressLabel)
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(String(localized: "rewards.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer()
                HSProgressBar(value: display.progress, style: .ring, showLabel: true)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.tiny)
        }
        .padding(.bottom, SpacingTokens.small)
    }

    private var tabFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(display.collections) { tab in
                    Button {
                        interactor?.filterByCollection(.init(collection: tab.collection))
                    } label: {
                        HStack(spacing: 6) {
                            Text(tab.emoji).font(.system(size: 16))
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
                                            ? Color.white.opacity(0.25)
                                            : ColorTokens.Kid.surfaceAlt
                                    )
                                )
                        }
                        .foregroundStyle(tab.isActive ? .white : ColorTokens.Kid.ink)
                        .padding(.horizontal, SpacingTokens.medium)
                        .padding(.vertical, SpacingTokens.tiny)
                        .frame(minHeight: 44)
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
                ForEach(display.cells) { cell in
                    StickerCellView(cell: cell) {
                        interactor?.openSticker(.init(id: cell.id))
                        if cell.isUnlocked && cell.isNew {
                            // Auto-claim "new" badge when the kid taps the sticker.
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

// MARK: - StickerCellView

private struct StickerCellView: View {
    let cell: StickerCellViewModel
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    var body: some View {
        Button(action: {
            onTap()
            withAnimation(reduceMotion ? nil : MotionTokens.bounce) {
                bounce.toggle()
            }
        }) {
            if cell.isUnlocked {
                unlockedCell
            } else {
                lockedCell
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cell.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Unlocked: HSLiquidGlassCard with color tint

    private var unlockedCell: some View {
        HSLiquidGlassCard(
            style: .tinted(ColorTokens.Brand.butter),
            padding: SpacingTokens.tiny
        ) {
            VStack(spacing: SpacingTokens.tiny) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.butter.opacity(0.18))
                        .frame(width: 64, height: 64)

                    Text(cell.emoji)
                        .font(.system(size: 38))
                        .scaleEffect(bounce ? 1.08 : 1.0)

                    if cell.isNew {
                        Circle()
                            .strokeBorder(ColorTokens.Brand.gold, lineWidth: 3)
                            .frame(width: 70, height: 70)
                    }
                }

                Text(cell.name)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if cell.isNew {
                    Text(String(localized: "rewards.badge.new"))
                        .font(TypographyTokens.mono(10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ColorTokens.Brand.gold))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Locked: plain surface, no glass

    private var lockedCell: some View {
        VStack(spacing: SpacingTokens.tiny) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Kid.surfaceAlt)
                    .frame(width: 64, height: 64)

                Text(cell.emoji)
                    .font(.system(size: 38))
                    .grayscale(0.95)
                    .opacity(0.35)

                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .padding(6)
                    .background(Circle().fill(ColorTokens.Kid.surface))
                    .offset(x: 22, y: 22)
            }

            Text(cell.name)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.tiny)
    }
}

// MARK: - StickerDetailSheet

private struct StickerDetailSheet: View {
    let detail: StickerDetailViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Capsule()
                .fill(ColorTokens.Kid.line)
                .frame(width: 36, height: 4)
                .padding(.top, SpacingTokens.tiny)

            ZStack {
                Circle()
                    .fill(
                        detail.isUnlocked
                            ? ColorTokens.Brand.butter.opacity(0.30)
                            : ColorTokens.Kid.surfaceAlt
                    )
                    .frame(width: 140, height: 140)
                Text(detail.emoji)
                    .font(.system(size: 80))
                    .opacity(detail.isUnlocked ? 1 : 0.4)
                    .grayscale(detail.isUnlocked ? 0 : 0.9)
            }

            VStack(spacing: SpacingTokens.tiny) {
                Text(detail.name)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(detail.collectionName)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            HSCard(style: .flat, padding: SpacingTokens.medium) {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    Label {
                        Text(detail.unlockCondition)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.ink)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }

                    if let dateLabel = detail.unlockedDateLabel {
                        Label {
                            Text(dateLabel)
                                .font(TypographyTokens.body(13))
                                .foregroundStyle(ColorTokens.Kid.inkMuted)
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundStyle(ColorTokens.Brand.mint)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()

            HSButton(
                String(localized: "rewards.detail.close"),
                style: .primary,
                action: onClose
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.large)
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.Kid.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

// MARK: - StickerUnlockOverlay

private struct StickerUnlockOverlay: View {
    let unlock: StickerUnlockViewModel
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stickerScale: CGFloat = 0.2
    @State private var confettiAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            // Confetti rain (emoji raining downward)
            ForEach(0..<unlock.confettiEmojis.count * 3, id: \.self) { index in
                let emoji = unlock.confettiEmojis[index % unlock.confettiEmojis.count]
                Text(emoji)
                    .font(.system(size: CGFloat.random(in: 22...36)))
                    .offset(
                        x: CGFloat.random(in: -160...160),
                        y: confettiAppeared ? CGFloat.random(in: 200...500) : -CGFloat.random(in: 100...300)
                    )
                    .opacity(confettiAppeared ? 0.85 : 0)
                    .accessibilityHidden(true)
            }

            VStack(spacing: SpacingTokens.large) {
                Text(String(localized: "rewards.unlock.badge"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.vertical, SpacingTokens.tiny)
                    .background(Capsule().fill(ColorTokens.Brand.gold))
                    .textCase(.uppercase)
                    .tracking(1.0)

                Text(unlock.emoji)
                    .font(.system(size: 120))
                    .scaleEffect(stickerScale)
                    .shadow(color: ColorTokens.Brand.gold.opacity(0.5), radius: 18)

                Text(unlock.name)
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                HSButton(
                    String(localized: "rewards.unlock.cta"),
                    style: .primary,
                    icon: "sparkles",
                    action: onDismiss
                )
                .padding(.horizontal, SpacingTokens.xxLarge)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "rewards.a11y.unlocked"), unlock.name)
        )
        .onAppear {
            if reduceMotion {
                stickerScale = 1
                confettiAppeared = true
                return
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                stickerScale = 1
            }
            withAnimation(.easeOut(duration: 1.6)) {
                confettiAppeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Rewards") {
    RewardsView(childId: "preview-child")
        .environment(AppContainer.preview())
}
