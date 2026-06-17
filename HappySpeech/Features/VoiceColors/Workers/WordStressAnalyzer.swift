import Foundation

// MARK: - WordStressAnalyzer
//
// Worker режима «Логическое ударение». По массиву мгновенных амплитуд (RMS)
// записи определяет, какое слово ребёнок выделил голосом — то есть какое
// прозвучало громче и протяжнее.
//
// Подход (методически — выделение голосом = усиление громкости + длительности,
// Е. Ф. Архипова): амплитудная огибающая делится на N равных по времени
// сегментов по числу слов, в каждом считается средняя громкость голосовых
// (надпороговых) кадров. Слово с максимальной средней громкостью считается
// «главным». Нормализованные высоты столбиков отдаются в UI как опора.
//
// Чистая, без I/O — полностью тестируема.

struct WordStressAnalyzer: Sendable {

    /// Порог голосовой активности: кадры тише порога считаются паузой и не
    /// учитываются при усреднении (иначе тишина между словами «съедает» громкость).
    let voiceFloor: Float

    init(voiceFloor: Float = 0.04) {
        self.voiceFloor = voiceFloor
    }

    // MARK: - Public

    /// Считает среднюю громкость каждого слова из амплитудной огибающей.
    /// - Parameters:
    ///   - envelope: последовательность мгновенных амплитуд 0…1 (порядок по времени).
    ///   - wordCount: число слов во фразе (≥1).
    /// - Returns: массив средних RMS на слово (длиной `wordCount`), 0…1.
    func perWordRMS(envelope: [Float], wordCount: Int) -> [Float] {
        guard wordCount > 0 else { return [] }
        guard !envelope.isEmpty else { return Array(repeating: 0, count: wordCount) }

        // Обрезаем ведущую/хвостовую тишину, чтобы сегментация попадала на речь.
        let trimmed = trimSilence(envelope)
        let frames = trimmed.isEmpty ? envelope : trimmed
        let perSegment = max(1, frames.count / wordCount)

        var result: [Float] = []
        result.reserveCapacity(wordCount)
        for word in 0..<wordCount {
            let start = word * perSegment
            let end = (word == wordCount - 1) ? frames.count : min(frames.count, start + perSegment)
            guard start < end else { result.append(0); continue }
            let slice = Array(frames[start..<end])
            result.append(meanVoiced(slice))
        }
        return result
    }

    /// Индекс самого громкого слова (или −1, если речь не распознана).
    func loudestIndex(perWordRMS rms: [Float]) -> Int {
        guard let maxVal = rms.max(), maxVal > voiceFloor,
              let idx = rms.firstIndex(of: maxVal) else {
            return -1
        }
        return idx
    }

    /// Нормализованные высоты столбиков 0…1 для UI (самое громкое слово → 1.0).
    func normalisedHeights(perWordRMS rms: [Float]) -> [Float] {
        guard let maxVal = rms.max(), maxVal > 0 else {
            return Array(repeating: 0.2, count: rms.count)
        }
        // Нижняя граница столбика 0.2 — чтобы тихие слова всё равно были видны.
        return rms.map { 0.2 + 0.8 * ($0 / maxVal) }
    }

    /// Совпало ли выделение: самое громкое слово = целевое, и оно достаточно
    /// контрастно (на ≥20% громче среднего из остальных).
    func didEmphasiseTarget(perWordRMS rms: [Float], targetIndex: Int) -> Bool {
        guard rms.indices.contains(targetIndex) else { return false }
        guard loudestIndex(perWordRMS: rms) == targetIndex else { return false }
        let others = rms.enumerated().filter { $0.offset != targetIndex }.map { $0.element }
        guard !others.isEmpty else { return rms[targetIndex] > voiceFloor }
        let othersMean = others.reduce(0, +) / Float(others.count)
        guard othersMean > 0 else { return rms[targetIndex] > voiceFloor }
        return rms[targetIndex] >= othersMean * 1.2
    }

    // MARK: - Private

    private func meanVoiced(_ frames: [Float]) -> Float {
        let voiced = frames.filter { $0 >= voiceFloor }
        let source = voiced.isEmpty ? frames : voiced
        guard !source.isEmpty else { return 0 }
        return source.reduce(0, +) / Float(source.count)
    }

    private func trimSilence(_ envelope: [Float]) -> [Float] {
        guard let first = envelope.firstIndex(where: { $0 >= voiceFloor }),
              let last = envelope.lastIndex(where: { $0 >= voiceFloor }),
              first <= last else {
            return []
        }
        return Array(envelope[first...last])
    }
}
