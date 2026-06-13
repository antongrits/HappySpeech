import Foundation

// MARK: - DDKSequence

/// Слоговой ряд для пробы диадохокинеза («скороговорка-ракета»).
///
/// Классические клинические ряды: моносиллабические (повтор одного слога —
/// измеряет «чистый» темп) и трисиллабический «па-та-ка» (alternating motion —
/// дополнительно измеряет переключение места артикуляции: губы→зубы→нёбо).
public struct DDKSequence: Sendable, Equatable, Identifiable {

    public let id: String
    /// Слоги ряда в порядке произнесения (для отображения и озвучки).
    public let syllables: [String]
    /// Сколько слогов составляет ОДИН цикл ряда (моно = 1, «па-та-ка» = 3).
    public let cycleLength: Int
    /// Сколько циклов ребёнок должен повторить за попытку.
    public let targetCycles: Int

    public init(id: String, syllables: [String], cycleLength: Int, targetCycles: Int) {
        self.id = id
        self.syllables = syllables
        self.cycleLength = cycleLength
        self.targetCycles = targetCycles
    }

    /// Целевое число слоговых ядер за попытку.
    public var targetSyllableCount: Int { cycleLength * targetCycles }

    /// Отображаемая строка ряда («па-та-ка»).
    public var displayString: String { syllables.joined(separator: "-") }
}

// MARK: - DDKCatalog

/// Каталог рядов диадохокинеза. Моносиллабические разогревают (губной/язычный/
/// заднеязычный), трисиллабический «па-та-ка» — целевой переключательный ряд.
public enum DDKCatalog {

    /// Стандартный набор рядов (от простого к сложному).
    public static let sequences: [DDKSequence] = [
        DDKSequence(id: "ddk-pa", syllables: ["па"], cycleLength: 1, targetCycles: 8),
        DDKSequence(id: "ddk-ta", syllables: ["та"], cycleLength: 1, targetCycles: 8),
        DDKSequence(id: "ddk-ka", syllables: ["ка"], cycleLength: 1, targetCycles: 8),
        DDKSequence(id: "ddk-pataka", syllables: ["па", "та", "ка"], cycleLength: 3, targetCycles: 4)
    ]

    /// Ряд по идентификатору, либо первый как безопасный дефолт.
    public static func sequence(id: String) -> DDKSequence {
        sequences.first { $0.id == id } ?? sequences[0]
    }
}

// MARK: - DDKVerdict

/// Игровой вердикт попытки относительно темпа и ритма.
public enum DDKVerdict: String, Sendable, Equatable {
    /// Быстро и ровно — отличная оромоторная координация для возраста.
    case fastSteady
    /// Хороший устойчивый темп.
    case steady
    /// Получилось, но ритм рваный (большой разброс интервалов).
    case uneven
    /// Темп заметно ниже ожидаемого для возраста.
    case slow
    /// Слогов почти не разобрать (нет ряда) — честно «не расслышала».
    case notDetected
}

// MARK: - DDKQualityFlag

/// Качественные наблюдения (эвристики, не диагноз).
public enum DDKQualityFlag: String, Sendable, Equatable, CaseIterable {
    /// Слогов меньше задуманного — ряд не доведён до конца.
    case incompleteSequence
    /// Слогов больше задуманного — возможно, дробление/лишние призвуки.
    case extraSyllables
    /// Рваный ритм — интервалы между слогами сильно «гуляют».
    case unevenRhythm
    /// Тихая запись — слабая воздушная струя/голос.
    case weakVoice
}

// MARK: - DDKEvaluation

/// Полный результат оценки одной попытки диадохокинеза.
public struct DDKEvaluation: Sendable, Equatable {
    /// Темп, слогов/сек (0, если не определён).
    public let syllablesPerSecond: Double
    /// Ровность ритма 0…1 (1 — идеально ровно; 0 — рвано). nil, если ядер < 3.
    public let steadiness: Double?
    /// Сколько слогов обнаружено.
    public let detectedSyllables: Int
    /// Сколько ожидалось.
    public let targetSyllables: Int
    /// Вердикт.
    public let verdict: DDKVerdict
    /// Качественные флаги.
    public let flags: [DDKQualityFlag]
    /// Звёзды попытки 0…3.
    public let stars: Int
    /// Исходное измерение (для специалиста/отладки); nil при notDetected.
    public let measurement: SyllableRateMeasurement?

    public init(
        syllablesPerSecond: Double,
        steadiness: Double?,
        detectedSyllables: Int,
        targetSyllables: Int,
        verdict: DDKVerdict,
        flags: [DDKQualityFlag],
        stars: Int,
        measurement: SyllableRateMeasurement?
    ) {
        self.syllablesPerSecond = syllablesPerSecond
        self.steadiness = steadiness
        self.detectedSyllables = detectedSyllables
        self.targetSyllables = targetSyllables
        self.verdict = verdict
        self.flags = flags
        self.stars = stars
        self.measurement = measurement
    }
}

// MARK: - SyllableRateClassifier

