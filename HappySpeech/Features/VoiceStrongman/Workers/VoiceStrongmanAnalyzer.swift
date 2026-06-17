import Foundation

// MARK: - VoiceStrongmanAnalyzer
//
// Чистый детерминированный анализатор результата попытки (без I/O, без
// AVFoundation) — отдельно тестируется. Две задачи:
//   • громкость: попала ли средняя/устойчивая громкость в комфортную зону
//     уровня (антикрик — попадание В зону, не максимум);
//   • высота: пройдена ли лесенка глиссандо и совпало ли направление
//     (вверх/вниз) по тренду питч-контура.

struct VoiceStrongmanAnalyzer: Sendable {

    // MARK: - Loudness

    /// Доля кадров записи, попавших в комфортную зону уровня.
    func inBandFraction(frames: [Float], level: LoudnessLevel) -> Float {
        guard !frames.isEmpty else { return 0 }
        let inside = frames.filter { $0 >= level.lowerBound && $0 <= level.upperBound }
        return Float(inside.count) / Float(frames.count)
    }

    /// Средняя громкость записи (для нормализации шара после остановки).
    func averageLoudness(frames: [Float]) -> Float {
        guard !frames.isEmpty else { return 0 }
        return frames.reduce(0, +) / Float(frames.count)
    }

    /// Попала ли громкость в зону: достаточная доля кадров внутри полосы.
    func didHitBand(frames: [Float], level: LoudnessLevel) -> Bool {
        inBandFraction(frames: frames, level: level)
            >= VoiceStrongmanScoring.loudnessInBandFraction
    }

    /// Мгновенное попадание в зону по одному значению громкости (для live UI).
    func isInBand(loudness: Float, level: LoudnessLevel) -> Bool {
        loudness >= level.lowerBound && loudness <= level.upperBound
    }

    // MARK: - Pitch ladder

    /// Нормализованная высота 0…1 из частоты в детском диапазоне.
    func normalisedPitch(frequencyHz: Double?) -> Float? {
        guard let freq = frequencyHz,
              freq >= VoiceStrongmanScoring.pitchFloorHz,
              freq <= VoiceStrongmanScoring.pitchCeilHz else { return nil }
        let span = VoiceStrongmanScoring.pitchCeilHz - VoiceStrongmanScoring.pitchFloorHz
        return Float((freq - VoiceStrongmanScoring.pitchFloorHz) / span)
    }

    /// Доля лесенки, которую прошёл голос за попытку (0…1):
    /// размах нормализованной высоты в нужном направлении.
    func ladderReached(contour: [PitchPoint], direction: PitchDirection) -> Float {
        let voiced = contour.compactMap { normalisedPitch(frequencyHz: $0.frequencyHz) }
        guard voiced.count >= 2, let minV = voiced.min(), let maxV = voiced.max() else { return 0 }
        // Размах высоты = насколько широко ребёнок промодулировал голос.
        return min(1, maxV - minV)
    }

    /// Совпало ли направление глиссандо с целевым (тренд: первая половина vs вторая).
    func didMatchDirection(contour: [PitchPoint], direction: PitchDirection) -> Bool {
        let voiced = contour.compactMap { point -> Float? in
            normalisedPitch(frequencyHz: point.frequencyHz)
        }
        guard voiced.count >= 4 else { return false }
        let half = voiced.count / 2
        let firstAvg = voiced[0..<half].reduce(0, +) / Float(half)
        let secondAvg = voiced[half...].reduce(0, +) / Float(voiced.count - half)
        let delta = secondAvg - firstAvg
        // Небольшой порог, чтобы шум не считался движением.
        let threshold: Float = 0.08
        switch direction {
        case .up:   return delta >= threshold
        case .down: return delta <= -threshold
        }
    }

    /// Итог глиссандо: лесенка пройдена достаточно И направление совпало.
    func didClimbLadder(contour: [PitchPoint], direction: PitchDirection) -> Bool {
        ladderReached(contour: contour, direction: direction)
            >= VoiceStrongmanScoring.ladderReachThreshold
            && didMatchDirection(contour: contour, direction: direction)
    }
}
