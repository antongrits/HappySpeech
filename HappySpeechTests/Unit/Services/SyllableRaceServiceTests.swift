@preconcurrency import AVFoundation
@testable import HappySpeech
import XCTest

// MARK: - SyllableRaceServiceTests
//
// Покрытие сервисного слоя «Скороговорки-ракеты» (DDK / диадохокинез).
// DSP-ядро (SyllableRateAnalyzer/Classifier) уже покрыто в SyllableRateAnalyzerTests —
// здесь тестируется именно Services-обёртка:
//
//   • LiveSyllableRaceService.loadPCM16kMono — чтение и ресемплинг аудиофайла:
//       - уже 16 кГц mono → отдаётся без конвертации, длина сохраняется;
//       - 44.1 кГц → ресемплинг к 16 кГц (длина ≈ ratio, mono);
//       - несуществующий/битый файл → бросает.
//   • LiveSyllableRaceService.analyzeAttempt — end-to-end на реальном WAV
//     (ритмичный слоговой ряд из тон-бёрстов) → детерминированная DDKEvaluation;
//     тишина → честный verdict .notDetected без фабрикации.
//   • MockSyllableRaceService — скрипт ответов, ротация cursor по кругу,
//     receivedSequenceIds для проверки переданных аргументов.

final class SyllableRaceServiceTests: XCTestCase {

    private let sampleRate = SyllableRateAnalyzer.expectedSampleRate  // 16000

    // MARK: - WAV-хелперы (real files in temp)

