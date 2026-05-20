@testable import HappySpeech
import XCTest

// MARK: - YINPitchTrackerTests
//
// v31 Wave E Ф.1 — проверяет корректность определения F0 на синтезированных
// синусоидах и пограничные случаи (тишина, шум, диапазон).

final class YINPitchTrackerTests: XCTestCase {

    private let tracker = YINPitchTracker(config: .kidVoice)

    // MARK: - Helpers

    /// Генерирует sine-wave заданной частоты.
    private func sine(frequency: Double, sampleRate: Double = 16_000, duration: Double = 0.2) -> [Float] {
        let count = Int(sampleRate * duration)
        let twoPi = 2.0 * Double.pi
        return (0..<count).map { i in
            Float(sin(twoPi * frequency * Double(i) / sampleRate))
        }
    }

    /// Генерирует белый шум фиксированной амплитуды.
    private func whiteNoise(amplitude: Float = 0.05, count: Int = 4096) -> [Float] {
        var rng = SystemRandomNumberGenerator()
        return (0..<count).map { _ in
            Float.random(in: -amplitude...amplitude, using: &rng)
        }
    }

    // MARK: - Tests

    func test_estimate_returns_nil_on_empty_buffer() {
        let result = tracker.estimateFrequency(in: [])
        XCTAssertNil(result)
    }

    func test_estimate_returns_nil_on_too_short_buffer() {
        let samples = sine(frequency: 220, duration: 0.005)
        let result = tracker.estimateFrequency(in: samples)
        XCTAssertNil(result)
    }

    func test_estimate_220hz_sine_returns_value_within_5_percent() throws {
        let samples = sine(frequency: 220)
        let f = try XCTUnwrap(tracker.estimateFrequency(in: samples))
        XCTAssertEqual(f, 220, accuracy: 11)
    }

    func test_estimate_330hz_sine_returns_value_within_5_percent() throws {
        let samples = sine(frequency: 330)
        let f = try XCTUnwrap(tracker.estimateFrequency(in: samples))
        XCTAssertEqual(f, 330, accuracy: 17)
    }

    func test_estimate_440hz_sine_returns_value_within_5_percent() throws {
        let samples = sine(frequency: 440)
        let f = try XCTUnwrap(tracker.estimateFrequency(in: samples))
        XCTAssertEqual(f, 440, accuracy: 22)
    }

    func test_estimate_50hz_sine_returns_nil_below_min() {
        let samples = sine(frequency: 50)
        let result = tracker.estimateFrequency(in: samples)
        XCTAssertNil(result, "50 Hz should be rejected (below 100 Hz min for kid voice)")
    }

    func test_estimate_700hz_sine_returns_nil_above_max() {
        let samples = sine(frequency: 700)
        let result = tracker.estimateFrequency(in: samples)
        XCTAssertNil(result, "700 Hz should be rejected (above 500 Hz max)")
    }

    func test_estimate_white_noise_returns_nil_or_implausible() {
        let samples = whiteNoise()
        // Noise should usually return nil; if not, it's at least within the
        // allowed range (consistency, not crash).
        let result = tracker.estimateFrequency(in: samples)
        if let value = result {
            XCTAssertGreaterThanOrEqual(value, 100)
            XCTAssertLessThanOrEqual(value, 500)
        }
    }

    func test_estimate_silence_returns_nil() {
        let samples = [Float](repeating: 0, count: 4096)
        // For pure silence both diff and CMNDF are 0 → CMNDF[τ]=1 → no τ passes
        // threshold → result must be nil.
        let result = tracker.estimateFrequency(in: samples)
        XCTAssertNil(result)
    }

    func test_estimate_180hz_sine_within_5_percent() throws {
        let samples = sine(frequency: 180)
        let f = try XCTUnwrap(tracker.estimateFrequency(in: samples))
        XCTAssertEqual(f, 180, accuracy: 9)
    }

    // MARK: - ContourComparator tests

    func test_comparator_identical_contours_high_similarity() {
        let points: [PitchPoint] = (0...20).map { i in
            PitchPoint(time: Double(i) / 20.0, frequencyHz: 200 + Double(i) * 5)
        }
        let cmp = ContourComparator()
        let sim = cmp.similarity(model: points, live: points)
        XCTAssertGreaterThan(sim, 0.95)
        XCTAssertEqual(cmp.stars(for: sim), 3)
    }

    func test_comparator_inverted_contours_low_similarity() {
        let up: [PitchPoint] = (0...20).map { i in
            PitchPoint(time: Double(i) / 20.0, frequencyHz: 150 + Double(i) * 10)
        }
        let down: [PitchPoint] = (0...20).map { i in
            PitchPoint(time: Double(i) / 20.0, frequencyHz: 350 - Double(i) * 10)
        }
        let cmp = ContourComparator()
        let sim = cmp.similarity(model: up, live: down)
        XCTAssertLessThan(sim, 0.40)
    }

    func test_comparator_empty_inputs_returns_zero() {
        let cmp = ContourComparator()
        XCTAssertEqual(cmp.similarity(model: [], live: []), 0)
        XCTAssertEqual(cmp.similarity(model: [PitchPoint(time: 0, frequencyHz: 220)], live: []), 0)
    }

    func test_comparator_star_thresholds() {
        let cmp = ContourComparator()
        XCTAssertEqual(cmp.stars(for: 0.90), 3)
        XCTAssertEqual(cmp.stars(for: 0.70), 2)
        XCTAssertEqual(cmp.stars(for: 0.50), 1)
        XCTAssertEqual(cmp.stars(for: 0.20), 0)
    }
}
