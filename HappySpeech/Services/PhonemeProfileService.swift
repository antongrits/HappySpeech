import Foundation
import OSLog

// MARK: - PhonemeProfileServiceProtocol

/// Сервис «Фонемного паспорта» — пофонемная агрегация GOP-наблюдений и оценка
/// динамики освоения.
///
/// Декаплирован от ML-движка выравнивания: оперирует уже-сохранёнными
/// `PhonemeObservationDTO` (см. `PhonemeObservationRepository`). Сам сервис лишь
/// записывает наблюдения и агрегирует/прогнозирует по ним — он не знает, как
/// именно посчитаны `gop`/`posterior` (это делает отдельный ML-слой).
///
/// **Важно (project guide §11):** это ОЦЕНКА ДИНАМИКИ по относительным метрикам
/// (self-baseline ребёнка), а НЕ диагноз, не клиническое заключение и не гарантия
/// результата. Абсолютная GOP-шкала смещена (модель дообучена на синтетике),
/// поэтому используются только внутрисубъектные относительные/трендовые выводы.
///
/// Хранимые данные — только числа/IPA, никакого аудио и PII (COPPA-safe).
public protocol PhonemeProfileServiceProtocol: Sendable {

    // swiftlint:disable function_parameter_count
    /// Записать одно пофонемное наблюдение.
    ///
    /// - Parameters:
    ///   - childId: идентификатор ребёнка (без PII).
    ///   - phoneme: целевая фонема в IPA.
    ///   - wordId: id слова урока (не само слово).
    ///   - position: позиция в слове.
    ///   - gop: Goodness of Pronunciation (относительная мера).
    ///   - posterior: усреднённая апостериорная вероятность фонемы.
    ///   - defect: классифицированный исход ("ok"/"distortion"/"substitution"/
    ///     "age_substitution"/"omission").
    ///   - competitor: IPA конкурента для замен, иначе nil.
    func record(
        childId: String,
        phoneme: String,
        wordId: String,
        position: PhonemeWordPosition,
        gop: Double,
        posterior: Double,
        defect: String,
        competitor: String?
    ) async throws
    // swiftlint:enable function_parameter_count

    /// Построить агрегированный паспорт ребёнка (матрица + топ-проблемы).
    func profile(childId: String) async throws -> PhonemeProfile

    /// Спрогнозировать динамику освоения конкретной фонемы.
    func predict(childId: String, phoneme: String) async throws -> MasteryForecast
}

// MARK: - PhonemeProfileMath (чистая детерминированная логика)

/// Чистые детерминированные вычисления паспорта — без I/O.
///
/// Выделены отдельно, чтобы покрыть юнит-тестами напрямую (EWMA, Theil-Sen,
/// self-baseline перцентили, агрегация) на синтетических данных.
public enum PhonemeProfileMath {

    // MARK: Константы

    /// Размер выборки для self-baseline калибровки (первые N наблюдений ребёнка
    /// задают его персональные перцентили).
    public static let baselineSampleSize = 20

    /// Минимум наблюдений по фонеме для построения прогноза.
    public static let minForecastObservations = 8

    /// Коэффициент сглаживания EWMA (вес последнего наблюдения).
    public static let ewmaAlpha = 0.3

    /// Порог self-baseline уровня, считающийся «автоматизацией» фонемы.
    public static let masteryThreshold = 0.85

    /// Границы клампа ETA (недели).
    public static let etaMinWeeks = 1
    public static let etaMaxWeeks = 12

    // MARK: EWMA

    /// Экспоненциально-взвешенное скользящее среднее последовательности.
    /// Пустой вход → 0. `alpha` — вес последнего элемента.
    public static func ewma(_ values: [Double], alpha: Double = ewmaAlpha) -> Double {
        guard let first = values.first else { return 0 }
        let a = min(max(alpha, 0), 1)
        var acc = first
        for value in values.dropFirst() {
            acc = a * value + (1 - a) * acc
        }
        return acc
    }

    // MARK: Self-baseline калибровка

