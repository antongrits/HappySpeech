import Foundation

// MARK: - SibilantPole

/// Полюс акустического континуума «свистящий ↔ шипящий».
public enum SibilantPole: String, Sendable, Equatable {
    /// Свистящие: С, Сь, З, Зь, Ц — высокочастотный шум (узкий желобок).
    case whistling
    /// Шипящие: Ш, Ж, Щ, Ч — более низкий шум (широкая «чашечка»).
    case hissing

    /// Полюс для целевого звука (кириллическая буква, любой регистр),
    /// либо `nil`, если звук не сибилянт (Р/Л/К… акустическим зеркалом не меряются).
    public static func pole(forTargetSound sound: String) -> SibilantPole? {
        guard let first = sound
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .first else { return nil }
        switch first {
        case "С", "З", "Ц": return .whistling
        case "Ш", "Ж", "Щ", "Ч": return .hissing
        default: return nil
        }
    }
}

// MARK: - SibilantVerdict

/// Итог попытки относительно целевого полюса.
public enum SibilantVerdict: String, Sendable, Equatable {
    /// Звук в целевой зоне континуума — отчётливый сибилянт нужного полюса.
    case onTarget
    /// Близко к целевой зоне, но смещён к середине.
    case nearTarget
    /// Звук в середине континуума («между С и Ш»).
    case middle
    /// Звук на ПРОТИВОПОЛОЖНОМ полюсе (классическая замена С↔Ш).
    case oppositePole
    /// Устойчивый фрикативный шум не найден (тишина/гласный/слишком коротко).
    case noFrication
}

// MARK: - SibilantQualityFlag

/// Дополнительные качественные наблюдения (эвристики, не диагноз).
public enum SibilantQualityFlag: String, Sendable, Equatable, CaseIterable {
    /// Спектр сильно размыт — шум диффузный, без чёткого фокуса
    /// (акустически похоже на межзубное/боковое искажение — формулируем мягко).
    case diffuseSpectrum
    /// Слабая воздушная струя — звук тихий относительно возможностей записи.
    case weakAirstream
    /// Сегмент короткий — звук получился, но его стоит «потянуть» дольше.
    case shortSustain
}

// MARK: - SibilantEvaluation

/// Полный результат оценки одной попытки.
public struct SibilantEvaluation: Sendable, Equatable {
    /// Позиция на континууме 0…1: 0 — полюс Ш (низкий шум), 1 — полюс С (высокий).
    public let continuumPosition: Double
    /// Вердикт относительно целевого полюса.
    public let verdict: SibilantVerdict
    /// Качественные флаги.
    public let flags: [SibilantQualityFlag]
    /// Звёзды попытки 0…3 (0 — только при noFrication).
    public let stars: Int
    /// Исходное измерение (для специалиста/отладки); nil при noFrication.
    public let measurement: SibilantMeasurement?
    /// Целевой полюс.
    public let targetPole: SibilantPole

    public init(
        continuumPosition: Double,
        verdict: SibilantVerdict,
        flags: [SibilantQualityFlag],
        stars: Int,
        measurement: SibilantMeasurement?,
        targetPole: SibilantPole
    ) {
        self.continuumPosition = continuumPosition
        self.verdict = verdict
        self.flags = flags
        self.stars = stars
        self.measurement = measurement
        self.targetPole = targetPole
    }
}

// MARK: - SibilantContinuumClassifier

/// Детерминированный маппинг акустического измерения на континуум «С ↔ Ш»
/// и игровой вердикт. Чистая логика без I/O — полностью юнит-тестируема.
///
/// ## Калибровка полюсов
/// Якоря центроида выбраны по данным акустической фонетики ДЕТСКОЙ речи
/// (короткий вокальный тракт сдвигает фрикативный шум вверх): полюс [ш] ≈ 3.8 кГц,
/// полюс [с] ≈ 7.2 кГц. Позиция — лог-частотная интерполяция между якорями
/// (слух воспринимает высоту логарифмически).
///
/// ## Честные границы
/// Якоря и пороги — документированные эвристики, не валидированные на клиническом
/// корпусе. Вердикты сформулированы как игровая обратная связь («звук убежал к Ш»),
/// не как логопедическое заключение (project guide §11).
public enum SibilantContinuumClassifier {

