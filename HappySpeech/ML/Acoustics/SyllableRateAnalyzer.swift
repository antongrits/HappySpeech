import Accelerate
import Foundation

// MARK: - SyllableRateMeasurement

/// Результат анализа диадохокинеза (DDK) — ритмичного повторения слогов.
///
/// Диадохокинез — стандартная логопедическая проба оромоторной координации:
/// ребёнка просят как можно быстрее и ровнее повторять слоговой ряд (моно «па-па-па»
/// или мульти «па-та-ка»). Измеряются: темп (слогов в секунду), ритмическая
/// стабильность (постоянство межслоговых интервалов) и фактическое число слогов.
/// Эти показатели чувствительны к артикуляционной диспраксии и сниженной
/// оромоторной ловкости (Fletcher 1972; Williams & Stackhouse 2000).
///
/// ## Честные границы
/// Это ИЗМЕРЕНИЕ акустики записи (энергетических вершин), не диагноз и не
/// клиническая оценка речи (project guide §11). Детекция слоговых ядер по
/// огибающей энергии — общепринятый, но приблизительный метод (De Jong & Wempe
/// 2009); на детском голосе пороги эвристические и НЕ валидированы на клиническом
/// корпусе. Использовать только для игровой биообратной связи, сравнения попыток
/// одного ребёнка между собой и мотивации.
public struct SyllableRateMeasurement: Sendable, Equatable {

    /// Число обнаруженных слоговых ядер (энергетических вершин).
    public let syllableCount: Int

    /// Темп: слогов в секунду по голосовому интервалу (от первого до последнего ядра).
    public let syllablesPerSecond: Double

    /// Голосовая длительность ряда, секунды (от первого до последнего слога).
    public let voicedDurationSec: Double

    /// Коэффициент вариации межслоговых интервалов (0…1+): мера НЕровности ритма.
    /// 0 — идеально равномерно; ~0.1 — типично ровно у взрослого; > 0.35 — рваный.
    /// `nil`, если ядер < 3 (по двум интервалам CV неустойчив).
    public let intervalCV: Double?

    /// Средний межслоговой интервал, секунды (`nil`, если < 2 ядер).
    public let meanIntervalSec: Double?

    /// Пиковая RMS-амплитуда записи (0…1) — индикатор громкости/уверенности.
    public let peakRMS: Double

    public init(
        syllableCount: Int,
        syllablesPerSecond: Double,
        voicedDurationSec: Double,
        intervalCV: Double?,
        meanIntervalSec: Double?,
        peakRMS: Double
    ) {
        self.syllableCount = syllableCount
        self.syllablesPerSecond = syllablesPerSecond
        self.voicedDurationSec = voicedDurationSec
        self.intervalCV = intervalCV
        self.meanIntervalSec = meanIntervalSec
        self.peakRMS = peakRMS
    }
}

// MARK: - SyllableRateAnalyzer

/// Детерминированный DSP-анализатор темпа слогов (диадохокинез) по огибающей
/// энергии. Чистый vDSP/Accelerate, без ML-моделей и без сети — работает мгновенно
/// на любом устройстве (COPPA-safe by construction, переживает сбой Core ML).
///
/// ## Алгоритм (peak-picking по огибающей энергии — De Jong & Wempe 2009)
/// 1. Кадрирование: окна `frameSize` сэмплов, шаг `hopSize` (≈10 мс @ 16 кГц).
/// 2. По кадру — RMS-энергия. Получается огибающая громкости речи.
/// 3. Сглаживание огибающей скользящим средним (убирает дрожание).
/// 4. Адаптивный порог: доля от пиковой энергии + абсолютный пол шума.
/// 5. Поиск локальных максимумов огибающей выше порога с обязательным
///    минимальным разнесением вершин (рефрактерный период `minPeakGapSec`) —
///    физически слог не короче ~90 мс даже при быстром темпе у ребёнка.
/// 6. Каждый максимум = одно слоговое ядро. Из положений ядер считаются темп,
///    межслоговые интервалы и коэффициент их вариации (ровность ритма).
///
/// Возвращает `nil`, если запись слишком тихая / короткая (нет голоса) — честное
/// «не расслышала», без фабрикации.
public enum SyllableRateAnalyzer {

    // MARK: - Tunables (документированные эвристики)

