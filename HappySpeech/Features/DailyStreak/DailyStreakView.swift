import OSLog
import SwiftUI

// MARK: - DailyStreakDisplayLogic

@MainActor
protocol DailyStreakDisplayLogic: AnyObject {
    func displayLoad(viewModel: DailyStreakModels.Load.ViewModel) async
    func displayCheckIn(viewModel: DailyStreakModels.CheckIn.ViewModel) async
    func displayUseSaver(viewModel: DailyStreakModels.UseSaver.ViewModel) async
}

// MARK: - DailyStreakViewModel

@MainActor
@Observable
final class DailyStreakViewModelHolder: DailyStreakDisplayLogic {

    var loadVM: DailyStreakModels.Load.ViewModel?
    var checkInVM: DailyStreakModels.CheckIn.ViewModel?
    var saverVM: DailyStreakModels.UseSaver.ViewModel?
    var showToast: Bool = false

    func displayLoad(viewModel: DailyStreakModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayCheckIn(viewModel: DailyStreakModels.CheckIn.ViewModel) async {
        self.checkInVM = viewModel
        self.showToast = true
    }

    func displayUseSaver(viewModel: DailyStreakModels.UseSaver.ViewModel) async {
        self.saverVM = viewModel
        self.showToast = true
    }
}

// MARK: - DailyStreakView (Clean Swift: View)
//
// Block S.1 v16 — экран Daily Streak Rewards.
//
// Layout (sheet, presentationDetent .medium / .large):
//   1. Hero header — большое число дней + статус
//   2. Progress bar до следующего milestone
//   3. Milestones grid (3×2): иконка + дни + lock state
//   4. Streak Saver button (раз в месяц)
//   5. Longest streak badge
//
// Accessibility:
//   • VoiceOver: каждый milestone-row имеет label "<title>, <days> дней,
//     <получен/закрыт>"
//   • Dynamic Type: scaledFont, lineLimit(nil)
//   • Reduced Motion: убираем pulse у flame

struct DailyStreakView: View {

    let childId: String
    let childName: String

    @State private var holder = DailyStreakViewModelHolder()
    @State private var interactor: DailyStreakInteractor?
    @State private var presenter: DailyStreakPresenter?
    @State private var router: DailyStreakRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "DailyStreak.View")

