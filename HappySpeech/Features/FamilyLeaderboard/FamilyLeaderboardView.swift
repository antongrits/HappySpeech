import OSLog
import SwiftUI

// MARK: - FamilyLeaderboardDisplayLogic

@MainActor
protocol FamilyLeaderboardDisplayLogic: AnyObject {
    func displayLoad(viewModel: FamilyLeaderboardModels.Load.ViewModel) async
}

// MARK: - FamilyLeaderboardViewModel

@MainActor
@Observable
final class FamilyLeaderboardViewModelHolder: FamilyLeaderboardDisplayLogic {

    var viewModel: FamilyLeaderboardModels.Load.ViewModel?
    var period: LeaderboardPeriod = .week

    func displayLoad(viewModel: FamilyLeaderboardModels.Load.ViewModel) async {
        self.viewModel = viewModel
    }
}

// MARK: - FamilyLeaderboardView (Clean Swift: View)
//
// Block S.2 v19 — дружелюбный, неунижающий семейный рейтинг.
//
// Layout (sheet):
//   1. Header card (title + subtitle)
//   2. Period chip (week/month/all-time)
//   3. Podium (топ-3: золото/серебро/бронза) — если участников ≥ 3
//   4. Ранжированный список оставшихся участников (4-е и ниже)
//   5. Тёплая ободряющая подпись внизу
//   6. Empty state, если нет сессий за период
//
// Дизайн-эталон: references/leaderboard.{png,html} — тёплый кремовый канвас,
// подиум с пьедесталами, коралловая подсветка лидера, золото/серебро/бронза.
//
// Accessibility:
//   • Row a11yLabel: "Место 1, Маша, 12 сессий, точность 87%"
//   • Period picker с .accessibilityLabel
//   • Dynamic Type, Reduced Motion compliant.

struct FamilyLeaderboardView: View {

    let parentId: String

    @State private var holder = FamilyLeaderboardViewModelHolder()
    @State private var interactor: FamilyLeaderboardInteractor?
    @State private var presenter: FamilyLeaderboardPresenter?
    @State private var router: FamilyLeaderboardRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyLeaderboard.View")

    init(parentId: String) {
        self.parentId = parentId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                    if let viewModel = holder.viewModel {
                        headerSection(viewModel: viewModel)
                        periodChip(viewModel: viewModel)
                        if viewModel.isEmpty {
                            emptyState
                        } else {
                            leaderboardBody(viewModel: viewModel)
                        }
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .padding(.top, SpacingTokens.sp10)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(
                ZStack {
                    ColorTokens.Kid.bg
                    HSMeshGradientBackground(palette: .rewards, animated: !reduceMotion)
                        .blendMode(.softLight)
                        .accessibilityHidden(true)
                }
                .ignoresSafeArea()
            )
            .navigationTitle(Text("leaderboard.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("leaderboard.close.a11y"))
                }
            }
        }
        .task {
            await setupAndLoad()
        }
    }

    // MARK: - Body composition

