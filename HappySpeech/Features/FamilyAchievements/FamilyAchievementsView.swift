import OSLog
import SwiftUI

// MARK: - FamilyAchievementsViewModelHolder

@MainActor
@Observable
final class FamilyAchievementsViewModelHolder: FamilyAchievementsDisplayLogic {

    var loadVM: FamilyAchievementsModels.Load.ViewModel?
    var recomputeVM: FamilyAchievementsModels.Recompute.ViewModel?
    var showToast: Bool = false

    func displayLoad(viewModel: FamilyAchievementsModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayRecompute(viewModel: FamilyAchievementsModels.Recompute.ViewModel) async {
        self.recomputeVM = viewModel
        if viewModel.toastMessage != nil {
            self.showToast = true
        }
    }
}

// MARK: - FamilyAchievementsView (Clean Swift: View)
//
// Block R.4 v18 — экран общих достижений семьи.
//
// Layout (sheet, presentationDetent .large):
//   1. Family streak hero — combinedDays + activeRatio
//   2. Members section — карточки с per-child summary
//   3. Achievements list — unlocked + locked, прогресс bar на каждом
//   4. Summary footer — totals
//
// Accessibility:
//   • VoiceOver: каждый member row = «<имя>, <возраст>, <статус>»
//   • Achievement row = «<title>, <progress>, <unlocked/locked>»
//   • Dynamic Type: scaledFont, lineLimit(nil)
//   • Reduced Motion: пропуск progress анимации
//   • Touch targets: parent contour ≥44pt

struct FamilyAchievementsView: View {

    let familyId: String

    @State private var holder = FamilyAchievementsViewModelHolder()
    @State private var interactor: FamilyAchievementsInteractor?
    @State private var presenter: FamilyAchievementsPresenter?
    @State private var router: FamilyAchievementsRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyAchievements.View")

