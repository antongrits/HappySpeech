import Charts
import OSLog
import SwiftUI

// MARK: - PlainProgressViewModelHolder

@MainActor
@Observable
final class PlainProgressViewModelHolder: PlainProgressDisplayLogic {

    var loadVM: PlainProgressModels.Load.ViewModel?
    var errorMessage: String?
    var shareText: String?

    func displayLoad(viewModel: PlainProgressModels.Load.ViewModel) async {
        self.loadVM = viewModel
        self.errorMessage = nil
    }

    func displayLoadFailure(message: String) async {
        self.errorMessage = message
    }

    func displayShare(viewModel: PlainProgressModels.Share.ViewModel) async {
        self.shareText = viewModel.summaryText
    }
}

// MARK: - PlainProgressView (Clean Swift: View)
//
// v29 Фаза 8, Функция 9 «Понятный прогресс».
//
// Родительская аналитика человеческим языком:
//   1. Hero header (заголовок + подзаголовок с именем ребёнка)
//   2. Карточка-нарратив недели (главный блок) — на HSLiquidGlassCard
//   3. «Месяц назад / сейчас» — сравнение с прогресс-барами
//   4. Вехи прогресса — понятные достижения
//   5. Рекомендация «что делать дальше»
//   6. ShareLink — поделиться сводкой со специалистом
//
// Accessibility:
//   • VoiceOver: нарратив и вехи — комбинированные labels
//   • Dynamic Type: ScrollView root, .lineLimit(nil), minimumScaleFactor
//   • Reduced Motion: анимации появления гейтятся reduceMotion
//   • Light + Dark: ColorTokens.Parent адаптируются
//   • Touch targets: ShareLink ≥ 48pt

struct PlainProgressView: View {

    let childId: String

