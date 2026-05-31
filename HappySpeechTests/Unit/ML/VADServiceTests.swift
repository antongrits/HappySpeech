@testable import HappySpeech
import AVFoundation
import XCTest

// MARK: - VADServiceTests
//
// Покрывает LiveVADService: energy-threshold VAD на vDSP RMS, адаптивный
// baseline + гистерезис тишины, и эвристику усталости по дисперсии амплитуд.
// MockVADService — фиксированный контракт.

final class VADServiceTests: XCTestCase {

    private static let sampleRate: Double = 16_000

    /// 16kHz mono буфер из массива сэмплов. static + локальное создание → Sendable-safe.
    private static func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate, channels: 1, interleaved: false)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(samples.count, 1)))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        for (i, s) in samples.enumerated() { buf.floatChannelData![0][i] = s }
        return buf
    }

    private static func tone(_ n: Int, amp: Float, freq: Float = 220) -> [Float] {
        (0 ..< n).map { amp * sin(2 * .pi * freq * Float($0) / Float(sampleRate)) }
    }

    private static func silence(_ n: Int) -> [Float] { [Float](repeating: 0, count: n) }

    // MARK: - isSpeech: happy path

    func test_isSpeech_loudTone_returnsTrue() {
        let sut = LiveVADService()
        // Громкий тон заметно превышает adaptive baseline + speechThreshold.
        let speech = sut.isSpeech(buffer: Self.makeBuffer(Self.tone(512, amp: 0.8)))
        XCTAssertTrue(speech, "Громкий тон должен распознаваться как речь")
    }

    func test_isSpeech_silence_returnsFalse() {
        let sut = LiveVADService()
        let speech = sut.isSpeech(buffer: Self.makeBuffer(Self.silence(512)))
        XCTAssertFalse(speech, "Тишина не должна распознаваться как речь")
    }

    // MARK: - isActive hysteresis (edge case)

    func test_isActive_becomesTrueOnSpeech_thenFalseAfterSilenceFrames() {
        let sut = LiveVADService()
        // Один громкий буфер → isActive == true.
        _ = sut.isSpeech(buffer: Self.makeBuffer(Self.tone(512, amp: 0.9)))
        XCTAssertTrue(sut.isActive, "После речи VAD активен")

        // Гистерезис: тишины должно быть > silenceFrames (30), чтобы деактивировать.
        for _ in 0..<35 {
            _ = sut.isSpeech(buffer: Self.makeBuffer(Self.silence(512)))
        }
        XCTAssertFalse(sut.isActive, "После 30+ кадров тишины VAD деактивируется")
    }

    func test_isActive_staysTrueDuringShortSilence() {
        let sut = LiveVADService()
        _ = sut.isSpeech(buffer: Self.makeBuffer(Self.tone(512, amp: 0.9)))
        // Меньше silenceFrames кадров тишины → всё ещё активен.
        for _ in 0..<10 {
            _ = sut.isSpeech(buffer: Self.makeBuffer(Self.silence(512)))
        }
        XCTAssertTrue(sut.isActive, "Короткая пауза не сбрасывает активность")
    }

    // MARK: - isSpeech: empty buffer (error/edge case)

    func test_isSpeech_emptyBuffer_returnsFalse() {
        let sut = LiveVADService()
        let buf = Self.makeBuffer([])
        XCTAssertFalse(sut.isSpeech(buffer: buf), "Пустой буфер → не речь, без краша")
    }

    // MARK: - detectFatigue

    func test_detectFatigue_insufficientHistory_returnsNormal() {
        let sut = LiveVADService()
        // < 10 элементов → ранний выход в .normal.
        XCTAssertEqual(sut.detectFatigue(amplitudeHistory: [0.2, 0.3, 0.1]), .normal)
    }

    func test_detectFatigue_lowAmplitude_returnsTired() {
        let sut = LiveVADService()
        // mean в диапазоне 0..<0.05 → .tired.
        let history = [Float](repeating: 0.02, count: 12)
        XCTAssertEqual(sut.detectFatigue(amplitudeHistory: history), .tired)
    }

    func test_detectFatigue_lowVariance_returnsTired() {
        let sut = LiveVADService()
        // mean выше 0.05, но дисперсия почти нулевая (монотонный сигнал) → .tired.
        let history = [Float](repeating: 0.1, count: 12)
        XCTAssertEqual(sut.detectFatigue(amplitudeHistory: history), .tired)
    }

    func test_detectFatigue_normalRange_returnsNormal() {
        let sut = LiveVADService()
        // mean ≈ 0.1 (диапазон 0.05..<0.15) с дисперсией выше порога 0.002 → .normal.
        let history: [Float] = [0.02, 0.18, 0.03, 0.17, 0.04, 0.16, 0.05, 0.15, 0.06, 0.14, 0.07, 0.13]
        XCTAssertEqual(sut.detectFatigue(amplitudeHistory: history), .normal)
    }

    func test_detectFatigue_highAmplitude_returnsFresh() {
        let sut = LiveVADService()
        // mean > 0.15 с дисперсией выше порога → .fresh.
        let history: [Float] = [0.2, 0.4, 0.25, 0.45, 0.3, 0.5, 0.22, 0.48, 0.35, 0.4, 0.28, 0.46]
        XCTAssertEqual(sut.detectFatigue(amplitudeHistory: history), .fresh)
    }

    // MARK: - MockVADService contract

    func test_mock_alwaysSpeech_alwaysNormalFatigue() {
        let mock = MockVADService()
        XCTAssertTrue(mock.isSpeech(buffer: Self.makeBuffer(Self.silence(512))))
        XCTAssertEqual(mock.detectFatigue(amplitudeHistory: []), .normal)
        XCTAssertFalse(mock.isActive)
    }
}
