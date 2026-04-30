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

    // MARK: - Real transcript analysis (WhisperKit path)

    /// Анализирует WhisperTranscript для детектирования дисфлюентностей.
    /// Три класса: повторения (regex), пролонгации (сегмент > 300ms на 1–2 символа), внутрисловные паузы (> 800ms).
    func analyzeRealTranscript(_ transcript: WhisperTranscript) -> DysfluencyAnalysis {
        let repetitions = detectRepetitions(in: transcript.fullText)
        let prolongations = detectProlongations(in: transcript.segments)
        let insideWordPauses = detectInsideWordPauses(in: transcript.segments)

        let vowels: Set<Character> = ["а", "е", "ё", "и", "о", "у", "ы", "э", "ю", "я"]
        let totalSyllables = transcript.fullText.lowercased().filter { vowels.contains($0) }.count

        let dysfluencyCount = repetitions + prolongations + insideWordPauses
        let rate = totalSyllables > 0
            ? Float(dysfluencyCount) * 100.0 / Float(totalSyllables)
            : 0.0

        logger.info("FluencyAnalyzer real: rep=\(repetitions, privacy: .public) prol=\(prolongations, privacy: .public)")
        logger.info("FluencyAnalyzer real: pauses=\(insideWordPauses, privacy: .public) syl=\(totalSyllables, privacy: .public) rate=\(rate, privacy: .public)")

        return DysfluencyAnalysis(
            repetitions: repetitions,
            prolongations: prolongations,
            insideWordPauses: insideWordPauses,
            totalSyllables: totalSyllables,
            rate: rate,
            isStub: false
        )
    }

    /// Stub-анализ для graceful fallback когда WhisperKit недоступен.
    func makeStubAnalysis(text: String) -> DysfluencyAnalysis {
        let (repetitions, _) = analyzeDysfluency(transcript: text)
        let syllables = estimateSyllableCount(in: text)
        let rate = dysfluencyRate(count: repetitions, syllables: syllables)
        return DysfluencyAnalysis(
            repetitions: repetitions,
            prolongations: 0,
            insideWordPauses: 0,
            totalSyllables: syllables,
            rate: rate,
            isStub: true
        )
    }

    // MARK: - Private helpers

    private func detectRepetitions(in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"\b(\w{2,})\s+\1\b"#) else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, range: range)
    }

    private func detectProlongations(in segments: [WhisperSegment]) -> Int {
        // Короткий токен (≤2 видимых символа без пробелов) длительностью > 300ms → растяжение гласной
        segments.filter { seg in
            let trimmed = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let durMs = seg.endMs - seg.startMs
            return trimmed.count <= 2 && durMs > 300
        }.count
    }

    private func detectInsideWordPauses(in segments: [WhisperSegment]) -> Int {
        guard segments.count > 1 else { return 0 }
        var count = 0
        for i in 0..<(segments.count - 1) {
            let cur = segments[i]
            let next = segments[i + 1]
            let gapMs = next.startMs - cur.endMs
            // Внутрисловная пауза: текущий токен не заканчивается пробелом / пунктуацией
            let lastChar = cur.text.last
            let isContinuation = lastChar.map { !$0.isWhitespace && !$0.isPunctuation } ?? true
            if isContinuation && gapMs > 800 {
                count += 1
            }
        }
        return count
    }
}

// MARK: - DysfluencyAnalysis

struct DysfluencyAnalysis: Sendable {
    let repetitions: Int
    let prolongations: Int
    let insideWordPauses: Int
    let totalSyllables: Int
    let rate: Float        // спотыканий на 100 слогов
    let isStub: Bool
}
