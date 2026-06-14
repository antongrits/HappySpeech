@preconcurrency import AVFoundation
@testable import HappySpeech
import XCTest

// MARK: - AcousticMirrorServiceTests
//
// Покрытие сервисного слоя «Акустического зеркала» (континуум С↔Ш).
// DSP-ядро (SibilantAcousticsAnalyzer/SibilantContinuumClassifier) уже покрыто в
// SibilantAcousticsTests — здесь тестируется именно Services-обёртка:
//
//   • LiveAcousticMirrorService.analyzeAttempt — guard на полюс: НЕсибилянт
//     (Р/Л/К…) → бросает AppError.mlInferenceFailed (ветка, которой нет в ядре).
//   • analyzeAttempt — реальный высокочастотный фрикативный шум (полюс С) →
//     детерминированная SibilantEvaluation с измерением; тишина → .noFrication.
//   • LiveAcousticMirrorService.loadPCM16kMono — чтение/ресемплинг (mono, 16 кГц).
//   • MockAcousticMirrorService — скрипт ответов, ротация cursor,
//     receivedTargetSounds для проверки переданного звука.

final class AcousticMirrorServiceTests: XCTestCase {

    private let sampleRate = SibilantAcousticsAnalyzer.expectedSampleRate  // 16000

    // MARK: - WAV-хелперы

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
            .appendingPathComponent("sibilant_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    /// Узкополосный высокочастотный шум (центр `centerHz`) — модель фрикативного
    /// сегмента сибилянта. Высокий центроид → полюс [с] (свистящий).
    private func fricativeNoise(
        durationSec: Double,
        centerHz: Double,
        amp: Float = 0.4
    ) -> [Float] {
        let n = Int(durationSec * sampleRate)
        var seed: UInt64 = 0x1234_5678
        func rand() -> Float {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(Int32(truncatingIfNeeded: seed >> 33)) / Float(Int32.max)
        }
        // Несущая на centerHz, модулированная белым шумом — даёт энергию у centerHz
        // с высоким ZCR (характерно для фрикатива).
        var out = [Float](repeating: 0, count: n)
        for i in 0 ..< n {
            let carrier = sin(2 * .pi * Float(centerHz) * Float(i) / Float(sampleRate))
            let noise = rand()
            out[i] = amp * carrier * (0.6 + 0.4 * noise)
        }
        return out
    }

    private func cleanup(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    // MARK: - Guard: НЕсибилянт → mlInferenceFailed

    func test_analyzeAttempt_nonSibilantSound_throwsMLInferenceFailed() async throws {
        let url = try writeWav(fricativeNoise(durationSec: 0.6, centerHz: 7_000), sampleRate: sampleRate)
        defer { cleanup(url) }

        let service = LiveAcousticMirrorService()
        do {
            _ = try await service.analyzeAttempt(url: url, targetSound: "Р")
            XCTFail("Звук Р не сибилянт — ожидалась ошибка mlInferenceFailed")
        } catch let error as AppError {
            guard case .mlInferenceFailed = error else {
                XCTFail("Ожидался AppError.mlInferenceFailed, получено: \(error)")
                return
            }
        }
    }

    func test_analyzeAttempt_emptySound_throwsMLInferenceFailed() async throws {
        let url = try writeWav(fricativeNoise(durationSec: 0.5, centerHz: 7_000), sampleRate: sampleRate)
        defer { cleanup(url) }

        let service = LiveAcousticMirrorService()
        do {
            _ = try await service.analyzeAttempt(url: url, targetSound: "")
            XCTFail("Пустой звук не сибилянт — ожидалась ошибка")
        } catch let error as AppError {
            guard case .mlInferenceFailed = error else {
                XCTFail("Ожидался mlInferenceFailed, получено: \(error)")
                return
            }
        }
    }

    // MARK: - Guard выполняется ДО чтения файла: несуществующий файл, но валидный С → тоже бросает (по полюсу нет, по файлу — да)

    func test_analyzeAttempt_validSibilantMissingFile_throws() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("absent_\(UUID().uuidString).wav")
        let service = LiveAcousticMirrorService()
        var caught: Error?
        do {
            _ = try await service.analyzeAttempt(url: missing, targetSound: "С")
        } catch {
            caught = error
        }
        // Полюс валиден (С), но файла нет → ошибка чтения аудио (не фабрикация).
        let error = try XCTUnwrap(caught, "Несуществующий файл должен привести к ошибке")
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    // MARK: - Тишина → honest noFrication, без фабрикации

    func test_analyzeAttempt_silence_returnsNoFrication() async throws {
        let silence = [Float](repeating: 0, count: Int(sampleRate * 1.0))
        let url = try writeWav(silence, sampleRate: sampleRate)
        defer { cleanup(url) }

        let service = LiveAcousticMirrorService()
        let evaluation = try await service.analyzeAttempt(url: url, targetSound: "С")
        XCTAssertEqual(evaluation.verdict, .noFrication)
        XCTAssertEqual(evaluation.stars, 0)
        XCTAssertNil(evaluation.measurement, "При noFrication измерение должно быть nil")
        XCTAssertEqual(evaluation.targetPole, .whistling)
    }

    // MARK: - Высокочастотный шум для С-цели → распознан фрикатив (не noFrication)

    func test_analyzeAttempt_highFreqNoiseForWhistling_detectsFrication() async throws {
        // Длинный (>0.4с) высокочастотный шум — устойчивый сибилянт у С-полюса.
        let url = try writeWav(
            fricativeNoise(durationSec: 0.8, centerHz: 7_200), sampleRate: sampleRate
        )
        defer { cleanup(url) }

        let service = LiveAcousticMirrorService()
        let evaluation = try await service.analyzeAttempt(url: url, targetSound: "С")
        XCTAssertNotEqual(evaluation.verdict, .noFrication,
                          "Устойчивый высокочастотный фрикативный шум должен распознаться")
        XCTAssertNotNil(evaluation.measurement)
        XCTAssertEqual(evaluation.targetPole, .whistling)
        // Континуум-позиция в допустимых границах 0…1.
        XCTAssertGreaterThanOrEqual(evaluation.continuumPosition, 0)
        XCTAssertLessThanOrEqual(evaluation.continuumPosition, 1)
    }

    // MARK: - loadPCM16kMono: уже 16 кГц mono → длина сохраняется

    func test_loadPCM16kMono_already16kMono_preservesLength() throws {
        let samples = fricativeNoise(durationSec: 0.5, centerHz: 6_000)
        let url = try writeWav(samples, sampleRate: sampleRate)
        defer { cleanup(url) }

        let pcm = try LiveAcousticMirrorService.loadPCM16kMono(url: url)
        XCTAssertEqual(Double(pcm.count), Double(samples.count), accuracy: Double(sampleRate) * 0.05)
        XCTAssertGreaterThan(pcm.count, 0)
    }

    // MARK: - loadPCM16kMono: 44.1 кГц → ресемплинг к 16 кГц

    func test_loadPCM16kMono_resamplesFrom44k() throws {
        let highRate = 44_100.0
        let n = Int(0.4 * highRate)
        let samples = (0 ..< n).map { 0.3 * sin(2 * .pi * 5_000 * Float($0) / Float(highRate)) }
        let url = try writeWav(samples, sampleRate: highRate)
        defer { cleanup(url) }

        let pcm = try LiveAcousticMirrorService.loadPCM16kMono(url: url)
        let expected = Double(samples.count) * (sampleRate / highRate)
        XCTAssertEqual(Double(pcm.count), expected, accuracy: expected * 0.10)
        XCTAssertLessThan(pcm.count, samples.count)
    }

    // MARK: - MockAcousticMirrorService: дефолт

    func test_mockService_default_returnsDefaultEvaluation() async throws {
        let mock = MockAcousticMirrorService()
        let eval = try await mock.analyzeAttempt(
            url: URL(fileURLWithPath: "/tmp/x.wav"), targetSound: "С"
        )
        XCTAssertEqual(eval, MockAcousticMirrorService.defaultEvaluation)
        XCTAssertEqual(eval.verdict, .onTarget)
        XCTAssertEqual(eval.stars, 3)
        XCTAssertEqual(eval.targetPole, .whistling)
    }

    // MARK: - MockAcousticMirrorService: скрипт с ротацией

    func test_mockService_scriptedResponses_rotate() async throws {
        let onTarget = MockAcousticMirrorService.defaultEvaluation
        let opposite = SibilantEvaluation(
            continuumPosition: 0.15, verdict: .oppositePole, flags: [],
            stars: 1, measurement: nil, targetPole: .whistling
        )
        let mock = MockAcousticMirrorService(scripted: [onTarget, opposite])
        let url = URL(fileURLWithPath: "/tmp/x.wav")

        let r1 = try await mock.analyzeAttempt(url: url, targetSound: "С")
        let r2 = try await mock.analyzeAttempt(url: url, targetSound: "С")
        let r3 = try await mock.analyzeAttempt(url: url, targetSound: "С")

        XCTAssertEqual(r1, onTarget)
        XCTAssertEqual(r2, opposite)
        XCTAssertEqual(r3, onTarget, "Cursor должен пойти по кругу после конца скрипта")
    }

    // MARK: - MockAcousticMirrorService: receivedTargetSounds

    func test_mockService_recordsReceivedTargetSounds() async throws {
        let mock = MockAcousticMirrorService()
        let url = URL(fileURLWithPath: "/tmp/x.wav")
        _ = try await mock.analyzeAttempt(url: url, targetSound: "С")
        _ = try await mock.analyzeAttempt(url: url, targetSound: "Ш")

        let received = await mock.receivedTargetSounds
        XCTAssertEqual(received, ["С", "Ш"])
    }

    // MARK: - MockAcousticMirrorService: пустой скрипт → дефолт

    func test_mockService_emptyScript_fallsBackToDefault() async throws {
        let mock = MockAcousticMirrorService(scripted: [])
        let eval = try await mock.analyzeAttempt(
            url: URL(fileURLWithPath: "/tmp/x.wav"), targetSound: "Ш"
        )
        XCTAssertEqual(eval, MockAcousticMirrorService.defaultEvaluation)
    }
}
