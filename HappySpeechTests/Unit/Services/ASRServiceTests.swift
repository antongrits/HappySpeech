@testable import HappySpeech
import XCTest

// MARK: - ASRServiceTests
//
// Block V v18 — покрытие ASRService через MockASRService (6 тестов).
// Тестируется контрактное поведение протокола ASRService.

final class ASRServiceTests: XCTestCase {

    private func makeSUT() -> MockASRService {
        MockASRService()
    }

    // MARK: - isReady

    func test_isReady_defaultIsTrue() {
        let sut = makeSUT()
        XCTAssertTrue(sut.isReady)
    }

    func test_isReady_canBeOverriddenToFalse() {
        let sut = makeSUT()
        sut.isReady = false
        XCTAssertFalse(sut.isReady)
    }

    // MARK: - transcribe

    func test_transcribe_returnsDefaultTranscript() async throws {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.wav")
        let result = try await sut.transcribe(url: url)
        XCTAssertFalse(result.transcript.isEmpty)
    }

    func test_transcribe_confidenceInValidRange() async throws {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.wav")
        let result = try await sut.transcribe(url: url)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
    }

    func test_transcribe_wordTimestampsNotEmpty() async throws {
        let sut = makeSUT()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.wav")
        let result = try await sut.transcribe(url: url)
        XCTAssertFalse(result.wordTimestamps.isEmpty)
    }

    // MARK: - loadModel

    func test_loadModel_doesNotThrow() async {
        let sut = makeSUT()
        await XCTAssertNoThrowAsync { try await sut.loadModel() }
    }

    // MARK: - LiveASRService offline-first contract

    /// Без bundled-модели в тестовом окружении (нет `Resources/Models/Whisper/` в
    /// тест-bundle) `loadModel` обязан бросить `asrModelNotLoaded` — а НЕ пытаться
    /// скачивать whisper-tiny с HuggingFace. Любой сетевой/HF error означал бы
    /// нарушение offline-first.
    func test_liveASR_loadModel_failsWithModelNotLoaded_neverNetwork() async {
        let sut = LiveASRService()
        do {
            try await sut.loadModel(tier: .kidOnDevice)
            // Если модель вдруг доступна (на устройстве с bundle) — это валидно.
            XCTAssertTrue(sut.isReady)
        } catch let error as AppError {
            XCTAssertEqual(error, .asrModelNotLoaded)
            XCTAssertFalse(sut.isReady)
        } catch {
            XCTFail("Ожидался AppError.asrModelNotLoaded (offline), получено: \(error)")
        }
    }

    /// `transcribe` на незагруженном `LiveASRService` выполняет ленивую загрузку
    /// bundled-модели; при её отсутствии — `asrModelNotLoaded`, без сетевых попыток.
    func test_liveASR_transcribe_lazyLoads_throwsModelNotLoadedOffline() async {
        let sut = LiveASRService()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("silence.wav")
        do {
            _ = try await sut.transcribe(url: url)
            XCTAssertTrue(sut.isReady)
        } catch let error as AppError {
            XCTAssertEqual(error, .asrModelNotLoaded)
        } catch {
            XCTFail("Ожидался AppError.asrModelNotLoaded (offline lazy-load), получено: \(error)")
        }
    }
}

private func XCTAssertNoThrowAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
    } catch {
        XCTFail("Unexpected throw: \(error)", file: file, line: line)
    }
}
