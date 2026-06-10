import OSLog
import SwiftUI

// MARK: - WeeklySoundReportViewModelHolder

@MainActor
@Observable
final class WeeklySoundReportViewModelHolder: WeeklySoundReportDisplayLogic {

    var loadVM: WeeklySoundReportModels.Load.ViewModel?
    var selectedDetail: WeeklySoundReportModels.SelectSound.ViewModel?
    var shareText: String?
    var loadFailed: Bool = false

    func displayLoad(viewModel: WeeklySoundReportModels.Load.ViewModel) async {
        self.loadFailed = false
        self.loadVM = viewModel
    }

    func displayLoadFailure() async {
        self.loadFailed = true
    }

    func displaySelectSound(viewModel: WeeklySoundReportModels.SelectSound.ViewModel) async {
        self.selectedDetail = viewModel
    }

    func displayShare(viewModel: WeeklySoundReportModels.Share.ViewModel) async {
        self.shareText = viewModel.shareText
    }
}

// MARK: - WeeklySoundReportView (Clean Swift: View)
//
// F-301 v25 — экран «Итоги недели» для родителя.
//
// Layout:
//   1. Шапка с навигацией по неделям (‹ Прошлая / Следующая ›)
//   2. Summary-блок (Ляля + строка резюме + прогресс занятых дней)
//   3. Карточки целевых звуков с прогресс-кольцом и трендом
//   4. ShareLink «Поделиться отчётом»
//
// Accessibility:
//   • VoiceOver: progressRing → «Успешность звука Ш: 78%».
//   • Dynamic Type: ScrollView + minimumScaleFactor.
//   • Reduced Motion: убираем анимацию раскрытия карточки.

struct WeeklySoundReportView: View {

    let childId: String
    let initialWeekOffset: Int

    @State private var holder = WeeklySoundReportViewModelHolder()
    @State private var interactor: WeeklySoundReportInteractor?
    @State private var presenter: WeeklySoundReportPresenter?
    @State private var router: WeeklySoundReportRouter?
    @State private var expandedSoundId: String?
    @State private var currentWeekOffset: Int

    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    init(childId: String, weekOffset: Int = 0) {
        self.childId = childId
        self.initialWeekOffset = weekOffset
        self._currentWeekOffset = State(initialValue: weekOffset)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            weekNavigator(viewModel: viewModel)
                            summaryCard(viewModel: viewModel)
                            if viewModel.sounds.isEmpty {
                                emptyState
                            } else {
                                soundsList(viewModel.sounds)
                            }
                            shareSection(viewModel: viewModel)
                        } else if holder.loadFailed {
                            failureState
                        } else {
                            loadingState
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("weeklyReport.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToParentHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("weeklyReport.close.a11y"))
                }
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Week navigator

    @ViewBuilder
    private func weekNavigator(viewModel: WeeklySoundReportModels.Load.ViewModel) -> some View {
        HSCard(style: .flat, padding: SpacingTokens.sp3) {
            HStack {
                Button {
                    Task { await changeWeek(to: currentWeekOffset - 1) }
                } label: {
                    HStack(spacing: SpacingTokens.sp1) {
                        Image(systemName: "chevron.left")
                            .font(TypographyTokens.caption(13).weight(.semibold))
                        Text("weeklyReport.nav.previous")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Brand.primary)
                }
                .frame(minHeight: 44)
                .accessibilityLabel(Text("weeklyReport.nav.previous.a11y"))

                Spacer()

                VStack(spacing: SpacingTokens.micro) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .accessibilityHidden(true)
                    Text(viewModel.dateRangeLabel)
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Button {
                    Task { await changeWeek(to: currentWeekOffset + 1) }
                } label: {
                    HStack(spacing: SpacingTokens.sp1) {
                        Text("weeklyReport.nav.next")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.right")
                            .font(TypographyTokens.caption(13).weight(.semibold))
                    }
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(
                        viewModel.canGoNext
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Parent.inkMuted
                    )
                }
                .frame(minHeight: 44)
                .disabled(!viewModel.canGoNext)
                .accessibilityLabel(Text("weeklyReport.nav.next.a11y"))
            }
        }
    }

    // MARK: - Summary card

    @ViewBuilder
    private func summaryCard(viewModel: WeeklySoundReportModels.Load.ViewModel) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                    HSMascotView(mood: .happy, size: 64)
                        .accessibilityHidden(true)

                    Text(viewModel.summaryLine)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(
                        String(
                            format: String(localized: "weeklyReport.activeDays.label"),
                            viewModel.activeDays
                        )
                    )
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)

