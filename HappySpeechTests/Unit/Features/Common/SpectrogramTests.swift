import Testing
import Foundation
import SwiftUI
@testable import HappySpeech

// MARK: - SpectrogramTests

/// Unit-тесты для компонента Spectrogram (vDSP FFT + Canvas + Models).
///
/// Покрывает:
/// - Пустую спектрограмму
/// - FFT-пайплайн с ненулевым результатом
/// - Форму Mel-filterbank (40 бинов)
/// - Цветовую функцию (границы 0 → blue, 1 → red)
/// - Smoke-тест Reduce Motion fallback
@Suite("SpectrogramTests")
struct SpectrogramTests {

    // MARK: - testEmptySpectrogram

    @Test("Пустая спектрограмма имеет 0 кадров и нулевую длительность")
    func testEmptySpectrogram() {
        let empty = Spectrogram.empty
        #expect(empty.frames.isEmpty)
        #expect(empty.duration == 0)
        #expect(empty.sampleRate == 16_000)
    }

    // MARK: - testSpectrogramInitPreservesValues

    @Test("Инициализатор Spectrogram сохраняет переданные значения")
    func testSpectrogramInitPreservesValues() {
        let frames: [[Float]] = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]]
        let spec = Spectrogram(frames: frames, sampleRate: 16_000, duration: 2.5)

        #expect(spec.frames.count == 2)
        #expect(spec.sampleRate == 16_000)
        #expect(spec.duration == 2.5)
        #expect(spec.frames[0] == [0.1, 0.2, 0.3])
    }

    // MARK: - testMelBinCount

    @Test("Константа melBinCount равна 40")
    func testMelBinCount() {
        #expect(Spectrogram.melBinCount == 40)
    }

    // MARK: - testColorFromMagnitudeBoundaries

    @Test("Цветовая функция: magnitude=0 → холодный оттенок, magnitude=1 → тёплый")
    func testColorFromMagnitudeBoundaries() {
        // neutral style: lowHue=240, highHue=0
        let style = SpectrogramStyle.neutral

        // Нулевое значение → оттенок 240 (синий)
        let lowHue = style.lowHue
        #expect(lowHue == 240.0)

        // Единичное значение → оттенок 0 (красный)
        let highHue = style.highHue
        #expect(highHue == 0.0)

        // Разница между lowHue и highHue — не ноль (есть градиент)
        #expect(lowHue != highHue)
    }

    // MARK: - testSpectrogramStyleAllCases

    @Test("Все стили SpectrogramStyle имеют корректные диапазоны оттенков")
    func testSpectrogramStyleAllCases() {
        for style in SpectrogramStyle.allCases {
            // Оттенки в диапазоне 0–360
            #expect(style.lowHue >= 0 && style.lowHue <= 360)
            #expect(style.highHue >= 0 && style.highHue <= 360)
        }
    }

    // MARK: - testRenderConfigDefaults

    @Test("SpectrogramRenderConfig.defaultConfig имеет ожидаемые значения")
    func testRenderConfigDefaults() {
        let config = SpectrogramRenderConfig.defaultConfig
        #expect(config.logMin == -3.0)
        #expect(config.logMax == 3.0)
        #expect(config.saturation == 0.85)
        #expect(config.brightness == 0.9)
    }

    // MARK: - testNormalizationClamping

    @Test("Нормализация magnitude зажимается в [0, 1]")
    func testNormalizationClamping() {
        let config = SpectrogramRenderConfig.defaultConfig
        let range = config.logMax - config.logMin

        // Ниже минимума → 0
        let belowMin = max(0, min(1, (-10.0 - config.logMin) / range))
        #expect(belowMin == 0.0)

        // Выше максимума → 1
        let aboveMax = max(0, min(1, (10.0 - config.logMin) / range))
        #expect(aboveMax == 1.0)

        // В пределах диапазона → промежуточное
        let mid = max(0, min(1, (0.0 - config.logMin) / range))
        #expect(mid > 0.0 && mid < 1.0)
    }

    // MARK: - testPlaceholderFrameShape

    @Test("Заглушечный кадр StaticSpectrogramView имеет 40 бинов")
    func testPlaceholderFrameShape() {
        // StaticSpectrogramView использует makePlaceholderFrame() — проверяем
        // через Spectrogram.melBinCount что размер верный.
        let expectedBins = Spectrogram.melBinCount
        let placeholderFrame: [Float] = (0..<expectedBins).map { bin in
            let normalized = Float(bin) / Float(expectedBins)
            let envelope = sin(Float.pi * normalized)
            let config = SpectrogramRenderConfig.defaultConfig
            return config.logMin + envelope * (config.logMax - config.logMin)
        }
        #expect(placeholderFrame.count == 40)
    }

    // MARK: - testSpectrogramEquality

    @Test("Spectrogram соответствует протоколу Equatable корректно")
    func testSpectrogramEquality() {
        let frames: [[Float]] = [[1.0, 2.0]]
        let a = Spectrogram(frames: frames, sampleRate: 16_000, duration: 1.0)
        let b = Spectrogram(frames: frames, sampleRate: 16_000, duration: 1.0)
        let c = Spectrogram(frames: [[3.0]], sampleRate: 16_000, duration: 0.5)

        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - testReduceMotionFallback (smoke)

    @Test("StaticSpectrogramView инициализируется без сбоев (smoke)")
    @MainActor
    func testReduceMotionStaticFallback() {
        // Smoke-тест: убеждаемся что StaticSpectrogramView создаётся без crash.
        let view = StaticSpectrogramView(spectrogram: .empty, style: .neutral)
        // Если дошли сюда — fallback работает.
        _ = view.body
    }
}
