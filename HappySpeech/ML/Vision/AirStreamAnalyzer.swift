import Accelerate
import Foundation

// MARK: - AirStreamProfile

/// Профиль воздушного потока, полученный из спектрального анализа аудиобуфера.
public struct AirStreamProfile: Sendable {
    /// Тип воздушного потока (определяется по спектральному профилю).
    public let streamType: AirStreamType
    /// Нормализованная интенсивность 0.0–1.0.
    public let intensity: Float
    /// Уверенность классификации 0.0–1.0.
    public let confidence: Float
    /// Энергия в полосе дыхания (0–500 Hz), нормализованная.
    public let breathingBandEnergy: Float
    /// Энергия в полосе свистящих (4–8 kHz), нормализованная.
    public let whistlingBandEnergy: Float
    /// Энергия в полосе шипящих (2–5 kHz), нормализованная.
    public let hissingBandEnergy: Float
}

// MARK: - AirStreamType

/// Классификация воздушного потока по спектральному профилю.
public enum AirStreamType: String, Sendable, CaseIterable {
    /// Тишина / отсутствие потока.
    case silence
    /// Дыхание / выдох без звука (0–500 Hz доминирует).
    case breathing
    /// Свистящий поток — С, З, Ц (4–8 kHz доминирует).
    case whistling
    /// Шипящий поток — Ш, Ж, Ч, Щ (2–5 kHz доминирует).
    case hissing
    /// Голосовой шум широкополосный (речь).
    case voice
}

// MARK: - AirStreamAnalyzer

/// Анализатор воздушного потока через spectral-энергетический анализ (vDSP FFT).
/// Работает в ML/Vision слое — использует сырой Float32-буфер @ 16kHz.
/// Отличается от `AirStreamDetector` в `Services/`:
///   тот работает с ARKit blendshapes + mic amplitude (AR-режим),
///   этот — чистый DSP-анализ буфера без ARKit зависимости.
///
/// Полосы (при 16 kHz):
///   - breathing : 0–500 Hz → бины 0...(N/32)
///   - hissing   : 2–5 kHz  → бины (N/8)...(N*5/32)
///   - whistling : 4–8 kHz  → бины (N/4)...(N/2)
///   - voice     : 500–2000 Hz (широкая речевая полоса)
///
/// `nFFT` должен быть степенью двойки. По умолчанию 512 (32ms @ 16kHz).
public enum AirStreamAnalyzer {

    // MARK: - Constants

    private static let sampleRate: Float = 16_000
    private static let nFFT: Int = 512         // длина FFT (степень 2)
    private static let silenceThreshold: Float = 0.005   // ниже = тишина
    private static let voiceThreshold: Float  = 0.6      // выше = голос/шум

    // MARK: - Public API

    /// Анализирует Float32-массив сэмплов и возвращает профиль воздушного потока.
    /// - Parameter samples: нормализованные PCM float32, длина >= 512.
    /// - Returns: профиль `AirStreamProfile`.
    public static func analyze(samples: [Float]) -> AirStreamProfile {
        guard samples.count >= nFFT else {
            return silentProfile()
        }

        // Берём первые nFFT сэмплов, оконная функция Хэннинга
        var windowed = Array(samples.prefix(nFFT))
        applyHanningWindow(buffer: &windowed)

        // Вычисляем спектральные мощности
        let magnitudes = computeMagnitudes(buffer: windowed)
        let totalEnergy = magnitudes.reduce(0, +)

        guard totalEnergy > silenceThreshold else {
            return silentProfile()
        }

        // Интегральные энергии по полосам
        let breathEnergy  = bandEnergy(magnitudes: magnitudes, binStart: 0,
                                       binEnd: nFFT / 64)              // 0–500 Hz
        let voiceEnergy   = bandEnergy(magnitudes: magnitudes, binStart: nFFT / 64,
                                       binEnd: nFFT / 8)               // 500–2000 Hz
        let hissingEnergy = bandEnergy(magnitudes: magnitudes, binStart: nFFT / 8,
                                       binEnd: nFFT * 5 / 32)          // 2–5 kHz
        let whistleEnergy = bandEnergy(magnitudes: magnitudes, binStart: nFFT / 4,
                                       binEnd: nFFT / 2)               // 4–8 kHz

        // Нормализация к totalEnergy
        let bNorm = breathEnergy  / totalEnergy
        let vNorm = voiceEnergy   / totalEnergy
        let hNorm = hissingEnergy / totalEnergy
        let wNorm = whistleEnergy / totalEnergy

        // Классификация по доминирующей полосе
        let (streamType, confidence) = classify(
            breathing: bNorm, voice: vNorm, hissing: hNorm, whistling: wNorm,
            totalEnergy: totalEnergy
        )

        // Интенсивность = нормализованный totalEnergy к условному максимуму 0.5 RMS
        let rms = sqrt(totalEnergy / Float(nFFT))
        let intensity = min(1.0, rms / 0.5)

        return AirStreamProfile(
            streamType: streamType,
            intensity: intensity,
            confidence: confidence,
            breathingBandEnergy: bNorm,
            whistlingBandEnergy: wNorm,
            hissingBandEnergy: hNorm
        )
    }