    init(childId: String, childName: String) {
        self.childId = childId
        self.childName = childName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.sp5) {
                    if let viewModel = holder.loadVM {
                        heroSection(viewModel: viewModel)
                        progressSection(viewModel: viewModel)
                        milestonesGrid(viewModel: viewModel)
                        saverSection(viewModel: viewModel)
                        longestSection(viewModel: viewModel)
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .padding(.top, SpacingTokens.sp10)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.sp4)
            }
            .background(ColorTokens.Kid.bg.ignoresSafeArea())
            .navigationTitle(Text("streak.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("streak.close.a11y"))
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast,
                   let toast = holder.checkInVM?.toastMessage ?? holder.saverVM?.bannerMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: holder.showToast)
        }
        .task {
            await setupAndLoad()
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(viewModel: DailyStreakModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(viewModel.statusEmoji)
                .font(.system(size: 64))
                .accessibilityHidden(true)

            Text(verbatim: "\(viewModel.currentStreak)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(ColorTokens.Brand.primary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .spring(duration: 0.45), value: viewModel.currentStreak)

            Text(String(format: String(localized: "streak.days.unit"), viewModel.currentStreak))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)

            Text(viewModel.statusLabel)
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp5)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorTokens.Kid.surface)
                .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(
            format: String(localized: "streak.hero.a11y"),
            viewModel.currentStreak,
            viewModel.statusLabel
        )))
    }

    // MARK: - Progress

    @ViewBuilder
    private func progressSection(viewModel: DailyStreakModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            if let nextTitle = viewModel.nextMilestoneTitle,
               let nextDays = viewModel.nextMilestoneDays {
                Text(String(format: String(localized: "streak.next.label"), nextTitle, nextDays))
                    .font(TypographyTokens.callout())
                    .foregroundStyle(ColorTokens.Kid.ink)

                ProgressView(value: viewModel.progressToNext)
                    .tint(ColorTokens.Brand.primary)
                    .progressViewStyle(.linear)
                    .accessibilityLabel(Text("streak.progress.a11y"))
                    .accessibilityValue(Text("\(Int(viewModel.progressToNext * 100))%"))
            } else {
                Text("streak.next.completed")
                    .font(TypographyTokens.callout())
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
    }

    // MARK: - Milestones grid

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: SpacingTokens.sp3),
        GridItem(.flexible(), spacing: SpacingTokens.sp3),
        GridItem(.flexible(), spacing: SpacingTokens.sp3)
    ]

    @ViewBuilder
    private func milestonesGrid(viewModel: DailyStreakModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            HStack {
                Text("streak.milestones.title")
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Kid.ink)
                Spacer()
                Text(verbatim: "\(viewModel.unlockedCount)/\(viewModel.totalMilestones)")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }

            LazyVGrid(columns: gridColumns, spacing: SpacingTokens.sp3) {
                ForEach(viewModel.milestones) { row in
                    milestoneCard(row: row)
                }
            }
        }
    }

    @ViewBuilder
    private func milestoneCard(row: DailyStreakModels.Load.MilestoneRow) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: row.symbolName)
                .font(.title)
                .foregroundStyle(row.isUnlocked
                                 ? ColorTokens.Brand.gold
                                 : ColorTokens.Kid.inkSoft.opacity(0.4))
                .frame(height: 36)

            Text(verbatim: "\(row.days)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(row.isUnlocked ? ColorTokens.Kid.ink : ColorTokens.Kid.inkMuted)

            Text("streak.days.short")
                .font(.caption2)
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(row.isUnlocked ? ColorTokens.Kid.surface : ColorTokens.Kid.surfaceAlt)
                .opacity(row.isUnlocked ? 1.0 : 0.6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.accessibilityLabel))
        .accessibilityAddTraits(row.isUnlocked ? .isStaticText : [])
    }

    // MARK: - Saver

    @ViewBuilder
    private func saverSection(viewModel: DailyStreakModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "lifepreserver")
                    .font(.title2)
                    .foregroundStyle(viewModel.saverAvailable
                                     ? ColorTokens.Brand.sky
                                     : ColorTokens.Kid.inkSoft)
                    .accessibilityHidden(true)
                Text("streak.saver.title")
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Kid.ink)
            }

            Text(viewModel.saverHintLabel)
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)

            Button {
                Task { await useSaver() }
            } label: {
                Text("streak.saver.cta")
                    .font(TypographyTokens.cta())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ColorTokens.Brand.sky)
            .disabled(!viewModel.saverAvailable)
            .accessibilityHint(Text("streak.saver.cta.hint"))
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(ColorTokens.Kid.surface)
        )
    }

    // MARK: - Longest

    @ViewBuilder
    private func longestSection(viewModel: DailyStreakModels.Load.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "rosette")
                .font(.title2)
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("streak.longest.title")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Text(String(format: String(localized: "streak.longest.value"), viewModel.longestStreak))
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            Spacer()
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption())
            .foregroundStyle(.white)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Brand.primary)
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
            let presenter = DailyStreakPresenter(displayLogic: holder)
            let interactor = DailyStreakInteractor(
                childId: childId,
                notificationService: container.notificationService,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = DailyStreakRouter(dismissAction: { dismiss() })
        }

        await interactor?.load(request: .init(childId: childId))
        await interactor?.checkIn(request: .init(childId: childId, now: Date()))
        await interactor?.scheduleReminderIfNeeded(childName: childName)
        // Перезагружаем после check-in чтобы UI обновился
        await interactor?.load(request: .init(childId: childId))
    }

    private func useSaver() async {
        await interactor?.useSaver(request: .init(childId: childId, now: Date()))
        await interactor?.load(request: .init(childId: childId))
    }
}

// NOTE deferred to Block Q (test coverage): snapshot tests for DailyStreakView
// in light + dark, Dynamic Type axL, broken state, all-milestones-unlocked.

#if DEBUG
#Preview("DailyStreak / loaded") {
    DailyStreakView(childId: "preview-child", childName: "Маша")
        .environment(AppContainer.preview())
}
#endif
