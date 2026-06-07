@preconcurrency import AVFoundation
@testable import HappySpeech
import XCTest

// MARK: - BlowDetectionServiceTests
//
// Покрытие акустической детекции выдоха/дутья на Apple Sound Analysis + DSP.
// Верифицируемо на симуляторе: путь через файл (`analyzeFile` поверх
// SNAudioFileAnalyzer + AirStreamAnalyzer) детерминирован и не требует
// микрофона/устройства. Тесты подают синтезированный «выдох» (широкополосный/
// низкочастотный шум) и тишину, проверяя детекцию реального сигнала.

final class BlowDetectionServiceTests: XCTestCase {

    // MARK: - Helpers

    private static let sampleRate: Double = 16_000

    /// Пишет валидный 16kHz mono WAV из массива сэмплов в temp и возвращает URL.
    private func writeWAV(_ samples: [Float]) throws -> URL {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ) else { throw XCTSkip("Не удалось создать AVAudioFormat") }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else { throw XCTSkip("Не удалось создать AVAudioPCMBuffer") }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData?[0] {
            for (i, s) in samples.enumerated() { channel[i] = s }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("blow_test_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func silence(seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(Self.sampleRate * seconds))
    }

    /// Детерминированный xorshift64 — стабильный «белый шум» без зависимости от
    /// системного rand(): тест не должен флакать от прогона к прогону.
    private struct SeedRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    /// Низкочастотный воздушный шум — спектральный профиль реального выдоха в
    /// микрофон: доминирует полоса 0–500 Hz, нет голосовых гармоник, поток
    /// устойчивый и достаточно громкий (сильный направленный выдох в микрофон,
    /// а не еле слышное дыхание у границы порога). Детерминирован (seeded RNG).
    private func breathNoise(seconds: Double, amp: Float = 0.6) -> [Float] {
        let n = Int(Self.sampleRate * seconds)
        var state: Float = 0
        var out = [Float](repeating: 0, count: n)
        var rng = SeedRNG(state: 0x9E37_79B9_7F4A_7C15)
        for i in 0..<n {
            // Детерминированный белый шум −1…1 из старших бит генератора.
            let white = Float(rng.next() >> 11) / Float(1 << 53) * 2 - 1
            // Однополюсный low-pass: концентрирует энергию в низких частотах.
            state = state * 0.96 + white * 0.04
            out[i] = state * amp * 12  // компенсация затухания LP
        }
        return out
    }

    // MARK: - BlowSignalFusion (чистая логика, без аудиостека)

    func test_fusion_breathingProfile_aboveThreshold_detectsBlowWithHysteresis() {
        var fusion = BlowSignalFusion(config: .default)
        let profile = AirStreamProfile(
            streamType: .breathing,
            intensity: 0.8,
            confidence: 0.9,
            breathingBandEnergy: 0.7,
            whistlingBandEnergy: 0.05,
            hissingBandEnergy: 0.1
        )
        // Первый кадр: гистерезис ещё не открыт (minSustainFrames=2).
        let first = fusion.fuse(profile: profile, classifierConfidence: 0, timestamp: 0)
        XCTAssertFalse(first.isBlowing, "Один кадр не должен открывать гейт (гистерезис)")
        XCTAssertGreaterThan(first.strength, BlowDetectionConfig.default.strengthThreshold)
        // Второй кадр подряд: гейт открыт — реальный устойчивый выдох.
        let second = fusion.fuse(profile: profile, classifierConfidence: 0, timestamp: 0.032)
        XCTAssertTrue(second.isBlowing, "Два активных кадра подряд → дутьё обнаружено")
        XCTAssertGreaterThan(second.dspConfidence, 0)
    }

    func test_fusion_silence_neverDetectsBlow() {
        var fusion = BlowSignalFusion(config: .default)
        let silent = AirStreamProfile(
            streamType: .silence, intensity: 0, confidence: 1,
            breathingBandEnergy: 0, whistlingBandEnergy: 0, hissingBandEnergy: 0
        )
        for i in 0..<10 {
            let s = fusion.fuse(profile: silent, classifierConfidence: 0, timestamp: Double(i) * 0.032)
            XCTAssertFalse(s.isBlowing, "Тишина не должна давать дутьё")
            XCTAssertEqual(s.strength, 0, accuracy: 0.001)
        }
    }

    func test_fusion_voiceProfile_doesNotCountAsBlow() {
        var fusion = BlowSignalFusion(config: .default)
        let voice = AirStreamProfile(
            streamType: .voice, intensity: 0.9, confidence: 0.9,
            breathingBandEnergy: 0.1, whistlingBandEnergy: 0.1, hissingBandEnergy: 0.1
        )
        for i in 0..<6 {
            let s = fusion.fuse(profile: voice, classifierConfidence: 0, timestamp: Double(i) * 0.032)
            XCTAssertFalse(s.isBlowing, "Голос (речь) — не выдох/дутьё")
            XCTAssertEqual(s.dspConfidence, 0, accuracy: 0.001)
        }
    }

    func test_fusion_classifierBoost_opensGateWhenDSPWeak() {
        var fusion = BlowSignalFusion(config: .default)
        // Слабый, но дыхательный профиль; встроенный классификатор уверенно
        // подтверждает выдох → совокупная сила превышает порог.
        let weakBreath = AirStreamProfile(
            streamType: .breathing, intensity: 0.3, confidence: 0.4,
            breathingBandEnergy: 0.3, whistlingBandEnergy: 0, hissingBandEnergy: 0
        )
        _ = fusion.fuse(profile: weakBreath, classifierConfidence: 0.95, timestamp: 0)
        let second = fusion.fuse(profile: weakBreath, classifierConfidence: 0.95, timestamp: 0.032)
        XCTAssertTrue(second.isBlowing, "Уверенный классификатор усиливает слабый DSP-сигнал")
        XCTAssertGreaterThan(second.classifierConfidence, 0.9)
    }

    func test_fusion_reset_clearsHysteresis() {
        var fusion = BlowSignalFusion(config: .default)
        let profile = AirStreamProfile(
            streamType: .breathing, intensity: 0.8, confidence: 0.9,
            breathingBandEnergy: 0.7, whistlingBandEnergy: 0, hissingBandEnergy: 0
        )
        _ = fusion.fuse(profile: profile, classifierConfidence: 0, timestamp: 0)
        _ = fusion.fuse(profile: profile, classifierConfidence: 0, timestamp: 0.032)
        fusion.reset()
        let afterReset = fusion.fuse(profile: profile, classifierConfidence: 0, timestamp: 0.064)
        XCTAssertFalse(afterReset.isBlowing, "После reset гистерезис должен начаться заново")
    }

    // MARK: - Relevant labels matching (без хардкода версий классификатора)

    func test_relevantLabels_matchesBreathWindBlowRoots() {
        let known = ["speech", "breathing", "wind", "music", "blowing_nose", "applause", "whistling"]
        let relevant = BlowDetectionCore.relevantLabels(in: known)
        XCTAssertTrue(relevant.contains("breathing"))
        XCTAssertTrue(relevant.contains("wind"))
        XCTAssertTrue(relevant.contains("whistling"))
        XCTAssertTrue(relevant.contains("blowing_nose"))
        XCTAssertFalse(relevant.contains("speech"))
        XCTAssertFalse(relevant.contains("music"))
        XCTAssertFalse(relevant.contains("applause"))
    }

    func test_relevantLabels_emptyWhenNoMatches() {
        let relevant = BlowDetectionCore.relevantLabels(in: ["speech", "music", "applause", "dog"])
        XCTAssertTrue(relevant.isEmpty, "Без релевантных меток множество пустое → DSP-режим")
    }

    // MARK: - BlowFileResult aggregation

    func test_fileResult_aggregatesRatioPeakAndLongestRun() {
        let active = BlowSample(isBlowing: true, strength: 0.6, dspConfidence: 0.7,
                                classifierConfidence: 0, timestamp: 0)
        func sample(_ blowing: Bool, t: TimeInterval, strength: Float) -> BlowSample {
            BlowSample(isBlowing: blowing, strength: strength, dspConfidence: 0,
                       classifierConfidence: 0, timestamp: t)
        }
        let samples = [
            sample(false, t: 0.00, strength: 0.0),
            sample(true,  t: 0.10, strength: 0.5),
            sample(true,  t: 0.20, strength: 0.9),   // пик
            sample(true,  t: 0.30, strength: 0.6),
            sample(false, t: 0.40, strength: 0.0),
            sample(true,  t: 0.50, strength: 0.4)
        ]
        let result = BlowFileResult(samples: samples)
        XCTAssertEqual(result.blowingRatio, 4.0 / 6.0, accuracy: 0.001)
        XCTAssertEqual(result.peakStrength, 0.9, accuracy: 0.001)
        // Самая длинная серия — 3 кадра по шагу 0.10 c = 0.30 c.
        XCTAssertEqual(result.longestBlowDuration, 0.30, accuracy: 0.001)
        XCTAssertTrue(result.hasSustainedBlow)
        _ = active
    }

    func test_fileResult_empty_isInert() {
        let result = BlowFileResult(samples: [])
        XCTAssertEqual(result.blowingRatio, 0)
        XCTAssertEqual(result.peakStrength, 0)
        XCTAssertEqual(result.longestBlowDuration, 0)
        XCTAssertFalse(result.hasSustainedBlow)
    }

    // MARK: - analyzeFile (verifiable on simulator, real WAV path)

    func test_analyzeFile_silence_noSustainedBlow() async throws {
        let url = try writeWAV(silence(seconds: 1.0))
        defer { cleanup(url) }
        let service = LiveBlowDetectionService()
        let result = try await service.analyzeFile(url: url)
        XCTAssertFalse(result.hasSustainedBlow, "Тишина не должна детектироваться как выдох")
        XCTAssertEqual(result.peakStrength, 0, accuracy: 0.05)
        XCTAssertFalse(result.samples.isEmpty, "Должны быть покадровые сэмплы")
    }

    func test_analyzeFile_breathNoise_detectsSustainedBlow() async throws {
        // Низкочастотный шум ≈ реальный выдох в микрофон.
        let url = try writeWAV(silence(seconds: 0.1) + breathNoise(seconds: 1.2))
        defer { cleanup(url) }
        let service = LiveBlowDetectionService()
        let result = try await service.analyzeFile(url: url)
        XCTAssertTrue(result.hasSustainedBlow,
                      "Низкочастотный воздушный шум должен детектироваться как устойчивый выдох")
        XCTAssertGreaterThan(result.peakStrength, BlowDetectionConfig.default.strengthThreshold)
        XCTAssertGreaterThan(result.longestBlowDuration, 0.3,
                             "Должна быть заметная непрерывная серия выдоха")
    }

    func test_analyzeFile_missingFile_throws() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("does_not_exist_\(UUID().uuidString).wav")
        let service = LiveBlowDetectionService()
        do {
            _ = try await service.analyzeFile(url: url)
            XCTFail("Ожидалась ошибка чтения отсутствующего файла")
        } catch let error as BlowDetectionError {
            if case .fileNotReadable = error { return }
            XCTFail("Ожидалась .fileNotReadable, получено \(error)")
        } catch {
            XCTFail("Ожидалась BlowDetectionError, получено \(error)")
        }
    }

    // MARK: - Mock conforms to protocol (Preview / интеграция)

    func test_mockBlowDetection_conformsAndStreams() async {
        let mock = MockBlowDetectionService()
        mock.fileResult = BlowFileResult(samples: [
            BlowSample(isBlowing: true, strength: 0.7, dspConfidence: 0.7,
                       classifierConfidence: 0, timestamp: 0),
            BlowSample(isBlowing: true, strength: 0.7, dspConfidence: 0.7,
                       classifierConfidence: 0, timestamp: 0.1)
        ])
        let started = await mock.startLive()
        XCTAssertTrue(started)
        let result = try? await mock.analyzeFile(url: URL(fileURLWithPath: "/dev/null"))
        XCTAssertEqual(result?.blowingRatio, 1.0)
        await mock.stopLive()
    }
}
