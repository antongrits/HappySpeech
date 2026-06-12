import Foundation

// MARK: - PhonemePassportPresenter
//
// Чистое форматирование секции «Фонемный паспорт» (GOP-анализ) из доменного
// `PhonemeProfile` + `MasteryForecast`. Без I/O и без random — детерминированно
// тестируется напрямую. Никаких вычислений динамики здесь: всё уже посчитано
// `PhonemeProfileMath` в сервисе; презентер только локализует и раскладывает по
// VM-структурам (Clean Swift — Presenter formats, не считает).
//
// Шкала уровней — относительная (self-baseline ребёнка), поэтому в UI всегда
// сопровождается честной пометкой «оценка относительная, не клиническая».

enum PhonemePassportPresenter {

    // MARK: - Public entry

    /// Строит ViewModel секции паспорта. Пустой профиль (нет наблюдений) даёт
    /// `isEmpty == true` с дружелюбным empty-state.
    static func makeViewModel(
        profile: PhonemeProfile,
        forecasts: [MasteryForecast]
    ) -> PhonemePassportViewModel {
        let title = String(localized: "passport.title")
        let disclaimer = String(localized: "passport.disclaimer")

        guard !profile.cells.isEmpty else {
            return PhonemePassportViewModel(
                titleText: title,
                subtitleText: "",
                columns: columns(),
                rows: [],
                trends: [],
                forecasts: [],
                lastObservationText: "",
                disclaimerText: disclaimer,
                isEmpty: true,
                emptyText: String(localized: "passport.empty.message"),
                csvExport: "",
                csvFileName: csvFileName(childId: profile.childId)
            )
        }

        let cols = columns()
        let rows = makeRows(cells: profile.cells, columns: cols)
        let trends = makeTrends(profile: profile)
        let forecastVMs = forecasts
            .filter { $0.status != .insufficientData }
            .map(makeForecast)
            .sorted { lhs, rhs in
                if lhs.needsConsultation != rhs.needsConsultation {
                    return lhs.needsConsultation && !rhs.needsConsultation
                }
                return lhs.currentLevel < rhs.currentLevel
            }

        let subtitle = makeSubtitle(profile: profile)
        let lastObservation = makeLastObservationText(profile: profile)
        let csv = makeCSV(profile: profile)

        return PhonemePassportViewModel(
            titleText: title,
            subtitleText: subtitle,
            columns: cols,
            rows: rows,
            trends: trends,
            forecasts: forecastVMs,
            lastObservationText: lastObservation,
            disclaimerText: disclaimer,
            isEmpty: false,
            emptyText: "",
            csvExport: csv,
            csvFileName: csvFileName(childId: profile.childId)
        )
    }

    // MARK: - Matrix columns (positions)

    static func columns() -> [PhonemePassportColumn] {
        [
            PhonemePassportColumn(
                key: PhonemeWordPosition.initial.rawValue,
                title: String(localized: "passport.position.initial")
            ),
            PhonemePassportColumn(
                key: PhonemeWordPosition.medial.rawValue,
                title: String(localized: "passport.position.medial")
            ),
            PhonemePassportColumn(
                key: PhonemeWordPosition.final.rawValue,
                title: String(localized: "passport.position.final")
            )
        ]
    }

    // MARK: - Matrix rows (phoneme × position)

    private static func makeRows(
        cells: [PhonemePositionCell],
        columns: [PhonemePassportColumn]
    ) -> [PhonemePassportRowViewModel] {
        // Группируем по фонеме, сохраняя стабильный порядок появления.
        var order: [String] = []
        var byPhoneme: [String: [PhonemeWordPosition: PhonemePositionCell]] = [:]
        for cell in cells {
            if byPhoneme[cell.phoneme] == nil {
                byPhoneme[cell.phoneme] = [:]
                order.append(cell.phoneme)
            }
            byPhoneme[cell.phoneme]?[cell.position] = cell
        }

        return order.map { phoneme in
            let cellsByPosition = byPhoneme[phoneme] ?? [:]
            let label = displayLabel(forIPA: phoneme)
            let rowCells = columns.map { column -> PhonemePassportCellViewModel in
                let position = PhonemeWordPosition(rawOrInitial: column.key)
                if let cell = cellsByPosition[position] {
                    return makeCell(label: label, column: column, cell: cell)
                }
                return emptyCell(label: label, column: column, position: position)
            }
            return PhonemePassportRowViewModel(phoneme: label, cells: rowCells)
        }
    }

