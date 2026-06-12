import Foundation

// MARK: - PhonemeProfileTypes
//
// Доменные типы «Фонемного паспорта» — агрегаты и прогноз динамики освоения,
// строящиеся над накопленными `PhonemeObservationDTO`. Это ОЦЕНКА ДИНАМИКИ
// (тренд по относительным метрикам), а НЕ диагноз и не клиническое заключение
// (project guide §11). Никакого аудио / PII в этих типах нет.

// MARK: - PhonemeWordPosition

/// Позиция фонемы в слове. Соответствует строковому полю модели/DTO.
public enum PhonemeWordPosition: String, Sendable, CaseIterable, Codable {
    case initial
    case medial
    case final

    /// Безопасный разбор строки наблюдения (неизвестное → .initial).
    public init(rawOrInitial raw: String) {
        self = PhonemeWordPosition(rawValue: raw) ?? .initial
    }

    /// Краткая русская метка для UI/экспорта.
    public var ruShort: String {
        switch self {
        case .initial: return "нач."
        case .medial:  return "сер."
        case .final:   return "кон."
        }
    }
}

// MARK: - PhonemeState

/// Агрегированное состояние фонемы в позиции — выводится из исходов наблюдений
/// (поле `defect`), а не из абсолютных порогов. Относительная интерпретация.
public enum PhonemeState: String, Sendable, Codable {
    /// Нет наблюдений в этой ячейке матрицы.
    case noData
    /// Преобладает корректное произнесение.
    case ok
    /// Преобладает искажение (звук есть, но смазан).
    case distortion
    /// Преобладает закономерная возрастная замена (Р→Л и т.п.).
    case ageSubstitution
    /// Преобладает замена на другой звук (не возрастная).
    case substitution
    /// Преобладает пропуск фонемы.
    case omission

    /// Русская метка состояния для специалиста.
    public var ruLabel: String {
        switch self {
        case .noData:          return "нет данных"
        case .ok:              return "норма"
        case .distortion:      return "искажение"
        case .ageSubstitution: return "возрастная замена"
        case .substitution:    return "замена"
        case .omission:        return "пропуск"
        }
    }
}

// MARK: - PhonemePositionCell

/// Одна ячейка матрицы «фонема × позиция».
public struct PhonemePositionCell: Sendable, Equatable, Identifiable {
    public var id: String { "\(phoneme)|\(position.rawValue)" }
    /// Целевая фонема (IPA).
    public let phoneme: String
    public let position: PhonemeWordPosition
    public let state: PhonemeState
    /// Число наблюдений в этой ячейке.
    public let observationCount: Int
    /// EWMA-уровень GOP, нормированный self-baseline'ом ребёнка в [0, 1].
    /// nil — если наблюдений нет.
    public let level: Double?
    /// Наиболее частый конкурент (IPA) для замен, иначе nil.
    public let dominantCompetitor: String?

    public init(
        phoneme: String,
        position: PhonemeWordPosition,
        state: PhonemeState,
        observationCount: Int,
        level: Double?,
        dominantCompetitor: String?
    ) {
        self.phoneme = phoneme
        self.position = position
        self.state = state
        self.observationCount = observationCount
        self.level = level
        self.dominantCompetitor = dominantCompetitor
    }
}

// MARK: - PhonemeProblem

/// Проблемная фонема для «топ-N» сводки паспорта.
public struct PhonemeProblem: Sendable, Equatable, Identifiable {
    public var id: String { phoneme }
    public let phoneme: String
    /// Усреднённый self-baseline уровень по всем позициям [0, 1] (меньше = хуже).
    public let level: Double
    /// Совокупное число наблюдений по всем позициям.
    public let observationCount: Int
    /// Преобладающее состояние (для подписи в UI).
    public let state: PhonemeState
    /// Доминирующий конкурент-замена (IPA), если есть.
    public let dominantCompetitor: String?

    public init(
        phoneme: String,
        level: Double,
        observationCount: Int,
        state: PhonemeState,
        dominantCompetitor: String?
    ) {
        self.phoneme = phoneme
        self.level = level
        self.observationCount = observationCount
        self.state = state
        self.dominantCompetitor = dominantCompetitor
    }
}

// MARK: - PhonemeProfile

