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
}

private func XCTAssertNoThrowAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        try await expression()
    } catch {
        XCTFail("Unexpected throw: \(error)", file: file, line: line)
    }
}
