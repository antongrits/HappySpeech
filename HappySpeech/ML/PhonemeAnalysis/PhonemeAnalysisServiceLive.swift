import Accelerate
import AVFoundation
@preconcurrency import CoreML
import Foundation
import OSLog

// MARK: - MFCCExtractorAdapter

/// Адаптер, оборачивающий `MFCCExtractor` (AVAudioPCMBuffer API) для работы с сырым PCM Data.
///
/// **Block D placeholder:** конвертирует Data → AVAudioPCMBuffer → вызывает MFCCExtractor.
/// Block G v13 заменит на real MFCC pipeline непосредственно из Data.
///
/// Выход: массив фреймов [[Float]] (39 коэффициентов каждый, 150 фреймов).
public struct MFCCExtractorAdapter: MFCCExtractorProtocol {

    private static let sampleRate: Double = 16_000
    /// Количество MFCC коэф. соответствует модели (39, не 40 — модель обучена на 39).
    private static let nMFCC = RussianPhonemeClassifierWrapper.nMFCC
    private static let nFrames = RussianPhonemeClassifierWrapper.nFrames

    public init() {}

    public func extract(from audio: Data) async throws -> [[Float]] {
        // Конвертируем сырой Float32 PCM Data в AVAudioPCMBuffer
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        )
        guard let format else {
            throw PhonemeAnalysisError.mfccExtractionFailed
        }

        let frameCount = audio.count / MemoryLayout<Float>.size
        guard frameCount > 0 else {
            throw PhonemeAnalysisError.mfccExtractionFailed
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw PhonemeAnalysisError.mfccExtractionFailed
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // Копируем сырые Float32 семплы в буфер
        audio.withUnsafeBytes { rawBytes in
            guard let srcPtr = rawBytes.bindMemory(to: Float.self).baseAddress,
                  let dstPtr = buffer.floatChannelData?[0] else { return }
            dstPtr.update(from: srcPtr, count: frameCount)
        }

        // Используем существующий MFCCExtractor
        let mlArray = try MFCCExtractor.extract(from: buffer)

        // Транспонируем MLMultiArray [1, 40, 150] → [[Float]] 150×40
        // Затем берём только nMFCC=39 коэффициентов (1 отбрасываем, 0-й коэф. обычно DC)
        return convertMLArrayToFrames(mlArray)
    }

    // MARK: Private

    /// Конвертирует MLMultiArray [1, nMFCC_full, T] в [[Float]] T×nMFCC_model.
    private func convertMLArrayToFrames(_ array: MLMultiArray) -> [[Float]] {
        let tSteps = Int(truncating: array.shape[2])
        let nFull = Int(truncating: array.shape[1])
        let take = min(nFull, Self.nMFCC)

        var frames: [[Float]] = []
        frames.reserveCapacity(tSteps)

        for tIdx in 0 ..< tSteps {
            var frame = [Float](repeating: 0, count: Self.nMFCC)
            for coeff in 0 ..< take {
                frame[coeff] = array[[0, coeff, tIdx] as [NSNumber]].floatValue
            }
            frames.append(frame)
        }

        return frames
    }
}

// MARK: - MockMFCCExtractor

/// Mock MFCC экстрактор для unit-тестов — возвращает синтетические фреймы.
public struct MockMFCCExtractor: MFCCExtractorProtocol, Sendable {
    private let nMFCC: Int
    private let nFrames: Int
    private let fillValue: Float

    public init(
        nMFCC: Int = RussianPhonemeClassifierWrapper.nMFCC,
        nFrames: Int = RussianPhonemeClassifierWrapper.nFrames,
        fillValue: Float = 0.1
    ) {
        self.nMFCC = nMFCC
        self.nFrames = nFrames
        self.fillValue = fillValue
    }

    public func extract(from audio: Data) async throws -> [[Float]] {
        let frame = Array(repeating: fillValue, count: nMFCC)
        return Array(repeating: frame, count: nFrames)
    }
}

// MARK: - PhonemeAnalysisServiceLive