    private static func makeCell(
        label: String,
        column: PhonemePassportColumn,
        cell: PhonemePositionCell
    ) -> PhonemePassportCellViewModel {
        let tone = tone(for: cell.state, level: cell.level)
        let levelText = cell.level.map { levelString($0) } ?? ""
        let stateText = stateLabel(cell.state)
        let a11y = String(
            format: String(localized: "passport.cell.a11y %@ %@ %@"),
            label, column.title, stateText
        )
        return PhonemePassportCellViewModel(
            phoneme: label,
            positionKey: column.key,
            levelText: levelText,
            tone: tone,
            stateText: stateText,
            hasData: cell.observationCount > 0,
            accessibilityLabel: a11y
        )
    }

    private static func emptyCell(
        label: String,
        column: PhonemePassportColumn,
        position: PhonemeWordPosition
    ) -> PhonemePassportCellViewModel {
        let a11y = String(
            format: String(localized: "passport.cell.a11y %@ %@ %@"),
            label, column.title, String(localized: "passport.state.noData")
        )
        return PhonemePassportCellViewModel(
            phoneme: label,
            positionKey: column.key,
            levelText: "",
            tone: .neutral,
            stateText: "",
            hasData: false,
            accessibilityLabel: a11y
        )
    }

    // MARK: - Trends (sparkline для слабейших фонем)

    private static func makeTrends(profile: PhonemeProfile) -> [PhonemePassportTrendViewModel] {
        profile.topProblems.map { problem in
            let cellsForPhoneme = profile.cells
                .filter { $0.phoneme == problem.phoneme }
                .sorted { positionRank($0.position) < positionRank($1.position) }
            // Точки динамики по позициям (initial→medial→final). Это наблюдаемая
            // в паспорте структура уровня по позициям — реальные значения, не выдумка.
            let points = cellsForPhoneme.enumerated().compactMap { index, cell -> PhonemePassportTrendPoint? in
                guard let level = cell.level else { return nil }
                return PhonemePassportTrendPoint(index: index, level: level)
            }
            let label = displayLabel(forIPA: problem.phoneme)
            let caption = String(
                format: String(localized: "passport.trend.caption %@ %@"),
                levelString(problem.level), stateLabel(problem.state)
            )
            return PhonemePassportTrendViewModel(
                phoneme: label,
                captionText: caption,
                tone: tone(for: problem.state, level: problem.level),
                points: points
            )
        }
        .filter { !$0.points.isEmpty }
    }

    // MARK: - Forecast

    static func makeForecast(_ forecast: MasteryForecast) -> PhonemePassportForecastViewModel {
        let label = displayLabel(forIPA: forecast.phoneme)
        let needsConsultation = forecast.status == .needsConsultation
        let summary = forecastSummary(forecast, label: label)
        let confidence = forecastConfidence(forecast)
        let (lowerFraction, upperFraction) = forecastCIFractions(forecast)
        let tone: PhonemePassportTone = needsConsultation
            ? .poor
            : (forecast.status == .mastered ? .good : .medium)

        var a11yParts = [label, summary]
        if let confidence { a11yParts.append(confidence) }
        if needsConsultation {
            a11yParts.append(String(localized: "passport.forecast.consultation"))
        }

        return PhonemePassportForecastViewModel(
            phoneme: label,
            summaryText: summary,
            confidenceText: confidence,
            needsConsultation: needsConsultation,
            currentLevel: forecast.currentLevel,
            confidenceLowerFraction: lowerFraction,
            confidenceUpperFraction: upperFraction,
            tone: tone,
            accessibilityLabel: a11yParts.joined(separator: ", ")
        )
    }

    private static func forecastSummary(_ forecast: MasteryForecast, label: String) -> String {
        switch forecast.status {
        case .mastered:
            return String(
                format: String(localized: "passport.forecast.mastered %@"),
                label
            )
        case .needsConsultation:
            return String(
                format: String(localized: "passport.forecast.needsConsultation %@"),
                label
            )
        case .improving:
            guard let weeks = forecast.estimatedWeeksToMastery else {
                return String(
                    format: String(localized: "passport.forecast.improving.noEta %@"),
                    label
                )
            }
            // «Звук Ш: ожидаемое освоение через 4 занятия» — плюрализация занятий.
            let lessons = lessonsPhrase(weeks)
            return String(
                format: String(localized: "passport.forecast.improving %@ %@"),
                label, lessons
            )
        case .insufficientData:
            return String(
                format: String(localized: "passport.forecast.insufficient %@"),
                label
            )
        }
    }

    private static func forecastConfidence(_ forecast: MasteryForecast) -> String? {
        guard forecast.status == .improving,
              let lower = forecast.etaLowerWeeks,
              let upper = forecast.etaUpperWeeks else { return nil }
        return String(
            format: String(localized: "passport.forecast.ci %lld %lld"),
            lower, upper
        )
    }

