@testable import HappySpeech
import AVFoundation
import XCTest

// MARK: - AdaptiveVADTests
//
// v32 — покрытие адаптивного AmplitudeVAD (порог по фоновому шуму + гистерезис)
// и контракта makeVAD(). Silero VAD заблокирован (stateful LSTM, см.
// ADR-V32-SILERO-VAD-BLOCKED) — основной on-device детектор это AmplitudeVAD.

final class AdaptiveVADTests: XCTestCase {

    private static let sampleRate = Double(VADResult.Constants.sampleRate)
    private let chunk = VADResult.Constants.chunkSize  // 512

    /// Создаёт 16kHz mono буфер заданной длины из массива сэмплов.
    /// `static` + создаётся локально → не пересекается с актором (Sendable-safe).
    private static func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate, channels: 1, interleaved: false)!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        for (i, s) in samples.enumerated() { buf.floatChannelData![0][i] = s }
        return buf
    }

    private func silence(_ n: Int) -> [Float] { [Float](repeating: 0, count: n) }

    private func tone(_ n: Int, amp: Float, freq: Float = 220) -> [Float] {
        (0 ..< n).map { amp * sin(2 * .pi * freq * Float($0) / Float(Self.sampleRate)) }
    }

    /// Прогоняет буфер через VAD внутри одного выражения, не удерживая ссылку
    /// на не-Sendable буфер за пределами вызова.
    private func runSession(_ samples: [Float], vad: AmplitudeVAD) async throws -> VADSession {
        try await vad.processBuffer(Self.makeBuffer(samples))
    }

    // MARK: - makeVAD factory

    func test_makeVAD_returnsAmplitudeVAD() async {
        let vad = await makeVAD()
        XCTAssertTrue(vad is AmplitudeVAD, "makeVAD должен возвращать адаптивный AmplitudeVAD")
    }

    // MARK: - Speech vs silence

    func test_loudTone_detectedAsSpeech() async throws {
        let vad = AmplitudeVAD()
        // буфер: тишина для калибровки фона + громкий тон
        let samples = silence(chunk * 4) + tone(chunk * 4, amp: 0.5)
        let session = try await runSession(samples, vad: vad)
        let speechChunks = session.chunks.filter { $0.isSpeech }.count
        XCTAssertGreaterThan(speechChunks, 0, "Громкий тон должен детектироваться как речь")
        XCTAssertTrue(session.hasSpeech)
    }

    func test_pureSilence_noSpeech() async throws {
        let vad = AmplitudeVAD()
        let session = try await runSession(silence(chunk * 8), vad: vad)
        let speechChunks = session.chunks.filter { $0.isSpeech }.count
        XCTAssertEqual(speechChunks, 0, "Тишина не должна давать речь")
        XCTAssertFalse(session.hasSpeech)
    }

    // MARK: - Adaptive threshold to background noise

    func test_adaptiveThreshold_quietSpeechOverQuietNoise_detected() async throws {
        let vad = AmplitudeVAD()
        // очень тихий фон, затем относительно тихая «речь» — адаптация должна
        // поднять чувствительность и поймать речь над низким noiseFloor.
        let samples = tone(chunk * 6, amp: 0.002) + tone(chunk * 6, amp: 0.05)
        let session = try await runSession(samples, vad: vad)
        let lateSpeech = session.chunks.suffix(6).filter { $0.isSpeech }.count
        XCTAssertGreaterThan(lateSpeech, 0,
            "Над тихим фоном тихая речь должна детектироваться (адаптивный порог)")
    }

    func test_speechOnsetFromSilence_detected() async throws {
        // Внезапный устойчивый громкий сигнал из тишины — это онсет речи
        // (нет предшествующего «тихого» периода, чтобы выучить его как фон).
        // VAD должен честно считать его речью.
        let vad = AmplitudeVAD()
        let samples = tone(chunk * 12, amp: 0.08)
        let session = try await runSession(samples, vad: vad)
        let speechRatio = Double(session.chunks.filter { $0.isSpeech }.count) /
                          Double(max(session.chunks.count, 1))
        XCTAssertGreaterThan(speechRatio, 0.5,
            "Устойчивый громкий онсет из тишины — речь")
    }

    func test_noiseFloorAdapts_thenQuietRelativeSignalNotSpeech() async throws {
        // Сначала умеренный фон удерживается «тихим» относительно громких пиков,
        // что поднимает noiseFloor; затем сигнал той же амплитуды, что и фон,
        // не должен массово считаться речью (адаптация порога вверх).
        let vad = AmplitudeVAD()
        // чередуем громкие пики (речь) и фон 0.03 — фон будет «тихим» относительно
        // пиков и поднимет noiseFloor; финальный ровный участок 0.03 — уже фон.
        var samples: [Float] = []
        for _ in 0 ..< 4 {
            samples += tone(chunk, amp: 0.5)   // громкий пик
            samples += tone(chunk, amp: 0.03)  // фон
        }
        samples += tone(chunk * 4, amp: 0.03)  // ровный фон в конце
        let session = try await runSession(samples, vad: vad)
        let tailSpeech = session.chunks.suffix(4).filter { $0.isSpeech }.count
        XCTAssertEqual(tailSpeech, 0,
            "После адаптации noiseFloor ровный фоновый сигнал не должен считаться речью")
    }

    // MARK: - VADResult / probability sanity

    func test_speechProbability_inRange() async throws {
        let vad = AmplitudeVAD()
        let session = try await runSession(silence(chunk) + tone(chunk * 3, amp: 0.4), vad: vad)
        for r in session.chunks {
            XCTAssertGreaterThanOrEqual(r.speechProbability, 0)
            XCTAssertLessThanOrEqual(r.speechProbability, 1)
        }
    }
}
