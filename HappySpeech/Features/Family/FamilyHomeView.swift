import SwiftUI

// MARK: - FamilyHomeView
//
// Parent-circuit. Показывает сетку всех детей семьи, прогресс-бар, стрик,
// быстрые переходы к сравнению и совместной игре.
// Tap → переключение ребёнка + переход в ChildHome.
// Long-press → ProfileEditorView для редактирования профиля.
//
// VIP: View → Interactor → Presenter → ViewModel (@Observable).

/// Identifiable-цель для редактора профиля ребёнка. Используется как `item`
/// у `.sheet(item:)`, чтобы устранить race пустого шита (id и флаг показа
/// ранее ставились в одном тике long-press жеста).
private struct ProfileEditorTarget: Identifiable {
    let id: String
}

/// Обёртка локализованного сообщения об ошибке из Presenter в `LocalizedError`,
/// чтобы переиспользовать `HSErrorStateView(error:onRetry:)`.
private struct FamilyHomeDisplayError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct FamilyHomeView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - VIP

    @State private var viewModel = FamilyHomeViewModel()
    @State private var interactor: FamilyHomeInteractor?
    @State private var presenter: FamilyHomePresenter?
    @State private var router: FamilyHomeRouter?

    // MARK: - Local UI

    @State private var profileEditorChild: ProfileEditorTarget?

    // MARK: S.2 v16 — Family Leaderboard
    @State private var showingLeaderboard = false

    // MARK: S12 Hero Transitions (Block S)
    // Namespace для matchedGeometryEffect: avatar circle → увеличение при переходе в ChildHome.
    @Namespace private var familyAvatarNamespace

    // MARK: - Layout
    //
    // Regular (iPad full/split ≥1/2): 3 columns.
    // Compact (iPhone, Slide Over, narrow split): 2 columns.

    private var columns: [GridItem] {
        let colCount = hSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp4), count: colCount)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
                    greetingSection

                    if viewModel.isLoading && viewModel.children.isEmpty {
                        loadingState
                    } else if let message = viewModel.errorMessage, viewModel.children.isEmpty {
                        errorState(message)
                    } else if viewModel.children.isEmpty {
                        emptyState
                    } else {
                        familySummarySection
                        childrenSection
                        actionsSection
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(
                ZStack {
                    ColorTokens.Parent.bg
                    HSMeshGradientBackground(palette: .calm, animated: false)
                        .accessibilityHidden(true)
                }
                .ignoresSafeArea()
            )
            .navigationTitle(String(localized: "family.home.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .refreshable { await refresh() }
        }
        .task { await bootstrap() }
        .sheet(item: $profileEditorChild) { target in
            ProfileEditorView(childId: target.id) {
                Task { await refresh() }
            }
            .environment(container)
            .environment(coordinator)
        }
        .sheet(isPresented: $showingLeaderboard) {
            FamilyLeaderboardView(parentId: "")
                .environment(container)
        }
    }

    // MARK: - Sections

    private var greetingSection: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(viewModel.greeting)
                    .font(TypographyTokens.headline(24))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                    .accessibilityAddTraits(.isHeader)

                if !viewModel.children.isEmpty {
                    Text(familySubtitle)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: SpacingTokens.sp1)
            // F.tier1 v21: mascot мягче в dark.
            LyalyaMascotView(state: .waving, size: 60)
                .opacity(colorScheme == .dark ? 0.92 : 1.0)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.sp3)
    }

    private var familySubtitle: String {
        let count = viewModel.children.count
        if count == 1 {
            return String(localized: "family.home.subtitle.one_child")
        }
        return String(format: String(localized: "family.home.subtitle.many"), count)
    }

    // MARK: - Family Summary
    //
    // Сводка строится ИСКЛЮЧИТЕЛЬНО из реальных данных детей (viewModel.children):
    // число профилей, лучшая активная серия дней, средний прогресс. Никаких
    // фабрикаций — все три значения вычисляются из загруженных ChildSummary.

    private var familySummarySection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionTitle(
                String(localized: "family.home.summary.title"),
                note: String(localized: "family.home.summary.note")
            )

            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
                HStack(spacing: 0) {
                    summaryStat(
                        value: "\(viewModel.children.count)",
                        label: String(localized: "family.home.summary.children"),
                        icon: "person.2.fill",
                        tint: ColorTokens.Brand.lilac
                    )
                    summaryDivider
                    summaryStat(
                        value: "\(bestStreak)",
                        label: String(localized: "family.home.summary.best_streak"),
                        icon: "flame.fill",
                        tint: ColorTokens.Brand.primary
                    )
                    summaryDivider
                    summaryStat(
                        value: "\(averageProgressPercent)%",
                        label: String(localized: "family.home.summary.avg_progress"),
                        icon: "chart.line.uptrend.xyaxis",
                        tint: ColorTokens.Brand.gold
                    )
                }
            }
        }
    }

    private var bestStreak: Int {
        viewModel.children.map(\.currentStreak).max() ?? 0
    }

    private var averageProgressPercent: Int {
        guard !viewModel.children.isEmpty else { return 0 }
        let avg = viewModel.children.map(\.overallProgress).reduce(0, +) / Double(viewModel.children.count)
        return Int((avg * 100).rounded())
    }

    private func summaryStat(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .accessibilityHidden(true)

            Text(value)
                .font(TypographyTokens.headline(22).monospacedDigit())
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value), \(label.replacingOccurrences(of: "\n", with: " "))")
    }

    private var summaryDivider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(ColorTokens.Parent.line)
            .frame(width: 1, height: 56)
            .accessibilityHidden(true)
    }

    // MARK: - Section title helper

    private func sectionTitle(_ title: String, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sp2) {
            Text(title)
                .font(TypographyTokens.headline(19))
                .foregroundStyle(ColorTokens.Parent.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
            Spacer(minLength: SpacingTokens.sp1)
            if let note {
                Text(note)
                    .font(TypographyTokens.caption(12).weight(.medium))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, SpacingTokens.micro)
    }

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionTitle(String(localized: "family.home.section.children"))
            childrenGrid
        }
    }

    private var childrenGrid: some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp4) {
            ForEach(Array(viewModel.children.enumerated()), id: \.element.id) { index, child in
                // S12: matchedGeometryEffect на аватар-круг карточки ребёнка.
                // При tap avatar «летит» к ChildHome hero (если ReduceMotion off).
                ChildCardView(
                    child: child,
                    themeColor: viewModel.themeColor(for: child),
                    avatarIllustration: viewModel.avatarIllustrationName(for: child),
                    avatarHeroId: reduceMotion ? nil : "child_avatar_\(child.id)",
                    avatarNamespace: reduceMotion ? nil : familyAvatarNamespace
                )
                .onTapGesture {
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
                            handleChildTap(child)
                        }
                    } else {
                        handleChildTap(child)
                    }
                }
                .onLongPressGesture {
                    profileEditorChild = ProfileEditorTarget(id: child.id)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(childCardA11yLabel(child))
                .accessibilityHint(String(localized: "family.home.child_card.hint"))
                .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.94)
                }
                .hsParallaxTile(factor: 0.25)
                .zIndex(Double(viewModel.children.count - index))
            }

            AddChildCard {
                coordinator.navigate(to: .onboarding)
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionTitle(String(localized: "family.home.section.actions"))
            actionButtons
        }
    }

    private var actionButtons: some View {
        VStack(spacing: SpacingTokens.sp3) {
            if viewModel.hasMultipleChildren {
                HSLiquidGlassCard(style: .primary) {
                    Button {
                        coordinator.navigate(to: .comparisonDashboard)
                    } label: {
                        HStack(spacing: SpacingTokens.sp3) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(TypographyTokens.headline(22))
                                .foregroundStyle(ColorTokens.Parent.accent)
                                .accessibilityHidden(true)
                            Text(String(localized: "family.home.compare"))
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: SpacingTokens.sp1)
                            Image(systemName: "chevron.right")
                                .font(TypographyTokens.caption(14))
                                .foregroundStyle(ColorTokens.Parent.inkSoft)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(String(localized: "family.home.compare"))
                }

                // S.2 v16 — Family Leaderboard (parent-only).
                HSLiquidGlassCard(style: .primary) {
                    Button {
                        showingLeaderboard = true
                    } label: {
                        HStack(spacing: SpacingTokens.sp3) {
                            Image(systemName: "trophy.fill")
                                .font(TypographyTokens.headline(22))
                                .foregroundStyle(ColorTokens.Brand.gold)
                                .accessibilityHidden(true)
                            Text(String(localized: "family.home.leaderboard"))
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: SpacingTokens.sp1)
                            Image(systemName: "chevron.right")
                                .font(TypographyTokens.caption(14))
                                .foregroundStyle(ColorTokens.Parent.inkSoft)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(String(localized: "family.home.leaderboard"))
                    .accessibilityHint(String(localized: "family.home.leaderboard.hint"))
                }
            }

            HSLiquidGlassCard(style: .primary) {
                Button {
                    let firstChildId = viewModel.children.first?.id ?? ""
                    coordinator.navigate(to: .siblingMultiplayer(childId: firstChildId))
                } label: {
                    HStack(spacing: SpacingTokens.sp3) {
                        Image(systemName: "gamecontroller.fill")
                            .font(TypographyTokens.headline(22))
                            .foregroundStyle(ColorTokens.Brand.lilac)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "family.home.play_together"))
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.85)
                            Text(String(localized: "family.home.play_together.subtitle"))
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.85)
                        }
                        Spacer(minLength: SpacingTokens.sp1)
                        Image(systemName: "chevron.right")
                            .font(TypographyTokens.caption(14))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(String(localized: "family.home.play_together"))
            }

            HSLiquidGlassCard(style: .primary) {
                Button {
                    coordinator.navigate(to: .sharePlay)
                } label: {
                    HStack(spacing: SpacingTokens.sp3) {
                        Image(systemName: "shareplay")
                            .font(TypographyTokens.headline(22))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "family.home.shareplay_title"))
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(ColorTokens.Parent.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.85)
                            Text(String(localized: "shareplay.family_home.subtitle"))
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.85)
                        }
                        Spacer(minLength: SpacingTokens.sp1)
                        Image(systemName: "chevron.right")
                            .font(TypographyTokens.caption(14))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(String(localized: "family.home.shareplay_title"))
                .accessibilityHint(String(localized: "shareplay.family_home.a11y_hint"))
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        HSLoadingView(message: String(localized: "family.home.loading"))
            .frame(maxWidth: .infinity, minHeight: 360)
            .accessibilityLabel(String(localized: "family.home.loading"))
    }

    private var emptyState: some View {
        HSEmptyStateView(
            warmPanel: .waving,
            title: String(localized: "family.home.empty.title"),
            subtitle: String(localized: "family.home.empty.message"),
            actionTitle: String(localized: "family.home.empty.action")
        ) {
            coordinator.navigate(to: .onboarding)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private func errorState(_ message: String) -> some View {
        HSErrorStateView(error: FamilyHomeDisplayError(message: message)) {
            Task { await refresh() }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                coordinator.navigate(to: .settings)
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(ColorTokens.Parent.accent)
            }
            .accessibilityLabel(String(localized: "settings.title"))
        }
    }

    // MARK: - Actions

    private func handleChildTap(_ child: FamilyHome.ChildSummary) {
        container.currentChildId = child.id
        coordinator.navigate(to: .childHome(childId: child.id))
    }

    // MARK: - VIP Bootstrap

    private func bootstrap() async {
        if interactor == nil {
            let presenter = FamilyHomePresenter()
            let interactor = FamilyHomeInteractor(childRepository: container.childRepository)
            let router = FamilyHomeRouter(coordinator: coordinator, container: container)
            presenter.viewModel = viewModel
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = router
        }
        await refresh()
    }

    private func refresh() async {
        await interactor?.load(FamilyHome.LoadRequest())
    }

    // MARK: - Accessibility

    private func childCardA11yLabel(_ child: FamilyHome.ChildSummary) -> String {
        let progress = Int(child.overallProgress * 100)
        let streak = child.currentStreak
        let yearsStr = String(localized: "years.short")
        let progressStr = String(localized: "progress.label")
        let streakStr = String(localized: "streak.days.short")
        return "\(child.name), \(child.age) \(yearsStr), \(progressStr) \(progress)%, \(streak) \(streakStr)"
    }
}

