@testable import HappySpeech
import XCTest

// MARK: - MockSpeechAnalyzerService Tests
//
// v31 Волна D Ф.4 — фактическая iOS 26 SpeechAnalyzer API требует
// реальной аудио-сессии (см. WWDC25 277), потому интеграционно
// проверяется только в QA на устройстве. Здесь — контрактные тесты
// поверх `MockSpeechAnalyzerService` (и проверка fallback-движка
// в LiveSpeechAnalyzerService).

final class SpeechAnalyzerServiceTests: XCTestCase {

    // MARK: - MockSpeechAnalyzerService

    func test_mock_currentEngineIsMock() async {
        let mock = MockSpeechAnalyzerService()
        XCTAssertEqual(mock.currentEngine, .mock)
        XCTAssertFalse(mock.isAppleAPIAvailable)
    }

    func test_mock_startReturnsStream() async throws {
        let mock = MockSpeechAnalyzerService()
        let stream = try await mock.startLiveTranscript()
        // консумируем 1 event в фоне
        let consumeTask = Task<SpeechAnalyzerEvent?, Never> {
            for await event in stream { return event }
            return nil
        }
        await mock.feedTranscripts([
            SpeechAnalyzerEvent(transcript: "привет", isFinal: false)
        ])
        let received = await consumeTask.value
        XCTAssertEqual(received?.transcript, "привет")
        await mock.stopLiveTranscript()
    }

    func test_mock_stopTerminatesStream() async throws {
        let mock = MockSpeechAnalyzerService()
        let stream = try await mock.startLiveTranscript()
        // Стрим должен завершиться через stopLiveTranscript().
        let collected = Task<[SpeechAnalyzerEvent], Never> {
            var acc: [SpeechAnalyzerEvent] = []
            for await event in stream { acc.append(event) }
            return acc
        }
        await mock.feedTranscripts([
            SpeechAnalyzerEvent(transcript: "a", isFinal: false),
            SpeechAnalyzerEvent(transcript: "ab", isFinal: false),
            SpeechAnalyzerEvent(transcript: "abc", isFinal: true)
        ])
        await mock.finishStream()
        let acc = await collected.value
        XCTAssertEqual(acc.count, 3)
        XCTAssertTrue(acc.last?.isFinal == true)
    }

    func test_mock_appendAudio_accumulatesFrameCount() async {
        let mock = MockSpeechAnalyzerService()
        await mock.appendAudio(samples: [0.0, 0.1, 0.2])
        await mock.appendAudio(samples: [0.0, 0.1])
        let frames = await mock.appendedFrames
        XCTAssertEqual(frames, 5)
    }

    func test_mock_startCount_incrementsOnEachStart() async throws {
        let mock = MockSpeechAnalyzerService()
        _ = try await mock.startLiveTranscript()
        await mock.stopLiveTranscript()
        _ = try await mock.startLiveTranscript()
        await mock.stopLiveTranscript()
        let count = await mock.startCount
        XCTAssertEqual(count, 2)
    }

    func test_event_finalFlag_preserved() {
        let event = SpeechAnalyzerEvent(transcript: "тест", isFinal: true, confidence: 0.95)
        XCTAssertTrue(event.isFinal)
        XCTAssertEqual(event.confidence, 0.95)
        XCTAssertEqual(event.transcript, "тест")
    }

    // MARK: - LiveSpeechAnalyzerService (engine routing)

    func test_live_currentEngine_isWhisperKitFallbackOnCurrentSDK() async {
        // На текущем Xcode SDK iOS 26 SpeechAnalyzer не интегрирован
        // как ABI-стабильный API → должен сообщать .whisperKitFallback.
        let mockASR = MockASRService()
        let live = LiveSpeechAnalyzerService(asrService: mockASR)
        XCTAssertEqual(live.currentEngine, .whisperKitFallback)
    }

    func test_live_isAppleAPIAvailable_matchesOS() async {
        let mockASR = MockASRService()
        let live = LiveSpeechAnalyzerService(asrService: mockASR)
        if #available(iOS 26, *) {
            XCTAssertTrue(live.isAppleAPIAvailable)
        } else {
            XCTAssertFalse(live.isAppleAPIAvailable)
        }
    }

    func test_live_doubleStart_throwsAlreadyRunning() async throws {
        let mockASR = MockASRService()
        let live = LiveSpeechAnalyzerService(asrService: mockASR)
        _ = try await live.startLiveTranscript()
        do {
            _ = try await live.startLiveTranscript()
            XCTFail("Ожидалась ошибка alreadyRunning")
        } catch SpeechAnalyzerError.alreadyRunning {
            // ok
        } catch {
            XCTFail("Ожидалась SpeechAnalyzerError.alreadyRunning, получено \(error)")
        }
        await live.stopLiveTranscript()
    }

    func test_live_stopAfterStart_doesNotThrow() async throws {
        let mockASR = MockASRService()
        let live = LiveSpeechAnalyzerService(asrService: mockASR)
        _ = try await live.startLiveTranscript()
        await live.stopLiveTranscript()
        // повторный stop безопасен.
        await live.stopLiveTranscript()
    }
}