    /// Удобная перегрузка для AVAudioPCMBuffer.
    public static func analyze(pcmBuffer: UnsafeMutablePointer<Float>, frameCount: Int) -> AirStreamProfile {
        let samples = Array(UnsafeBufferPointer(start: pcmBuffer, count: min(frameCount, nFFT * 4)))
        return analyze(samples: samples)
    }

    // MARK: - Private helpers

    private static func silentProfile() -> AirStreamProfile {
        AirStreamProfile(
            streamType: .silence,
            intensity: 0,
            confidence: 1.0,
            breathingBandEnergy: 0,
            whistlingBandEnergy: 0,
            hissingBandEnergy: 0
        )
    }

    /// Применяет оконную функцию Хэннинга для снижения спектральной утечки.
    private static func applyHanningWindow(buffer: inout [Float]) {
        let n = buffer.count
        for i in 0..<n {
            let window = 0.5 * (1 - cos(2 * .pi * Float(i) / Float(n - 1)))
            buffer[i] *= window
        }
    }

    /// Вычисляет амплитудный спектр через vDSP FFT.
    /// - Returns: массив амплитуд длиной nFFT/2.
    private static func computeMagnitudes(buffer: [Float]) -> [Float] {
        let halfN = nFFT / 2
        var real = buffer
        var imag = [Float](repeating: 0, count: nFFT)

        // withUnsafeMutableBufferPointer гарантирует, что поинтеры переживают всё тело блока
        return real.withUnsafeMutableBufferPointer { realBuf in
            imag.withUnsafeMutableBufferPointer { imagBuf in
                var complexBuffer = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)

                guard let fftSetup = vDSP_create_fftsetup(
                    vDSP_Length(log2(Float(nFFT))), FFTRadix(kFFTRadix2)
                ) else {
                    return [Float](repeating: 0, count: halfN)
                }
                defer { vDSP_destroy_fftsetup(fftSetup) }

                vDSP_fft_zip(
                    fftSetup, &complexBuffer, 1,
                    vDSP_Length(log2(Float(nFFT))), FFTDirection(FFT_FORWARD)
                )

                var magnitudes = [Float](repeating: 0, count: halfN)
                vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(halfN))

                // Нормализация
                var scale = Float(1.0 / Float(nFFT))
                vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfN))

                return magnitudes
            }
        }
    }

    /// Суммирует энергию в указанном диапазоне бинов.
    private static func bandEnergy(magnitudes: [Float], binStart: Int, binEnd: Int) -> Float {
        let start = max(0, min(binStart, magnitudes.count))
        let end   = max(0, min(binEnd, magnitudes.count))
        guard start < end else { return 0 }
        var sum: Float = 0
        vDSP_sve(Array(magnitudes[start..<end]), 1, &sum, vDSP_Length(end - start))
        return sum
    }

    /// Классификация по нормализованным энергиям полос.
    private static func classify(
        breathing: Float, voice: Float, hissing: Float, whistling: Float,
        totalEnergy: Float
    ) -> (AirStreamType, Float) {
        // Голосовой шум — широкополосный, voice >= 0.4 и ни одна высокочастотная полоса не доминирует
        if voice > 0.4 && hissing < 0.3 && whistling < 0.3 {
            return (.voice, min(1.0, voice))
        }
        // Свистящий: 4–8 kHz сильно доминирует (С, З, Ц)
        if whistling > hissing && whistling > breathing && whistling > voice {
            return (.whistling, min(1.0, whistling * 3))
        }
        // Шипящий: 2–5 kHz доминирует (Ш, Ж, Ч, Щ)
        if hissing > whistling && hissing > breathing && hissing > voice {
            return (.hissing, min(1.0, hissing * 2.5))
        }
        // Дыхание: low-freq доминирует
        if breathing > 0.1 {
            return (.breathing, min(1.0, breathing * 4))
        }
        return (.silence, 0.5)
    }
}
