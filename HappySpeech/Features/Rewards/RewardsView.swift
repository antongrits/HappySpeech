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
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    /// Единая точка выхода из kid-маршрутов (navigate(to:) заменяет root,
    /// поэтому dismiss() — no-op в top-level режиме).
    @Environment(\.exitGame) private var exitGame

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

    /// Fix #5a — screenshot-tour mode (true when launched with
    /// `-HSStartRoute`). Заморозить анимированный mesh-фон, чтобы захват
    /// получил стабильный кадр.
    fileprivate static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-HSStartRoute")
    }

    // MARK: - Init

    init(childId: String) {
        self.childId = childId
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // v27 visual modernization (#2) — экран наград ощущается как
                // кульминация: mesh-палитра .rewards (gold/butter/primaryLo)
                // становится полноценным фоновым слоем, а не лёгким softLight-
                // оверлеем. iOS 18+ — MeshGradient, fallback iOS 17 — radial.
                //
                // Fix #5a — анимация mesh-фазы отключается под
                // -HSStartRoute (скриншот-тур), иначе на захвате ловится
                // волнистый артефакт переходного кадра.
                HSMeshGradientBackground(palette: .rewards, animated: !Self.isScreenshotMode)
                    .ignoresSafeArea()
                    // В dark mesh приглушён, чтобы gold/butter не «выгорал»,
                    // в light — почти полный для тёплого золотого сияния.
                    .opacity(colorScheme == .dark ? 0.45 : 0.85)
                    .transaction { tx in
                        if Self.isScreenshotMode { tx.disablesAnimations = true }
                    }
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                // Fix v34 — мягкий gold radial overlay поверх
                // монохромного butter mesh заменяет старые gold/primaryLo
                // mesh-точки. Radial gradient не даёт banding (на отличие от
                // прямой MeshGradient интерполяции между точками разной
                // насыщенности), но возвращает «золотое сияние» характера
                // экрана наград. Центр на 30%/30% — kavsoft hero-spot, едва
                // заметный второй акцент в правом нижнем углу.
                ZStack {
                    RadialGradient(
                        colors: [
                            ColorTokens.Brand.gold.opacity(colorScheme == .dark ? 0.18 : 0.32),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.30, y: 0.25),
                        startRadius: 20,
                        endRadius: 360
                    )
                    RadialGradient(
                        colors: [
                            ColorTokens.Brand.primaryLo.opacity(colorScheme == .dark ? 0.12 : 0.22),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.80, y: 0.85),
                        startRadius: 30,
                        endRadius: 320
                    )
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    headerSection
                    walletHeroRow
                    leaderboardBanner
                    tabFilterSection
                    contentSection
                    if !display.achievementRows.isEmpty {
                        achievementsSection
                    }
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(ColorTokens.Kid.ink)
                    }
                    .accessibilityLabel(String(localized: "action.back", defaultValue: "Назад"))
                }
            }
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
            .overlay {
                // Lottie-салют поверх unlock-оверлея (под Reduced Motion скрыт).
                if unlockOverlay != nil, !reduceMotion {
                    HSLottieContainer(
                        asset: .celebrateUnlockAchievement,
                        fallback: AnyView(EmptyView()),
                        size: CGSize(width: 260, height: 260)
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
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
        // Step 10 Batch A — hero обёрнут в HSLiquidGlassCard.elevated:
        // mesh .rewards палитра проходит за стеклом, создавая «золотое сияние»
        // за полупрозрачным стеклом — kavsoft-style hero на iOS 26+.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                // Top row: Lyalya + counts + ring
                HStack(alignment: .center, spacing: SpacingTokens.medium) {
                    // E v21: 3D Ляля в header Rewards (требование «3D героев на каждом экране»).
                    // size=96 > 80 threshold → 3D через LyalyaHeroView.
                    LyalyaHeroView(state: lyalyaHeaderState, size: 96)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(display.progressLabel)
                            .font(TypographyTokens.title(22))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .accessibilityAddTraits(.isHeader)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(String(localized: "rewards.progress"))
                            .font(TypographyTokens.body(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .textCase(.lowercase)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer()

                    HSProgressBar(value: display.progress, style: .ring, showLabel: true)
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                }

                // Subtitle row — на первом запуске Presenter подставляет
                // дружелюбное приглашение (headerSubtitle), иначе обычный текст.
                Text(display.headerSubtitle)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.9)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.tiny)
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

    // MARK: - Wallet Hero Row
    //
    // Коралловая строка «У тебя N монеток» под шапкой — эталон kid-rewards.
    // Показывает доступный баланс крупным числом + мотиватор (сколько до следующей
    // награды). Скрывается когда кошелёк ещё пуст (0 заработано).

    @ViewBuilder
    private var walletHeroRow: some View {
        if display.walletViewModel.totalEarned > 0 {
            HSCard(style: .flat) {
                HStack(spacing: SpacingTokens.medium) {
                    // Монетки — крупное число
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.gold.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Image(systemName: "star.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ColorTokens.Brand.gold)
                            .hsSymbolEffect(.bounce, value: display.walletViewModel.available)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        // «У тебя 48 монеток»
                        (Text(String(localized: "rewards.wallet.hero.prefix", defaultValue: "У тебя "))
                         + Text("\(display.walletViewModel.available)")
                            .fontWeight(.bold)
                            .foregroundStyle(ColorTokens.Brand.gold)
                         + Text(String(localized: "rewards.wallet.hero.suffix", defaultValue: " монеток")))
                            .font(TypographyTokens.headline(17))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        Text(display.headerSubtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(SpacingTokens.regular)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.small)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(display.walletViewModel.accessibilityLabel)
        }
    }

    // MARK: - Mini leaderboard banner (v32 P2)
    //
    // 1-строчный социальный мотиватор над сеткой стикеров. Tap → переход в
    // полный лидерборд произношения. Сам лидерборд — parent-circuit (COPPA),
    // переход осознанный и инициирует ребёнок, а не reads child data.
    // Для preview / standalone использует hardcoded плейсхолдер,
    // потому что реальный leaderboard worker подключится позже.
    private var leaderboardBanner: some View {
        Button {
            container.hapticService.selection()
            let parentId = coordinator.authUser?.uid ?? ""
            coordinator.navigate(to: .pronunciationLeaderboard(parentId: parentId))
        } label: {
            HSCard(style: .elevated) {
                HStack(spacing: SpacingTokens.small) {
                    Image(systemName: "star.fill")
                        .font(TypographyTokens.body(16).weight(.bold))
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .hsSymbolEffect(.pulse, value: display.cells.count)
                        .accessibilityHidden(true)
                    Text(String(localized: "rewards.leaderboard.banner"))
                        .font(TypographyTokens.body(14).weight(.semibold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, SpacingTokens.small)
            }
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(ColorTokens.Brand.gold.opacity(0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        // v32 P1 — ShadowTokens.kidDepth: two-layer depth under leaderboard banner card.
        .depthShadow(ShadowTokens.kidDepth)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "rewards.leaderboard.banner"))
        .accessibilityHint(String(localized: "rewards.leaderboard.banner.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private var tabFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(display.collections) { tab in
                    Button {
                        interactor?.filterByCollection(.init(collection: tab.collection))
                    } label: {
                        HStack(spacing: 6) {
                            // Fix #7c — category icon-chip укрупнён до 18pt
                            // и переокрашен: при active state читается в onAccent
                            // (контраст на coral capsule), в idle — Brand.primary.
                            // HSContentSymbol поддерживает и SF Symbol (gift.fill),
                            // и Asset (reward_rocket, word_forest, seasonal_…).
                            HSContentSymbol(
                                tab.emoji,
                                size: 16,
                                tint: tab.isActive
                                    ? ColorTokens.Overlay.onAccent
                                    : ColorTokens.Brand.primary
                            )
                            .frame(width: 22, height: 22)
                            // Чип в горизонтальном ScrollView: название берёт свою
                            // полную intrinsic-ширину (.fixedSize) и НЕ усекается «…»
                            // («Космос»→«Кос…» раньше). Скролл обрабатывает overflow.
                            Text(tab.title)
                                .font(TypographyTokens.body(14))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
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
                        .foregroundStyle(tab.isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
                        // Fix v34 — chip-padding с SpacingTokens.medium
                        // сжат до SpacingTokens.small: на iPhone 17 Pro
                        // (390pt safe area) три chip'а «Все 72», «Животные 12»,
                        // «Лес 6» теперь полностью помещаются без клиппинга.
                        .padding(.horizontal, SpacingTokens.small)
                        .padding(.vertical, SpacingTokens.tiny)
                        .frame(minHeight: 56)
                        // Fix v33 P1 — на золотом mesh-фоне inactive
                        // capsule на ColorTokens.Kid.surface (off-white) сливался
                        // с butter mesh, третий чип «терялся». Двухслойная заливка:
                        // непрозрачная Kid.surface + чёткий border ColorTokens.Kid.line
                        // даёт читаемый контур в обоих режимах и на любом тоне фона.
                        .background(
                            Capsule().fill(
                                tab.isActive
                                    ? ColorTokens.Brand.primary
                                    : ColorTokens.Kid.surface
                            )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    tab.isActive
                                        ? Color.clear
                                        : ColorTokens.Kid.line.opacity(0.6),
                                    lineWidth: 1.5
                                )
                        )
                        // Явная hit-area по форме чипа: без contentShape тап-зона
                        // .plain-кнопки сводится к непрозрачным пикселям label, из-за
                        // чего VoiceOver/UI-тесты не могли вычислить activation point
                        // (chip «Лес» считался невалидным). Capsule = вся капсула кликабельна.
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityValue("\(tab.count)")
                    .accessibilityAddTraits(tab.isActive ? [.isButton, .isSelected] : .isButton)
                }
            }
            // D-19 v27 — contentMargins даёт «дышащий» отступ по обоим краям,
            // последний чип не обрезается жёстко — видно, что ряд скроллится.
            .padding(.vertical, SpacingTokens.micro)
        }
        .contentMargins(.horizontal, SpacingTokens.screenEdge, for: .scrollContent)
        .padding(.bottom, SpacingTokens.small)
    }

    @ViewBuilder
    private var contentSection: some View {
        if display.isEmpty {
            // kid-контур: анимированный Lottie empty-state «нет наград».
            HSEmptyStateView(
                lottie: .emptyNoRewards,
                fallbackSymbol: "gift",
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
                    // Fix v34 — `scrollTransition` + `hsParallaxTile`
                    // убраны. Они давали «лестницу призрачных стикеров» на 3.10:
                    // каждый стикер получал собственный y-offset через
                    // GeometryReader в parallax-модификаторе, ломая сетку
                    // LazyVGrid, а scrollTransition фейдил карточки ниже фолда
                    // в 0 opacity, и они стопкой накладывались друг на друга.
                    // Аппarent-анимация (scale+opacity) сохраняется через
                    // .onAppear в StickerCellView.
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.small)
            .padding(.bottom, SpacingTokens.xLarge)
        }
    }

    // MARK: - Achievements Section
    //
    // Эталон kid-rewards: секция «Достижения» — горизонтальный скролл карточек
    // после сетки стикеров. Каждая карточка: эмодзи, заголовок, прогресс-звёзды.
    // Разблокированные — тёплый gold/butter, заблокированные — серые.

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            // Заголовок секции + счётчик
            achievementsSectionHeader

            // Горизонтальный скролл карточек
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.medium) {
                    ForEach(Array(display.achievementRows.prefix(12).enumerated()), id: \.element.id) { index, row in
                        achievementCard(row, index: index)
                    }
                }
                .padding(.vertical, SpacingTokens.tiny)
            }
            .contentMargins(.horizontal, SpacingTokens.screenEdge, for: .scrollContent)
            .padding(.bottom, SpacingTokens.xLarge)
        }
        .accessibilityElement(children: .contain)
    }

    private var achievementsSectionHeader: some View {
        let unlocked = display.achievementRows.filter(\.isUnlocked).count
        let total = display.achievementRows.count
        return HStack {
            Text(String(localized: "rewards.achievements.title", defaultValue: "Достижения"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text("\(unlocked) из \(total)")
                .font(TypographyTokens.caption(13).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.medium)
    }

    private func achievementCard(_ row: AchievementRowViewModel, index: Int) -> some View {
        Button {
            interactor?.openAchievement(.init(key: row.key))
        } label: {
            VStack(spacing: SpacingTokens.small) {
                // Эмодзи / иконка достижения
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .fill(row.isUnlocked
                              ? ColorTokens.Brand.butter.opacity(0.30)
                              : ColorTokens.Kid.surfaceAlt)
                        .frame(width: 68, height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                                .strokeBorder(
                                    row.isUnlocked
                                        ? ColorTokens.Brand.gold.opacity(0.65)
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    HSContentSymbol(row.emoji, size: 34, tint: row.isUnlocked
                                    ? ColorTokens.Brand.gold : ColorTokens.Kid.inkSoft)
                        .grayscale(row.isUnlocked ? 0 : 0.7)
                        .accessibilityHidden(true)
                }

                // Название
                Text(row.title)
                    .font(TypographyTokens.caption(11).weight(.medium))
                    .foregroundStyle(row.isUnlocked ? ColorTokens.Kid.ink : ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                // Прогресс-звёзды (3 звезды — заполнено по прогрессу)
                achievementStars(progress: row.progress)
            }
            .frame(width: 100)
            .padding(.vertical, SpacingTokens.regular)
            .padding(.horizontal, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1.5)
                    )
            )
            .kidTileShadow()
        }
        .buttonStyle(.plain)
        .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
            content
                .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private func achievementStars(progress: Double) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                let threshold = Double(i + 1) / 3.0
                Image(systemName: progress >= threshold ? "star.fill" : "star")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(progress >= threshold
                                     ? ColorTokens.Brand.gold
                                     : ColorTokens.Kid.inkSoft)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let presenter = RewardsPresenter()
        presenter.display = display
        let interactor = RewardsInteractor(
            repository: container.rewardsRepository,
            realmActor: container.realmActor
        )
        interactor.presenter = presenter
        let router = RewardsRouter()
        router.onDismiss = { dismiss() }

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        interactor.loadRewards(.init(childId: childId, forceReload: false))
    }
}
