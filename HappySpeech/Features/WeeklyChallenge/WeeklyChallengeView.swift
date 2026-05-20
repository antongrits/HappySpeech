import OSLog
import SwiftUI

// MARK: - WeeklyChallengeViewModelHolder

@MainActor
@Observable
final class WeeklyChallengeViewModelHolder: WeeklyChallengeDisplayLogic {

    var loadVM: WeeklyChallengeModels.Load.ViewModel?
    var markDayVM: WeeklyChallengeModels.MarkDay.ViewModel?
    var switchKindVM: WeeklyChallengeModels.SwitchKind.ViewModel?
    var showToast: Bool = false
    var showRewardBurst: Bool = false

    func displayLoad(viewModel: WeeklyChallengeModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayMarkDay(viewModel: WeeklyChallengeModels.MarkDay.ViewModel) async {
        self.markDayVM = viewModel
        self.showToast = true
        if viewModel.celebrate {
            self.showRewardBurst = true
        }
    }

    func displaySwitchKind(viewModel: WeeklyChallengeModels.SwitchKind.ViewModel) async {
        self.switchKindVM = viewModel
        self.showToast = true
    }
}

// MARK: - WeeklyChallengeView (Clean Swift: View)
//
// Block R.3 v18 — экран еженедельных челленджей.
//
// Layout (sheet, presentationDetent .large):
//   1. Hero header — текущий челлендж + symbol + завершённость
//   2. Progress ring + percent label
//   3. 7-day grid — Пн-Вс с состоянием
//   4. Reward unlock card (special sticker/badge)
//   5. Switch challenge kind picker (если не completed)
//
// Accessibility:
//   • VoiceOver: каждая ячейка дня = «<день>: <состояние>»
//   • Dynamic Type: scaledFont, lineLimit(nil)
//   • Reduced Motion: убираем reward-burst анимацию
//   • Touch targets: ячейки дней = 44x44, segmented picker = 56pt

struct WeeklyChallengeView: View {

    let childId: String

    @State private var holder = WeeklyChallengeViewModelHolder()
    @State private var interactor: WeeklyChallengeInteractor?
    @State private var presenter: WeeklyChallengePresenter?
    @State private var router: WeeklyChallengeRouter?
    @State private var pickerSelection: WeeklyChallengeKind = .soundStreak

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "WeeklyChallenge.View")

