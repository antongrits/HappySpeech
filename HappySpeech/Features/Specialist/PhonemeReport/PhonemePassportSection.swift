import Charts
import SwiftUI
import UniformTypeIdentifiers

// MARK: - PhonemePassportSection
//
// Секция «Фонемный паспорт» (GOP-анализ) экрана PhonemeReport. Визуально
// согласована с основным отчётом: те же токены (Spec.*, тёплая палитра Brand),
// HSCard/HSLiquidGlassCard, симметричные отступы, .minimumScaleFactor и
// .lineLimit(nil) — без обрезки текста, влезает на SE 375pt.
//
// Состоит из: компактной матрицы «фонема × позиция», sparkline-динамики GOP по
// слабейшим фонемам, прогноза освоения с CI-полосой и бейджем консультации,
// CSV-экспорта (ShareLink) и дружелюбного empty-state.

extension PhonemeReportView {

    // MARK: - Section root

    @ViewBuilder
    func passportSection(_ passport: PhonemePassportViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            passportSectionHeader(passport)

            if passport.isEmpty {
                passportEmptyCard(passport)
            } else {
                passportMatrixCard(passport)
                if !passport.trends.isEmpty {
                    passportTrendsCard(passport)
                }
                if !passport.forecasts.isEmpty {
                    passportForecastCard(passport)
                }
                passportDisclaimer(passport)
                passportExportButton(passport)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private func passportSectionHeader(_ passport: PhonemePassportViewModel) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.Spec.accent)
                Text(passport.titleText)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            if !passport.subtitleText.isEmpty {
                Text(passport.subtitleText)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, SpacingTokens.tiny)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Matrix card (фонема × позиция)

    private func passportMatrixCard(_ passport: PhonemePassportViewModel) -> some View {
        HSLiquidGlassCard(style: .primary) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                passportMatrixHeaderRow(passport.columns)
                ForEach(passport.rows) { row in
                    passportMatrixRow(row)
                }
                if !passport.lastObservationText.isEmpty {
                    Text(passport.lastObservationText)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Spec.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func passportMatrixHeaderRow(_ columns: [PhonemePassportColumn]) -> some View {
        HStack(spacing: passportCellSpacing) {
            // Угловая ячейка под колонку фонем (пустой спейсер для выравнивания).
            Color.clear
                .frame(width: passportPhonemeColumnWidth, height: 1)
            ForEach(columns) { column in
                Text(column.title)
                    .font(TypographyTokens.caption(11).weight(.semibold))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func passportMatrixRow(_ row: PhonemePassportRowViewModel) -> some View {
        HStack(spacing: passportCellSpacing) {
            Text(row.phoneme)
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Spec.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: passportPhonemeColumnWidth, alignment: .leading)
            ForEach(row.cells) { cell in
                passportMatrixCell(cell)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.cells.map(\.accessibilityLabel).joined(separator: ", ")))
    }

    private func passportMatrixCell(_ cell: PhonemePassportCellViewModel) -> some View {
        let color = passportTone(cell.tone)
        return VStack(spacing: 2) {
            if cell.hasData {
                Text(cell.levelText)
                    .font(TypographyTokens.caption(11).weight(.semibold))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.chip)
                .fill(cell.hasData ? color.opacity(0.18) : ColorTokens.Spec.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.chip)
                .strokeBorder(
                    cell.hasData ? color.opacity(0.55) : ColorTokens.Spec.line,
                    lineWidth: 1
                )
        )
        .accessibilityHidden(true)
    }

    // MARK: - Trends card (sparkline GOP по слабейшим фонемам)

    private func passportTrendsCard(_ passport: PhonemePassportViewModel) -> some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text(String(localized: "passport.trends.title"))
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                ForEach(passport.trends) { trend in
                    passportTrendRow(trend)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func passportTrendRow(_ trend: PhonemePassportTrendViewModel) -> some View {
        let color = passportTone(trend.tone)
        return HStack(spacing: SpacingTokens.sp3) {
            Text(trend.phoneme)
                .font(TypographyTokens.title(18))
                .foregroundStyle(ColorTokens.Spec.ink)
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(trend.captionText)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            passportSparkline(trend.points, color: color)
                .frame(width: 72, height: 34)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(trend.phoneme), \(trend.captionText)"))
    }

    private func passportSparkline(
        _ points: [PhonemePassportTrendPoint],
        color: Color
    ) -> some View {
        Chart(points) { point in
            LineMark(
                x: .value("index", point.index),
                y: .value("level", point.level)
            )
            .foregroundStyle(color)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("index", point.index),
                y: .value("level", point.level)
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

    // MARK: - Forecast card (прогноз + CI-полоса + консультация)

    private func passportForecastCard(_ passport: PhonemePassportViewModel) -> some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                Text(String(localized: "passport.forecast.title"))
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                ForEach(passport.forecasts) { forecast in
                    passportForecastRow(forecast)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func passportForecastRow(_ forecast: PhonemePassportForecastViewModel) -> some View {
        let color = passportTone(forecast.tone)
        return VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                Text(forecast.summaryText)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if forecast.needsConsultation {
                    consultationBadge
                }
            }
            passportConfidenceBar(forecast: forecast, color: color)
            if let confidence = forecast.confidenceText {
                Text(confidence)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(forecast.accessibilityLabel))
    }

    /// CI-полоса: трек 0…1 (доля от макс. горизонта), маркер текущего уровня и
    /// затенённая полоса доверительного интервала ETA.
    private func passportConfidenceBar(
        forecast: PhonemePassportForecastViewModel,
        color: Color
    ) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ColorTokens.Spec.line)
                    .frame(height: 6)
                if let lower = forecast.confidenceLowerFraction,
                   let upper = forecast.confidenceUpperFraction {
                    let start = min(lower, upper) * width
                    let span = max(abs(upper - lower) * width, 4)
                    Capsule()
                        .fill(color.opacity(0.35))
                        .frame(width: span, height: 6)
                        .offset(x: start)
                }
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .offset(x: max(min(CGFloat(forecast.currentLevel) * width, width - 10), 0))
            }
            .frame(height: 10)
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    private var consultationBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "stethoscope")
                .font(.system(size: 10, weight: .bold))
            Text(String(localized: "passport.forecast.consultation"))
                .font(TypographyTokens.caption(11).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(ColorTokens.Brand.rose)
        .padding(.horizontal, SpacingTokens.tiny)
        .padding(.vertical, SpacingTokens.micro)
        .background(Capsule().fill(ColorTokens.Brand.rose.opacity(0.14)))
    }

    // MARK: - Disclaimer (честная относительная шкала)

    private func passportDisclaimer(_ passport: PhonemePassportViewModel) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp2) {
            Image(systemName: "info.circle")
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
            Text(passport.disclaimerText)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpacingTokens.tiny)
    }

    // MARK: - CSV export (ShareLink — реальный экспорт)

    @ViewBuilder
    private func passportExportButton(_ passport: PhonemePassportViewModel) -> some View {
        if !passport.csvExport.isEmpty {
            ShareLink(
                item: PhonemePassportCSVDocument(
                    text: passport.csvExport,
                    fileName: passport.csvFileName
                ),
                preview: SharePreview(passport.titleText)
            ) {
                Label {
                    Text(String(localized: "passport.export.button"))
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
                .font(TypographyTokens.cta())
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(ColorTokens.Spec.accent)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.button)
                        .strokeBorder(ColorTokens.Spec.accent, lineWidth: 1.5)
                )
            }
            .accessibilityLabel(Text(String(localized: "passport.export.button.a11y")))
        }
    }

    // MARK: - Empty state (паспорт пуст — дружелюбно, не ошибка)

    private func passportEmptyCard(_ passport: PhonemePassportViewModel) -> some View {
        HSCard(style: .flat) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 34))
                    .foregroundStyle(ColorTokens.Spec.accent)
                Text(String(localized: "passport.empty.title"))
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                Text(passport.emptyText)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Layout constants

    private var passportPhonemeColumnWidth: CGFloat { 36 }
    private var passportCellSpacing: CGFloat { SpacingTokens.sp2 }

    // MARK: - Tone color (warm palette: gold/butter/rose; neutral = muted)

    func passportTone(_ tone: PhonemePassportTone) -> Color {
        switch tone {
        case .good:    return ColorTokens.Brand.gold
        case .medium:  return ColorTokens.Brand.butter
        case .poor:    return ColorTokens.Brand.rose
        case .neutral: return ColorTokens.Spec.inkMuted
        }
    }
}

// MARK: - PhonemePassportCSVDocument

/// Транспорт CSV-экспорта паспорта через `ShareLink`. Пишет `.csv` во временный
/// файл с осмысленным именем — открывается в Файлах/Почте/AirDrop без PII.
struct PhonemePassportCSVDocument: Transferable {
    let text: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(document.text.utf8)
        }
        .suggestedFileName { "\($0.fileName).csv" }
    }
}