    /// Персентильный ранг `value` среди отсортированной baseline-выборки в [0, 1].
    ///
    /// Если baseline пустой — используется грубая сигмоида-подобная нормализация
    /// сырого GOP (на случай прогноза до накопления базы). Внутрисубъектный дизайн:
    /// мы сравниваем ребёнка с его собственной историей, не с популяцией.
    public static func selfBaselinePercentile(_ value: Double, baseline: [Double]) -> Double {
        guard !baseline.isEmpty else {
            // Грубая нормализация сырого GOP в [0, 1] без базы (логистическая).
            return 1.0 / (1.0 + exp(-value))
        }
        let sorted = baseline.sorted()
        // Доля элементов базы строго меньше value + половина равных (mid-rank).
        var below = 0
        var equal = 0
        for element in sorted {
            if element < value { below += 1 } else if element == value { equal += 1 }
        }
        let rank = Double(below) + Double(equal) / 2.0
        return min(max(rank / Double(sorted.count), 0), 1)
    }

    // MARK: Theil-Sen

    /// Робастный Theil-Sen наклон по точкам (x, y): медиана попарных наклонов.
    /// Возвращает nil, если уникальных x меньше двух (наклон не определён).
    public static func theilSenSlope(points: [(x: Double, y: Double)]) -> Double? {
        guard points.count >= 2 else { return nil }
        var slopes: [Double] = []
        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                let dx = points[j].x - points[i].x
                guard dx != 0 else { continue }
                slopes.append((points[j].y - points[i].y) / dx)
            }
        }
        guard !slopes.isEmpty else { return nil }
        return median(slopes)
    }

    /// Все попарные наклоны Theil-Sen (для оценки CI через IQR).
    public static func pairwiseSlopes(points: [(x: Double, y: Double)]) -> [Double] {
        var slopes: [Double] = []
        guard points.count >= 2 else { return slopes }
        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                let dx = points[j].x - points[i].x
                guard dx != 0 else { continue }
                slopes.append((points[j].y - points[i].y) / dx)
            }
        }
        return slopes
    }

    /// Медиана (линейная интерполяция середины для чётной длины).
    public static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }

    /// Межквартильный размах (Q1, Q3) методом простых перцентилей.
    public static func interquartileRange(_ values: [Double]) -> (q1: Double, q3: Double) {
        guard !values.isEmpty else { return (0, 0) }
        let sorted = values.sorted()
        return (percentile(sorted, 0.25), percentile(sorted, 0.75))
    }

    /// Перцентиль `p` (0…1) отсортированного массива — линейная интерполяция.
    public static func percentile(_ sortedValues: [Double], _ p: Double) -> Double {
        guard let first = sortedValues.first else { return 0 }
        guard sortedValues.count > 1 else { return first }
        let pos = p * Double(sortedValues.count - 1)
        let lower = Int(pos.rounded(.down))
        let upper = Int(pos.rounded(.up))
        let frac = pos - Double(lower)
        return sortedValues[lower] + frac * (sortedValues[upper] - sortedValues[lower])
    }

    // MARK: Defect → State

    /// Сводит набор исходов (`defect`) ячейки в одно состояние — по преобладанию.
    public static func dominantState(defects: [String]) -> PhonemeState {
        guard !defects.isEmpty else { return .noData }
        var counts: [PhonemeState: Int] = [:]
        for raw in defects {
            counts[state(fromDefect: raw), default: 0] += 1
        }
        // Стабильный порядок при равенстве: ok > distortion > ageSub > sub > omission.
        let order: [PhonemeState] = [.ok, .distortion, .ageSubstitution, .substitution, .omission]
        return order.max(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) }) ?? .ok
    }

    /// Маппинг строкового исхода наблюдения в `PhonemeState`.
    public static func state(fromDefect raw: String) -> PhonemeState {
        switch raw {
        case "ok":               return .ok
        case "distortion":       return .distortion
        case "age_substitution": return .ageSubstitution
        case "substitution":     return .substitution
        case "omission":         return .omission
        default:                 return .distortion
        }
    }

    // MARK: Прогноз

    /// Строит прогноз по наблюдениям одной фонемы (отсортированы по дате).
    ///
    /// Возвращает `.insufficientData`, если наблюдений меньше порога. Иначе
    /// нормализует GOP self-baseline'ом, считает EWMA-уровень, Theil-Sen тренд
    /// (единиц уровня в неделю) и ETA до `masteryThreshold` с CI из IQR наклонов.
    public static func forecast(
        childId: String,
        phoneme: String,
        observations: [PhonemeObservationDTO],
        baseline: [Double]
    ) -> MasteryForecast {
        let sorted = observations.sorted { $0.date < $1.date }
        guard sorted.count >= minForecastObservations else {
            return .insufficient(
                childId: childId,
                phoneme: phoneme,
                observationCount: sorted.count
            )
        }

        // Нормализуем каждое GOP в self-baseline шкалу [0, 1].
        let levels = sorted.map { selfBaselinePercentile($0.gop, baseline: baseline) }
        let currentLevel = ewma(levels)

        // Точки тренда: x — недели от первого наблюдения, y — кумулятивный EWMA.
        let week: TimeInterval = 7 * 24 * 3600
        let firstDate = sorted[0].date
        var points: [(x: Double, y: Double)] = []
        var runningEWMA = levels[0]
        for (idx, level) in levels.enumerated() {
            if idx > 0 {
                runningEWMA = ewmaAlpha * level + (1 - ewmaAlpha) * runningEWMA
            }
            let x = sorted[idx].date.timeIntervalSince(firstDate) / week
            points.append((x: x, y: runningEWMA))
        }

        let slope = theilSenSlope(points: points) ?? 0

        // Уже автоматизирован.
        if currentLevel >= masteryThreshold {
            return MasteryForecast(
                childId: childId,
                phoneme: phoneme,
                status: .mastered,
                currentLevel: currentLevel,
                weeklySlope: slope,
                observationCount: sorted.count,
                estimatedWeeksToMastery: 0,
                etaLowerWeeks: nil,
                etaUpperWeeks: nil
            )
        }

        // Нет прогресса / регресс → честная рекомендация консультации.
        guard slope > 0 else {
            return MasteryForecast(
                childId: childId,
                phoneme: phoneme,
                status: .needsConsultation,
                currentLevel: currentLevel,
                weeklySlope: slope,
                observationCount: sorted.count,
                estimatedWeeksToMastery: nil,
                etaLowerWeeks: nil,
                etaUpperWeeks: nil
            )
        }

        // ETA = (τ − level) / slope, clamp [1, 12].
        let remaining = masteryThreshold - currentLevel
        let rawWeeks = remaining / slope
        let eta = clampWeeks(rawWeeks)

        // CI из IQR попарных наклонов: более крутой Q3 → ближе, пологий Q1 → дальше.
        let slopes = pairwiseSlopes(points: points).filter { $0 > 0 }
        var lower: Int?
        var upper: Int?
        if !slopes.isEmpty {
            let iqr = interquartileRange(slopes)
            if iqr.q3 > 0 { lower = clampWeeks(remaining / iqr.q3) }
            if iqr.q1 > 0 { upper = clampWeeks(remaining / iqr.q1) }
            // Гарантируем lower ≤ eta ≤ upper после клампа.
            if let lowerValue = lower, let upperValue = upper, lowerValue > upperValue {
                swap(&lower, &upper)
            }
        }

        return MasteryForecast(
            childId: childId,
            phoneme: phoneme,
            status: .improving,
            currentLevel: currentLevel,
            weeklySlope: slope,
            observationCount: sorted.count,
            estimatedWeeksToMastery: eta,
            etaLowerWeeks: lower,
            etaUpperWeeks: upper
        )
    }

    /// Кламп числа недель в допустимый диапазон [etaMinWeeks, etaMaxWeeks].
    public static func clampWeeks(_ weeks: Double) -> Int {
        let rounded = Int(weeks.rounded())
        return min(max(rounded, etaMinWeeks), etaMaxWeeks)
    }

    // MARK: Агрегация паспорта

    /// Строит полный паспорт из всех наблюдений ребёнка.
    ///
    /// self-baseline формируется из первых `baselineSampleSize` GOP (по дате).
    public static func buildProfile(
        childId: String,
        observations: [PhonemeObservationDTO],
        now: Date = Date()
    ) -> PhonemeProfile {
        guard !observations.isEmpty else {
            return .empty(childId: childId, generatedAt: now)
        }
        let sorted = observations.sorted { $0.date < $1.date }
        let baseline = Array(sorted.prefix(baselineSampleSize)).map(\.gop)
        let isCalibrated = sorted.count >= baselineSampleSize

        // Группируем по (phoneme, position).
        var grouped: [String: [PhonemeObservationDTO]] = [:]
        for obs in sorted {
            let key = "\(obs.phoneme)|\(PhonemeWordPosition(rawOrInitial: obs.position).rawValue)"
            grouped[key, default: []].append(obs)
        }

        var cells: [PhonemePositionCell] = []
        for (key, group) in grouped {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let phoneme = parts[0]
            let position = PhonemeWordPosition(rawOrInitial: parts[1])
            let levels = group.map { selfBaselinePercentile($0.gop, baseline: baseline) }
            let cell = PhonemePositionCell(
                phoneme: phoneme,
                position: position,
                state: dominantState(defects: group.map(\.defect)),
                observationCount: group.count,
                level: ewma(levels),
                dominantCompetitor: dominantCompetitor(group.compactMap(\.competitor))
            )
            cells.append(cell)
        }
        // Стабильный порядок: по фонеме, затем по позиции.
        cells.sort {
            if $0.phoneme != $1.phoneme { return $0.phoneme < $1.phoneme }
            return positionOrder($0.position) < positionOrder($1.position)
        }

        let topProblems = computeTopProblems(observations: sorted, baseline: baseline, limit: 3)

        return PhonemeProfile(
            childId: childId,
            generatedAt: now,
            cells: cells,
            totalObservations: sorted.count,
            topProblems: topProblems,
            isCalibrated: isCalibrated
        )
    }

    /// Топ-N проблемных фонем по возрастанию self-baseline уровня.
    public static func computeTopProblems(
        observations: [PhonemeObservationDTO],
        baseline: [Double],
        limit: Int
    ) -> [PhonemeProblem] {
        var byPhoneme: [String: [PhonemeObservationDTO]] = [:]
        for obs in observations {
            byPhoneme[obs.phoneme, default: []].append(obs)
        }
        var problems: [PhonemeProblem] = []
        for (phoneme, group) in byPhoneme {
            let levels = group.map { selfBaselinePercentile($0.gop, baseline: baseline) }
            problems.append(
                PhonemeProblem(
                    phoneme: phoneme,
                    level: ewma(levels),
                    observationCount: group.count,
                    state: dominantState(defects: group.map(\.defect)),
                    dominantCompetitor: dominantCompetitor(group.compactMap(\.competitor))
                )
            )
        }
        // Хуже = меньший уровень. Тай-брейк по фонеме для детерминизма.
        problems.sort {
            if $0.level != $1.level { return $0.level < $1.level }
            return $0.phoneme < $1.phoneme
        }
        return Array(problems.prefix(limit))
    }

    /// Наиболее частый конкурент (IPA) или nil.
    public static func dominantCompetitor(_ competitors: [String]) -> String? {
        guard !competitors.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for c in competitors { counts[c, default: 0] += 1 }
        return counts.max(by: { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key > rhs.key // детерминированный тай-брейк
        })?.key
    }

    private static func positionOrder(_ position: PhonemeWordPosition) -> Int {
        switch position {
        case .initial: return 0
        case .medial:  return 1
        case .final:   return 2
        }
    }
}