    /// Размер кадра огибающей в сэмплах (≈16 мс @ 16 кГц).
    public static let frameSize = 256

    /// Шаг кадра (≈10 мс @ 16 кГц) — временно́е разрешение огибающей.
    public static let hopSize = 160

    /// Частота дискретизации, на которую рассчитан анализ.
    public static let expectedSampleRate: Double = 16_000

    /// Полуокно сглаживания огибающей в кадрах (скользящее среднее 2k+1 кадров).
    static let smoothingHalfWindow = 3

    /// Минимальный зазор между соседними слоговыми вершинами, секунды.
    /// Физический рефрактер слога: даже быстрый детский DDK ≈ 6–7 слог/с → ~150 мс;
    /// порог 0.09 с (≈11 слог/с) оставляет запас и отсекает дробление одного слога.
    static let minPeakGapSec: Double = 0.09

    /// Доля от пиковой огибающей, выше которой кадр может быть вершиной (гейт).
    static let peakThresholdShare: Double = 0.30

    /// Абсолютный пол RMS — совсем тихие записи (микрофон прикрыт) не анализируем.
    static let rmsFloor: Double = 0.004

    /// Минимально осмысленное число кадров записи для анализа.
    static let minFrames = 8

    /// Минимальная «глубина» долины между двумя вершинами как доля от меньшей из
    /// них — две вершины засчитываются раздельными, только если между ними энергия
    /// падала достаточно (иначе это одно «плато» слога). 0…1.
    static let minValleyDropShare: Double = 0.65

    // MARK: - Public API

    /// Анализирует моно-PCM (Float32) и возвращает измерение ряда слогов,
    /// либо `nil`, если голоса нет.
    ///
    /// - Parameters:
    ///   - pcm: сэмплы −1…1, mono.
    ///   - sampleRate: частота дискретизации входа (ожидается 16 кГц).
    public static func analyze(
        pcm: [Float],
        sampleRate: Double = expectedSampleRate
    ) -> SyllableRateMeasurement? {
        guard sampleRate > 0, pcm.count >= frameSize * minFrames else { return nil }

        let envelope = energyEnvelope(pcm: pcm)
        guard envelope.count >= minFrames else { return nil }

        let peakEnergy = envelope.max() ?? 0
        guard peakEnergy > rmsFloor else { return nil }

        let smoothed = smooth(envelope, halfWindow: smoothingHalfWindow)
        let secondsPerFrame = Double(hopSize) / sampleRate
        let minGapFrames = max(1, Int((minPeakGapSec / secondsPerFrame).rounded()))
        let threshold = max(rmsFloor, peakEnergy * peakThresholdShare)

        let peakFrames = pickPeaks(
            smoothed,
            threshold: threshold,
            minGapFrames: minGapFrames
        )

        // Ряд из < 2 слогов — не диадохокинез (короткий вскрик / шум). Честно nil.
        guard peakFrames.count >= 2 else { return nil }

        let onsetTimes = peakFrames.map { Double($0) * secondsPerFrame }
        let voicedDuration = (onsetTimes.last ?? 0) - (onsetTimes.first ?? 0)

        // Межслоговые интервалы.
        var intervals: [Double] = []
        intervals.reserveCapacity(onsetTimes.count - 1)
        for idx in 1 ..< onsetTimes.count {
            intervals.append(onsetTimes[idx] - onsetTimes[idx - 1])
        }
        let meanInterval = intervals.isEmpty ? nil : intervals.reduce(0, +) / Double(intervals.count)

        // Темп: считаем по интервалам (N слогов = N−1 интервалов укладываются в
        // голосовую длительность). Если длительность вырождена — даём nil-безопасно 0.
        let rate: Double
        if voicedDuration > 0 {
            rate = Double(peakFrames.count - 1) / voicedDuration
        } else {
            rate = 0
        }

        // Коэффициент вариации интервалов — только при ≥3 ядрах (≥2 интервалов).
        let cv: Double?
        if intervals.count >= 2, let mean = meanInterval, mean > 0 {
            let variance = intervals.reduce(0.0) { acc, value in
                let dev = value - mean
                return acc + dev * dev
            } / Double(intervals.count)
            cv = variance.squareRoot() / mean
        } else {
            cv = nil
        }

        return SyllableRateMeasurement(
            syllableCount: peakFrames.count,
            syllablesPerSecond: rate,
            voicedDurationSec: voicedDuration,
            intervalCV: cv,
            meanIntervalSec: meanInterval,
            peakRMS: peakEnergy
        )
    }

