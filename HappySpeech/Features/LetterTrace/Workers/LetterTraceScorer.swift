import Foundation
import OSLog

// MARK: - LetterTraceScoring

/// Сравнение пользовательских stroke'ов с эталонным контуром.
/// Не диагностика моторики — лишь педагогический числовой фидбек.
public enum LetterTraceScoring {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LetterTrace.Scorer"
    )

    /// Считает similarity 0…1 между пользовательским и эталонным контурами.
    ///
    /// Алгоритм:
    /// 1. Эталонные точки — берём все вершины ломаных, оставляя их как
    ///    набор контрольных точек (denser sampling на длинных сегментах).
    /// 2. Для каждой эталонной точки находим ближайшую пользовательскую,
    ///    собираем массив минимальных расстояний.
    /// 3. mean(distance) трансформируем в similarity = 1 - clamp(mean/threshold).
    /// 4. Полное покрытие: если пользователь не нарисовал ничего —
    ///    similarity = 0; если контур слишком короткий относительно эталона —
    ///    дополнительно penalize.
    ///
    /// Координаты в [0,1] (нормализованные относительно canvas).
    public static func similarity(
        userStrokes: [[TracePoint]],
        referenceStrokes: [[TracePoint]]
    ) -> Double {
        let userPoints = densify(strokes: userStrokes, step: 0.02)
        let refPoints = densify(strokes: referenceStrokes, step: 0.02)
        guard !refPoints.isEmpty else { return 0 }
        guard !userPoints.isEmpty else { return 0 }

        let distances: [Double] = refPoints.map { refPoint in
            nearestDistance(refPoint, in: userPoints)
        }
        let meanDistance = distances.reduce(0, +) / Double(distances.count)
        // distance threshold: 0.18 диагонали холста — комфортный детский допуск.
        let distanceScore = max(0, 1.0 - (meanDistance / 0.18))

        // coverage: насколько user точки покрыли длину эталона.
        let coverage = Self.coverage(userPoints: userPoints, referencePoints: refPoints)
        let raw = distanceScore * 0.7 + coverage * 0.3
        return max(0, min(1, raw))
    }

    // MARK: - Helpers

    private static func densify(strokes: [[TracePoint]], step: Double) -> [TracePoint] {
        var result: [TracePoint] = []
        for stroke in strokes {
            guard !stroke.isEmpty else { continue }
            result.append(stroke[0])
            for i in 1..<stroke.count {
                let a = stroke[i - 1]
                let b = stroke[i]
                let dx = b.x - a.x
                let dy = b.y - a.y
                let len = (dx * dx + dy * dy).squareRoot()
                guard len > step else {
                    result.append(b)
                    continue
                }
                let count = Int(len / step)
                for k in 1...count {
                    let t = Double(k) / Double(count + 1)
                    result.append(TracePoint(x: a.x + dx * t, y: a.y + dy * t))
                }
                result.append(b)
            }
        }
        return result
    }

    private static func nearestDistance(_ point: TracePoint, in cloud: [TracePoint]) -> Double {
        var bestSquared = Double.infinity
        for other in cloud {
            let dx = point.x - other.x
            let dy = point.y - other.y
            let sq = dx * dx + dy * dy
            if sq < bestSquared {
                bestSquared = sq
            }
        }
        return bestSquared.squareRoot()
    }

    /// Сколько эталонных точек имеют пользовательскую соседнюю в пределах 0.15.
    private static func coverage(
        userPoints: [TracePoint],
        referencePoints: [TracePoint]
    ) -> Double {
        guard !referencePoints.isEmpty else { return 0 }
        let threshold = 0.15
        let covered = referencePoints.filter { ref in
            nearestDistance(ref, in: userPoints) <= threshold
        }.count
        return Double(covered) / Double(referencePoints.count)
    }
}

// MARK: - LetterTraceWorkerProtocol

@MainActor
protocol LetterTraceWorkerProtocol {
    func loadItems() -> [TraceItem]
    func score(itemId: String, userStrokes: [[TracePoint]]) -> TraceScore
}

// MARK: - LiveLetterTraceWorker

@MainActor
final class LiveLetterTraceWorker: LetterTraceWorkerProtocol {

    func loadItems() -> [TraceItem] {
        LetterTraceCorpus.allItems
    }

    func score(itemId: String, userStrokes: [[TracePoint]]) -> TraceScore {
        guard let item = LetterTraceCorpus.item(byId: itemId) else {
            return TraceScore(similarity: 0)
        }
        let sim = LetterTraceScoring.similarity(
            userStrokes: userStrokes,
            referenceStrokes: item.strokes
        )
        return TraceScore(similarity: sim)
    }
}
