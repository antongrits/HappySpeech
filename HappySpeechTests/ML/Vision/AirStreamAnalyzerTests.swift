import XCTest

@testable import HappySpeech

// MARK: - AirStreamAnalyzerTests

final class AirStreamAnalyzerTests: XCTestCase {

    // MARK: - Test 1: Тишина → .silence

    func testSilenceClassifiedAsSilence() {
        let samples = [Float](repeating: 0.0, count: 512)
        let profile = AirStreamAnalyzer.analyze(samples: samples)
        XCTAssertEqual(profile.streamType, .silence,
            "Нулевой сигнал должен классифицироваться как silence")
        XCTAssertEqual(profile.intensity, 0.0, accuracy: 0.01)
    }

    // MARK: - Test 2: Слишком короткий буфер → silence fallback (не краш)

    func testShortBufferReturnssilence() {
        let samples: [Float] = [0.1, 0.2, 0.3]
        let profile = AirStreamAnalyzer.analyze(samples: samples)
        XCTAssertEqual(profile.streamType, .silence,
            "Буфер < 512 сэмплов должен вернуть silence без краша")
    }

    // MARK: - Test 3: Синусоида 5 kHz → whistling (свистящий)

    func testHighFrequencySineDetectedAsWhistling() {
        // sin(2π × 5000 × t) @ 16kHz
        let freq: Float = 5000
        let sr: Float   = 16000
        let samples = (0..<512).map { i in
            sin(2 * Float.pi * freq * Float(i) / sr) * 0.3
        }
        let profile = AirStreamAnalyzer.analyze(samples: samples)
        // 5kHz должна попасть в whistling полосу (4–8 kHz)
        XCTAssertEqual(profile.streamType, .whistling,
            "5kHz синусоида должна классифицироваться как whistling (С, З, Ц)")
    }

    // MARK: - Test 4: Синусоида 3 kHz → hissing (шипящий)

    func testMidFrequencySineDetectedAsHissing() {
        let freq: Float = 3000
        let sr: Float   = 16000
        let samples = (0..<512).map { i in
            sin(2 * Float.pi * freq * Float(i) / sr) * 0.3
        }
        let profile = AirStreamAnalyzer.analyze(samples: samples)
        // 3kHz в диапазоне hissing (2–5 kHz)
        XCTAssertEqual(profile.streamType, .hissing,
            "3kHz синусоида должна классифицироваться как hissing (Ш, Ж, Ч, Щ)")
    }

    // MARK: - Test 5: Интенсивность в [0, 1]

    func testIntensityIsAlwaysNormalized() {
        // Очень громкий сигнал
        let samples = [Float](repeating: 1.0, count: 512)
        let profile = AirStreamAnalyzer.analyze(samples: samples)
        XCTAssertGreaterThanOrEqual(profile.intensity, 0.0)
        XCTAssertLessThanOrEqual(profile.intensity, 1.0,
            "intensity всегда должна быть в [0, 1]")
    }

    // MARK: - Test 6: Уверенность в [0, 1]

    func testConfidenceIsAlwaysNormalized() {
        let testCases: [[Float]] = [
            [Float](repeating: 0.0, count: 512),
            (0..<512).map { _ in Float.random(in: -0.3...0.3) },
            (0..<512).map { i in sin(2 * .pi * 5000 * Float(i) / 16000) * 0.5 }
        ]
        for samples in testCases {
            let profile = AirStreamAnalyzer.analyze(samples: samples)
            XCTAssertGreaterThanOrEqual(profile.confidence, 0.0)
            XCTAssertLessThanOrEqual(profile.confidence, 1.0,
                "confidence всегда должна быть в [0, 1]")
        }
    }

    // MARK: - Test 7: Энергии полос суммируются разумно

    func testBandEnergiesAreBetweenZeroAndOne() {
        let freq: Float = 4500
        let samples = (0..<512).map { i in
            sin(2 * Float.pi * freq * Float(i) / 16000) * 0.2
        }
        let profile = AirStreamAnalyzer.analyze(samples: samples)
        XCTAssertGreaterThanOrEqual(profile.breathingBandEnergy, 0.0)
        XCTAssertGreaterThanOrEqual(profile.hissingBandEnergy, 0.0)
        XCTAssertGreaterThanOrEqual(profile.whistlingBandEnergy, 0.0)
        XCTAssertLessThanOrEqual(profile.breathingBandEnergy, 1.0)
        XCTAssertLessThanOrEqual(profile.hissingBandEnergy, 1.0)
        XCTAssertLessThanOrEqual(profile.whistlingBandEnergy, 1.0)
    }
}
