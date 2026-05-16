@testable import HappySpeech
import Foundation
import XCTest

// MARK: - MelSpectrogramExtractorTests
//
// Block 2.8.4 v25 — DSP-математика log-mel спектрограммы.
//
// MelSpectrogramExtractor — чистый vDSP-пайплайн (pre-emphasis → framing →
// Hamming → FFT → mel filterbank → log) без сетевых вызовов. Полностью
// детерминирован: на известный сигнал даёт известную структуру.
//
// Параметры (унифицированы с RealMFCCExtractor):
//   SR 16 kHz, frame 400, hop 160, nFFT 512, 40 mel-бинов.

final class MelSpectrogramExtractorTests: XCTestCase {

    private var extractor: MelSpectrogramExtractor!

    override func setUp() async throws {
        try await super.setUp()
        extractor = MelSpectrogramExtractor()
    }

    override func tearDown() async throws {
        extractor = nil
        try await super.tearDown()
    }

    /// Синусоида заданной частоты, 16 kHz mono.
    private func sineWave(frequencyHz: Double, samples: Int, amplitude: Float = 0.5) -> [Float] {
        let sr = MelSpectrogramExtractor.sampleRate
        return (0..<samples).map { i in
            amplitude * Float(sin(2.0 * Double.pi * frequencyHz * Double(i) / sr))
        }
    }

    // MARK: - Constants

    func test_constants_unifiedWithMFCCPipeline() {
        XCTAssertEqual(MelSpectrogramExtractor.sampleRate, 16_000)
        XCTAssertEqual(MelSpectrogramExtractor.frameSize, 400)
        XCTAssertEqual(MelSpectrogramExtractor.hopSize, 160)
        XCTAssertEqual(MelSpectrogramExtractor.nFFT, 512)
        XCTAssertEqual(MelSpectrogramExtractor.nMelBins, 40)
    }

    // MARK: - extract([Float])

    func test_extract_silence_producesFrames() async {
        let silence = [Float](repeating: 0, count: 16_000)
        let result = await extractor.extract(from: silence)
        XCTAssertFalse(result.frames.isEmpty)
        // 1 сек @ 16kHz, frame 400, hop 160 → (16000-400)/160 + 1 = 98 кадров
        XCTAssertEqual(result.frames.count, 98)
    }

    func test_extract_everyFrameHas40MelBins() async {
        let signal = sineWave(frequencyHz: 1000, samples: 16_000)
        let result = await extractor.extract(from: signal)
        for frame in result.frames {
            XCTAssertEqual(frame.count, 40, "Каждый кадр — 40 mel-бинов")
        }
    }

    func test_extract_durationMatchesInput() async {
        let signal = sineWave(frequencyHz: 440, samples: 8_000)
        let result = await extractor.extract(from: signal)
        XCTAssertEqual(result.duration, 0.5, accuracy: 0.001, "8000 / 16000 = 0.5 сек")
    }

    func test_extract_sampleRatePreserved() async {
        let result = await extractor.extract(from: sineWave(frequencyHz: 440, samples: 4_000))
        XCTAssertEqual(result.sampleRate, 16_000)
    }

    func test_extract_shortAudio_belowFrameSize_emptyFrames() async {
        // Меньше frameSize (400) → ни одного кадра не помещается
        let result = await extractor.extract(from: [Float](repeating: 0.1, count: 100))
        XCTAssertTrue(result.frames.isEmpty)
        XCTAssertEqual(result.duration, 100.0 / 16_000.0, accuracy: 0.0001)
    }

    func test_extract_exactlyOneFrame() async {
        // Ровно frameSize сэмплов → ровно 1 кадр
        let result = await extractor.extract(from: sineWave(frequencyHz: 500, samples: 400))
        XCTAssertEqual(result.frames.count, 1)
    }

    func test_extract_emptyAudio_emptyFrames() async {
        let result = await extractor.extract(from: [])
        XCTAssertTrue(result.frames.isEmpty)
        XCTAssertEqual(result.duration, 0)
    }