    /// Нормирует границы CI (недели) к долям [0…1] относительно `etaMaxWeeks`,
    /// чтобы отрисовать CI-полосу. Меньше недель → ближе к 0 (быстрее).
    private static func forecastCIFractions(
        _ forecast: MasteryForecast
    ) -> (lower: Double?, upper: Double?) {
        guard forecast.status == .improving else { return (nil, nil) }
        let maxWeeks = Double(PhonemeProfileMath.etaMaxWeeks)
        let lower = forecast.etaLowerWeeks.map { min(max(Double($0) / maxWeeks, 0), 1) }
        let upper = forecast.etaUpperWeeks.map { min(max(Double($0) / maxWeeks, 0), 1) }
        return (lower, upper)
    }

    // MARK: - Subtitle / last observation

    private static func makeSubtitle(profile: PhonemeProfile) -> String {
        let observations = observationsPhrase(profile.totalObservations)
        let calibration = profile.isCalibrated
            ? String(localized: "passport.subtitle.calibrated")
            : String(localized: "passport.subtitle.calibrating")
        return String(
            format: String(localized: "passport.subtitle %@ %@"),
            observations, calibration
        )
    }

    private static func makeLastObservationText(profile: PhonemeProfile) -> String {
        let formatted = Self.dateFormatter.string(from: profile.generatedAt)
        return String(
            format: String(localized: "passport.lastObservation %@"),
            formatted
        )
    }

    // MARK: - CSV export (специалист)

    /// РЕАЛЬНЫЙ CSV: фонема,позиция,GOP,состояние,наблюдений,конкурент,дата.
    /// Без PII (только IPA/числа). Разделитель — запятая, значения экранируются.
    static func makeCSV(profile: PhonemeProfile) -> String {
        var lines: [String] = []
        lines.append(
            [
                String(localized: "passport.csv.header.phoneme"),
                String(localized: "passport.csv.header.position"),
                String(localized: "passport.csv.header.gop"),
                String(localized: "passport.csv.header.state"),
                String(localized: "passport.csv.header.observations"),
                String(localized: "passport.csv.header.competitor"),
                String(localized: "passport.csv.header.date")
            ].map(csvEscape).joined(separator: ",")
        )

        let generated = Self.csvDateFormatter.string(from: profile.generatedAt)
        let ordered = profile.cells.sorted { lhs, rhs in
            if lhs.phoneme != rhs.phoneme { return lhs.phoneme < rhs.phoneme }
            return positionRank(lhs.position) < positionRank(rhs.position)
        }
        for cell in ordered {
            let level = cell.level.map { String(format: "%.3f", $0) } ?? ""
            let row = [
                displayLabel(forIPA: cell.phoneme),
                cell.position.ruShort,
                level,
                stateLabel(cell.state),
                String(cell.observationCount),
                cell.dominantCompetitor.map { displayLabel(forIPA: $0) } ?? "",
                generated
            ]
            lines.append(row.map(csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    static func csvFileName(childId: String) -> String {
        // Без PII: хэшируемый суффикс заменяем коротким безопасным маркером.
        let safe = childId.prefix(8).filter { $0.isLetter || $0.isNumber }
        return "phoneme_passport_\(safe)"
    }

    // MARK: - Tone

    static func tone(for state: PhonemeState, level: Double?) -> PhonemePassportTone {
        switch state {
        case .noData:
            return .neutral
        case .ok:
            // Норма, но низкий уровень → не «отлично», а «внимание».
            if let level, level < PhonemeProfileMath.masteryThreshold * 0.7 {
                return .medium
            }
            return .good
        case .distortion, .ageSubstitution:
            return .medium
        case .substitution, .omission:
            return .poor
        }
    }

    // MARK: - Localized labels

    static func stateLabel(_ state: PhonemeState) -> String {
        switch state {
        case .noData:          return String(localized: "passport.state.noData")
        case .ok:              return String(localized: "passport.state.ok")
        case .distortion:      return String(localized: "passport.state.distortion")
        case .ageSubstitution: return String(localized: "passport.state.ageSubstitution")
        case .substitution:    return String(localized: "passport.state.substitution")
        case .omission:        return String(localized: "passport.state.omission")
        }
    }

    /// Человеко-читаемая метка фонемы: Cyrillic из словаря, иначе сам IPA.
    static func displayLabel(forIPA ipa: String) -> String {
        IPADictionary.info(for: ipa)?.cyrillic.uppercased() ?? ipa
    }

    private static func levelString(_ level: Double) -> String {
        String(
            format: String(localized: "passport.gop.value %@"),
            String(format: "%.2f", level)
        )
    }

    // MARK: - Plural phrases (корректное русское склонение)

    private static func observationsPhrase(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "passport.observations.count"),
            count
        )
    }

    private static func lessonsPhrase(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "passport.lessons.count"),
            count
        )
    }

    private static func positionRank(_ position: PhonemeWordPosition) -> Int {
        switch position {
        case .initial: return 0
        case .medial:  return 1
        case .final:   return 2
        }
    }

    // MARK: - Date formatters

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