    @ViewBuilder
    private func leaderboardBody(viewModel: FamilyLeaderboardModels.Load.ViewModel) -> some View {
        let podium = Array(viewModel.rows.prefix(3))
        let rest = Array(viewModel.rows.dropFirst(3))

        if podium.count >= 3 {
            podiumSection(rows: podium)
        } else {
            // < 3 участников — подиум не строим, показываем обычный список.
            rowsList(rows: viewModel.rows)
        }

        if !rest.isEmpty {
            listHeader
            rowsList(rows: rest)
        }

        encouragingFooter
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(viewModel: FamilyLeaderboardModels.Load.ViewModel) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "trophy.fill")
                        .font(.title)
                        .foregroundStyle(ColorTokens.Brand.gold)
                        .hsSymbolEffect(.bounce, value: viewModel.rows.first?.childName)
                        .accessibilityHidden(true)
                    Text(viewModel.title)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                        .accessibilityAddTraits(.isHeader)
                }
                Text(viewModel.subtitle)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Period chip

    private func periodChip(viewModel: FamilyLeaderboardModels.Load.ViewModel) -> some View {
        Picker(String(localized: "leaderboard.period.picker.title"), selection: $holder.period) {
            ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                Text(period.localizedTitle).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(Text("leaderboard.period.picker.title"))
        .onChange(of: holder.period) { _, newValue in
            Task { await interactor?.changePeriod(request: .init(period: newValue)) }
        }
    }

    // MARK: - Podium (top-3)

    @ViewBuilder
    private func podiumSection(rows: [FamilyLeaderboardModels.Load.ViewModel.Row]) -> some View {
        // rows[0] = 1st (gold), rows[1] = 2nd (silver), rows[2] = 3rd (bronze)
        HStack(alignment: .bottom, spacing: SpacingTokens.sp2) {
            podiumColumn(row: rows[1], place: .silver, pedestalHeight: 76)
            podiumColumn(row: rows[0], place: .gold, pedestalHeight: 100)
            podiumColumn(row: rows[2], place: .bronze, pedestalHeight: 60)
        }
        .padding(.top, SpacingTokens.sp3)
        .padding(.bottom, SpacingTokens.sp1)
        .background(
            // Тёплое золотистое свечение под подиумом.
            RadialGradient(
                colors: [ColorTokens.Brand.gold.opacity(0.16), .clear],
                center: .top,
                startRadius: 4,
                endRadius: 180
            )
            .accessibilityHidden(true)
        )
        .accessibilityElement(children: .contain)
    }

    private func podiumColumn(
        row: FamilyLeaderboardModels.Load.ViewModel.Row,
        place: PodiumPlace,
        pedestalHeight: CGFloat
    ) -> some View {
        let avatarSize: CGFloat = place == .gold ? 70 : 58
        return VStack(spacing: SpacingTokens.sp1) {
            if place == .gold {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
            } else {
                Spacer().frame(height: 18)
            }

            avatarBubble(name: row.childName, ring: place.color, size: avatarSize)

            Text(row.childName)
                .font(TypographyTokens.headline(14))
                .foregroundStyle(ColorTokens.Kid.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)

            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
                Text(row.scoreLabel)
                    .font(TypographyTokens.caption(13).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
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
                        colors: [place.color, place.color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: pedestalHeight)

                Text(verbatim: "\(row.rank)")
                    .font(TypographyTokens.kidHero(30))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .padding(.top, SpacingTokens.sp2)
            }
            .padding(.top, SpacingTokens.sp1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }

    /// Кружок-аватар с инициалом ребёнка в цветном кольце.
    private func avatarBubble(name: String, ring: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [ring, ring.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Circle()
                .fill(ColorTokens.Kid.surface)
                .frame(width: size - 7, height: size - 7)
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.Kid.ink)
        }
        .accessibilityHidden(true)
    }

    // MARK: - List

    private var listHeader: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Text("leaderboard.list.header")
                .font(TypographyTokens.caption(13).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .textCase(.uppercase)
            Rectangle()
                .fill(ColorTokens.Kid.line)
                .frame(height: 1)
        }
        .padding(.top, SpacingTokens.sp2)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func rowsList(rows: [FamilyLeaderboardModels.Load.ViewModel.Row]) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(rows) { row in
                rowCard(row: row)
                    .hsParallaxTile(factor: 0.3)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(
            reduceMotion ? nil : MotionTokens.settleSpring,
            value: rows.count
        )
    }

    @ViewBuilder
    private func rowCard(row: FamilyLeaderboardModels.Load.ViewModel.Row) -> some View {
        let highlighted = row.isLeader
        HStack(spacing: SpacingTokens.sp3) {
            // Rank number / medal
            ZStack {
                Circle()
                    .fill(rankBackground(row: row))
                    .frame(width: 36, height: 36)
                if let medal = row.medal {
                    Image(systemName: medal.symbolName)
                        .font(.title3)
                        .foregroundStyle(medalTint(medal))
                        .accessibilityLabel(Text(medalAccessibilityLabel(medal)))
                } else {
                    Text(verbatim: "\(row.rank)")
                        .font(TypographyTokens.labelRounded(17, weight: .bold))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
            }

            avatarBubble(name: row.childName, ring: ColorTokens.Brand.primaryLo, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.childName)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(row.primaryStat)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: SpacingTokens.sp2)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
                Text(row.scoreLabel)
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp1)
            .background(
                Capsule().fill(ColorTokens.Kid.surfaceAlt)
            )
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(highlighted
                      ? ColorTokens.Brand.primary.opacity(0.12)
                      : ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    highlighted ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                    lineWidth: highlighted ? 1.5 : 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }

    private func rankBackground(row: FamilyLeaderboardModels.Load.ViewModel.Row) -> Color {
        if row.medal != nil {
            return ColorTokens.Brand.gold.opacity(0.18)
        }
        return ColorTokens.Kid.surfaceAlt
    }

    // Block G v18: цвет медали (золото/серебро/бронза) для SF Symbol tint.
    private func medalTint(_ medal: FamilyLeaderboardModels.Load.ViewModel.Medal) -> Color {
        switch medal {
        case .gold:   return ColorTokens.Badge.gold
        case .silver: return ColorTokens.Badge.silver
        case .bronze: return ColorTokens.Badge.bronze
        }
    }

    // Block G v18: a11y label для медали (важно для VoiceOver).
    private func medalAccessibilityLabel(_ medal: FamilyLeaderboardModels.Load.ViewModel.Medal) -> String {
        switch medal {
        case .gold:   return String(localized: "leaderboard.medal.gold.a11y")
        case .silver: return String(localized: "leaderboard.medal.silver.a11y")
        case .bronze: return String(localized: "leaderboard.medal.bronze.a11y")
        }
    }

    // MARK: - Encouraging footer

    private var encouragingFooter: some View {
        HStack(spacing: SpacingTokens.sp3) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(ColorTokens.Brand.butter.opacity(0.30))
                    .frame(width: 40, height: 40)
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("leaderboard.footer.title")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text("leaderboard.footer.subtitle")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
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
                            ColorTokens.Brand.butter.opacity(0.20),
                            ColorTokens.Kid.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .padding(.top, SpacingTokens.sp2)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            // H v18 — Lyalya hero вместо SF Symbol для тёплого empty-state.
            LyalyaMascotView(state: .thinking, size: 100)
                .accessibilityHidden(true)
            Text("leaderboard.empty.title")
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
            Text("leaderboard.empty.subtitle")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp10)
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = FamilyLeaderboardPresenter(displayLogic: holder)
            let interactor = FamilyLeaderboardInteractor(
                childRepository: container.childRepository,
                sessionRepository: container.sessionRepository
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = FamilyLeaderboardRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init(parentId: parentId, period: holder.period))
    }
}

// MARK: - PodiumPlace

private enum PodiumPlace {
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

// NOTE deferred to Block Q (test coverage): snapshot tests, week boundary edge.
