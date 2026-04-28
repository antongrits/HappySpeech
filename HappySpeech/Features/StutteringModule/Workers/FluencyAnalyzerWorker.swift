import Foundation
import OSLog

// MARK: - OnsetClassification

enum OnsetClassification: Sendable, Equatable {
    case soft         // attackTime >= threshold (100+ ms)
    case borderline   // attackTime 50–99 ms
    case hard         // attackTime < 50 ms
}

// MARK: - FluencyAnalyzerWorkerProtocol

protocol FluencyAnalyzerWorkerProtocol: AnyObject, Sendable {
    /// Calculates attack time from a rolling RMS buffer and classifies onset.
    /// - Parameter rmsBuffer: Array of RMS values sampled at 50ms intervals.
    /// - Parameter threshold: Adaptive threshold (baseline × multiplier).
    /// - Parameter difficulty: Determines threshold for soft/hard boundary.
    func classifyOnset(
        rmsBuffer: [Float],
        threshold: Float,
        difficulty: StutteringDifficulty
    ) -> (classification: OnsetClassification, attackTimeMs: Float)

    /// Counts dysfluency markers in a WhisperKit transcript.
    func analyzeDysfluency(transcript: String) -> (repetitions: Int, totalTokens: Int)

    /// Estimates total syllable count from a Russian transcript using simple heuristic.
    func estimateSyllableCount(in text: String) -> Int

    /// Computes dysfluency rate: dysfluencies * 100 / totalSyllables.
    func dysfluencyRate(count: Int, syllables: Int) -> Float
}

// MARK: - FluencyAnalyzerWorker

final class FluencyAnalyzerWorker: FluencyAnalyzerWorkerProtocol, @unchecked Sendable {

    private let logger = HSLogger.ml

    // MARK: - Onset classification

    func classifyOnset(
        rmsBuffer: [Float],
        threshold: Float,
        difficulty: StutteringDifficulty
    ) -> (classification: OnsetClassification, attackTimeMs: Float) {
        // RMS buffer sampled at 20 Hz (50 ms per tick).
        let tickMs: Float = 50

        // Find index where amplitude first crosses noiseFloor (>0.05).
        let noiseFloor: Float = 0.05
        guard let onsetIdx = rmsBuffer.firstIndex(where: { $0 > noiseFloor }) else {
            return (.hard, 0)
        }

        // Peak RMS in first 500 ms (10 ticks).
        let window = Array(rmsBuffer.prefix(10))
        let peakRMS = window.max() ?? 0
        guard peakRMS > threshold else {
            return (.hard, 0)
        }

        // Time from first crossing noiseFloor to reaching 80% of peak.
        let targetRMS = peakRMS * 0.8
        let attackEnd = rmsBuffer.dropFirst(onsetIdx).firstIndex(where: { $0 >= targetRMS })
        let attackTickCount: Float
        if let endIdx = attackEnd {
            attackTickCount = Float(endIdx - onsetIdx)
        } else {
            attackTickCount = Float(rmsBuffer.count - onsetIdx)
        }
        let attackTimeMs = attackTickCount * tickMs

        let softThreshold = difficulty.attackTimeThresholdMs
        let classification: OnsetClassification
        if attackTimeMs >= softThreshold {
            classification = .soft
        } else if attackTimeMs >= 50 {
            classification = .borderline
        } else {
            classification = .hard
        }

        logger.info(
            "FluencyAnalyzer onset: attackMs=\(attackTimeMs, privacy: .public) class=\(String(describing: classification), privacy: .public)"
        )
        return (classification, attackTimeMs)
    }

    // MARK: - Dysfluency analysis

    func analyzeDysfluency(transcript: String) -> (repetitions: Int, totalTokens: Int) {
        let words = transcript
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let totalTokens = words.count

        // Simple repetition heuristic: consecutive identical tokens or 2-3 char prefix repeats.
        var repetitions = 0
        for i in 1..<words.count {
            let prev = words[i - 1]
            let curr = words[i]
            if prev == curr {
                repetitions += 1
                continue
            }
            // Syllable-level repetition: ма-ма, ба-ба (token[0..2] == token[0..2])
            let prevPrefix = String(prev.prefix(3))
            let currPrefix = String(curr.prefix(3))
            if prevPrefix == currPrefix && prevPrefix.count >= 2 {
                repetitions += 1
            }
        }

        logger.info(
            "FluencyAnalyzer dysfluency: repetitions=\(repetitions, privacy: .public) tokens=\(totalTokens, privacy: .public)"
        )
        return (repetitions, totalTokens)
    }

    // MARK: - Syllable count (Russian heuristic: count vowels)

    func estimateSyllableCount(in text: String) -> Int {
        let vowels = CharacterSet(charactersIn: "аеёиоуыэюяАЕЁИОУЫЭЮЯaeiouyAEIOUY")
        return text.unicodeScalars.filter { vowels.contains($0) }.count
    }

    // MARK: - Rate

    func dysfluencyRate(count: Int, syllables: Int) -> Float {
        guard syllables > 0 else { return 0 }
        return Float(count * 100) / Float(syllables)
    }
}