/// Детерминированный маппинг измерения темпа слогов на игровой вердикт и звёзды.
/// Чистая логика без I/O — полностью юнит-тестируема.
///
/// ## Возрастные ориентиры темпа (DDK rate)
/// Нормы диадохокинеза растут с возрастом по мере созревания оромоторики
/// (Fletcher 1972; Robbins & Klee 1987 — детская речь). Для моносиллабического
/// ряда у детей 5–8 лет ожидаемый темп ≈ 3.5–5.5 слог/с (5 лет ниже, 8 — выше).
/// Для переключательного «па-та-ка» темп закономерно ниже моно (требуется
/// переключение артикуляторов), ориентир ≈ 2.5–4.0 цикла-слога/с.
///
/// ## Честные границы
/// Ориентиры — эвристические пороги, НЕ нормативная таблица и НЕ диагноз
/// (project guide §11). Вердикты сформулированы как игровая обратная связь.
public enum SyllableRateClassifier {

    // MARK: - Калибровочные константы (эвристики, документированы выше)

    /// Нижняя граница «хорошего» темпа для возраста (слог/с), линейно по возрасту.
    /// 5 лет → 3.3; 8 лет → 4.8 (моносиллабический ряд).
    static func steadyRateFloor(age: Int, isAlternating: Bool) -> Double {
        let clampedAge = min(8, max(5, age))
        // Линейная интерполяция 5→3.3, 8→4.8.
        let mono = 3.3 + (Double(clampedAge - 5) / 3.0) * (4.8 - 3.3)
        // Переключательный ряд медленнее — масштабируем 0.72.
        return isAlternating ? mono * 0.72 : mono
    }

    /// Темп выше этой доли от floor считается «быстрым» (даём 3-ю звезду темпа).
    static let fastRateShare: Double = 1.25

    /// Порог рваного ритма: CV интервалов выше → ритм неровный.
    static let unevenCVThreshold: Double = 0.32

    /// Порог тихой записи (пиковая RMS).
    static let weakVoiceRMS: Double = 0.02

    /// Допуск по числу слогов (± от ожидаемого) для флага полноты ряда.
    static let syllableCountTolerance: Int = 1

    // MARK: - Public API

    /// Ровность ритма из коэффициента вариации интервалов: 1 − min(1, CV/threshold').
    /// При CV=0 → 1.0; при CV=2×unevenThreshold → 0. nil, если CV нет.
    public static func steadiness(intervalCV: Double?) -> Double? {
        guard let cv = intervalCV else { return nil }
        let normalizer = unevenCVThreshold * 2
        return max(0, min(1, 1 - cv / normalizer))
    }

    /// Оценивает измерение относительно ряда и возраста ребёнка.
    public static func evaluate(
        measurement: SyllableRateMeasurement?,
        sequence: DDKSequence,
        childAge: Int
    ) -> DDKEvaluation {
        let target = sequence.targetSyllableCount

        guard let measurement, measurement.syllableCount >= 2 else {
            return DDKEvaluation(
                syllablesPerSecond: 0,
                steadiness: nil,
                detectedSyllables: measurement?.syllableCount ?? 0,
                targetSyllables: target,
                verdict: .notDetected,
                flags: [],
                stars: 0,
                measurement: measurement
            )
        }

        let isAlternating = sequence.cycleLength > 1
        let floor = steadyRateFloor(age: childAge, isAlternating: isAlternating)
        let rate = measurement.syllablesPerSecond
        let steady = steadiness(intervalCV: measurement.intervalCV)

        // Флаги.
        var flags: [DDKQualityFlag] = []
        if measurement.syllableCount < target - syllableCountTolerance {
            flags.append(.incompleteSequence)
        }
        if measurement.syllableCount > target + syllableCountTolerance {
            flags.append(.extraSyllables)
        }
        if let cv = measurement.intervalCV, cv > unevenCVThreshold {
            flags.append(.unevenRhythm)
        }
        if measurement.peakRMS < weakVoiceRMS {
            flags.append(.weakVoice)
        }

        // Вердикт: сначала темп, затем ритм.
        let verdict: DDKVerdict
        if rate >= floor * fastRateShare, !flags.contains(.unevenRhythm) {
            verdict = .fastSteady
        } else if rate >= floor {
            verdict = flags.contains(.unevenRhythm) ? .uneven : .steady
        } else if flags.contains(.unevenRhythm) {
            verdict = .uneven
        } else {
            verdict = .slow
        }

        let stars = starCount(verdict: verdict, flags: flags)

        return DDKEvaluation(
            syllablesPerSecond: rate,
            steadiness: steady,
            detectedSyllables: measurement.syllableCount,
            targetSyllables: target,
            verdict: verdict,
            flags: flags,
            stars: stars,
            measurement: measurement
        )
    }

    /// Звёзды попытки: 3 — быстро и ровно; 2 — устойчиво или неровно-но-в-темпе;
    /// 1 — медленно/рвано, но ряд получился; 0 — ряд не распознан.
    static func starCount(verdict: DDKVerdict, flags: [DDKQualityFlag]) -> Int {
        switch verdict {
        case .fastSteady:
            return 3
        case .steady:
            // Неполный ряд снижает до 2→ остаётся 2 (темп есть). Полный = 2.
            return flags.contains(.incompleteSequence) ? 2 : 3
        case .uneven:
            return 2
        case .slow:
            return 1
        case .notDetected:
            return 0
        }
    }
}
