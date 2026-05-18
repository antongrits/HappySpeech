import Foundation

// MARK: - TempoAnalyzer
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Чистая (pure) утилита анализа ровности темпа по моментам отбитых слогов.
// Метрика — коэффициент вариации межслоговых интервалов (CV = σ / μ):
// чем ниже CV, тем ровнее темп. Это стандартный показатель ритмичности,
// устойчивый к абсолютной скорости (что важно: цель — ровность, не быстрота).
//
// Полностью детерминирована и offline — легко покрывается unit-тестами.

enum TempoAnalyzer {

    /// Порог CV для оценки «ровно».
    static let smoothThreshold = 0.22
    /// Порог CV для оценки «немного неровно».
    static let slightlyUnevenThreshold = 0.45

    /// Вычисляет коэффициент вариации межударных интервалов.
    /// Возвращает 0, если ударов недостаточно для оценки (< 3).
    static func variationCoefficient(of beatTimestamps: [TimeInterval]) -> Double {
        let sorted = beatTimestamps.sorted()
        guard sorted.count >= 3 else { return 0 }

        var intervals: [TimeInterval] = []
        for index in 1..<sorted.count {
            intervals.append(sorted[index] - sorted[index - 1])
        }
        let positive = intervals.filter { $0 > 0 }
        guard positive.count >= 2 else { return 0 }

        let mean = positive.reduce(0, +) / Double(positive.count)
        guard mean > 0 else { return 0 }

        let variance = positive
            .map { ($0 - mean) * ($0 - mean) }
            .reduce(0, +) / Double(positive.count)
        let stdDev = variance.squareRoot()
        return stdDev / mean
    }

    /// Качественная оценка темпа по моментам ударов.
    static func rating(for beatTimestamps: [TimeInterval]) -> TempoRating {
        // Недостаточно ударов — считаем неровным (ребёнок не отбил рисунок).
        guard beatTimestamps.count >= 3 else { return .uneven }
        return rating(forVariationCoefficient: variationCoefficient(of: beatTimestamps))
    }

    /// Качественная оценка темпа по уже вычисленному CV.
    static func rating(forVariationCoefficient coefficient: Double) -> TempoRating {
        if coefficient <= smoothThreshold {
            return .smooth
        } else if coefficient <= slightlyUnevenThreshold {
            return .slightlyUneven
        } else {
            return .uneven
        }
    }
}
