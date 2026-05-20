import Foundation

// MARK: - YINPitchTracker
//
// Минимальная корректная реализация YIN pitch-tracker для детских голосов
// (100–500 Hz). Алгоритм:
//   1. Разностная функция d_t(τ) = Σ(x[i] - x[i+τ])²
//   2. Кумулятивно-нормированная средне-разностная функция CMNDF.
//   3. Поиск первого τ с CMNDF(τ) < threshold (типично 0.10–0.15).
//   4. Возвращаем F0 = sampleRate / τ_min, если найдено в диапазоне.
//
// Источник алгоритма:
//   • de Cheveigné A., Kawahara H. "YIN, a fundamental frequency estimator
//     for speech and music." JASA 111 (4), 2002.
//   • Использован только Step 1–4 эталонного описания (Step 5 parabolic
//     interpolation и Step 6 best local estimate опущены: для возрастного
//     детского голоса базового алгоритма достаточно). Полную ссылку
//     см. в комментариях каждой функции.
//
// Реализация Swift, без сторонних библиотек, MIT-style — собственный код.
// Только Foundation + Accelerate (если доступен), но базовая версия — Pure Swift.

/// Pitch-tracker для коротких окон (1024–4096 семплов) детского голоса.
struct YINPitchTracker: Sendable {

    let config: PitchTrackerConfig

    init(config: PitchTrackerConfig = .kidVoice) {
        self.config = config
    }

    // MARK: - Public

    /// Оценивает основную частоту F0 на одном окне семплов.
    /// - Parameter samples: монo-семплы в формате PCM Float (-1…+1).
    /// - Returns: F0 в Hz или `nil`, если детектирован шум / пауза.
    func estimateFrequency(in samples: [Float]) -> Double? {
        // Минимальный размер окна — достаточно для нижней частоты диапазона.
        let minTau = Int((config.sampleRate / config.maxFrequencyHz).rounded(.down))
        let maxTau = Int((config.sampleRate / config.minFrequencyHz).rounded(.up))
        guard samples.count > maxTau * 2 else { return nil }
        guard minTau > 1, maxTau > minTau else { return nil }

        let diff = differenceFunction(samples, maxTau: maxTau)
        let cmndf = cumulativeMeanNormalizedDifference(diff)

        // YIN Step 4: first τ с CMNDF(τ) < threshold.
        for tau in minTau..<maxTau where cmndf[tau] < config.yinThreshold {
            // Локальный минимум: уточнить параболической интерполяцией.
            let refinedTau = parabolicInterpolation(cmndf, tau: tau)
            let freq = config.sampleRate / refinedTau
            if freq >= config.minFrequencyHz, freq <= config.maxFrequencyHz {
                return freq
            }
        }
        return nil
    }

    // MARK: - YIN Step 1 — difference function

    /// d_t(τ) = Σ_{i=1}^{W} (x[i] − x[i+τ])²
    private func differenceFunction(_ samples: [Float], maxTau: Int) -> [Double] {
        // Длина окна анализа W. Используем половину буфера.
        let windowSize = samples.count / 2
        var diff = [Double](repeating: 0, count: maxTau + 1)
        for tau in 1...maxTau {
            var sum: Double = 0
            for i in 0..<windowSize {
                let delta = Double(samples[i]) - Double(samples[i + tau])
                sum += delta * delta
            }
            diff[tau] = sum
        }
        return diff
    }

    // MARK: - YIN Step 2/3 — cumulative mean-normalised difference function

    /// CMNDF(τ) = d(τ) · τ / Σ_{j=1}^{τ} d(j),  CMNDF(0) = 1
    private func cumulativeMeanNormalizedDifference(_ diff: [Double]) -> [Double] {
        var cmndf = [Double](repeating: 1, count: diff.count)
        var runningSum: Double = 0
        for tau in 1..<diff.count {
            runningSum += diff[tau]
            if runningSum == 0 {
                cmndf[tau] = 1
            } else {
                cmndf[tau] = diff[tau] * Double(tau) / runningSum
            }
        }
        return cmndf
    }

    // MARK: - YIN Step 5 — parabolic interpolation (minimal)

    /// Локальная параболическая интерполяция вокруг точки `tau`.
    /// Уменьшает шум дискретизации в выборке F0.
    private func parabolicInterpolation(_ cmndf: [Double], tau: Int) -> Double {
        guard tau > 0, tau < cmndf.count - 1 else { return Double(tau) }
        let s0 = cmndf[tau - 1]
        let s1 = cmndf[tau]
        let s2 = cmndf[tau + 1]
        let denom = 2 * (2 * s1 - s2 - s0)
        guard denom != 0 else { return Double(tau) }
        let shift = (s2 - s0) / denom
        return Double(tau) + shift
    }
}

// MARK: - ContourComparator

/// Сравнивает live-контур ребёнка с эталонным.
/// Используется в Score-стадии (и при Reduced Motion — для статической
/// картинки после записи).
struct ContourComparator: Sendable {

    /// Метрика сходства [0…1].
    /// Идея: нормализуем оба контура до [0…1] (mean-subtracted, range-scaled),
    /// после чего считаем 1 − средняя абсолютная ошибка по тем точкам,
    /// где обе серии озвучены.
    func similarity(model: [PitchPoint], live: [PitchPoint]) -> Double {
        guard !model.isEmpty, !live.isEmpty else { return 0 }

        // Приводим оба к одинаковой временной сетке N=20 ячеек.
        let bins = 20
        let modelResampled = resample(model, bins: bins).map(normaliseSeries)
        let liveResampled = resample(live, bins: bins).map(normaliseSeries)

        guard let modelN = modelResampled, let liveN = liveResampled else { return 0 }

        var errors: [Double] = []
        for index in 0..<bins {
            if let mp = modelN[index], let lp = liveN[index] {
                errors.append(abs(mp - lp))
            }
        }
        guard !errors.isEmpty else { return 0 }
        let mae = errors.reduce(0, +) / Double(errors.count)
        return max(0, 1 - mae)
    }

    /// Звёзды по сходству: ≥0.85 → 3, ≥0.65 → 2, ≥0.45 → 1, иначе 0.
    func stars(for similarity: Double) -> Int {
        switch similarity {
        case 0.85...:  return 3
        case 0.65...:  return 2
        case 0.45...:  return 1
        default:       return 0
        }
    }

    // MARK: - Private

    /// Пересэмплирует контур в `bins` равных временных ячеек.
    /// `nil`-частоты остаются `nil`.
    private func resample(_ points: [PitchPoint], bins: Int) -> [Double?]? {
        guard bins > 1 else { return nil }
        var result: [Double?] = Array(repeating: nil, count: bins)
        let step = 1.0 / Double(bins)
        for binIndex in 0..<bins {
            let low = Double(binIndex) * step
            let high = Double(binIndex + 1) * step
            let inBin = points.filter { $0.time >= low && $0.time < high }
            let voiced = inBin.compactMap { $0.frequencyHz }
            if voiced.isEmpty {
                result[binIndex] = nil
            } else {
                result[binIndex] = voiced.reduce(0, +) / Double(voiced.count)
            }
        }
        return result
    }

    /// Нормализует серию (mean 0, range 1) — для устранения смещения
    /// абсолютной высоты голоса между детьми.
    private func normaliseSeries(_ series: [Double?]) -> [Double?] {
        let voiced = series.compactMap { $0 }
        guard let minimum = voiced.min(), let maximum = voiced.max(), maximum > minimum else {
            return series
        }
        let range = maximum - minimum
        return series.map { value -> Double? in
            guard let value else { return nil }
            return (value - minimum) / range
        }
    }
}
