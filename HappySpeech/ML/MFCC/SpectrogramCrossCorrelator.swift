import Accelerate
import Foundation
import OSLog

// MARK: - SpectrogramCrossCorrelator

/// Сравнивает две log-mel спектрограммы и возвращает метрики acoustic similarity.
///
/// Используется для:
/// - rule-based детекции корректности произношения (child vs reference)
/// - визуального feedback в `SpeechVisualizationView` (где рассогласование)
/// - оценки sound classification qualitative (когда ML score альтернативный
///   взгляд нужен)
///
/// ### Реализованные метрики
///
/// 1. **Cosine similarity** между усреднёнными по времени mel-векторами —
///    общая «спектральная похожесть» (быстро, грубо).
/// 2. **Frame-wise normalized cross-correlation** с DTW alignment —
///    учитывает temporal jitter (ребёнок говорит быстрее/медленнее эталона).
/// 3. **Per-bin correlation** — даёт картину «в каких частотных диапазонах
///    больше всего различий» (визуализация горячих зон).
///
/// ### COPPA / Performance
///
/// Все вычисления локальные (vDSP). Никаких сетевых вызовов. Сложность
/// `O(T₁·T₂·M)` для DTW (T = число кадров, M = число бинов = 40), что для
/// типичной длительности 1-2 сек составляет ~20 K операций — <5 мс на iPhone 12+.
///
/// ## See Also
/// - ``MelSpectrogramExtractor``
/// - ``SpectrogramSimilarityResult``
public actor SpectrogramCrossCorrelator {

    // MARK: - Logger

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SpectrogramCC")

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Сравнивает две спектрограммы и возвращает полный набор метрик.
    ///
    /// - Parameters:
    ///   - child: log-mel спектрограмма ребёнка
    ///   - reference: эталонная спектрограмма (TTS-сгенерированная или из БД образцов)
    /// - Returns: ``SpectrogramSimilarityResult`` с агрегированными и per-bin метриками
    public func compare(
        child: MelSpectrogram,
        reference: MelSpectrogram
    ) -> SpectrogramSimilarityResult {
        guard !child.frames.isEmpty, !reference.frames.isEmpty else {
            return .empty
        }

        let cosineMean = cosineSimilarityOfMeanVectors(child: child, reference: reference)
        let dtwScore = dtwNormalizedScore(child: child, reference: reference)
        let perBin = perBinCorrelation(child: child, reference: reference)

        // Композитная оценка: 0.4 · cosine + 0.6 · DTW (DTW важнее, учитывает время)
        let composite = 0.4 * cosineMean + 0.6 * dtwScore

        logger.debug(
            "SpectrogramCC: cosine=\(cosineMean), dtw=\(dtwScore), composite=\(composite)"
        )

        return SpectrogramSimilarityResult(
            cosineSimilarity: cosineMean,
            dtwScore: dtwScore,
            perBinCorrelation: perBin,
            compositeScore: composite
        )
    }

    /// Быстрая cosine similarity без DTW — для real-time UI feedback.
    public func quickCosineScore(
        child: MelSpectrogram,
        reference: MelSpectrogram
    ) -> Float {
        guard !child.frames.isEmpty, !reference.frames.isEmpty else { return 0 }
        return cosineSimilarityOfMeanVectors(child: child, reference: reference)
    }

    // MARK: - Cosine Similarity (mean-vector)

    /// Усредняет каждую спектрограмму по времени до вектора длиной 40 (число mel-бинов),
    /// затем cosine similarity между этими двумя векторами.
    private func cosineSimilarityOfMeanVectors(
        child: MelSpectrogram,
        reference: MelSpectrogram
    ) -> Float {
        let childMean = meanByTime(child.frames)
        let refMean = meanByTime(reference.frames)
        guard !childMean.isEmpty, !refMean.isEmpty else { return 0 }
        return cosineSimilarity(childMean, refMean)
    }

    /// Усредняет 2D-массив по первой оси: `[T][M]` → `[M]`.
    private func meanByTime(_ frames: [[Float]]) -> [Float] {
        guard let firstFrame = frames.first else { return [] }
        let m = firstFrame.count
        var acc = [Float](repeating: 0, count: m)
        for frame in frames {
            for i in 0 ..< m {
                acc[i] += frame[i]
            }
        }
        let invCount = 1.0 / Float(frames.count)
        for i in 0 ..< m { acc[i] *= invCount }
        return acc
    }

    /// Cosine similarity двух векторов: `(a·b) / (|a|·|b|)`, нормализован в `[-1, 1]`,
    /// затем масштабирован в `[0, 1]`.
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &normA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &normB, vDSP_Length(b.count))

        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 1e-10 else { return 0 }

        let cos = dot / denom
        return (cos + 1.0) / 2.0  // [-1,1] → [0,1]
    }

    // MARK: - DTW (Dynamic Time Warping)

    /// DTW alignment + нормализованная similarity.
    ///
    /// Использует Euclidean distance между frame-векторами как локальную стоимость.
    /// Возвращает `1 / (1 + avgDistance / referenceMagnitude)` ∈ `(0, 1]`.
    private func dtwNormalizedScore(
        child: MelSpectrogram,
        reference: MelSpectrogram
    ) -> Float {
        let childFrames = child.frames
        let refFrames = reference.frames
        let t1 = childFrames.count
        let t2 = refFrames.count
        guard t1 > 0, t2 > 0 else { return 0 }

        // DP-таблица DTW
        let inf = Float.greatestFiniteMagnitude
        var dp = Array(repeating: Array(repeating: inf, count: t2 + 1), count: t1 + 1)
        dp[0][0] = 0

        for i in 1 ... t1 {
            for j in 1 ... t2 {
                let cost = euclideanDistance(childFrames[i - 1], refFrames[j - 1])
                let prev = min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                dp[i][j] = cost + prev
            }
        }

        let totalCost = dp[t1][t2]
        let pathLen = Float(max(t1, t2))
        let avgCost = totalCost / pathLen

        // Нормализация: малые avgCost → 1.0, большие → 0.0.
        // Эмпирический scale: log-mel значения обычно в диапазоне [-3, 3] →
        // максимально ожидаемая Euclidean distance на 40-D векторе ~ sqrt(40·36) ≈ 38.
        let normalized = 1.0 / (1.0 + avgCost / 8.0)
        return normalized
    }

    /// Euclidean distance двух векторов (vDSP).
    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var diff = [Float](repeating: 0, count: a.count)
        vDSP_vsub(b, 1, a, 1, &diff, 1, vDSP_Length(a.count))
        var sumSq: Float = 0
        vDSP_svesq(diff, 1, &sumSq, vDSP_Length(diff.count))
        return sqrt(sumSq)
    }

    // MARK: - Per-Bin Correlation

    /// Корреляция Пирсона по каждому mel-бину между двумя спектрограммами.
    ///
    /// Если длины разные, обрезаем по минимальной (DTW здесь не применяется, чтобы
    /// сохранить интерпретируемость per-bin метрик).
    ///
    /// - Returns: массив длиной 40, значения в `[-1, 1]` (1 = perfect, -1 = inverse).
    private func perBinCorrelation(
        child: MelSpectrogram,
        reference: MelSpectrogram
    ) -> [Float] {
        let nBins = MelSpectrogram.melBinCount
        let minLen = min(child.frames.count, reference.frames.count)
        guard minLen > 1 else { return [Float](repeating: 0, count: nBins) }

        var result = [Float](repeating: 0, count: nBins)
        for bin in 0 ..< nBins {
            let childCol = (0 ..< minLen).map { child.frames[$0][bin] }
            let refCol = (0 ..< minLen).map { reference.frames[$0][bin] }
            result[bin] = pearsonCorrelation(childCol, refCol)
        }
        return result
    }

    private func pearsonCorrelation(_ a: [Float], _ b: [Float]) -> Float {
        let n = a.count
        guard n > 1, n == b.count else { return 0 }

        var meanA: Float = 0
        var meanB: Float = 0
        vDSP_meanv(a, 1, &meanA, vDSP_Length(n))
        vDSP_meanv(b, 1, &meanB, vDSP_Length(n))

        var diffA = [Float](repeating: 0, count: n)
        var diffB = [Float](repeating: 0, count: n)
        var negMeanA = -meanA
        var negMeanB = -meanB
        vDSP_vsadd(a, 1, &negMeanA, &diffA, 1, vDSP_Length(n))
        vDSP_vsadd(b, 1, &negMeanB, &diffB, 1, vDSP_Length(n))

        var num: Float = 0
        var sumSqA: Float = 0
        var sumSqB: Float = 0
        vDSP_dotpr(diffA, 1, diffB, 1, &num, vDSP_Length(n))
        vDSP_svesq(diffA, 1, &sumSqA, vDSP_Length(n))
        vDSP_svesq(diffB, 1, &sumSqB, vDSP_Length(n))

        let denom = sqrt(sumSqA) * sqrt(sumSqB)
        guard denom > 1e-10 else { return 0 }
        return num / denom
    }
}

