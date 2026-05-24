import OSLog
import SwiftUI

// MARK: - AchievementWallDisplayLogic

@MainActor
protocol AchievementWallDisplayLogic: AnyObject {
    func displayWall(viewModel: AchievementWallModels.LoadWall.ViewModel) async
    func displayDetail(viewModel: AchievementWallModels.OpenDetail.ViewModel) async
    func displayShare(viewModel: AchievementWallModels.Share.ViewModel) async
}

// MARK: - Holder

@MainActor
@Observable
final class AchievementWallViewModelHolder: AchievementWallDisplayLogic {

    var loadVM: AchievementWallModels.LoadWall.ViewModel?
    var detailVM: AchievementWallModels.OpenDetail.ViewModel?
    var pendingShareText: String?

    func displayWall(viewModel: AchievementWallModels.LoadWall.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayDetail(viewModel: AchievementWallModels.OpenDetail.ViewModel) async {
        self.detailVM = viewModel
    }

    func displayShare(viewModel: AchievementWallModels.Share.ViewModel) async {
        self.pendingShareText = viewModel.shareText
    }
}

// MARK: - AchievementWallView

struct AchievementWallView: View {

    let childId: String

    @State private var holder = AchievementWallViewModelHolder()
    @State private var interactor: AchievementWallInteractor?
    @State private var presenter: AchievementWallPresenter?
    @State private var router: AchievementWallRouter?
    @State private var didBootstrap = false
    @State private var showDetail = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.hapticService) private var hapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AchievementWall.View"
    )

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // Step 10 Batch A — Pattern 1: mesh .rewards (золотая палитра ≈
                // celebration) полноценным фоном вместо плоского Kid.bg.
                // Slight opacity-таплинг для тёмного режима, чтобы gold не выгорал.
                HSMeshGradientBackground(palette: .rewards, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.40 : 0.75)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                content
            }
            .navigationTitle(Text("Моя стена"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .sheet(isPresented: $showDetail) {
                detailSheet
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let vm = holder.loadVM {
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    heroPolaroid(vm)
                    gridSection(vm)
                    shareFooter(vm)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp4)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(vm.accessibilitySummary))
        } else {
            ProgressView().controlSize(.large)
        }
    }

    // MARK: - Hero polaroid

    private func heroPolaroid(_ vm: AchievementWallModels.LoadWall.ViewModel) -> some View {
        // Step 10 Batch A — Pattern 2: hero обёрнут в HSLiquidGlassCard.elevated.
        // Mesh .rewards-палитра просвечивает за стеклом — kavsoft-style hero.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 60)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.heroTitle)
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(vm.heroSubtitle)
                        .font(TypographyTokens.body(14).monospacedDigit())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Grid

    private func gridSection(_ vm: AchievementWallModels.LoadWall.ViewModel) -> some View {
        // Step 10 Batch A — Pattern 3+4: stagger entrance via scrollTransition
        // (fade+scale) и parallax-drift на каждой trophy-карточке. Reduce Motion
        // отключает обе анимации внутри модификаторов / scrollTransition.
        LazyVGrid(columns: gridColumns, spacing: SpacingTokens.sp2) {
            ForEach(vm.cells) { cell in
                badgeCell(cell)
                    .onTapGesture { openDetail(cell.id) }
                    .scrollTransition(.animated.threshold(.visible(0.3))) { content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                    }
                    .hsParallaxTile(factor: 0.25)
            }
        }
        .animation(reduceMotion ? nil : MotionTokens.settleSpring, value: vm.cells.count)
    }

    private func badgeCell(_ cell: AchievementWallCellViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(badgeBackground(for: cell))
                    .frame(width: 92, height: 92)
                // Task #67: decorative trophy_bg_* background (Hero/trophy_bg_*).
                // 9 hero illustrations: bronze / silver / gold / streak_7/30/100 /
                // lessons_10/50/100. Слой только для unlocked-карточек.
                if cell.isUnlocked, let bgSlug = Self.trophyBgSlug(for: cell) {
                    Image(bgSlug)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
                        .opacity(0.55)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
                Image(systemName: cell.iconName)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(badgeIconColor(for: cell))
                    .symbolRenderingMode(.hierarchical)
                    .hsSymbolEffect(.bounce, value: cell.isUnlocked)
                    .accessibilityHidden(true)
                if !cell.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .padding(4)
                        .background(
                            Circle().fill(ColorTokens.Kid.inkSoft)
                        )
                        .offset(x: 28, y: 28)
                        .accessibilityHidden(true)
                }
            }
            Text(cell.title)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(cell.isUnlocked ? ColorTokens.Kid.ink : ColorTokens.Kid.inkMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(SpacingTokens.sp1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(cell.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    private func badgeBackground(for cell: AchievementWallCellViewModel) -> Color {
        guard cell.isUnlocked else {
            return ColorTokens.Kid.surfaceAlt
        }
        switch cell.rarity {
        case .legendary: return ColorTokens.Brand.gold.opacity(0.22)
        case .rare:      return ColorTokens.Brand.lilac.opacity(0.22)
        case .common:    return ColorTokens.Brand.sky.opacity(0.18)
        }
    }

    private func badgeIconColor(for cell: AchievementWallCellViewModel) -> Color {
        guard cell.isUnlocked else { return ColorTokens.Kid.inkSoft }
        switch cell.rarity {
        case .legendary: return ColorTokens.Brand.gold
        case .rare:      return ColorTokens.Brand.lilac
        case .common:    return ColorTokens.Brand.sky
        }
    }

    /// Task #67 — выбор trophy-bg slug по cell.id / rarity.
    /// Сначала пытаемся подобрать конкретный trophy_bg_streak_*  или
    /// trophy_bg_lessons_* по id; fallback — bronze/silver/gold по rarity.
    /// Возвращает `nil` если slug не подходит (NOTE: не блокирует UI — есть
    /// fallback к цветному badgeBackground).
    private static func trophyBgSlug(for cell: AchievementWallCellViewModel) -> String? {
        let id = cell.id.lowercased()
        if id.contains("streak") {
            if id.contains("100") { return "trophy_bg_streak_100" }
            if id.contains("30") { return "trophy_bg_streak_30" }
            if id.contains("7") { return "trophy_bg_streak_7" }
        }
        if id.contains("lesson") {
            if id.contains("100") { return "trophy_bg_lessons_100" }
            if id.contains("50") { return "trophy_bg_lessons_50" }
            if id.contains("10") { return "trophy_bg_lessons_10" }
        }
        switch cell.rarity {
        case .legendary: return "trophy_bg_gold"
        case .rare:      return "trophy_bg_silver"
        case .common:    return "trophy_bg_bronze"
        }
    }

    // MARK: - Share footer

    private func shareFooter(_ vm: AchievementWallModels.LoadWall.ViewModel) -> some View {
        HSButton(
            String(localized: "achievement.wall.share"),
            style: .primary,
            size: .large,
            icon: "square.and.arrow.up"
        ) {
            Task { await shareTapped(childName: vm.heroTitle) }
        }
        .padding(.top, SpacingTokens.sp2)
        .accessibilityHint(Text("Поделиться стеной достижений через системное окно"))
    }

    // MARK: - Detail sheet

    @ViewBuilder
    private var detailSheet: some View {
        if let vm = holder.detailVM {
            NavigationStack {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp3) {
                        LyalyaMascotView(state: vm.mascotState, size: 80)
                            .padding(.top, SpacingTokens.sp3)
                            .accessibilityHidden(true)
                        ZStack {
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(vm.tintColor.opacity(vm.isUnlocked ? 0.25 : 0.12))
                                .frame(width: 160, height: 160)
                            Image(systemName: vm.iconName)
                                .font(.system(size: 72, weight: .semibold))
                                .foregroundStyle(
                                    vm.isUnlocked ? vm.tintColor : ColorTokens.Kid.inkSoft
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        .accessibilityHidden(true)
                        Text(vm.title)
                            .font(TypographyTokens.title(22))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        Text(vm.description)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SpacingTokens.screenEdge)
                            .lineLimit(nil)
                        if let dateLabel = vm.unlockedDateLabel {
                            Text(dateLabel)
                                .font(TypographyTokens.caption(12).monospacedDigit())
                                .foregroundStyle(ColorTokens.Kid.inkSoft)
                        }
                    }
                    .padding(.bottom, SpacingTokens.sp4)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDetail = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ColorTokens.Kid.inkSoft)
                        }
                        .accessibilityLabel(Text("Закрыть"))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(vm.accessibilityLabel))
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text("Закрыть"))
        }
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = AchievementWallPresenter(displayLogic: holder)
        let interactor = AchievementWallInteractor(
            realmActor: container.realmActor,
            childRepository: container.childRepository
        )
        interactor.presenter = presenter
        let router = AchievementWallRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.loadWall(.init(childId: childId))
    }

    private func openDetail(_ id: String) {
        hapticService.impact(.light)
        Task {
            await interactor?.openDetail(.init(achievementId: id))
            showDetail = true
        }
    }

    private func shareTapped(childName: String) async {
        hapticService.impact(.medium)
        await interactor?.share(.init(childName: childName))
        guard let shareText = holder.pendingShareText else { return }
        // Snapshot стены через ImageRenderer (iOS 16+).
        let snapshot = await renderWallSnapshot()
        router?.presentShareSheet(text: shareText, snapshot: snapshot)
    }

    @MainActor
    private func renderWallSnapshot() async -> UIImage? {
        guard let vm = holder.loadVM else { return nil }
        let snapshotView = WallSnapshotView(viewModel: vm)
            .environment(\.circuitContext, .kid)
            .frame(width: 360)
            .background(ColorTokens.Kid.bg)
        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

// MARK: - Snapshot view (off-screen)

private struct WallSnapshotView: View {
    let viewModel: AchievementWallModels.LoadWall.ViewModel

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.heroTitle)
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(viewModel.heroSubtitle)
                .font(TypographyTokens.body(14).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.cells) { cell in
                    VStack(spacing: 4) {
                        Image(systemName: cell.iconName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(
                                cell.isUnlocked ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft
                            )
                            .symbolRenderingMode(.hierarchical)
                        Text(cell.title)
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 70)
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Preview

#Preview("AchievementWall — Light") {
    AchievementWallView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("AchievementWall — Dark") {
    AchievementWallView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