/// Живая реализация фонемного анализа произношения.
///
/// Пайплайн:
/// 1. G2PWorker → ожидаемые фонемы из словаря (или правиловой fallback)
/// 2. MFCCExtractor → MFCC фреймы из PCM аудио
/// 3. RussianPhonemeClassifierWrapper → предсказанные фонемы (CoreML)
/// 4. DTW alignment → alignmentScore (0.0–1.0)
/// 5. Per-phoneme scoring → оценка уверенности для каждой фонемы
/// 6. Problem phonemes → фонемы с score < 0.6
///
/// **Confidence threshold:** logit softmax > 0.5 (что соответствует logit > 2.0 при 49 классах).
///
/// ## See Also
/// - ``PhonemeAnalysisService``
/// - ``G2PWorker``
/// - ``RussianPhonemeClassifierWrapper``
public actor PhonemeAnalysisServiceLive: PhonemeAnalysisService {

    private let logger = Logger(subsystem: "HappySpeech", category: "PhonemeAnalysisService")

    private let g2p: G2PWorker
    private let classifier: RussianPhonemeClassifierWrapper
    private let mfccExtractor: any MFCCExtractorProtocol

    // MARK: - Init

    public init(
        g2p: G2PWorker,
        classifier: RussianPhonemeClassifierWrapper,
        mfccExtractor: any MFCCExtractorProtocol
    ) {
        self.g2p = g2p
        self.classifier = classifier
        self.mfccExtractor = mfccExtractor
    }

    // MARK: - PhonemeAnalysisService

    public func analyze(audio: Data, expectedWord: String) async throws -> PhonemeAnalysisResult {
        logger.debug("PhonemeAnalysis: начало анализа слова '\(expectedWord)'")

        // 1. G2P: получаем ожидаемые фонемы
        let expected = try await g2p.transcribe(expectedWord)
        logger.debug("PhonemeAnalysis: ожидаемых фонем = \(expected.count)")

        // 2. MFCC из аудио
        let mfccFrames = try await mfccExtractor.extract(from: audio)

        // 3. Classifier: предсказываем фонемы по фреймам
        let predicted = try await classifier.predict(mfcc: mfccFrames)

        // 4. DTW alignment (expected phoneme sequence vs predicted frame sequence)
        let alignmentScore = scoreAlignment(expected: expected, predicted: predicted)

        // 5. Per-phoneme scoring
        let perPhonemeScore = computePerPhonemeScore(expected: expected, predicted: predicted)

        // 6. Problem phonemes (score < 0.6)
        let problemPhonemes = expected.filter { phoneme in
            (perPhonemeScore[phoneme.ipa] ?? 0.0) < 0.6
        }

        // 7. Overall score (среднее по всем ожидаемым фонемам)
        let overallScore: Double
        if perPhonemeScore.isEmpty {
            overallScore = 0.0
        } else {
            overallScore = perPhonemeScore.values.reduce(0.0, +) / Double(perPhonemeScore.count)
        }

        let problemList = problemPhonemes.map(\.ipa).joined(separator: ",")
        let overallFormatted = String(format: "%.2f", overallScore)
        logger.info("PhonemeAnalysis: '\(expectedWord, privacy: .public)' — overall=\(overallFormatted, privacy: .public), problems=\(problemList, privacy: .public)")

        return PhonemeAnalysisResult(
            expectedPhonemes: expected,
            predictedPhonemes: predicted,
            alignmentScore: alignmentScore,
            perPhonemeScore: perPhonemeScore,
            overallScore: overallScore,
            problemPhonemes: problemPhonemes
        )
    }

    // MARK: - DTW Alignment

    /// Вычисляет DTW (Dynamic Time Warping) score между ожидаемой и предсказанной последовательностями.
    ///
    /// Нормирует edit distance до [0.0, 1.0]:
    /// - 1.0 — идеальное совпадение (нулевые вставки/удаления)
    /// - 0.0 — полное несовпадение
    private func scoreAlignment(expected: [Phoneme], predicted: [PhonemeAlignment]) -> Double {
        guard !expected.isEmpty, !predicted.isEmpty else { return 0.0 }

        let m = expected.count
        // Сжимаем predicted до m * 4 максимально значимых фреймов
        let compressed = compressPredicted(predicted, toCount: min(predicted.count, m * 6))

        let n = compressed.count

        // DTW матрица (m+1) × (n+1)
        var dtw = [[Double]](
            repeating: [Double](repeating: Double.infinity, count: n + 1),
            count: m + 1
        )
        dtw[0][0] = 0.0

        for i in 1 ... m {
            for j in 1 ... n {
                let cost = expected[i - 1].ipa == compressed[j - 1].predictedIPA ? 0.0 : 1.0
                dtw[i][j] = cost + Swift.min(
                    dtw[i - 1][j],     // insertion
                    dtw[i][j - 1],     // deletion
                    dtw[i - 1][j - 1]  // match/replace
                )
            }
        }

        let dtwDistance = dtw[m][n]
        let maxDistance = Double(m + n)
        let normalizedDistance = dtwDistance / max(maxDistance, 1.0)
        return Swift.max(0.0, 1.0 - normalizedDistance)
    }

    /// Оставляет только фреймы с наибольшей уверенностью, сжимая до `toCount` элементов.
    private func compressPredicted(_ predicted: [PhonemeAlignment], toCount count: Int) -> [PhonemeAlignment] {
        guard predicted.count > count else { return predicted }
        let step = Double(predicted.count) / Double(count)
        return (0 ..< count).map { idx in
            predicted[Int(Double(idx) * step)]
        }
    }

    // MARK: - Per-Phoneme Scoring

    /// Вычисляет оценку уверенности для каждой ожидаемой фонемы.
    ///
    /// Логика: для каждой ожидаемой фонемы ищет в predicted фреймах сегмент,
    /// соответствующий временному окну этой фонемы, и берёт максимальную
    /// уверенность среди фреймов с совпадающей IPA.
    ///
    /// Fallback: если ни один фрейм не предсказал эту фонему → score = среднее confidence × 0.3.
    private func computePerPhonemeScore(
        expected: [Phoneme],
        predicted: [PhonemeAlignment]
    ) -> [String: Double] {
        guard !expected.isEmpty, !predicted.isEmpty else { return [:] }

        var scores: [String: Double] = [:]
        let totalPhonemes = expected.count
        let framesPerPhoneme = max(1, predicted.count / totalPhonemes)

        for (phonemeIdx, phoneme) in expected.enumerated() {
            // Временное окно: фреймы соответствующие позиции этой фонемы
            let windowStart = phonemeIdx * framesPerPhoneme
            let windowEnd = min(windowStart + framesPerPhoneme * 2, predicted.count)

            guard windowStart < predicted.count else {
                scores[phoneme.ipa] = (scores[phoneme.ipa] ?? 0.0).isNaN ? 0.0 : (scores[phoneme.ipa] ?? 0.0)
                continue
            }

            let windowFrames = Array(predicted[windowStart ..< windowEnd])

            // Ищем фреймы, предсказавшие эту фонему с высокой уверенностью
            let matchingFrames = windowFrames.filter { $0.predictedIPA == phoneme.ipa }

            if matchingFrames.isEmpty {
                // Нет совпадений в окне — penalty score
                let avgConfidence = windowFrames.map(\.confidence).reduce(0.0, +) / Double(windowFrames.count)
                scores[phoneme.ipa] = avgConfidence * 0.3
            } else {
                // Берём максимальную уверенность среди совпадающих фреймов
                let maxConfidence = matchingFrames.map(\.confidence).max() ?? 0.0
                // Если фонема встречается несколько раз в слове — берём max
                scores[phoneme.ipa] = Swift.max(scores[phoneme.ipa] ?? 0.0, maxConfidence)
            }
        }

        return scores
    }
}

