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
// Block S.2 v16 — еженедельный leaderboard для семьи.
//
// Layout (sheet):
//   1. Header (title + subtitle)
//   2. Period picker (week/month/all-time)
//   3. List of rows: rank + medal + name + primary/secondary stats
//   4. Empty state, если нет сессий за период
//
// Accessibility:
//   • Row a11yLabel: "Место 1, Маша, 12 сессий, точность 87%"
//   • Period picker: SegmentedPicker с .accessibilityLabel
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
                        periodPicker
                        if viewModel.isEmpty {
                            emptyState
                        } else {
                            rowsList(viewModel: viewModel)
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
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(Text("leaderboard.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("leaderboard.close.a11y"))
                }
            }
        }
        .task {
            await setupAndLoad()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(viewModel: FamilyLeaderboardModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .accessibilityHidden(true)
                Text(viewModel.title)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(viewModel.subtitle)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Period picker

    private var periodPicker: some View {
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

    // MARK: - Rows

    @ViewBuilder
    private func rowsList(viewModel: FamilyLeaderboardModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(viewModel.rows) { row in
                rowCard(row: row)
            }
        }
    }

    @ViewBuilder
    private func rowCard(row: FamilyLeaderboardModels.Load.ViewModel.Row) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankBackground(row: row))
                    .frame(width: 40, height: 40)
                if let medal = row.medal {
                    // Block G v18: SF Symbol с brand-tint вместо эмодзи медалей.
                    Image(systemName: medal.symbolName)
                        .font(.title2)
                        .foregroundStyle(medalTint(medal))
                        .accessibilityLabel(Text(medalAccessibilityLabel(medal)))
                } else {
                    Text(verbatim: "\(row.rank)")
                        .font(.title3.bold())
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(row.childName)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(spacing: SpacingTokens.sp2) {
                    Text(row.primaryStat)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("•")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                    Text(row.secondaryStat)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Spacer(minLength: SpacingTokens.sp2)

            Text(row.scoreLabel)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(row.isLeader ? ColorTokens.Brand.gold : ColorTokens.Parent.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTokens.Parent.surface)
                .shadow(color: .black.opacity(row.isLeader ? 0.10 : 0.04), radius: 8, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }

    private func rankBackground(row: FamilyLeaderboardModels.Load.ViewModel.Row) -> Color {
        if row.medal != nil {
            return ColorTokens.Brand.gold.opacity(0.20)
        }
        return ColorTokens.Parent.inkSoft.opacity(0.30)
    }

    // Block G v18: цвет медали (золото/серебро/бронза) для SF Symbol tint.
    private func medalTint(_ medal: FamilyLeaderboardModels.Load.ViewModel.Medal) -> Color {
        switch medal {
        case .gold:   return ColorTokens.Brand.gold
        case .silver: return ColorTokens.Parent.inkSoft
        case .bronze: return ColorTokens.Brand.primary
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

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            // H v18 — Lyalya hero вместо SF Symbol для тёплого parent empty-state.
            LyalyaMascotView(state: .thinking, size: 100)
                .accessibilityHidden(true)
            Text("leaderboard.empty.title")
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
            Text("leaderboard.empty.subtitle")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
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

// NOTE deferred to Block Q (test coverage): snapshot tests, week boundary edge.
