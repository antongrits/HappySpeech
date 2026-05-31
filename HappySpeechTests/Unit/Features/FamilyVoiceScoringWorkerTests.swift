@preconcurrency import AVFoundation
@testable import HappySpeech
import XCTest

// MARK: - FamilyVoiceScoringWorkerTests
//
// Подключение EnsembleASRService (Tier B) в родительский путь оценки произношения.
// Проверяет, что при подключённом ансамбле он реально вызывается (а не одиночный
// scorer), и что в него передаётся РЕАЛЬНОЕ слово (lowercased) и группа звука.

final class FamilyVoiceScoringWorkerTests: XCTestCase {

    /// Записывает валидный WAV (>4KB) в Documents и возвращает относительный путь.
    private func makeRecording(durationSec: Double = 1.0) throws -> String {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "ScoringTest", code: 1)
        }
        let frameCount = AVAudioFrameCount(16_000 * durationSec)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "ScoringTest", code: 2)
        }
        buffer.frameLength = frameCount
        if let channel = buffer.floatChannelData?[0] {
            for index in 0..<Int(frameCount) {
                channel[index] = sin(2.0 * .pi * 330.0 * Float(index) / 16_000.0) * 0.3
            }
        }
        let relativePath = "scoring_test_\(UUID().uuidString).wav"
        let url = try FamilyVoiceRecorderWorker.resolveFilePath(relativePath)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return relativePath
    }

    private func cleanup(_ path: String) {
        if let url = try? FamilyVoiceRecorderWorker.resolveFilePath(path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Ensemble Tier B вызывается на родительском пути

    func test_ensembleTierB_isInvoked_withRealWordAndSound() async throws {
        let ensemble = MockEnsembleASRService(phonemeAccuracy: 0.91, confidence: 0.93)
        let worker = FamilyVoiceScoringWorker(
            pronunciationScorer: MockPronunciationScorerService(),
            ensembleASR: ensemble
        )
        let path = try makeRecording()
        defer { cleanup(path) }

        let score = await worker.score(childAudioPath: path, referenceWord: "Сова")

        XCTAssertEqual(ensemble.lastTier, .b, "Родительский контур → Tier B")
        XCTAssertEqual(ensemble.lastExpectedWord, "сова", "Реальное слово передаётся в lowercase (не пустая строка)")
        XCTAssertEqual(ensemble.lastTargetSound, "whistling", "Группа звука 'С' → whistling")
        XCTAssertEqual(score, 0.91, accuracy: 0.0001, "Используется phonemeAccuracy ансамбля")
    }

    func test_ensembleTierB_zeroPhonemeAccuracy_fallsBackToConfidence() async throws {
        let ensemble = MockEnsembleASRService(phonemeAccuracy: 0.0, confidence: 0.7)
        let worker = FamilyVoiceScoringWorker(
            pronunciationScorer: MockPronunciationScorerService(),
            ensembleASR: ensemble
        )
        let path = try makeRecording()
        defer { cleanup(path) }

        let score = await worker.score(childAudioPath: path, referenceWord: "рыба")
        XCTAssertEqual(score, 0.7, accuracy: 0.0001, "При нулевой phonemeAccuracy используется общая уверенность")
        XCTAssertEqual(ensemble.lastTargetSound, "sonants", "'р' → sonants")
    }

    // MARK: - Без ансамбля используется одиночный scorer (back-compat)

    func test_noEnsemble_usesSingleScorer() async throws {
        let worker = FamilyVoiceScoringWorker(
            pronunciationScorer: MockPronunciationScorerService(),
            ensembleASR: nil
        )
        let path = try makeRecording()
        defer { cleanup(path) }

        let score = await worker.score(childAudioPath: path, referenceWord: "шуба")
        // MockPronunciationScorerService.score → 0.82
        XCTAssertEqual(score, 0.82, accuracy: 0.0001, "Без ансамбля — одиночный scorer")
    }

    // MARK: - Полное отсутствие моделей → RMS фолбэк

    func test_noModels_usesRMSHeuristic() async throws {
        let worker = FamilyVoiceScoringWorker(pronunciationScorer: nil, ensembleASR: nil)
        let path = try makeRecording()
        defer { cleanup(path) }

        let score = await worker.score(childAudioPath: path, referenceWord: "кот")
        XCTAssertGreaterThanOrEqual(score, 0.5, "RMS-фолбэк держится в безопасном диапазоне")
        XCTAssertLessThanOrEqual(score, 0.95)
    }
}