    init(childId: String) {
        self.childId = childId
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel: viewModel)
                            progressSection(viewModel: viewModel)
                            weekGridSection(viewModel: viewModel)
                            rewardSection(viewModel: viewModel)
                            kindPickerSection(viewModel: viewModel)
                            footerSection
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }

                if holder.showRewardBurst {
                    rewardBurstOverlay
                        .accessibilityHidden(true)
                }
            }
            .navigationTitle(Text("weekly.screen.title"))
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
                    .accessibilityLabel(Text("weekly.close.a11y"))
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast,
                   let toast = holder.markDayVM?.toastMessage ?? holder.switchKindVM?.toastMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.4), value: holder.showToast)
        }
        .environment(\.circuitContext, .kid)
        .task {
            await setupAndLoad()
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            // E v21: 3D Ляля в loading state WeeklyChallenge.
            LyalyaHeroView(state: .happy, size: 110)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
        }
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(viewModel: WeeklyChallengeModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            // E v21: 3D Ляля hero на WeeklyChallenge (требование пользователя).
            LyalyaHeroView(state: .celebrating, size: 160)
                .frame(height: 160)
                .accessibilityHidden(true)

            Text(viewModel.challengeTitle)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(viewModel.challengeDescription)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp4)

            Text(viewModel.endOfWeekLabel)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.top, SpacingTokens.sp1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp5)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .depthShadow(ShadowTokens.kidDepth)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(
            format: String(localized: "weekly.hero.a11y"),
            viewModel.challengeTitle,
            viewModel.progressLabel
        )))
    }

    // MARK: - Progress

    @ViewBuilder
    private func progressSection(viewModel: WeeklyChallengeModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("weekly.progress.title")
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(viewModel.progressLabel)
                        .font(TypographyTokens.title(28))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .spring(duration: 0.45), value: viewModel.progress)
                }
                Spacer()
                HSProgressRing(
                    value: viewModel.progress,
                    size: 64,
                    lineWidth: 8,
                    color: viewModel.isCompleted
                        ? ColorTokens.Semantic.success
                        : ColorTokens.Brand.primary,
                    label: viewModel.progressPercentLabel
                )
                .accessibilityLabel(Text("weekly.progress.a11y"))
                .accessibilityValue(Text(viewModel.progressPercentLabel))
            }
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
    }

    // MARK: - Week grid

    private let weekColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2),
        count: 7
    )

    @ViewBuilder
    private func weekGridSection(viewModel: WeeklyChallengeModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("weekly.grid.title")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.leading, SpacingTokens.sp1)

            LazyVGrid(columns: weekColumns, spacing: SpacingTokens.sp2) {
                ForEach(viewModel.dayCells) { cell in
                    dayCell(cell)
                }
            }
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Kid.surface)
            )
        }
    }

    @ViewBuilder
    private func dayCell(_ cell: WeeklyChallengeModels.Load.DayCellViewModel) -> some View {
        Button {
            // Markdown toggle: только pending → completed (если не в будущем).
            if cell.progress == .pending {
                Task { await markDay(idx: cell.id) }
            }
        } label: {
            VStack(spacing: 4) {
                Text(cell.dayLabel)
                    .font(TypographyTokens.caption(11).weight(.medium))
                    .foregroundStyle(dayLabelColor(for: cell.progress))

                Image(systemName: cell.symbolName)
                    .font(.title3)
                    .foregroundStyle(daySymbolColor(for: cell.progress))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(dayBackground(for: cell.progress))
            )
        }
        .buttonStyle(.plain)
        .disabled(cell.progress != .pending)
        .accessibilityLabel(Text(cell.accessibilityLabel))
        .accessibilityHint(
            cell.progress == .pending
                ? Text("weekly.day.tap.hint")
                : Text("")
        )
    }

    private func dayLabelColor(for progress: DayProgress) -> Color {
        switch progress {
        case .completed: return ColorTokens.Semantic.success
        case .missed:    return ColorTokens.Kid.inkMuted
        case .locked:    return ColorTokens.Kid.inkSoft.opacity(0.5)
        case .pending:   return ColorTokens.Brand.primary
        }
    }

    private func daySymbolColor(for progress: DayProgress) -> Color {
        switch progress {
        case .completed: return ColorTokens.Semantic.success
        case .missed:    return ColorTokens.Kid.inkMuted
        case .locked:    return ColorTokens.Kid.inkSoft.opacity(0.5)
        case .pending:   return ColorTokens.Brand.primary
        }
    }

    private func dayBackground(for progress: DayProgress) -> Color {
        switch progress {
        case .completed: return ColorTokens.Semantic.success.opacity(0.12)
        case .missed:    return ColorTokens.Kid.bgDeep
        case .locked:    return ColorTokens.Kid.bgDeep.opacity(0.5)
        case .pending:   return ColorTokens.Brand.primary.opacity(0.12)
        }
    }

    // MARK: - Reward

    @ViewBuilder
    private func rewardSection(viewModel: WeeklyChallengeModels.Load.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: viewModel.rewardSymbol)
                .font(.system(size: 36))
                .foregroundStyle(
                    viewModel.rewardUnlocked
                        ? ColorTokens.Brand.gold
                        : ColorTokens.Kid.inkSoft.opacity(0.4)
                )
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            viewModel.rewardUnlocked
                                ? ColorTokens.Brand.gold.opacity(0.15)
                                : ColorTokens.Kid.bgDeep
                        )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.rewardUnlocked
                     ? String(localized: "weekly.reward.unlocked.label")
                     : String(localized: "weekly.reward.locked.label"))
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(viewModel.rewardTitle)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(
                    viewModel.rewardUnlocked
                        ? ColorTokens.Brand.gold.opacity(0.08)
                        : ColorTokens.Kid.surfaceAlt
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(
            format: String(localized: "weekly.reward.a11y"),
            viewModel.rewardTitle,
            viewModel.rewardUnlocked
                ? String(localized: "weekly.reward.unlocked.label")
                : String(localized: "weekly.reward.locked.label")
        )))
    }

    // MARK: - Kind picker

    @ViewBuilder
    private func kindPickerSection(viewModel: WeeklyChallengeModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text("weekly.kindPicker.title")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text("weekly.kindPicker.subtitle")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)

            VStack(spacing: SpacingTokens.sp2) {
                ForEach(WeeklyChallengeKind.allCases, id: \.self) { kind in
                    kindRow(kind: kind)
                }
            }
        }
        .padding(.top, SpacingTokens.sp2)
    }

    @ViewBuilder
    private func kindRow(kind: WeeklyChallengeKind) -> some View {
        let isCurrent = pickerSelection == kind
        Button {
            Task { await switchKind(to: kind) }
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: kind.symbolName)
                    .font(.title3)
                    .foregroundStyle(
                        isCurrent ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                isCurrent
                                    ? ColorTokens.Brand.primary.opacity(0.15)
                                    : ColorTokens.Kid.bgDeep
                            )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: String.LocalizationValue(kind.titleKey)))
                        .font(TypographyTokens.body(14).weight(.medium))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: String.LocalizationValue(kind.descriptionKey)))
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(SpacingTokens.sp3)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .strokeBorder(
                        isCurrent ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                        lineWidth: isCurrent ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("weekly.footer.note")
            .font(TypographyTokens.caption(11))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Reward burst overlay

    private var rewardBurstOverlay: some View {
        ZStack {
            // 3.H v23: ранее использовался невидимый hit-target через
            // hardcoded цвет с opacity 0.001. Заменено на Color.clear +
            // contentShape — тот же эффект без нарушения design tokens rule.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
            HSRewardBurst(isShowing: holder.showRewardBurst)
                .task {
                    try? await Task.sleep(for: .seconds(2.0))
                    holder.showRewardBurst = false
                }
        }
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
                Capsule().fill(ColorTokens.Brand.primary)
            )
            .depthShadow(ShadowTokens.kidDepth)
            .task {
                try? await Task.sleep(for: .seconds(2.5))
                holder.showToast = false
            }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = WeeklyChallengePresenter(displayLogic: holder)
            let interactor = WeeklyChallengeInteractor(
                childId: childId,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = WeeklyChallengeRouter(dismissAction: { dismiss() })
        }

        await interactor?.load(request: .init(childId: childId, now: Date()))
        if let kindRaw = holder.loadVM?.symbolName,
           let firstKind = WeeklyChallengeKind.allCases.first(where: { $0.symbolName == kindRaw }) {
            pickerSelection = firstKind
        }
    }

    private func markDay(idx: Int) async {
        await interactor?.markDay(request: .init(
            childId: childId,
            dayIndex: idx,
            now: Date()
        ))
        await interactor?.load(request: .init(childId: childId, now: Date()))
    }

    private func switchKind(to kind: WeeklyChallengeKind) async {
        pickerSelection = kind
        await interactor?.switchKind(request: .init(
            childId: childId,
            kind: kind,
            now: Date()
        ))
        await interactor?.load(request: .init(childId: childId, now: Date()))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WeeklyChallenge / loaded") {
    WeeklyChallengeView(childId: "preview-child")
        .environment(AppContainer.preview())
}
#endif