                    HSProgressBar(
                        value: viewModel.activeDaysProgress,
                        style: .parent,
                        tint: ColorTokens.Brand.mint
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sounds list

    @ViewBuilder
    private func soundsList(_ sounds: [SoundCardViewModel]) -> some View {
        let total = sounds.count
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.85)
        let animation: Animation = reduceMotion ? .linear(duration: 0) : spring
        ForEach(Array(sounds.enumerated()), id: \.element.id) { index, card in
            soundCard(card)
                .scrollTransition(.animated(animation)) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                }
                .zIndex(Double(total - index))
        }
    }

    // MARK: - Sound card

    @ViewBuilder
    private func soundCard(_ card: SoundCardViewModel) -> some View {
        let isExpanded = expandedSoundId == card.id
        let accentColor = soundFamilyColor(for: card.id)
        HSCard(style: .elevated) {
            HStack(spacing: 0) {
                // Left accent border — colour-coded by sound family
                RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 4)
                    .padding(.vertical, SpacingTokens.sp1)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                    Button {
                        Task { await toggleSound(card) }
                    } label: {
                        HStack(spacing: SpacingTokens.sp3) {
                            HSProgressRing(
                                value: card.successRate,
                                size: 56,
                                lineWidth: 7,
                                color: ringColor(for: card.successRate)
                            )
                            .accessibilityLabel(
                                Text(
                                    String(
                                        format: String(localized: "weeklyReport.ring.a11y"),
                                        card.id,
                                        Int((card.successRate * 100).rounded())
                                    )
                                )
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.soundLabel)
                                    .font(TypographyTokens.headline(17))
                                    .foregroundStyle(ColorTokens.Parent.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text(
                                    String.localizedStringWithFormat(
                                        String(localized: "weeklyReport.sound.sessions"),
                                        card.sessionCount
                                    )
                                )
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }

                            Spacer()

                            VStack(spacing: SpacingTokens.sp1) {
                                Image(systemName: card.trendArrow.symbolName)
                                    .font(TypographyTokens.headline(16).weight(.bold))
                                    .foregroundStyle(trendColor(card.trendArrow))
                                    .hsSymbolEffect(.bounce, value: card.successRate)
                                    .accessibilityLabel(Text(trendA11y(card.trendArrow)))

                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(Text("weeklyReport.card.expand.hint"))

                    if isExpanded, let detail = holder.selectedDetail, detail.soundTarget == card.id {
                        expandedDetail(detail)
                    }
                }
                .padding(.leading, SpacingTokens.sp3)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: isExpanded)
    }

    @ViewBuilder
    private func expandedDetail(_ detail: WeeklySoundReportModels.SelectSound.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Divider()

            if detail.topWordsFormatted.isEmpty && detail.weakWordsFormatted.isEmpty {
                Text("weeklyReport.detail.noWords")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }

            if !detail.topWordsFormatted.isEmpty {
                wordsBlock(
                    titleKey: "weeklyReport.detail.topWords",
                    words: detail.topWordsFormatted,
                    tint: ColorTokens.Brand.gold
                )
            }

            if !detail.weakWordsFormatted.isEmpty {
                wordsBlock(
                    titleKey: "weeklyReport.detail.weakWords",
                    words: detail.weakWordsFormatted,
                    tint: ColorTokens.Semantic.warning
                )
            }

            HSCard(style: .gradientTinted(GradientTokens.cardGold), padding: SpacingTokens.sp3) {
                HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.butter.opacity(0.20))
                            .frame(width: 28, height: 28)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.Brand.butter)
                            .hsSymbolEffect(.variableColor, value: detail.tipText)
                    }
                    .accessibilityHidden(true)

                    Text(detail.tipText)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func wordsBlock(titleKey: String, words: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text(LocalizedStringKey(titleKey))
                .font(TypographyTokens.caption(11))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(ColorTokens.Parent.inkMuted)

            ForEach(words, id: \.self) { word in
                HStack(spacing: SpacingTokens.sp2) {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(word)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
        }
    }

    // MARK: - Share

    @ViewBuilder
    private func shareSection(viewModel: WeeklySoundReportModels.Load.ViewModel) -> some View {
        if let text = holder.shareText {
            ShareLink(item: text) {
                Label {
                    Text("weeklyReport.share.button")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
                .font(TypographyTokens.cta())
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(ColorTokens.Brand.primary)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.button)
                        .strokeBorder(ColorTokens.Brand.primary, lineWidth: 1.5)
                )
            }
            .padding(.top, SpacingTokens.sp2)
            .accessibilityLabel(Text("weeklyReport.share.button.a11y"))
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("weeklyReport.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    private var failureState: some View {
        HSEmptyStateView(
            icon: "exclamationmark.triangle",
            title: String(localized: "weeklyReport.error.title"),
            message: String(localized: "weeklyReport.error.message"),
            action: { Task { await reload() } },
            actionTitle: String(localized: "weeklyReport.error.retry")
        )
        .padding(.top, SpacingTokens.sp8)
    }

    private var emptyState: some View {
        HSEmptyStateView(
            icon: "calendar.badge.exclamationmark",
            title: String(localized: "weeklyReport.empty.title"),
            message: String(localized: "weeklyReport.empty.message")
        )
        .padding(.vertical, SpacingTokens.sp8)
    }

    // MARK: - Color helpers

    /// Maps a target sound letter to its sound-family accent colour.
    private func soundFamilyColor(for sound: String) -> Color {
        let hissing = ["Ш", "Ж", "Ч", "Щ"]
        let whistling = ["С", "З", "Ц"]
        let sonorant = ["Р", "Рь", "Л", "Ль"]
        if hissing.contains(sound) { return ColorTokens.SoundFamilyColors.Hissing.hue }
        if whistling.contains(sound) { return ColorTokens.SoundFamilyColors.Whistling.hue }
        if sonorant.contains(sound) { return ColorTokens.SoundFamilyColors.Sonorant.hue }
        return ColorTokens.SoundFamilyColors.Velar.hue
    }

    private func ringColor(for rate: Double) -> Color {
        switch rate {
        case 0.8...:    return ColorTokens.Brand.gold
        case 0.5..<0.8: return ColorTokens.Semantic.warning
        default:        return ColorTokens.Brand.rose
        }
    }

    private func trendColor(_ trend: TrendArrow) -> Color {
        switch trend {
        case .up:     return ColorTokens.Brand.gold
        case .stable: return ColorTokens.Parent.inkMuted
        case .down:   return ColorTokens.Brand.rose
        }
    }

    private func trendA11y(_ trend: TrendArrow) -> String {
        switch trend {
        case .up:     return String(localized: "weeklyReport.trend.up.a11y")
        case .stable: return String(localized: "weeklyReport.trend.stable.a11y")
        case .down:   return String(localized: "weeklyReport.trend.down.a11y")
        }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = WeeklySoundReportPresenter(displayLogic: holder)
            let worker = WeeklySoundReportWorker(
                sessionRepository: container.sessionRepository,
                childRepository: container.childRepository
            )
            let interactor = WeeklySoundReportInteractor(
                childId: childId,
                weekOffset: currentWeekOffset,
                worker: worker,
                analyticsService: container.analyticsService,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = WeeklySoundReportRouter(dismissAction: { exitToParentHome() })
        }
        await reload()
    }

    private func reload() async {
        holder.loadVM = nil
        holder.loadFailed = false
        await interactor?.load(request: .init(childId: childId, weekOffset: currentWeekOffset))
        await interactor?.shareReport(request: .init())
    }

    private func changeWeek(to offset: Int) async {
        guard offset <= 0 else { return }
        currentWeekOffset = offset
        expandedSoundId = nil
        holder.selectedDetail = nil
        await reload()
    }

    private func toggleSound(_ card: SoundCardViewModel) async {
        if expandedSoundId == card.id {
            expandedSoundId = nil
            return
        }
        expandedSoundId = card.id
        await interactor?.selectSound(request: .init(soundTarget: card.id))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WeeklySoundReport") {
    WeeklySoundReportView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
