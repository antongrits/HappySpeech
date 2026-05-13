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
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(String(localized: "leaderboard.header.title"))
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)

                Text(viewModel.totalChildrenText.isEmpty
                     ? String(localized: "leaderboard.header.subtitle")
                     : viewModel.totalChildrenText)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: SpacingTokens.sp2)

            Image(systemName: "trophy.fill")
                .font(TypographyTokens.titleLarge(36))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)
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
            HSEmptyState(
                icon: "person.3.sequence",
                title: String(localized: "leaderboard.empty.title"),
                message: String(localized: "leaderboard.empty.message"),
                actionTitle: nil
            )

        case .ready:
            VStack(spacing: SpacingTokens.sp3) {
                if viewModel.rows.count >= 3 {
                    podiumSection
                }
                listSection
            }

        case .error(let message):
            HSEmptyState(
                icon: "exclamationmark.triangle",
                title: String(localized: "leaderboard.error.title"),
                message: message,
                actionTitle: String(localized: "leaderboard.error.retry")
            ) {
                Task { await refresh() }
            }
        }
    }

    // MARK: - Podium (top-3)

    private var podiumSection: some View {
        let top3 = Array(viewModel.rows.prefix(3))
        return HStack(alignment: .bottom, spacing: SpacingTokens.sp3) {
            if top3.count >= 2 {
                podiumColumn(row: top3[1], height: 100, accent: .silver)
            }
            if let first = top3.first {
                podiumColumn(row: first, height: 130, accent: .gold)
            }
            if top3.count >= 3 {
                podiumColumn(row: top3[2], height: 80, accent: .bronze)
            }
        }
        .padding(.vertical, SpacingTokens.sp3)
        .accessibilityLabel(String(localized: "leaderboard.podium.a11y"))
    }

    private func podiumColumn(
        row: PronunciationLeaderboard.LeaderboardRow,
        height: CGFloat,
        accent: PodiumAccent
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ZStack {
                Circle()
                    .fill(accent.color.opacity(0.20))
                    .frame(width: 56, height: 56)
                Text(String(row.childName.prefix(1)))
                    .font(TypographyTokens.headline(22))
                    .foregroundStyle(accent.color)
            }

            Text(row.childName)
                .font(TypographyTokens.headline(14))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(row.accuracyText)
                .font(TypographyTokens.headline(18))
                .foregroundStyle(accent.color)

            RoundedRectangle(cornerRadius: 8)
                .fill(accent.color.opacity(0.7))
                .frame(width: 64, height: height)
                .overlay(
                    Text("\(row.position)")
                        .font(TypographyTokens.titleLarge(28))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "leaderboard.podium.row.a11y"),
                   row.position, row.childName, row.accuracyText)
        )
    }

    // MARK: - List

    private var listSection: some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(viewModel.rows) { row in
                LeaderboardRowView(
                    row: row,
                    onTap: { router?.routeToChildProgress(childId: row.id) }
                )
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
            HSCard(
                style: row.isYou ? .tinted(ColorTokens.Brand.primary.opacity(0.10)) : .flat,
                padding: SpacingTokens.sp3
            ) {
                HStack(spacing: SpacingTokens.sp3) {
                    // Position / medal
                    ZStack {
                        Circle()
                            .fill(positionColor.opacity(0.15))
                            .frame(width: 40, height: 40)
                        if let medal = row.medalSymbol {
                            Image(systemName: medal)
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(positionColor)
                        } else {
                            Text("\(row.position)")
                                .font(TypographyTokens.headline(16))
                                .foregroundStyle(positionColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.childName)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(row.sessionsCountText)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }

                    Spacer(minLength: SpacingTokens.sp1)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.accuracyText)
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        HStack(spacing: 2) {
                            Image(systemName: row.trendIcon)
                                .font(TypographyTokens.caption(11))
                                .foregroundStyle(trendColor)
                                .accessibilityHidden(true)
                            Text(row.trendLabel)
                                .font(TypographyTokens.caption(11))
                                .foregroundStyle(trendColor)
                        }
                    }
                }
            }
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
        case 2: return Color.gray
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
        case .silver: return Color.gray
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