// MARK: - SpectrogramSimilarityResult

/// Результат сравнения двух спектрограмм.
public struct SpectrogramSimilarityResult: Sendable, Equatable {

    /// Cosine similarity усреднённых по времени mel-векторов, `[0, 1]`.
    public let cosineSimilarity: Float

    /// DTW-нормализованная similarity, `[0, 1]`.
    public let dtwScore: Float

    /// Per-bin Pearson correlation, длиной 40 (для визуализации hot-spots).
    public let perBinCorrelation: [Float]

    /// Композитная оценка `0.4·cosine + 0.6·DTW`.
    public let compositeScore: Float

    public init(
        cosineSimilarity: Float,
        dtwScore: Float,
        perBinCorrelation: [Float],
        compositeScore: Float
    ) {
        self.cosineSimilarity = cosineSimilarity
        self.dtwScore = dtwScore
        self.perBinCorrelation = perBinCorrelation
        self.compositeScore = compositeScore
    }

    /// Безопасный empty default.
    public static let empty = SpectrogramSimilarityResult(
        cosineSimilarity: 0,
        dtwScore: 0,
        perBinCorrelation: [Float](repeating: 0, count: MelSpectrogram.melBinCount),
        compositeScore: 0
    )

    /// Возвращает индексы bin-ов, где корреляция ниже порога — «проблемные частоты».
    public func problematicBins(threshold: Float = 0.5) -> [Int] {
        perBinCorrelation.enumerated()
            .filter { $0.element < threshold }
            .map { $0.offset }
    }
}