/// Полный агрегат «Фонемного паспорта» ребёнка на момент построения.
///
/// Содержит матрицу «фонема × позиция», общее число наблюдений и топ-3 проблемные
/// фонемы. Все уровни — относительные (self-baseline перцентили ребёнка), поэтому
/// корректно сравнивать ребёнка с самим собой во времени, а не с популяцией.
/// Оценка динамики, не диагноз.
public struct PhonemeProfile: Sendable, Equatable {
    public let childId: String
    /// Дата построения снимка.
    public let generatedAt: Date
    /// Матрица «фонема × позиция». Содержит только наблюдавшиеся фонемы.
    public let cells: [PhonemePositionCell]
    /// Общее число наблюдений, по которым построен паспорт.
    public let totalObservations: Int
    /// Топ-3 наиболее проблемные фонемы (по возрастанию уровня).
    public let topProblems: [PhonemeProblem]
    /// `true`, когда наблюдений достаточно для калибровки self-baseline
    /// (≥ `PhonemeProfileMath.baselineSampleSize`).
    public let isCalibrated: Bool

    public init(
        childId: String,
        generatedAt: Date = Date(),
        cells: [PhonemePositionCell],
        totalObservations: Int,
        topProblems: [PhonemeProblem],
        isCalibrated: Bool
    ) {
        self.childId = childId
        self.generatedAt = generatedAt
        self.cells = cells
        self.totalObservations = totalObservations
        self.topProblems = topProblems
        self.isCalibrated = isCalibrated
    }

    /// Пустой паспорт (наблюдений нет).
    public static func empty(childId: String, generatedAt: Date = Date()) -> PhonemeProfile {
        PhonemeProfile(
            childId: childId,
            generatedAt: generatedAt,
            cells: [],
            totalObservations: 0,
            topProblems: [],
            isCalibrated: false
        )
    }
}

// MARK: - MasteryForecast

/// Прогноз динамики освоения одной фонемы.
///
/// Строится только при ≥ `PhonemeProfileMath.minForecastObservations` наблюдениях.
/// Уровень — EWMA по self-baseline перцентилям; тренд — робастный Theil-Sen наклон
/// по (дата, EWMA-GOP). ETA до автоматизации = (τ − level)/slope, клампится в
/// [1, 12] недель. CI берётся из IQR множества попарных наклонов Theil-Sen.
///
/// Это ОЦЕНКА ДИНАМИКИ, а не диагноз и не гарантия результата (project guide §11).
public struct MasteryForecast: Sendable, Equatable {
    /// Исход прогноза.
    public enum Status: String, Sendable, Codable {
        /// Недостаточно наблюдений для прогноза.
        case insufficientData
        /// Положительная динамика — есть прогноз ETA.
        case improving
        /// Уже на уровне автоматизации (level ≥ τ).
        case mastered
        /// Нулевой/отрицательный тренд — рекомендуется консультация специалиста.
        case needsConsultation
    }

    public let childId: String
    public let phoneme: String
    public let status: Status
    /// Текущий EWMA-уровень в self-baseline шкале [0, 1].
    public let currentLevel: Double
    /// Theil-Sen наклон (единиц уровня в неделю). Может быть ≤ 0.
    public let weeklySlope: Double
    /// Число наблюдений, по которым построен прогноз.
    public let observationCount: Int
    /// Оценка недель до автоматизации (clamp [1, 12]). nil — кроме `.improving`.
    public let estimatedWeeksToMastery: Int?
    /// Нижняя граница доверительного интервала ETA (недели), если применимо.
    public let etaLowerWeeks: Int?
    /// Верхняя граница доверительного интервала ETA (недели), если применимо.
    public let etaUpperWeeks: Int?

    public init(
        childId: String,
        phoneme: String,
        status: Status,
        currentLevel: Double,
        weeklySlope: Double,
        observationCount: Int,
        estimatedWeeksToMastery: Int?,
        etaLowerWeeks: Int?,
        etaUpperWeeks: Int?
    ) {
        self.childId = childId
        self.phoneme = phoneme
        self.status = status
        self.currentLevel = currentLevel
        self.weeklySlope = weeklySlope
        self.observationCount = observationCount
        self.estimatedWeeksToMastery = estimatedWeeksToMastery
        self.etaLowerWeeks = etaLowerWeeks
        self.etaUpperWeeks = etaUpperWeeks
    }

    /// Конструктор «данных недостаточно».
    public static func insufficient(
        childId: String,
        phoneme: String,
        observationCount: Int,
        currentLevel: Double = 0
    ) -> MasteryForecast {
        MasteryForecast(
            childId: childId,
            phoneme: phoneme,
            status: .insufficientData,
            currentLevel: currentLevel,
            weeklySlope: 0,
            observationCount: observationCount,
            estimatedWeeksToMastery: nil,
            etaLowerWeeks: nil,
            etaUpperWeeks: nil
        )
    }
}
