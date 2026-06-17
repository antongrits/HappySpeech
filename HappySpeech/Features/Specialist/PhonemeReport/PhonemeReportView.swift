import Charts
import SwiftUI

// MARK: - PhonemeReportDisplayLogic

@MainActor
protocol PhonemeReportDisplayLogic: AnyObject {
    func displayLoad(_ viewModel: PhonemeReportModels.Load.ViewModel)
}

// MARK: - PhonemeReportView
//
// A-09: Детальный пофонемный отчёт для специалиста — карта точности по
// целевым звукам ребёнка с историей по сессиям. Паритет SpeechLP-отчётов.
//
// ОХВАТ (честно): отчёт показывает звуки, которые РЕАЛЬНО присутствуют в
// плане коррекции ребёнка и/или истории сессий. Точность каждого звука —
// агрегат реальных `Session.successRate`; звук без сессий помечается «нет
// данных». Это не выдуманная карта из 42 IPA — это то, что реально измерено.

struct PhonemeReportView: View {

    let childId: String

    @Environment(AppContainer.self) private var container
    @Environment(\.exitToSpecialistHome) private var exitToSpecialistHome
    @Environment(\.hapticService) private var hapticService

    @State private var model = PhonemeReportDisplayModel()
    @State private var interactor: PhonemeReportInteractor?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(model.viewModel?.titleText ?? String(localized: "phonemeReport.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hapticService.impact(.light)
                        exitToSpecialistHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                guard interactor == nil else { return }
                let built = PhonemeReportRouter.makeInteractor(
                    container: container,
                    display: model
                )
                interactor = built
                await built.load(.init(childId: childId))
                isLoading = false
            }
        }
        .environment(\.circuitContext, .specialist)
        .accessibilityIdentifier("PhonemeReportRoot")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .controlSize(.large)
                .tint(ColorTokens.Spec.accent)
        } else if let vm = model.viewModel {
            if let errorText = vm.errorText {
                errorState(errorText)
            } else if vm.isEmpty {
                emptyState(passport: vm.passport)
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        header(vm)
                        if !vm.accuracyTimeline.isEmpty {
                            accuracyTimelineSection(vm)
                            summaryMetricsRow(vm)
                        }
                        legend
                        ForEach(vm.groups) { group in
                            groupSection(group)
                        }
                        if let passport = vm.passport {
                            passportSection(passport)
                        }
                        footnote
                        doneButton
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaPadding(.bottom)
            }
        }
    }

    // MARK: - Header

    private func header(_ vm: PhonemeReportModels.Load.ViewModel) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Spec.accent)
                    Text(vm.childNameText)
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                Text(vm.summaryText)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "checklist")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                    Text(vm.coverageText)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.accent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Accuracy Timeline (ДИНАМИКА ТОЧНОСТИ)

    /// Линейный чарт динамики точности по всем сессиям — аналог «ДИНАМИКА
    /// ТОЧНОСТИ» из дизайн-референса. Каждая точка = одна сессия.
    private func accuracyTimelineSection(
        _ vm: PhonemeReportModels.Load.ViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(String(localized: "phonemeReport.timeline.title",
                        defaultValue: "Динамика точности"))
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Spec.ink)
                .textCase(.uppercase)
                .tracking(0.5)
                .accessibilityAddTraits(.isHeader)

            HSCard(style: .elevated) {
                Chart(vm.accuracyTimeline) { point in
                    LineMark(
                        x: .value(String(localized: "phonemeReport.chart.date",
                                         defaultValue: "Дата"),
                                  point.date),
                        y: .value(String(localized: "phonemeReport.chart.accuracy",
                                         defaultValue: "Точность"),
                                  point.accuracy)
                    )
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value(String(localized: "phonemeReport.chart.date",
                                         defaultValue: "Дата"),
                                  point.date),
                        y: .value(String(localized: "phonemeReport.chart.accuracy",
                                         defaultValue: "Точность"),
                                  point.accuracy)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorTokens.Spec.accent.opacity(0.25),
                                     ColorTokens.Spec.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value(String(localized: "phonemeReport.chart.date",
                                         defaultValue: "Дата"),
                                  point.date),
                        y: .value(String(localized: "phonemeReport.chart.accuracy",
                                         defaultValue: "Точность"),
                                  point.accuracy)
                    )
                    .foregroundStyle(ColorTokens.Spec.accent)
                    .symbolSize(30)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0.0, 0.5, 1.0]) { value in
                        AxisGridLine()
                            .foregroundStyle(ColorTokens.Spec.grid.opacity(0.4))
                        AxisValueLabel {
                            if let pct = value.as(Double.self) {
                                Text("\(Int(pct * 100))%")
                                    .font(TypographyTokens.caption(10))
                                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                            .foregroundStyle(ColorTokens.Spec.grid.opacity(0.3))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                    }
                }
                .frame(height: 160)
                .accessibilityLabel(
                    String(localized: "phonemeReport.timeline.a11y",
                           defaultValue: "График динамики точности")
                )
            }
        }
    }

    // MARK: - Summary metrics row (X% · Y попыток · Z сессий)

    private func summaryMetricsRow(
        _ vm: PhonemeReportModels.Load.ViewModel
    ) -> some View {
        HSCard(style: .flat) {
            HStack(spacing: 0) {
                summaryMetric(
                    value: vm.avgAccuracyText,
                    label: String(localized: "phonemeReport.metric.accuracy",
                                  defaultValue: "Точность"),
                    tint: ColorTokens.Brand.gold
                )
                metricsDivider
                summaryMetric(
                    value: vm.totalAttemptsText,
                    label: String(localized: "phonemeReport.metric.attempts",
                                  defaultValue: "Попыток"),
                    tint: ColorTokens.Spec.accent
                )
                metricsDivider
                summaryMetric(
                    value: vm.totalSessionsText,
                    label: String(localized: "phonemeReport.metric.sessions",
                                  defaultValue: "Сессий"),
                    tint: ColorTokens.Brand.lilac
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryMetric(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Text(value)
                .font(TypographyTokens.headline(22).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var metricsDivider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(ColorTokens.Spec.line)
            .frame(width: 1, height: 40)
            .accessibilityHidden(true)
    }

    // MARK: - Legend (warm tones)

    private var legend: some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                legendItem(color: tone(.good), label: String(localized: "phonemeReport.legend.good"))
                legendItem(color: tone(.medium), label: String(localized: "phonemeReport.legend.medium"))
                legendItem(color: tone(.poor), label: String(localized: "phonemeReport.legend.poor"))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Group section

    private func groupSection(_ group: PhonemeReportGroupViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(group.subtitle)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, SpacingTokens.tiny)

            VStack(spacing: SpacingTokens.sp2) {
                ForEach(group.rows) { row in
                    phonemeRow(row)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Phoneme row

    private func phonemeRow(_ row: PhonemeRowViewModelA09) -> some View {
        HSCard(style: row.tone == nil ? .flat : .tinted(ColorTokens.Spec.surface)) {
            HStack(alignment: .center, spacing: SpacingTokens.sp3) {
                accuracyRing(row)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: SpacingTokens.sp2) {
                        Text(row.sound)
                            .font(TypographyTokens.title(22))
                            .foregroundStyle(ColorTokens.Spec.ink)
                        Text(row.accuracyText)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(row.tone.map(tone) ?? ColorTokens.Spec.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        if let trendText = row.trendText, let dir = row.trendDirection {
                            trendBadge(text: trendText, direction: dir)
                        }
                    }
                    if !row.detailText.isEmpty {
                        Text(row.detailText)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Spec.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    if let stageText = row.stageText {
                        Text(String(format: String(localized: "phonemeReport.row.stage %@"), stageText))
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Spec.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if row.history.count >= 2 {
                    sparkline(row.history, tone: row.tone)
                        .frame(width: 64, height: 36)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    // MARK: - Accuracy ring

    @ViewBuilder
    private func accuracyRing(_ row: PhonemeRowViewModelA09) -> some View {
        ZStack {
            Circle()
                .stroke(ColorTokens.Spec.line, lineWidth: 5)
                .frame(width: 46, height: 46)
            if let percent = row.accuracyPercent, let toneValue = row.tone {
                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100.0)
                    .stroke(
                        tone(toneValue),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 46, height: 46)
                Text("\(percent)")
                    .font(TypographyTokens.caption(13).weight(.bold))
                    .foregroundStyle(ColorTokens.Spec.ink)
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Trend badge

    private func trendBadge(text: String, direction: Int) -> some View {
        let symbol: String = direction > 0 ? "arrow.up.right"
            : (direction < 0 ? "arrow.down.right" : "arrow.right")
        let color: Color = direction > 0 ? ColorTokens.Brand.gold
            : (direction < 0 ? ColorTokens.Brand.rose : ColorTokens.Spec.inkMuted)
        return HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(TypographyTokens.caption(11))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.14)))
    }

    // MARK: - Sparkline (real history)

    private func sparkline(_ history: [HistoryPoint], tone toneValue: AccuracyTone?) -> some View {
        let color = toneValue.map(tone) ?? ColorTokens.Spec.accent
        return Chart(history) { point in
            LineMark(
                x: .value("date", point.date),
                y: .value("accuracy", point.accuracy)
            )
            .foregroundStyle(color)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("date", point.date),
                y: .value("accuracy", point.accuracy)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.28), color.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
    }

    // MARK: - Footnote (honesty about coverage)

    private var footnote: some View {
        HSCard(style: .flat) {
            HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                Image(systemName: "info.circle")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Text(String(localized: "phonemeReport.footnote"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Done button

    private var doneButton: some View {
        HSButton(
            String(localized: "phonemeReport.cta.done"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            exitToSpecialistHome()
        }
    }

    // MARK: - Empty / error states

    /// Экран-уровень empty (нет сессий). Если паспорт всё же содержит данные
    /// (были family-voice занятия с записью голоса), показываем его секцию —
    /// чтобы ценная GOP-аналитика не пряталась за «нет сессий».
    @ViewBuilder
    private func emptyState(passport: PhonemePassportViewModel?) -> some View {
        if let passport, !passport.isEmpty {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    sessionsEmptyCard
                    passportSection(passport)
                    footnote
                    doneButton
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaPadding(.bottom)
        } else {
            VStack(spacing: SpacingTokens.sp4) {
                sessionsEmptyCard
                doneButton
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp6)
        }
    }

    private var sessionsEmptyCard: some View {
        HSCard(style: .flat) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Text(String(localized: "phonemeReport.empty.title"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                Text(String(localized: "phonemeReport.empty.message"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp4)
        }
    }

    private func errorState(_ text: String) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            HSCard(style: .flat) {
                VStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(ColorTokens.Brand.rose)
                    Text(String(localized: "phonemeReport.error.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Spec.ink)
                        .multilineTextAlignment(.center)
                    Text(text)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.sp4)
            }
            doneButton
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp6)
    }

    // MARK: - Tone color (warm palette: gold/butter/rose)

    private func tone(_ tone: AccuracyTone) -> Color {
        switch tone {
        case .good:   return ColorTokens.Brand.gold
        case .medium: return ColorTokens.Brand.butter
        case .poor:   return ColorTokens.Brand.rose
        }
    }

    private func accessibilityLabel(for row: PhonemeRowViewModelA09) -> Text {
        var parts = [row.sound, row.accuracyText]
        if !row.detailText.isEmpty { parts.append(row.detailText) }
        if let trend = row.trendText { parts.append(trend) }
        if let stage = row.stageText { parts.append(stage) }
        return Text(parts.joined(separator: ", "))
    }
}

// MARK: - PhonemeReportDisplayModel

/// `@Observable` мост между VIP-презентером и SwiftUI-вью. Хранит готовую
/// ViewModel — никаких вычислений.
@MainActor
@Observable
final class PhonemeReportDisplayModel: PhonemeReportDisplayLogic {
    var viewModel: PhonemeReportModels.Load.ViewModel?

    func displayLoad(_ viewModel: PhonemeReportModels.Load.ViewModel) {
        self.viewModel = viewModel
    }
}

// MARK: - Preview

#Preview("PhonemeReport — Light") {
    PhonemeReportView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("PhonemeReport — Dark") {
    PhonemeReportView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