// MARK: - ChildCardView
//
// S12 Block S: добавлены параметры avatarHeroId и avatarNamespace для
// matchedGeometryEffect на аватар-круг. Nil-безопасны — backward compatible.

private struct ChildCardView: View {

    let child: FamilyHome.ChildSummary
    let themeColor: Color
    let avatarIllustration: String
    var avatarHeroId: String? = nil
    var avatarNamespace: Namespace.ID? = nil

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HSLiquidGlassCard(style: .tinted(themeColor), padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                // Avatar + streak chip (S12: matchedGeometryEffect если namespace передан)
                avatarSection

                // Name + age
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text(String(format: String(localized: "child.age.label"), child.age))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }

                Spacer(minLength: 0)

                // Progress bar + percent
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    HSProgressBar(value: child.overallProgress, style: .parent, tint: themeColor)
                    Text("\(Int((child.overallProgress * 100).rounded()))%")
                        .font(TypographyTokens.mono(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        }
        .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    @ViewBuilder
    private var avatarSection: some View {
        let baseCircle = ZStack {
            Circle()
                .fill(themeColor.opacity(0.22))
                .frame(width: 56, height: 56)
            Circle()
                .strokeBorder(themeColor.opacity(0.55), lineWidth: 2)
                .frame(width: 56, height: 56)
            Image(avatarIllustration)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(SpacingTokens.micro)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .accessibilityHidden(true)
        }

        let circleWithBadge = baseCircle
            .overlay(alignment: .bottomTrailing) {
                if child.currentStreak > 0 {
                    streakChip
                        .offset(x: 4, y: 2)
                }
            }

        if let heroId = avatarHeroId, let ns = avatarNamespace {
            circleWithBadge.matchedGeometryEffect(id: heroId, in: ns)
        } else {
            circleWithBadge
        }
    }

    private var streakChip: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .hsSymbolEffect(.pulse, value: child.currentStreak)
            Text("\(child.currentStreak)")
                .font(TypographyTokens.caption(11).weight(.bold).monospacedDigit())
                .foregroundStyle(ColorTokens.Parent.ink)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Parent.surface)
                .overlay(Capsule(style: .continuous).strokeBorder(ColorTokens.Parent.line, lineWidth: 1))
        )
        .accessibilityHidden(true)
    }
}

// MARK: - AddChildCard

private struct AddChildCard: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.sp4) {
                VStack(spacing: SpacingTokens.sp3) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Circle()
                            .strokeBorder(
                                ColorTokens.Brand.primary.opacity(0.55),
                                style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "plus")
                            .font(TypographyTokens.headline(22))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }

                    Text(String(localized: "family.home.add_child"))
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            }
        }
        .accessibilityLabel(String(localized: "family.home.add_child"))
    }
}

// MARK: - Preview

#Preview("Family Home") {
    let container = AppContainer.preview()
    return FamilyHomeView()
        .environment(container)
        .environment(AppCoordinator())
}

#Preview("Family Home — Multiple Children") {
    let container = AppContainer.preview()
    return FamilyHomeView()
        .environment(container)
        .environment(AppCoordinator())
}