    @State private var holder = PlainProgressViewModelHolder()
    @State private var interactor: PlainProgressInteractor?
    @State private var presenter: PlainProgressPresenter?
    @State private var router: PlainProgressRouter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PlainProgress.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel)
                            narrativeSection(viewModel.narrative)
                                .hsScrollEffect(.scaleFade)
                            if let comparison = viewModel.comparison {
                                comparisonSection(comparison)
                                    .hsScrollEffect(.scaleFade)
                            }
                            milestonesSection(viewModel.milestones)
                                .hsScrollEffect(.scaleFade)
                            recommendationSection(viewModel)
                                .hsScrollEffect(.scaleFade)
                            shareSection(viewModel)
                        } else if let error = holder.errorMessage {
                            errorSection(error)
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.sp4)
                }
            }
            .navigationTitle(Text("plainProgress.screen.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text("plainProgress.close.a11y"))
                }
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Hero

    private func heroSection(_ viewModel: PlainProgressModels.Load.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(viewModel.headerTitle)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(viewModel.headerSubtitle)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
            }
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Narrative (main block)

    private func narrativeSection(
        _ narrative: PlainProgressModels.Load.NarrativeViewModel
    ) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: narrative.trendSymbol)
                        .font(.system(size: 30))
                        .foregroundStyle(trendColor(narrative.trendTint))
                        .accessibilityHidden(true)

                    Text(narrative.title)
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Text(narrative.body)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().overlay(ColorTokens.Parent.line)

                Text(narrative.metricsLine)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(narrative.title). \(narrative.body) \(narrative.metricsLine)"
        )
    }

    // MARK: - Comparison
    //
    // v31 Волна C Ф.3 — переписано с GeometryReader+Capsule на native Swift
    // Charts BarMark. Контракт Presenter'а сохранён (ComparisonViewModel),
    // только View рендерит через `Chart`. Dynamic Type и VoiceOver chart
    // descriptions подключаются автоматически.

    private struct ComparisonBar: Identifiable {
        let id: String
        let label: String
        let value: Double
        let displayValue: String
        let tint: Color
    }

    private func comparisonSection(
        _ comparison: PlainProgressModels.Load.ComparisonViewModel
    ) -> some View {
        let bars: [ComparisonBar] = [
            ComparisonBar(
                id: "monthAgo",
                label: comparison.monthAgoLabel,
                value: comparison.monthAgoFraction,
                displayValue: comparison.monthAgoValue,
                tint: ColorTokens.Parent.inkSoft
            ),
            ComparisonBar(
                id: "now",
                label: comparison.nowLabel,
                value: comparison.nowFraction,
                displayValue: comparison.nowValue,
                tint: ColorTokens.Brand.primary
            )
        ]
        let chartAccessibility =
            "\(comparison.title). " +
            "\(comparison.monthAgoLabel) \(comparison.monthAgoValue). " +
            "\(comparison.nowLabel) \(comparison.nowValue). " +
            "\(comparison.deltaText)"

        return VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(comparison.title)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            Chart(bars) { bar in
                BarMark(
                    x: .value("share", bar.value),
                    y: .value("group", bar.label),
                    height: .ratio(0.5)
                )
                .foregroundStyle(bar.tint)
                .annotation(position: .trailing, alignment: .center) {
                    Text(bar.displayValue)
                        .font(TypographyTokens.caption(12).weight(.semibold).monospacedDigit())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .cornerRadius(6)
            }
            .chartXScale(domain: 0...1)
            .chartXAxis {
                AxisMarks(values: [0, 0.5, 1]) { value in
                    AxisGridLine().foregroundStyle(ColorTokens.Parent.line)
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            Text(String(format: "%.0f%%", raw * 100))
                                .font(TypographyTokens.caption(11))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
            }
            .frame(minHeight: 96)

            Text(comparison.deltaText)
                .font(TypographyTokens.body(13).weight(.medium))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Parent.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chartAccessibility)
    }

    // MARK: - Milestones

    private func milestonesSection(
        _ milestones: [PlainProgressModels.Load.MilestoneViewModel]
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text("plainProgress.milestone.sectionTitle")
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)

            VStack(spacing: SpacingTokens.sp2) {
                ForEach(milestones) { milestone in
                    milestoneRow(milestone)
                }
            }
        }
    }

    private func milestoneRow(
        _ milestone: PlainProgressModels.Load.MilestoneViewModel
    ) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: milestone.symbolName)
                .font(.title3)
                .foregroundStyle(
                    milestone.reached
                        ? ColorTokens.Overlay.onAccent
                        : ColorTokens.Parent.inkSoft
                )
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(
                        milestone.reached
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Parent.bg
                    )
                )
                .accessibilityHidden(true)

            Text(milestone.title)
                .font(TypographyTokens.body(14).weight(.medium))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: milestone.reached ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(
                    milestone.reached
                        ? ColorTokens.Brand.mint
                        : ColorTokens.Parent.inkSoft
                )
                .accessibilityHidden(true)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(ColorTokens.Parent.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
        )
        .depthShadow(ShadowTokens.parentDepth)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(milestone.accessibilityLabel))
    }

    // MARK: - Recommendation

    private func recommendationSection(
        _ viewModel: PlainProgressModels.Load.ViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "lightbulb.fill")
                    .font(.body)
                    .foregroundStyle(ColorTokens.Brand.butter)
                    .accessibilityHidden(true)
                Text(viewModel.recommendationTitle)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Parent.ink)
            }

            Text(viewModel.recommendationText)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Brand.butter.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(viewModel.recommendationTitle). \(viewModel.recommendationText)"
        )
    }

    // MARK: - Share

    private func shareSection(
        _ viewModel: PlainProgressModels.Load.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            if let shareText = holder.shareText {
                ShareLink(item: shareText) {
                    Label {
                        Text(viewModel.shareButtonTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(Text("plainProgress.share.hint"))
            } else {
                Button {
                    Task { await prepareShare() }
                } label: {
                    Label {
                        Text(viewModel.shareButtonTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(Text("plainProgress.share.hint"))
            }
        }
    }

    // MARK: - Loading / error

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("plainProgress.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .accessibilityHidden(true)
            Text(message)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private func trendColor(_ tint: TrendTint) -> Color {
        switch tint {
        case .positive:  return ColorTokens.Brand.mint
        case .neutral:   return ColorTokens.Brand.sky
        case .attention: return ColorTokens.Brand.butter
        }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = PlainProgressPresenter(displayLogic: holder)
            let worker = PlainProgressWorker(
                childRepository: container.childRepository,
                sessionRepository: container.sessionRepository
            )
            let interactor = PlainProgressInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = PlainProgressRouter(dismissAction: { dismiss() })
        }
        await interactor?.load(request: .init(childId: childId))
    }

    private func prepareShare() async {
        await interactor?.share(request: .init())
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PlainProgress / loaded") {
    PlainProgressView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