// MARK: - LivePhonemeProfileService

/// Боевая реализация: пишет/читает наблюдения через `PhonemeObservationRepository`,
/// агрегирует/прогнозирует через `PhonemeProfileMath`. Actor — изоляция стейта.
public actor LivePhonemeProfileService: PhonemeProfileServiceProtocol {

    private let repository: any PhonemeObservationRepository
    /// Источник «сейчас» — инъектируется для детерминированных тестов.
    private let now: @Sendable () -> Date

    public init(
        repository: any PhonemeObservationRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    // swiftlint:disable:next function_parameter_count
    public func record(
        childId: String,
        phoneme: String,
        wordId: String,
        position: PhonemeWordPosition,
        gop: Double,
        posterior: Double,
        defect: String,
        competitor: String?
    ) async throws {
        let observation = PhonemeObservationDTO(
            childId: childId,
            phoneme: phoneme,
            wordId: wordId,
            position: position.rawValue,
            gop: gop,
            posterior: posterior,
            defect: defect,
            competitor: competitor,
            date: now()
        )
        try await repository.save(observation)
        HSLogger.ml.debug(
            "PhonemeProfile.record phoneme=\(phoneme, privacy: .public) defect=\(defect, privacy: .public)"
        )
    }

    public func profile(childId: String) async throws -> PhonemeProfile {
        let observations = try await repository.fetch(childId: childId)
        return PhonemeProfileMath.buildProfile(
            childId: childId,
            observations: observations,
            now: now()
        )
    }

    public func predict(childId: String, phoneme: String) async throws -> MasteryForecast {
        // self-baseline берём из ВСЕХ наблюдений ребёнка (первые N по дате),
        // а не только по этой фонеме — это персональная база перцентилей.
        let all = try await repository.fetch(childId: childId)
        let baseline = Array(
            all.sorted { $0.date < $1.date }.prefix(PhonemeProfileMath.baselineSampleSize)
        ).map(\.gop)
        let phonemeObs = try await repository.fetch(childId: childId, phoneme: phoneme)
        return PhonemeProfileMath.forecast(
            childId: childId,
            phoneme: phoneme,
            observations: phonemeObs,
            baseline: baseline
        )
    }
}

// MARK: - MockPhonemeProfileService (preview / tests)

/// Лёгкий mock — детерминированный, без Realm. Хранит наблюдения в памяти и
/// прогоняет ту же `PhonemeProfileMath`, что и Live, поэтому пригоден для
/// предсказуемого preview/snapshot.
public actor MockPhonemeProfileService: PhonemeProfileServiceProtocol {

    private var observations: [PhonemeObservationDTO]
    private let now: @Sendable () -> Date

    public init(
        observations: [PhonemeObservationDTO] = [],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.observations = observations
        self.now = now
    }

    // swiftlint:disable:next function_parameter_count
    public func record(
        childId: String,
        phoneme: String,
        wordId: String,
        position: PhonemeWordPosition,
        gop: Double,
        posterior: Double,
        defect: String,
        competitor: String?
    ) async throws {
        observations.append(
            PhonemeObservationDTO(
                childId: childId,
                phoneme: phoneme,
                wordId: wordId,
                position: position.rawValue,
                gop: gop,
                posterior: posterior,
                defect: defect,
                competitor: competitor,
                date: now()
            )
        )
    }

    public func profile(childId: String) async throws -> PhonemeProfile {
        PhonemeProfileMath.buildProfile(
            childId: childId,
            observations: observations.filter { $0.childId == childId },
            now: now()
        )
    }

    public func predict(childId: String, phoneme: String) async throws -> MasteryForecast {
        let childObs = observations.filter { $0.childId == childId }
        let baseline = Array(
            childObs.sorted { $0.date < $1.date }.prefix(PhonemeProfileMath.baselineSampleSize)
        ).map(\.gop)
        return PhonemeProfileMath.forecast(
            childId: childId,
            phoneme: phoneme,
            observations: childObs.filter { $0.phoneme == phoneme },
            baseline: baseline
        )
    }
}
