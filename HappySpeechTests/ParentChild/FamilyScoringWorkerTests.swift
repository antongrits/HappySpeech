@testable import HappySpeech
import XCTest

// MARK: - FamilyScoringWorkerTests
//
// 5 unit-тестов для FamilyVoiceScoringWorker (F4).
// ScoringWorker тестируется через публичный метод score(childAudioPath:referenceWord:).
// ML-scorer подменяется SpyPronunciationScorer для изоляции от Core ML.
// RMS-fallback тестируется через несуществующий / маленький / нормальный файл.

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
    private func makeTempAudioFile(sizeBytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_audio_\(UUID().uuidString).m4a")
        let data = Data(repeating: 0, count: sizeBytes)
        try data.write(to: url)
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

        XCTAssertEqual(result, 1.0, accuracy: 0.001,
                       "При stubbedScore=1.0 результат должен быть 1.0")
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

        XCTAssertEqual(result, 0.0, accuracy: 0.001,
                       "При stubbedScore=0.0 результат должен быть 0.0")
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

        XCTAssertGreaterThan(result, 0.0, "Частичное совпадение должно давать результат > 0")
        XCTAssertLessThan(result, 1.0, "Частичное совпадение должно давать результат < 1")
        XCTAssertEqual(result, 0.72, accuracy: 0.001,
                       "При stubbedScore=0.72 результат должен быть 0.72")
    }

    // MARK: - 14. score_emptyTranscript_handlesGracefully (ML fails → RMS fallback)

    func test_score_emptyTranscript_handlesGracefully() async throws {
        let mockScorer = SpyPronunciationScorer()
        mockScorer.stubbedError = NSError(domain: "test", code: -1, userInfo: nil)
        let sut = FamilyVoiceScoringWorker(pronunciationScorer: mockScorer)

        // Файл достаточного размера → RMS heuristic вернёт [0.5, 0.95]
        let tempFile = try makeTempAudioFile(sizeBytes: 10_000)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let relativePath = try relativePathInDocuments(for: tempFile)

        let result = await sut.score(childAudioPath: relativePath, referenceWord: "мяч")

        XCTAssertGreaterThanOrEqual(result, 0.5,
                                    "При ошибке ML RMS heuristic должен вернуть >= 0.5")
        XCTAssertLessThanOrEqual(result, 0.95,
                                 "RMS heuristic не должен превышать 0.95")
    }

    // MARK: - 15. score_noMLScorer_usesRMSFallback

    func test_score_noMLScorer_usesRMSFallback() async throws {
        // Без ML scorer (nil) всегда используется RMS heuristic
        let sut = FamilyVoiceScoringWorker(pronunciationScorer: nil)

        let tempFile = try makeTempAudioFile(sizeBytes: 5_000)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let relativePath = try relativePathInDocuments(for: tempFile)

        let result = await sut.score(childAudioPath: relativePath, referenceWord: "кот")

        XCTAssertGreaterThanOrEqual(result, 0.5,
                                    "Без ML scorer результат должен быть >= 0.5 (RMS heuristic)")
        XCTAssertLessThanOrEqual(result, 0.95,
                                 "Без ML scorer результат не должен превышать 0.95")
    }
}