    init(familyId: String) {
        self.familyId = familyId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    if let viewModel = holder.loadVM {
                        streakHeroSection(hero: viewModel.streakHero)
                        membersSection(rows: viewModel.memberRows)
                        achievementsSection(achievements: viewModel.achievements)
                        summarySection(summary: viewModel.summary)
                        footerSection
                    } else {
                        loadingSection
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(Text("family.achievements.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("family.achievements.close.a11y"))
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast, let toast = holder.recomputeVM?.toastMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: holder.showToast)
        }
        .environment(\.circuitContext, .parent)
        .task {
            await setupAndLoad()
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            // E v21: 3D Ляля в loading state FamilyAchievements.
            LyalyaHeroView(state: .happy, mood: 0.6, size: 110)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
        }
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Streak Hero

    @ViewBuilder
    private func streakHeroSection(
        hero: FamilyAchievementsModels.Load.StreakHeroViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            // E v21: 3D Ляля hero на FamilyAchievements streak (требование пользователя).
            LyalyaHeroView(state: .celebrating, mood: 1.0, size: 160)
                .frame(height: 160)
                .accessibilityHidden(true)

            Text(hero.titleLabel)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Parent.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(hero.subtitleLabel)
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp4)

            VStack(spacing: SpacingTokens.sp1) {
                ProgressView(value: hero.progressFraction)
                    .tint(
                        hero.allActiveToday
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Parent.accent
                    )
                    .progressViewStyle(.linear)

                Text(hero.activeLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.top, SpacingTokens.sp1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp5)
        .padding(.horizontal, SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(
            format: String(localized: "family.streak.a11y"),
            hero.titleLabel,
            hero.activeLabel
        )))
    }

    // MARK: - Members

    @ViewBuilder
    private func membersSection(
        rows: [FamilyAchievementsModels.Load.MemberRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("family.members.title")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Parent.ink)
                .padding(.leading, SpacingTokens.sp1)

            if rows.isEmpty {
                Text("family.members.empty")
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .padding(SpacingTokens.sp4)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md)
                            .fill(ColorTokens.Parent.surface)
                    )
            } else {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(rows) { row in
                        memberCard(row: row)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func memberCard(row: FamilyAchievementsModels.Load.MemberRow) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            ZStack {
                Circle()
                    .fill(
                        row.isActiveToday
                            ? ColorTokens.Brand.primary.opacity(0.18)
                            : ColorTokens.Parent.bgDeep
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: row.avatarSymbol)
                    .font(.title3)
                    .foregroundStyle(
                        row.isActiveToday
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Parent.inkSoft
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                if row.isActiveToday {
                    Circle()
                        .fill(ColorTokens.Semantic.success)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().strokeBorder(ColorTokens.Parent.surface, lineWidth: 2)
                        )
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(row.name)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(row.ageLabel)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }

                HStack(spacing: SpacingTokens.sp2) {
                    Label(row.streakLabel, systemImage: "flame")
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .labelStyle(.titleAndIcon)
                    Spacer(minLength: 0)
                }

                if !row.masteredSoundsLabel.isEmpty {
                    Text(row.masteredSoundsLabel)
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }

    // MARK: - Achievements

    @ViewBuilder
    private func achievementsSection(
        achievements: [FamilyAchievementsModels.Load.AchievementRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("family.achievements.title")
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Parent.ink)
                .padding(.leading, SpacingTokens.sp1)

            VStack(spacing: SpacingTokens.sp2) {
                ForEach(achievements) { row in
                    achievementCard(row: row)
                }
            }
        }
    }

    @ViewBuilder
    private func achievementCard(
        row: FamilyAchievementsModels.Load.AchievementRow
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: row.symbolName)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(
                        row.isUnlocked
                            ? ColorTokens.Brand.gold
                            : ColorTokens.Parent.inkSoft.opacity(0.5)
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                row.isUnlocked
                                    ? ColorTokens.Brand.gold.opacity(0.15)
                                    : ColorTokens.Parent.bgDeep
                            )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(
                            row.isUnlocked
                                ? ColorTokens.Parent.ink
                                : ColorTokens.Parent.inkMuted
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(row.categoryLabel)
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Spacer(minLength: 0)

                Text(row.progressLabel)
                    .font(TypographyTokens.caption(12).weight(.medium))
                    .foregroundStyle(
                        row.isUnlocked
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Parent.inkMuted
                    )
            }

            Text(row.description)
                .font(TypographyTokens.body(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)

            ProgressView(value: row.progressFraction)
                .tint(
                    row.isUnlocked
                        ? ColorTokens.Brand.primary
                        : ColorTokens.Parent.accent
                )
                .progressViewStyle(.linear)
                .opacity(row.isUnlocked ? 1.0 : 0.7)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(
                    row.isUnlocked
                        ? ColorTokens.Brand.primary.opacity(0.04)
                        : ColorTokens.Parent.surface
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .strokeBorder(
                    row.isUnlocked
                        ? ColorTokens.Brand.primary.opacity(0.4)
                        : ColorTokens.Parent.line,
                    lineWidth: row.isUnlocked ? 1.5 : 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }

    // MARK: - Summary

    @ViewBuilder
    private func summarySection(
        summary: FamilyAchievementsModels.Load.SummaryRow
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp3) {
                summaryStatCard(
                    label: summary.totalSessionsLabel,
                    iconName: "graduationcap.fill",
                    color: ColorTokens.Brand.primary
                )
                summaryStatCard(
                    label: summary.totalMasteredSoundsLabel,
                    iconName: "waveform.path",
                    color: ColorTokens.Brand.sky
                )
                summaryStatCard(
                    label: String(
                        format: String(localized: "family.summary.unlocked"),
                        summary.unlockedCount,
                        summary.totalCount
                    ),
                    iconName: "trophy.fill",
                    color: ColorTokens.Brand.gold
                )
            }
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Parent.surface)
        )
    }

    @ViewBuilder
    private func summaryStatCard(label: String, iconName: String, color: Color) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp2)
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("family.achievements.footer.note")
            .font(TypographyTokens.caption(11))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Parent.accent)
            )
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .task {
                try? await Task.sleep(for: .seconds(2.5))
                holder.showToast = false
            }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = FamilyAchievementsPresenter(displayLogic: holder)
            let interactor = FamilyAchievementsInteractor(
                familyId: familyId,
                childRepository: container.childRepository,
                sessionRepository: container.sessionRepository,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = FamilyAchievementsRouter(dismissAction: { dismiss() })
        }

        await interactor?.load(request: .init(familyId: familyId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("FamilyAchievements / loaded") {
    FamilyAchievementsView(familyId: "preview-family")
        .environment(AppContainer.preview())
}
#endif
