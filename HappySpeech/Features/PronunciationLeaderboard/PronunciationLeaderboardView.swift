import SwiftUI

// MARK: - PronunciationLeaderboardView
//
// Parent contour экран — семейный рейтинг точности произношения.
// COPPA-safe: ranking ограничен одной семьёй (parentId), kids НЕ видят рейтинг.
//
// Состав:
// 1. Picker scope (Эта неделя / Прошлая неделя / Всё время).
// 2. Топ-3 podium (если детей ≥ 3).
// 3. Полный список с медалями, accuracy %, sessions count, trend label.
//
// Доступ: ParentHome → «Рейтинг семьи».

struct PronunciationLeaderboardView: View {

    let parentId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var viewModel = PronunciationLeaderboardViewModel()
    @State private var interactor: PronunciationLeaderboardInteractor?
    @State private var presenter: PronunciationLeaderboardPresenter?
    @State private var router: PronunciationLeaderboardRouter?

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Parent.bg.ignoresSafeArea()
            HSMeshGradientBackground(palette: .rewards, animated: !reduceMotion)
                .ignoresSafeArea()
                .blendMode(.softLight)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sectionGap) {
                    headerSection
                    scopePicker
                    contentSection
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp8)
            }
        }
        .navigationTitle(String(localized: "leaderboard.nav_title"))
        .navigationBarTitleDisplayMode(.large)
        .task { await bootstrap() }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Header

    private var headerSection: some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(alignment: .center, spacing: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(String(localized: "leaderboard.header.title"))
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                        .accessibilityAddTraits(.isHeader)

                    Text(viewModel.totalChildrenText.isEmpty
                         ? String(localized: "leaderboard.header.subtitle")
                         : viewModel.totalChildrenText)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: SpacingTokens.sp2)

                Image(systemName: "trophy.fill")
                    .font(TypographyTokens.titleLarge(36))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .hsSymbolEffect(.bounce, value: viewModel.rows.count)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, SpacingTokens.sp3)
    }

    // MARK: - Scope picker

    private var scopePicker: some View {
        Picker(String(localized: "leaderboard.scope_label"), selection: Binding(
            get: { viewModel.scope },
            set: { newValue in
                viewModel.scope = newValue
                Task {
                    await interactor?.selectScope(
                        PronunciationLeaderboard.SelectScopeRequest(scope: newValue)
                    )
                }
            }
        )) {
            ForEach(PronunciationLeaderboard.Scope.allCases, id: \.self) { scope in
                Text(scope.localizedTitle).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "leaderboard.scope_label"))
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, SpacingTokens.sp4)

        case .empty:
            HSEmptyStateView(
                mascot: .thinking,
                title: String(localized: "leaderboard.empty.title"),
                subtitle: String(localized: "leaderboard.empty.message")
            )
            .frame(maxWidth: .infinity, minHeight: 320)

        case .ready:
            VStack(spacing: SpacingTokens.sp3) {
                if viewModel.rows.count >= 3 {
                    podiumSection
                    listHeader
                }
                listSection
                encouragingFooter
            }

        case .error(let message):
            HSEmptyStateView(
                mascot: .sad,
                title: String(localized: "leaderboard.error.title"),
                subtitle: message,
                actionTitle: String(localized: "leaderboard.error.retry")
            ) {
                Task { await refresh() }
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        }
    }

    // MARK: - Podium (top-3)

    private var podiumSection: some View {
        let top3 = Array(viewModel.rows.prefix(3))
        return HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            if top3.count >= 2 {
                podiumColumn(row: top3[1], pedestalHeight: 76, accent: .silver)
            }
            if let first = top3.first {
                podiumColumn(row: first, pedestalHeight: 100, accent: .gold)
            }
            if top3.count >= 3 {
                podiumColumn(row: top3[2], pedestalHeight: 60, accent: .bronze)
            }
        }
        .padding(.top, SpacingTokens.sp3)
        .padding(.bottom, SpacingTokens.sp1)
        .background(
            RadialGradient(
                colors: [ColorTokens.Brand.gold.opacity(0.16), .clear],
                center: .top,
                startRadius: 4,
                endRadius: 180
            )
            .accessibilityHidden(true)
        )
        .accessibilityLabel(String(localized: "leaderboard.podium.a11y"))
    }

    private func podiumColumn(
        row: PronunciationLeaderboard.LeaderboardRow,
        pedestalHeight: CGFloat,
        accent: PodiumAccent
    ) -> some View {
        let avatarSize: CGFloat = accent == .gold ? 70 : 58
        return VStack(spacing: SpacingTokens.sp1) {
            if accent == .gold {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
            } else {
                Spacer().frame(height: 18)
            }

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.color, accent.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: avatarSize, height: avatarSize)
                Circle()
                    .fill(ColorTokens.Parent.surface)
                    .frame(width: avatarSize - 7, height: avatarSize - 7)
                Text(String(row.childName.prefix(1)))
                    .font(.system(size: avatarSize * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorTokens.Parent.ink)
            }
            .accessibilityHidden(true)

            Text(row.childName)
                .font(TypographyTokens.headline(14))
                .foregroundStyle(ColorTokens.Parent.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)

            HStack(spacing: 3) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.Semantic.success)
                    .accessibilityHidden(true)
                Text(row.accuracyText)
                    .font(TypographyTokens.caption(13).weight(.bold))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ZStack(alignment: .top) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [accent.color, accent.color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: pedestalHeight)

                Text("\(row.position)")
                    .font(TypographyTokens.kidHero(30))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .padding(.top, SpacingTokens.sp2)
            }
            .padding(.top, SpacingTokens.sp1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "leaderboard.podium.row.a11y"),
                   row.position, row.childName, row.accuracyText)
        )
    }

    // MARK: - List header

    private var listHeader: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Text("leaderboard.list.header")
                .font(TypographyTokens.caption(13).weight(.bold))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .textCase(.uppercase)
            Rectangle()
                .fill(ColorTokens.Parent.line)
                .frame(height: 1)
        }
        .padding(.top, SpacingTokens.sp1)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Encouraging footer

    private var encouragingFooter: some View {
        HStack(spacing: SpacingTokens.sp3) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(ColorTokens.Semantic.success.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.up.heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.Semantic.success)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("leaderboard.champions.footer.title")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text("leaderboard.champions.footer.subtitle")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTokens.Brand.butter.opacity(0.18),
                            ColorTokens.Parent.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .padding(.top, SpacingTokens.sp1)
        .accessibilityElement(children: .combine)
    }

    // MARK: - List

    private var listSection: some View {
        // Если показан подиум (≥3), список начинается с 4-го места.
        let listRows = viewModel.rows.count >= 3
            ? Array(viewModel.rows.dropFirst(3))
            : viewModel.rows
        return VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(listRows.enumerated()), id: \.element.id) { index, row in
                LeaderboardRowView(
                    row: row,
                    onTap: { router?.routeToChildProgress(childId: row.id) }
                )
                .scrollTransition(.animated(
                    reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85)
                )) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.95)
                }
                .hsParallaxTile(factor: 0.18)
                .zIndex(Double(listRows.count - index))
            }
        }
    }

    // MARK: - VIP bootstrap

    private func bootstrap() async {
        if interactor == nil {
            let presenter = PronunciationLeaderboardPresenter()
            let interactor = PronunciationLeaderboardInteractor(
                childRepository: container.childRepository,
                sessionRepository: container.sessionRepository,
                realmActor: container.realmActor
            )
            let router = PronunciationLeaderboardRouter(coordinator: coordinator)
            presenter.viewModel = viewModel
            presenter.youChildId = container.currentChildId
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = router

            // Префетч имён детей для подсветки.
            if let names = try? await container.childRepository.fetchAll() {
                presenter.childNameRegistry = Dictionary(
                    uniqueKeysWithValues: names.map { ($0.id, $0.name) }
                )
            }
        }
        await refresh()
    }

    private func refresh() async {
        viewModel.state = .loading
        await interactor?.load(PronunciationLeaderboard.LoadRequest(parentId: parentId))
    }
}