// MARK: - MockPhonemeAnalysisService

/// Mock-реализация для unit-тестов и SwiftUI Preview.
public actor MockPhonemeAnalysisService: PhonemeAnalysisService {
    public var simulatedOverallScore: Double
    public var simulatedProblemIPAs: [String]

    public init(overallScore: Double = 0.85, problemIPAs: [String] = []) {
        self.simulatedOverallScore = overallScore
        self.simulatedProblemIPAs = problemIPAs
    }

    public func analyze(audio: Data, expectedWord: String) async throws -> PhonemeAnalysisResult {
        let expected = [Phoneme(ipa: "a", position: 0), Phoneme(ipa: "b", position: 1)]
        let predicted = [PhonemeAlignment(frameIndex: 0, predictedIPA: "a", confidence: 0.9)]
        let perScore: [String: Double] = expected.reduce(into: [:]) { dict, p in
            dict[p.ipa] = simulatedProblemIPAs.contains(p.ipa) ? 0.4 : simulatedOverallScore
        }
        let problems = expected.filter { simulatedProblemIPAs.contains($0.ipa) }

        return PhonemeAnalysisResult(
            expectedPhonemes: expected,
            predictedPhonemes: predicted,
            alignmentScore: simulatedOverallScore,
            perPhonemeScore: perScore,
            overallScore: simulatedOverallScore,
            problemPhonemes: problems
        )
    }
}
