import Foundation

// MARK: - BeatScorer
//
// Чистая логика без I/O. Сопоставляет detected-tap'ы с expected-beat'ами
// по принципу:
//
//   Для каждого expected-beat ищем ближайший ещё не использованный tap
//   в окне ±tolerance. Если нашли — это hit, tap «израсходован».
//   Если не нашли — miss. Tap'ы, оставшиеся неиспользованными — extras.
//
// Из этого получаем precision / recall / F1.
//
// Почему F1 а не простой recall: при простом recall ребёнок может тапать
// без остановки и получить 100%. F1 балансирует пропуски и «лишние» тапы
// — это честнее как метрика ритма.
// CTO-decision-default Wave F Ф.7.

struct BeatScorer: Sendable {

    /// Окно толерантности (±). По умолчанию 150 мс (см. ТЗ).
    let toleranceSeconds: Double

    init(toleranceSeconds: Double = 0.150) {
        self.toleranceSeconds = max(0.020, toleranceSeconds)
    }

    /// Возвращает полную оценку упражнения.
    func score(expected: [ExpectedBeat], detected: [DetectedTap]) -> ExerciseScore {
        // Greedy ближайший-сосед с одноразовым потреблением tap'ов.
        // Идея: сортируем по времени, для каждого expected берём ближайший
        // tap в окне; если ещё не использован — hit.
        let sortedExpected = expected.sorted { $0.timeSeconds < $1.timeSeconds }
        let sortedTaps = detected.sorted { $0.timeSeconds < $1.timeSeconds }
        var taken = Array(repeating: false, count: sortedTaps.count)
        var hits = 0

        for beat in sortedExpected {
            let (idx, dist) = nearestAvailableTap(
                to: beat.timeSeconds,
                in: sortedTaps,
                taken: taken
            )
            if let i = idx, dist <= toleranceSeconds {
                taken[i] = true
                hits += 1
            }
        }

        let totalExpected = sortedExpected.count
        let totalDetected = sortedTaps.count
        let misses = totalExpected - hits
        let extras = totalDetected - hits
        let precision = totalDetected > 0 ? Double(hits) / Double(totalDetected) : 0
        let recall = totalExpected > 0 ? Double(hits) / Double(totalExpected) : 0
        let f1: Double
        if precision + recall > 0 {
            f1 = 2 * precision * recall / (precision + recall)
        } else {
            f1 = 0
        }

        return ExerciseScore(
            expectedBeats: totalExpected,
            detectedTaps: totalDetected,
            hits: hits,
            misses: misses,
            extras: extras,
            precision: precision,
            recall: recall,
            f1: f1
        )
    }

    /// 0…3 ★ из F1.
    /// 3★ при F1 ≥ 0.85, 2★ ≥ 0.6, 1★ ≥ 0.3, 0★ иначе.
    func stars(forF1 f1: Double) -> Int {
        switch f1 {
        case 0.85...:
            return 3
        case 0.6...:
            return 2
        case 0.3...:
            return 1
        default:
            return 0
        }
    }

    // MARK: - Private

    private func nearestAvailableTap(
        to t: Double,
        in taps: [DetectedTap],
        taken: [Bool]
    ) -> (index: Int?, distance: Double) {
        var bestIdx: Int?
        var bestDist = Double.infinity
        for (i, tap) in taps.enumerated() where !taken[i] {
            let d = abs(tap.timeSeconds - t)
            if d < bestDist {
                bestDist = d
                bestIdx = i
            }
        }
        return (bestIdx, bestDist)
    }
}

// MARK: - Expected beats builder

extension BeatScorer {

    /// Строит ожидаемые beat'ы из паттерна упражнения.
    /// beat-индекс i стартует в момент `cumulativeBeats[i] * beatDuration`,
    /// где cumulativeBeats — кумулятивная сумма pattern до i.
    static func buildExpectedBeats(for exercise: LogorhythmicsExercise) -> [ExpectedBeat] {
        let beatDuration = exercise.beatDurationSeconds
        let strongSet = Set(exercise.strongBeats)
        var result: [ExpectedBeat] = []
        var cursor: Double = 0
        for (i, dur) in exercise.pattern.enumerated() {
            result.append(
                ExpectedBeat(
                    index: i,
                    timeSeconds: cursor,
                    isStrong: strongSet.contains(i)
                )
            )
            cursor += Double(dur) * beatDuration
        }
        return result
    }
}