    // MARK: - Envelope

    /// Огибающая энергии: per-frame RMS через vDSP.
    static func energyEnvelope(pcm: [Float]) -> [Double] {
        let n = frameSize
        guard pcm.count >= n else { return [] }
        var envelope: [Double] = []
        envelope.reserveCapacity((pcm.count - n) / hopSize + 1)
        var offset = 0
        while offset + n <= pcm.count {
            var rms: Float = 0
            pcm.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                vDSP_rmsqv(base + offset, 1, &rms, vDSP_Length(n))
            }
            envelope.append(Double(rms))
            offset += hopSize
        }
        return envelope
    }

    /// Сглаживание скользящим средним (полуокно `halfWindow`).
    static func smooth(_ values: [Double], halfWindow: Int) -> [Double] {
        guard halfWindow > 0, values.count > 2 else { return values }
        var out = [Double](repeating: 0, count: values.count)
        for idx in values.indices {
            let lower = max(0, idx - halfWindow)
            let upper = min(values.count - 1, idx + halfWindow)
            var sum = 0.0
            for j in lower ... upper { sum += values[j] }
            out[idx] = sum / Double(upper - lower + 1)
        }
        return out
    }

    // MARK: - Peak picking

    /// Находит индексы локальных максимумов огибающей выше порога, разнесённых не
    /// менее чем на `minGapFrames` кадров, с проверкой глубины долины между ними
    /// (две вершины раздельны, только если энергия между ними падала достаточно —
    /// иначе это одно слоговое плато).
    static func pickPeaks(
        _ envelope: [Double],
        threshold: Double,
        minGapFrames: Int
    ) -> [Int] {
        guard envelope.count >= 3 else { return [] }

        // 1. Кандидаты — локальные максимумы выше порога.
        var candidates: [Int] = []
        for idx in 1 ..< (envelope.count - 1) {
            let value = envelope[idx]
            if value >= threshold,
               value >= envelope[idx - 1],
               value > envelope[idx + 1] {
                candidates.append(idx)
            }
        }
        // Граничные вершины (старт/финиш ряда) — частый случай первого слога.
        if let first = envelope.first, first >= threshold, first > envelope[1] {
            candidates.insert(0, at: 0)
        }
        if let last = envelope.last, last >= threshold, last > envelope[envelope.count - 2] {
            candidates.append(envelope.count - 1)
        }
        guard !candidates.isEmpty else { return [] }

        // 2. Подавление по рефрактеру + глубине долины: идём слева направо, держим
        //    последнюю принятую вершину.
        var accepted: [Int] = []
        for candidate in candidates {
            guard let lastAccepted = accepted.last else {
                accepted.append(candidate)
                continue
            }
            let gap = candidate - lastAccepted
            if gap < minGapFrames {
                // Слишком близко: оставляем более громкую из двух вершин.
                if envelope[candidate] > envelope[lastAccepted] {
                    accepted[accepted.count - 1] = candidate
                }
                continue
            }
            // Проверяем глубину долины между вершинами.
            let valley = minValue(envelope, from: lastAccepted, to: candidate)
            let lower = min(envelope[candidate], envelope[lastAccepted])
            // Долина должна опуститься ниже доли от меньшей вершины.
            if lower > 0, valley <= lower * minValleyDropShare {
                accepted.append(candidate)
            } else if envelope[candidate] > envelope[lastAccepted] {
                // Плато без провала — это один слог; держим громче.
                accepted[accepted.count - 1] = candidate
            }
        }
        return accepted
    }

    /// Минимум огибающей строго между двумя индексами (исключая концы).
    private static func minValue(_ envelope: [Double], from: Int, to: Int) -> Double {
        guard to - from > 1 else { return min(envelope[from], envelope[to]) }
        var result = Double.greatestFiniteMagnitude
        for idx in (from + 1) ..< to {
            result = min(result, envelope[idx])
        }
        return result == Double.greatestFiniteMagnitude ? 0 : result
    }
}
