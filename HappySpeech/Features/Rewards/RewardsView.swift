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
                            Text(tab.emoji).font(TypographyTokens.body(16)).accessibilityHidden(true)
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

// MARK: - StickerCellView
//
// S12 Block S: принимает опциональный heroNamespace для matchedGeometryEffect
// на emoji стикера. isHeroSource=false когда этот стикер летит в unlock overlay.

private struct StickerCellView: View {
    let cell: StickerCellViewModel
    let appearIndex: Int
    var heroNamespace: Namespace.ID? = nil
    var isHeroSource: Bool = true
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bounce = false
    @State private var appeared = false
    @State private var sparkleAngle: Double = 0

    private var appearDelay: Double {
        // Stagger: 30ms × index, capped to keep the screen alive.
        min(Double(appearIndex) * 0.030, 0.6)
    }

    var body: some View {
        Button(
            action: {
                onTap()
                withAnimation(reduceMotion ? nil : MotionTokens.bounce) {
                    bounce.toggle()
                }
            },
            label: {
                if cell.isUnlocked {
                    unlockedCell
                } else {
                    lockedCell
                }
            }
        )
        .buttonStyle(.plain)
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
                return
            }
            // Bounce-in только для unlocked. Locked — мягкий fade.
            let animation: Animation = cell.isUnlocked
                ? .spring(response: 0.5, dampingFraction: 0.55).delay(appearDelay)
                : .easeOut(duration: 0.35).delay(appearDelay)
            withAnimation(animation) {
                appeared = true
            }
            // Sparkle: вращение для isNew стикеров.
            if cell.isNew {
                withAnimation(
                    .linear(duration: 6).repeatForever(autoreverses: false)
                ) {
                    sparkleAngle = 360
                }
            }
        }
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
                    // Soft halo behind the icon
                    Circle()
                        .fill(ColorTokens.Brand.butter.opacity(0.18))
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: cell.isNew
                                ? ColorTokens.Brand.gold.opacity(0.55)
                                : Color.clear,
                            radius: 10
                        )

                    // Sparkle ring around isNew stickers
                    if cell.isNew {
                        sparkleRing
                            .frame(width: 84, height: 84)
                            .accessibilityHidden(true)
                    }

                    // S12: matchedGeometryEffect на emoji — source когда overlay закрыт.
                    emojiView

                    if cell.isNew {
                        Circle()
                            .strokeBorder(ColorTokens.Brand.gold, lineWidth: 3)
                            .frame(width: 70, height: 70)
                    }
                }

                Text(cell.name)
                    .font(TypographyTokens.caption(12))
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
            .frame(maxWidth: .infinity, minHeight: 88)
        }
    }

    // S12: emoji с опциональным matchedGeometryEffect (source или destination).
    @ViewBuilder
    private var emojiView: some View {
        let base = Text(cell.emoji)
            .font(TypographyTokens.display(38))
            .scaleEffect(bounce ? 1.08 : 1.0)
            .accessibilityHidden(true)
        if let ns = heroNamespace {
            base.matchedGeometryEffect(
                id: "sticker_\(cell.id)",
                in: ns,
                isSource: isHeroSource
            )
        } else {
            base
        }
    }

    /// Лёгкий sparkle-ring: 4 крошечных звёздочки по окружности, медленно вращается.
    private var sparkleRing: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(TypographyTokens.caption(10).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .offset(y: -42)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
        }
        .rotationEffect(.degrees(reduceMotion ? 0 : sparkleAngle))
    }

    // MARK: - Locked: plain surface, no glass

    private var lockedCell: some View {
        VStack(spacing: SpacingTokens.tiny) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Kid.surfaceAlt)
                    .frame(width: 64, height: 64)

                Text(cell.emoji)
                    .font(TypographyTokens.display(38))
                    .grayscale(0.95)
                    .opacity(0.35)
                    .accessibilityHidden(true)

                Image(systemName: "lock.fill")
                    .font(TypographyTokens.caption(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .padding(6)
                    .background(Circle().fill(ColorTokens.Kid.surface))
                    .offset(x: 22, y: 22)
                    .accessibilityLabel(String(localized: "rewards.locked"))
            }

            Text(cell.name)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
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
                    .font(TypographyTokens.kidDisplay(80))
                    .opacity(detail.isUnlocked ? 1 : 0.4)
                    .grayscale(detail.isUnlocked ? 0 : 0.9)
                    .accessibilityHidden(true)
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

            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.medium) {
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
                icon: "xmark",
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
//
// S12 Block S: добавлены параметры heroNamespace и heroSourceId для
// matchedGeometryEffect на emoji стикера (destination в overlay).
// Nil-безопасны — backward compatible.

private struct StickerUnlockOverlay: View {
    let unlock: StickerUnlockViewModel
    var heroNamespace: Namespace.ID? = nil
    var heroSourceId: String? = nil
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stickerScale: CGFloat = 0.2
    @State private var confettiAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(String(localized: "a11y.button.close"))

            // Confetti particles через swiftui-particles (benlmyers/swiftui-particles, MIT)
            if confettiAppeared {
                Emitter(from: .top, to: .bottom) {
                    Confetti(
                        [
                            ColorTokens.Brand.gold,
                            ColorTokens.Brand.primary,
                            ColorTokens.Brand.lilac,
                            ColorTokens.Feedback.correct
                        ],
                        size: .medium
                    )
                }
                .emitForever(intensity: 30)
                .particleLifetime(2.5)
                .emitSpread(0.9)
                .ignoresSafeArea()
                .allowsHitTesting(false)
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

                // S12: emoji — destination matchedGeometryEffect (isSource=false).
                unlockEmojiView

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

    // S12: emoji view с опциональным matchedGeometryEffect (isSource=false — destination).
    @ViewBuilder
    private var unlockEmojiView: some View {
        let base = Text(unlock.emoji)
            .font(TypographyTokens.kidDisplay(120))
            .scaleEffect(heroNamespace != nil ? 1 : stickerScale)
            .shadow(color: ColorTokens.Brand.gold.opacity(0.5), radius: 18)
            .accessibilityHidden(true)
        if let ns = heroNamespace, let sourceId = heroSourceId {
            base.matchedGeometryEffect(
                id: "sticker_\(sourceId)",
                in: ns,
                isSource: false
            )
        } else {
            base
        }
    }
}

// MARK: - Preview

#Preview("Rewards") {
    RewardsView(childId: "preview-child")
        .environment(AppContainer.preview())
}