// MARK: - LeaderboardRowView

private struct LeaderboardRowView: View {

    let row: PronunciationLeaderboard.LeaderboardRow
    let onTap: () -> Void

    private var trendColor: Color {
        switch row.trendColorToken {
        case "success": return ColorTokens.Semantic.success
        case "warning": return ColorTokens.Semantic.warning
        default:        return ColorTokens.Parent.inkMuted
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.sp3) {
                // Position / medal
                ZStack {
                    Circle()
                        .fill(row.isYou
                              ? ColorTokens.Brand.primary.opacity(0.18)
                              : ColorTokens.Parent.surface)
                        .frame(width: 36, height: 36)
                    if let medal = row.medalSymbol {
                        Image(systemName: medal)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(positionColor)
                    } else {
                        Text("\(row.position)")
                            .font(TypographyTokens.labelRounded(17, weight: .bold))
                            .foregroundStyle(row.isYou
                                             ? ColorTokens.Brand.primary
                                             : ColorTokens.Parent.inkMuted)
                    }
                }

                // Avatar bubble
                ZStack {
                    Circle()
                        .fill(row.isYou
                              ? ColorTokens.Brand.primaryLo
                              : ColorTokens.Parent.surface)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle().strokeBorder(
                                row.isYou ? ColorTokens.Brand.primaryLo : ColorTokens.Parent.line,
                                lineWidth: 1.5
                            )
                        )
                    Text(String(row.childName.prefix(1)))
                        .font(TypographyTokens.labelRounded(18, weight: .bold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: SpacingTokens.sp1) {
                        Text(row.childName)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        if row.isYou {
                            Text("leaderboard.you.tag")
                                .font(TypographyTokens.caption(10).weight(.bold))
                                .foregroundStyle(ColorTokens.Overlay.onAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(ColorTokens.Brand.primary))
                                .accessibilityHidden(true)
                        }
                    }
                    Text(row.sessionsCountText)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: SpacingTokens.sp2)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(row.accuracyText)
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .monospacedDigit()
                        .fixedSize()
                    HStack(spacing: 2) {
                        Image(systemName: row.trendIcon)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(trendColor)
                            .accessibilityHidden(true)
                        Text(row.trendLabel)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(trendColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .layoutPriority(1)
            }
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(row.isYou
                          ? ColorTokens.Brand.primary.opacity(0.12)
                          : ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        row.isYou ? ColorTokens.Brand.primary : ColorTokens.Parent.line,
                        lineWidth: row.isYou ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "leaderboard.row.a11y"),
                   row.position, row.childName, row.accuracyText, row.trendLabel)
        )
        .accessibilityHint(String(localized: "leaderboard.row.hint"))
    }

    private var positionColor: Color {
        switch row.position {
        case 1: return ColorTokens.Badge.gold
        case 2: return ColorTokens.Badge.silver
        case 3: return ColorTokens.Badge.bronze
        default: return ColorTokens.Brand.primary
        }
    }
}

// MARK: - PodiumAccent

private enum PodiumAccent {
    case gold
    case silver
    case bronze

    var color: Color {
        switch self {
        case .gold:   return ColorTokens.Badge.gold
        case .silver: return ColorTokens.Badge.silver
        case .bronze: return ColorTokens.Badge.bronze
        }
    }
}

// MARK: - Preview

#Preview("Pronunciation Leaderboard") {
    let container = AppContainer.preview()
    return NavigationStack {
        PronunciationLeaderboardView(parentId: "preview-parent")
            .environment(container)
            .environment(AppCoordinator())
    }
}