    // MARK: - Калибровочные константы (эвристики, документированы выше)

    /// Якорь центроида полюса Ш, Гц.
    public static let hissingAnchorHz: Double = 3_800
    /// Якорь центроида полюса С, Гц.
    public static let whistlingAnchorHz: Double = 7_200

    /// Зона «в цель»: позиция ≥ 0.68 для С-полюса (симметрично ≤ 0.32 для Ш).
    static let onTargetZone: Double = 0.68
    /// Зона «почти»: позиция ≥ 0.5 в сторону цели.
    static let nearZone: Double = 0.50

    /// Порог диффузного спектра, Гц (спектральное SD усреднённого сегмента).
    static let diffuseSpreadHz: Double = 2_350
    /// Порог слабой струи (пиковая RMS сегмента).
    static let weakAirstreamRMS: Double = 0.03
    /// Порог короткого сегмента, секунды.
    static let shortSustainSec: Double = 0.30

    // MARK: - Public API

    /// Позиция измерения на континууме 0 (Ш) … 1 (С) — лог-частотная интерполяция.
    public static func continuumPosition(centroidHz: Double) -> Double {
        guard centroidHz > 0 else { return 0.5 }
        let low = log(hissingAnchorHz)
        let high = log(whistlingAnchorHz)
        let value = (log(centroidHz) - low) / (high - low)
        return min(1, max(0, value))
    }

    /// Оценивает измерение (или его отсутствие) относительно целевого полюса.
    public static func evaluate(
        measurement: SibilantMeasurement?,
        targetPole: SibilantPole
    ) -> SibilantEvaluation {
        guard let measurement else {
            return SibilantEvaluation(
                continuumPosition: 0.5,
                verdict: .noFrication,
                flags: [],
                stars: 0,
                measurement: nil,
                targetPole: targetPole
            )
        }

        let position = continuumPosition(centroidHz: measurement.centroidHz)
        // «Расстояние к цели» в единицах позиции: для С-полюса цель = 1, для Ш = 0.
        let towardTarget = targetPole == .whistling ? position : 1 - position

        let verdict: SibilantVerdict
        if towardTarget >= onTargetZone {
            verdict = .onTarget
        } else if towardTarget >= nearZone {
            verdict = .nearTarget
        } else if towardTarget >= 1 - onTargetZone {
            verdict = .middle
        } else {
            verdict = .oppositePole
        }

        var flags: [SibilantQualityFlag] = []
        if measurement.spreadHz > diffuseSpreadHz { flags.append(.diffuseSpectrum) }
        if measurement.peakRMS < weakAirstreamRMS { flags.append(.weakAirstream) }
        if measurement.fricationDuration < shortSustainSec { flags.append(.shortSustain) }

        let stars = starCount(verdict: verdict, flags: flags)

        return SibilantEvaluation(
            continuumPosition: position,
            verdict: verdict,
            flags: flags,
            stars: stars,
            measurement: measurement,
            targetPole: targetPole
        )
    }

    /// Звёзды попытки: 3 — в цели и чисто; 2 — в цели с оговоркой или почти;
    /// 1 — звук есть, но не там; 0 — фрикативного звука нет.
    static func starCount(verdict: SibilantVerdict, flags: [SibilantQualityFlag]) -> Int {
        switch verdict {
        case .onTarget:
            return flags.contains(.diffuseSpectrum) ? 2 : 3
        case .nearTarget:
            return 2
        case .middle, .oppositePole:
            return 1
        case .noFrication:
            return 0
        }
    }
}
