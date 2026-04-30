import SwiftUI

// MARK: - FamilyHomeView
//
// Parent-circuit. Показывает сетку всех детей семьи, прогресс-бар, стрик,
// быстрые переходы к сравнению и совместной игре.
// Tap → переключение ребёнка + переход в ChildHome.
// Long-press → ProfileEditorView для редактирования профиля.
//
// VIP: View → Interactor → Presenter → ViewModel (@Observable).

struct FamilyHomeView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // MARK: - VIP

    @State private var viewModel = FamilyHomeViewModel()
    @State private var interactor: FamilyHomeInteractor?
    @State private var presenter: FamilyHomePresenter?
    @State private var router: FamilyHomeRouter?

    // MARK: - Local UI

    @State private var profileEditorChildId: String?
    @State private var showingProfileEditor = false

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
                    childrenGrid
                    actionButtons
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "family.home.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .refreshable { await refresh() }
        }
        .task { await bootstrap() }
        .sheet(isPresented: $showingProfileEditor) {
            if let childId = profileEditorChildId {
                ProfileEditorView(childId: childId) {
                    Task { await refresh() }
                }
                .environment(container)
                .environment(coordinator)
            }
        }
    }

    // MARK: - Sections

    private var greetingSection: some View {
        Text(viewModel.greeting)
            .font(TypographyTokens.headline(22))
            .foregroundStyle(ColorTokens.Parent.ink)
            .padding(.top, SpacingTokens.sp3)
            .accessibilityAddTraits(.isHeader)
    }

    private var childrenGrid: some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp4) {
            ForEach(viewModel.children) { child in
                ChildCardView(
                    child: child,
                    themeColor: viewModel.themeColor(for: child),
                    avatarEmoji: viewModel.avatarEmoji(for: child)
                )
                .onTapGesture {
                    handleChildTap(child)
                }
                .onLongPressGesture {
                    profileEditorChildId = child.id
                    showingProfileEditor = true
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(childCardA11yLabel(child))
                .accessibilityHint(String(localized: "family.home.child_card.hint"))
            }

            AddChildCard {
                coordinator.navigate(to: .onboarding)
            }
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
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(ColorTokens.Parent.accent)
                                .accessibilityHidden(true)
                            Text(String(localized: "family.home.compare"))
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(ColorTokens.Parent.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundStyle(ColorTokens.Parent.inkSoft)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(String(localized: "family.home.compare"))
                }
            }

            HSLiquidGlassCard(style: .primary) {
                Button {
                    let firstChildId = viewModel.children.first?.id ?? ""
                    coordinator.navigate(to: .siblingMultiplayer(childId: firstChildId))
                } label: {
                    HStack(spacing: SpacingTokens.sp3) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.lilac)
                            .accessibilityHidden(true)
                        Text(String(localized: "family.home.play_together"))
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
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
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "shareplay.startButton"))
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(ColorTokens.Parent.ink)
                            Text(String(localized: "shareplay.family_home.subtitle"))
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(String(localized: "shareplay.startButton"))
                .accessibilityHint(String(localized: "shareplay.family_home.a11y_hint"))
            }
        }
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

private struct ChildCardView: View {

    let child: FamilyHome.ChildSummary
    let themeColor: Color
    let avatarEmoji: String

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HSLiquidGlassCard(style: .tinted(themeColor), padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                // Avatar
                avatarSection

                // Name + age
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(String(format: String(localized: "child.age.label"), child.age))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }

                // Progress bar
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    HSProgressBar(value: child.overallProgress, style: .parent, tint: themeColor)
                    Text("\(Int(child.overallProgress * 100))%")
                        .font(TypographyTokens.mono(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }

                // Streak
                HStack(spacing: SpacingTokens.sp1) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("\(child.currentStreak) \(String(localized: "streak.days.short"))")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
            }
        }
        .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    private var avatarSection: some View {
        ZStack {
            Circle()
                .fill(themeColor.opacity(0.25))
                .frame(width: 56, height: 56)
            Text(avatarEmoji)
                .font(.system(size: 28))
        }
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
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }

                    Text(String(localized: "family.home.add_child"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
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
