@preconcurrency import AVFoundation
@testable import HappySpeech
import XCTest

// MARK: - FamilyScoringWorkerTests
//
// 5 unit-тестов для FamilyVoiceScoringWorker (F4).
// ScoringWorker тестируется через публичный метод score(childAudioPath:referenceWord:).
// ML-scorer подменяется SpyPronunciationScorer для изоляции от Core ML.
// RMS-fallback тестируется реальной PCM-записью с измеримой энергией.

final class FamilyScoringWorkerTests: XCTestCase {

    // MARK: - SpyPronunciationScorer: возвращает заданное значение

    private final class SpyPronunciationScorer: PronunciationScorerService, @unchecked Sendable {
        var isModelLoaded: Bool = true
        var stubbedScore: Double = 1.0
        var stubbedError: Error? = nil
        var callCount: Int = 0

        func score(audioURL: URL, targetSound: String) async throws -> PronunciationScore {
            callCount += 1
            if let err = stubbedError { throw err }
            return PronunciationScore(rawValue: stubbedScore)
        }

        func loadModel() async throws {}
    }

    // MARK: - Helpers

    /// Создаёт временный m4a-заглушку нужного размера (байты заполнены нулями).
    /// Используется только для путей, где аудио не декодируется (ML-scorer мок).
    private func makeTempAudioFile(sizeBytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_audio_\(UUID().uuidString).m4a")
        let data = Data(repeating: 0, count: sizeBytes)
        try data.write(to: url)
        return url
    }

    /// Создаёт реальный декодируемый WAV (синусоида 330 Гц, амплитуда 0.3),
    /// чтобы RMS-эвристика измерила настоящую энергию сигнала.
    private func makeRealWAV(durationSec: Double = 1.0) throws -> URL {
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
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_audio_\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    /// Конвертирует абсолютный URL в относительный путь (Documents/ prefix убирается).
    /// В тестах Documents не используется — передаём абсолютный путь напрямую.
    /// FamilyVoiceRecorderWorker.resolveFilePath() требует путь относительно Documents,
    /// поэтому для тестов используем абсолютный путь через хак: подменяем его напрямую
    /// используя публичный helper makeFileURL и relativeFilePath.
    private func relativePathInDocuments(for url: URL) throws -> String {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let destURL = docs.appendingPathComponent("family_recordings").appendingPathComponent(url.lastPathComponent)
        let folder = destURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        // Копируем temp файл в Documents/family_recordings/ для resolveFilePath
        if !FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.copyItem(at: url, to: destURL)
        }
        return try FamilyVoiceRecorderWorker.relativeFilePath(from: destURL)
    }

    // MARK: - 11. score_perfectMatch_returns100

    func test_score_perfectMatch_returns100() async throws {
        let mockScorer = SpyPronunciationScorer()
        mockScorer.stubbedScore = 1.0
        let sut = FamilyVoiceScoringWorker(pronunciationScorer: mockScorer)

        // Слово с шипящим звуком — маппится в группу "hissing" → ML scorer вызывается
        let tempFile = try makeTempAudioFile(sizeBytes: 8_000)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let relativePath = try relativePathInDocuments(for: tempFile)

        let result = await sut.score(childAudioPath: relativePath, referenceWord: "шар")

        XCTAssertEqual(result.value, 1.0, accuracy: 0.001,
                       "При stubbedScore=1.0 результат должен быть 1.0")
        XCTAssertFalse(result.isApproximate, "ML-оценка — реальная")
        XCTAssertEqual(mockScorer.callCount, 1,
                       "ML scorer должен вызваться ровно один раз для слова с шипящим")
    }

    // MARK: - 12. score_zeroMatch_returns0

    func test_score_zeroMatch_returns0() async throws {
        let mockScorer = SpyPronunciationScorer()
        mockScorer.stubbedScore = 0.0
        let sut = FamilyVoiceScoringWorker(pronunciationScorer: mockScorer)

        let tempFile = try makeTempAudioFile(sizeBytes: 8_000)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let relativePath = try relativePathInDocuments(for: tempFile)

        let result = await sut.score(childAudioPath: relativePath, referenceWord: "жук")

        XCTAssertEqual(result.value, 0.0, accuracy: 0.001,
                       "При stubbedScore=0.0 результат должен быть 0.0")
        XCTAssertFalse(result.isApproximate)
    }

    // MARK: - 13. score_partialMatch_returnsBetween

    func test_score_partialMatch_returnsBetween() async throws {
        let mockScorer = SpyPronunciationScorer()
        mockScorer.stubbedScore = 0.72
        let sut = FamilyVoiceScoringWorker(pronunciationScorer: mockScorer)

        let tempFile = try makeTempAudioFile(sizeBytes: 8_000)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let relativePath = try relativePathInDocuments(for: tempFile)

        let result = await sut.score(childAudioPath: relativePath, referenceWord: "рыба")

        XCTAssertGreaterThan(result.value, 0.0, "Частичное совпадение должно давать результат > 0")
        XCTAssertLessThan(result.value, 1.0, "Частичное совпадение должно давать результат < 1")
        XCTAssertEqual(result.value, 0.72, accuracy: 0.001,
                       "При stubbedScore=0.72 результат должен быть 0.72")
        XCTAssertFalse(result.isApproximate)
    }

    // MARK: - 14. score_emptyTranscript_handlesGracefully (ML fails → RMS fallback)

    func test_score_emptyTranscript_handlesGracefully() async throws {
        let mockScorer = SpyPronunciationScorer()
        mockScorer.stubbedError = NSError(domain: "test", code: -1, userInfo: nil)
        let sut = FamilyVoiceScoringWorker(pronunciationScorer: mockScorer)

        // ML падает → RMS heuristic измеряет реальную энергию записи.
        let tempFile = try makeRealWAV()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let relativePath = try relativePathInDocuments(for: tempFile)

        let result = await sut.score(childAudioPath: relativePath, referenceWord: "мяч")

        XCTAssertTrue(result.isApproximate,
                      "При ошибке ML — RMS heuristic, оценка помечается приблизительной")
        XCTAssertGreaterThan(result.value, 0,
                             "Реальный сигнал → ненулевая нормированная энергия")
        XCTAssertLessThanOrEqual(result.value, 1)
    }

    // MARK: - 15. score_noMLScorer_usesRMSFallback

    func test_score_noMLScorer_usesRMSFallback() async throws {
        // Без ML scorer (nil) всегда используется RMS heuristic
        let sut = FamilyVoiceScoringWorker(pronunciationScorer: nil)

        let tempFile = try makeRealWAV()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let relativePath = try relativePathInDocuments(for: tempFile)

        let result = await sut.score(childAudioPath: relativePath, referenceWord: "кот")

        XCTAssertTrue(result.isApproximate,
                      "Без ML scorer — RMS heuristic, оценка приблизительная")
        XCTAssertGreaterThan(result.value, 0,
                             "Реальный сигнал → ненулевая нормированная энергия (RMS)")
        XCTAssertLessThanOrEqual(result.value, 1)
    }
}