    /// Пишет mono WAV заданной частоты из массива сэмплов и возвращает URL.
    private func writeWav(_ samples: [Float], sampleRate: Double) throws -> URL {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { throw XCTSkip("Не удалось создать AVAudioFormat") }
        let frames = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw XCTSkip("Не удалось создать буфер")
        }
        buffer.frameLength = frames
        if let channel = buffer.floatChannelData?[0] {
            for (index, value) in samples.enumerated() { channel[index] = value }
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ddk_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    /// Ритмичный слоговой ряд: `count` тон-бёрстов длиной `burst` с паузой `gap`.
    private func syllableTrain(
        count: Int,
        burstSec: Double = 0.12,
        gapSec: Double = 0.12,
        amp: Float = 0.5,
        freq: Float = 200,
        rate: Double
    ) -> [Float] {
        let burstN = Int(burstSec * rate)
        let gapN = Int(gapSec * rate)
        var out: [Float] = []
        for _ in 0 ..< count {
            for i in 0 ..< burstN {
                out.append(amp * sin(2 * .pi * freq * Float(i) / Float(rate)))
            }
            out.append(contentsOf: [Float](repeating: 0, count: gapN))
        }
        return out
    }

    private func cleanup(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    private func sequence(syllables: Int) -> DDKSequence {
        DDKSequence(id: "ddk-test", syllables: ["па"], cycleLength: 1, targetCycles: syllables)
    }

    // MARK: - loadPCM16kMono: уже 16 кГц mono → без конвертации, длина сохранена

    func test_loadPCM16kMono_already16kMono_preservesLength() throws {
        let samples = syllableTrain(count: 4, rate: sampleRate)
        let url = try writeWav(samples, sampleRate: sampleRate)
        defer { cleanup(url) }

        let pcm = try LiveSyllableRaceService.loadPCM16kMono(url: url)
        // Допускаем небольшую разницу за счёт записи/чтения контейнера.
        XCTAssertEqual(Double(pcm.count), Double(samples.count), accuracy: Double(sampleRate) * 0.05,
                       "16 кГц mono должно читаться почти без изменения длины")
        XCTAssertGreaterThan(pcm.count, 0)
    }

    // MARK: - loadPCM16kMono: 44.1 кГц → ресемплинг к 16 кГц (длина уменьшается)

    func test_loadPCM16kMono_resamplesFrom44kTo16k() throws {
        let highRate = 44_100.0
        let samples = syllableTrain(count: 3, rate: highRate)
        let url = try writeWav(samples, sampleRate: highRate)
        defer { cleanup(url) }

        let pcm = try LiveSyllableRaceService.loadPCM16kMono(url: url)
        let expected = Double(samples.count) * (sampleRate / highRate)
        XCTAssertGreaterThan(pcm.count, 0)
        // Ресемплинг → длина ≈ expected (±10% запас на края конвертера).
        XCTAssertEqual(Double(pcm.count), expected, accuracy: expected * 0.10,
                       "Ресемплинг 44.1→16 кГц должен сжать число сэмплов в ~2.76 раза")
        XCTAssertLessThan(pcm.count, samples.count, "16 кГц короче, чем 44.1 кГц")
    }

    // MARK: - loadPCM16kMono: несуществующий файл → бросает

    func test_loadPCM16kMono_missingFile_throws() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does_not_exist_\(UUID().uuidString).wav")
        XCTAssertThrowsError(try LiveSyllableRaceService.loadPCM16kMono(url: missing))
    }

    // MARK: - analyzeAttempt: реальный ритмичный ряд → распознан, не notDetected

    func test_analyzeAttempt_rhythmicTrain_detectsSyllables() async throws {
        // 6 ровных слогов: burst+gap = 0.24с → темп ~4.2 слог/с.
        let samples = syllableTrain(count: 6, rate: sampleRate)
        let url = try writeWav(samples, sampleRate: sampleRate)
        defer { cleanup(url) }

        let service = LiveSyllableRaceService()
        let evaluation = try await service.analyzeAttempt(
            url: url, sequence: sequence(syllables: 6), childAge: 6
        )
        XCTAssertNotEqual(evaluation.verdict, .notDetected,
                          "Ровный слоговой ряд должен распознаться")
        XCTAssertGreaterThanOrEqual(evaluation.detectedSyllables, 2)
        XCTAssertGreaterThan(evaluation.syllablesPerSecond, 0)
        XCTAssertEqual(evaluation.targetSyllables, 6)
        XCTAssertGreaterThanOrEqual(evaluation.stars, 1)
    }

    // MARK: - analyzeAttempt: тишина → honest notDetected, без фабрикации

    func test_analyzeAttempt_silence_returnsNotDetected() async throws {
        let silence = [Float](repeating: 0, count: Int(sampleRate * 1.5))
        let url = try writeWav(silence, sampleRate: sampleRate)
        defer { cleanup(url) }

        let service = LiveSyllableRaceService()
        let evaluation = try await service.analyzeAttempt(
            url: url, sequence: sequence(syllables: 8), childAge: 6
        )
        XCTAssertEqual(evaluation.verdict, .notDetected)
        XCTAssertEqual(evaluation.stars, 0)
        XCTAssertEqual(evaluation.syllablesPerSecond, 0, accuracy: 0.0001)
    }

    // MARK: - analyzeAttempt: битый/пустой файл → бросает audioFormatUnsupported

    func test_analyzeAttempt_unreadableFile_throws() async throws {
        // Файл с не-аудио содержимым.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("garbage_\(UUID().uuidString).wav")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: url)
        defer { cleanup(url) }

        let service = LiveSyllableRaceService()
        var caught: Error?
        do {
            _ = try await service.analyzeAttempt(
                url: url, sequence: sequence(syllables: 8), childAge: 6
            )
        } catch {
            caught = error
        }
        // Битый файл обязан привести к ошибке (AVAudioFile / AppError) — не к фабрикации.
        let error = try XCTUnwrap(caught, "Битый файл должен привести к ошибке, а не к результату")
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    // MARK: - MockSyllableRaceService: дефолтный ответ

    func test_mockService_default_returnsDefaultEvaluation() async throws {
        let mock = MockSyllableRaceService()
        let eval = try await mock.analyzeAttempt(
            url: URL(fileURLWithPath: "/tmp/x.wav"),
            sequence: DDKCatalog.sequences[0],
            childAge: 6
        )
        XCTAssertEqual(eval, MockSyllableRaceService.defaultEvaluation)
        XCTAssertEqual(eval.verdict, .fastSteady)
        XCTAssertEqual(eval.stars, 3)
    }

    // MARK: - MockSyllableRaceService: скрипт ответов с ротацией cursor

    func test_mockService_scriptedResponses_rotate() async throws {
        let first = MockSyllableRaceService.defaultEvaluation
        let second = DDKEvaluation(
            syllablesPerSecond: 2.0, steadiness: 0.4, detectedSyllables: 4,
            targetSyllables: 8, verdict: .slow, flags: [.incompleteSequence],
            stars: 1, measurement: nil
        )
        let mock = MockSyllableRaceService(scripted: [first, second])
        let url = URL(fileURLWithPath: "/tmp/x.wav")
        let seq = DDKCatalog.sequences[0]

        let r1 = try await mock.analyzeAttempt(url: url, sequence: seq, childAge: 6)
        let r2 = try await mock.analyzeAttempt(url: url, sequence: seq, childAge: 6)
        let r3 = try await mock.analyzeAttempt(url: url, sequence: seq, childAge: 6)

        XCTAssertEqual(r1, first)
        XCTAssertEqual(r2, second)
        XCTAssertEqual(r3, first, "После конца скрипта cursor должен пойти по кругу")
    }

    // MARK: - MockSyllableRaceService: receivedSequenceIds фиксирует аргументы

    func test_mockService_recordsReceivedSequenceIds() async throws {
        let mock = MockSyllableRaceService()
        let url = URL(fileURLWithPath: "/tmp/x.wav")
        _ = try await mock.analyzeAttempt(url: url, sequence: DDKCatalog.sequences[0], childAge: 6)
        _ = try await mock.analyzeAttempt(url: url, sequence: DDKCatalog.sequences[3], childAge: 7)

        let ids = await mock.receivedSequenceIds
        XCTAssertEqual(ids, [DDKCatalog.sequences[0].id, DDKCatalog.sequences[3].id])
    }

    // MARK: - MockSyllableRaceService: пустой скрипт → подставляется дефолт

    func test_mockService_emptyScript_fallsBackToDefault() async throws {
        let mock = MockSyllableRaceService(scripted: [])
        let eval = try await mock.analyzeAttempt(
            url: URL(fileURLWithPath: "/tmp/x.wav"),
            sequence: DDKCatalog.sequences[0],
            childAge: 6
        )
        XCTAssertEqual(eval, MockSyllableRaceService.defaultEvaluation)
    }
}