    func test_extract_tone_concentratesEnergyInRelevantBins() async {
        // Низкочастотный тон 300 Гц → энергия концентрируется в нижних mel-бинах.
        let signal = sineWave(frequencyHz: 300, samples: 16_000)
        let result = await extractor.extract(from: signal)
        guard let midFrame = result.frames[safe: result.frames.count / 2] else {
            return XCTFail("Нет среднего кадра")
        }
        // Нижние бины должны иметь большую энергию чем верхние.
        let lowEnergy = midFrame[0..<8].reduce(0, +)
        let highEnergy = midFrame[32..<40].reduce(0, +)
        XCTAssertGreaterThan(lowEnergy, highEnergy,
            "Тон 300 Гц → энергия в нижних mel-бинах")
    }

    func test_extract_silenceVsTone_differentEnergy() async {
        let silence = await extractor.extract(from: [Float](repeating: 0, count: 16_000))
        let tone = await extractor.extract(from: sineWave(frequencyHz: 800, samples: 16_000))
        let silenceSum = silence.frames.flatMap { $0 }.reduce(0, +)
        let toneSum = tone.frames.flatMap { $0 }.reduce(0, +)
        // log-mel тишины → очень низкие значения (log of ~1e-10).
        XCTAssertGreaterThan(toneSum, silenceSum)
    }

    func test_extract_logMelValuesAreFinite() async {
        let result = await extractor.extract(from: sineWave(frequencyHz: 600, samples: 16_000))
        for frame in result.frames {
            for value in frame {
                XCTAssertTrue(value.isFinite, "log-mel значения конечны (нет NaN/Inf)")
            }
        }
    }

    // MARK: - extract(Data)

    func test_extractData_emptyData_throwsEmptyAudio() async {
        do {
            _ = try await extractor.extract(from: Data())
            XCTFail("Пустой Data должен бросить ошибку")
        } catch let error as MelSpectrogramError {
            XCTAssertEqual(error, .emptyAudio)
        } catch {
            XCTFail("Ожидалась MelSpectrogramError, получено: \(error)")
        }
    }

    func test_extractData_validPCM_producesFrames() async throws {
        let floats = sineWave(frequencyHz: 700, samples: 16_000)
        let data = floats.withUnsafeBytes { Data($0) }
        let result = try await extractor.extract(from: data)
        XCTAssertFalse(result.frames.isEmpty)
    }

    func test_extractData_matchesFloatArrayExtraction() async throws {
        let floats = sineWave(frequencyHz: 440, samples: 8_000)
        let data = floats.withUnsafeBytes { Data($0) }
        let fromData = try await extractor.extract(from: data)
        let fromArray = await extractor.extract(from: floats)
        XCTAssertEqual(fromData.frames.count, fromArray.frames.count)
    }

    // MARK: - MelSpectrogram model

    func test_melSpectrogram_emptyConstant() {
        XCTAssertTrue(MelSpectrogram.empty.frames.isEmpty)
        XCTAssertEqual(MelSpectrogram.empty.duration, 0)
        XCTAssertEqual(MelSpectrogram.empty.sampleRate, 16_000)
    }

    func test_melSpectrogram_melBinCountConstant() {
        XCTAssertEqual(MelSpectrogram.melBinCount, 40)
    }

    func test_melSpectrogram_asUISpectrogramPreservesFrames() {
        let mel = MelSpectrogram(
            frames: [[1, 2, 3], [4, 5, 6]],
            sampleRate: 16_000,
            duration: 1.0
        )
        let ui = mel.asUISpectrogram
        XCTAssertEqual(ui.frames.count, 2)
        XCTAssertEqual(ui.duration, 1.0)
    }

    func test_melSpectrogram_equatable() {
        let a = MelSpectrogram(frames: [[1, 2]], sampleRate: 16_000, duration: 1)
        let b = MelSpectrogram(frames: [[1, 2]], sampleRate: 16_000, duration: 1)
        let c = MelSpectrogram(frames: [[9, 9]], sampleRate: 16_000, duration: 1)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_melSpectrogramError_localizedDescription() {
        XCTAssertNotNil(MelSpectrogramError.emptyAudio.errorDescription)
        XCTAssertFalse(MelSpectrogramError.emptyAudio.errorDescription?.isEmpty ?? true)
    }
}

// MARK: - Array safe subscript helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
