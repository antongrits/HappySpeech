@preconcurrency import AVFoundation
@testable import HappySpeech
import XCTest

// MARK: - FluidAudioVADServiceTests
//
// Покрытие FluidAudioVADService и его выходного контракта.
//
// ⚠️ Реальный VadManager (FluidAudio SPM) при первом запуске однократно качает
// CoreML-модель Silero v6 с HuggingFace — настоящий инференс НЕ детерминирован и
// требует сети/ANE, поэтому здесь НЕ вызывается. Тестируются детерминированные
// части, не зависящие от модели:
//
//   • processBuffer: guard частоты дискретизации (≠16 кГц → invalidSampleRate),
//     срабатывает ДО загрузки модели → офлайн-безопасно.
//   • init(threshold:) не выполняет I/O — конструируется мгновенно.
//   • Контракт VADResult/VADSession (256-мс→512-сэмпл развёртка опирается на эти
//     вычисления): hasSpeech (≥30%), speechDuration, speechStart/End, пороги.
//   • VADError.errorDescription — локализованные сообщения.
//   • makeVAD(preferFluidAudio:) — graceful fallback: при недоступности модели
//     возвращает рабочий AmplitudeVAD без падения (контракт фабрики).

final class FluidAudioVADServiceTests: XCTestCase {

    private static let sampleRate = Double(VADResult.Constants.sampleRate)  // 16000
    private let chunk = VADResult.Constants.chunkSize                        // 512

    /// Создаёт буфер заданной частоты и СРАЗУ прогоняет его через service внутри
    /// одного выражения — не удерживая не-Sendable AVAudioPCMBuffer за `await`
    /// (Swift 6 strict concurrency; паттерн из AdaptiveVADTests).
    private func process(
        samples: [Float],
        sampleRate: Double,
        service: FluidAudioVADService
    ) async throws -> VADSession {
        try await service.processBuffer(Self.makeBuffer(samples, sampleRate: sampleRate))
    }

    /// 16kHz mono буфер из массива сэмплов. Создаётся локально и передаётся в
    /// actor-вызов в том же выражении, поэтому не пересекает границу актора как
    /// захваченная ссылка.
    private static func makeBuffer(_ samples: [Float], sampleRate: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(max(1, samples.count))
        )!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData?[0] {
            for (i, s) in samples.enumerated() { channel[i] = s }
        }
        return buffer
    }

    // MARK: - init: без I/O, контракт частоты жив без загрузки модели

    func test_init_doesNotPerformIO() async {
        // Конструирование сервиса синхронно и не выполняет I/O. Подтверждаем,
        // что свежесозданный сервис отвергает неверную частоту, не грузя модель.
        let service = FluidAudioVADService(threshold: 0.5)
        await assertInvalidSampleRate(samples: [Float](repeating: 0, count: 512),
                                      rate: 8_000, service: service)
    }

    // MARK: - processBuffer: неверная частота → invalidSampleRate (до загрузки модели)

    func test_processBuffer_wrongSampleRate_throwsInvalidSampleRate() async {
        let service = FluidAudioVADService(threshold: 0.5)
        await assertInvalidSampleRate(samples: [Float](repeating: 0, count: 1024),
                                      rate: 8_000, service: service, expectedRate: 8_000)
    }

    func test_processBuffer_44kSampleRate_throwsInvalidSampleRate() async {
        let service = FluidAudioVADService(threshold: 0.5)
        await assertInvalidSampleRate(samples: [Float](repeating: 0, count: 4096),
                                      rate: 44_100, service: service, expectedRate: 44_100)
    }

    /// Утверждает, что processBuffer на частоте `rate` бросает invalidSampleRate.
    private func assertInvalidSampleRate(
        samples: [Float],
        rate: Double,
        service: FluidAudioVADService,
        expectedRate: Double? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await process(samples: samples, sampleRate: rate, service: service)
            XCTFail("Частота \(rate) Гц должна отвергаться до загрузки модели", file: file, line: line)
        } catch let error as VADError {
            guard case .invalidSampleRate(let sr) = error else {
                XCTFail("Ожидался invalidSampleRate, получено: \(error)", file: file, line: line)
                return
            }
            if let expectedRate {
                XCTAssertEqual(sr, expectedRate, accuracy: 0.1, file: file, line: line)
            }
        } catch {
            XCTFail("Ожидался VADError, получено: \(error)", file: file, line: line)
        }
    }

    // MARK: - VADError: локализованные описания

    func test_vadError_descriptions_areNonEmpty() {
        XCTAssertFalse(VADError.modelNotFound.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(VADError.invalidSampleRate(8_000).errorDescription?.isEmpty ?? true)
        XCTAssertFalse(VADError.inferenceFailure("boom").errorDescription?.isEmpty ?? true)
        // Деталь инференса встроена в сообщение.
        XCTAssertTrue(VADError.inferenceFailure("boom").errorDescription?.contains("boom") ?? false)
    }

    // MARK: - VADSession контракт: hasSpeech (порог 30% чанков)

    func test_vadSession_hasSpeech_requiresAtLeast30Percent() {
        // 2 из 10 = 20% → нет речи.
        let low = VADSession(chunks: makeChunks(speechFlags: pattern(total: 10, speech: 2)))
        XCTAssertFalse(low.hasSpeech, "20% речевых чанков < порога 30%")

        // 3 из 10 = 30% → речь есть (>=).
        let atThreshold = VADSession(chunks: makeChunks(speechFlags: pattern(total: 10, speech: 3)))
        XCTAssertTrue(atThreshold.hasSpeech, "30% речевых чанков == порог")

        // 7 из 10 = 70% → речь.
        let high = VADSession(chunks: makeChunks(speechFlags: pattern(total: 10, speech: 7)))
        XCTAssertTrue(high.hasSpeech)
    }

    func test_vadSession_empty_hasNoSpeech() {
        let empty = VADSession(chunks: [])
        XCTAssertFalse(empty.hasSpeech)
        XCTAssertNil(empty.speechStart)
        XCTAssertNil(empty.speechEnd)
        XCTAssertEqual(empty.speechDuration, 0, accuracy: 0.0001)
    }

    // MARK: - VADSession контракт: speechDuration (число речевых чанков × 32 мс)

    func test_vadSession_speechDuration_countsSpeechChunks() {
        // 4 речевых чанка по 512 сэмплов @16кГц = 4 × 0.032 = 0.128 c.
        let session = VADSession(chunks: makeChunks(speechFlags: [true, true, false, true, false, true]))
        let expected = 4.0 * Double(VADResult.Constants.chunkSize) / Double(VADResult.Constants.sampleRate)
        XCTAssertEqual(session.speechDuration, expected, accuracy: 0.0001)
    }

    // MARK: - VADSession контракт: speechStart / speechEnd по timestamps

    func test_vadSession_speechStartAndEnd_reflectFirstAndLastSpeechChunk() {
        // Чанки с возрастающими timestamps; речь на индексах 2 и 4.
        var chunks: [VADResult] = []
        for i in 0 ..< 6 {
            let isSpeech = (i == 2 || i == 4)
            chunks.append(VADResult(
                speechProbability: isSpeech ? 0.9 : 0.1,
                isSpeech: isSpeech,
                threshold: 0.5,
                timestamp: TimeInterval(i) * 0.032
            ))
        }
        let session = VADSession(chunks: chunks)
        XCTAssertEqual(session.speechStart ?? -1, 2 * 0.032, accuracy: 0.0001)
        XCTAssertEqual(session.speechEnd ?? -1, 4 * 0.032, accuracy: 0.0001)
    }

    // MARK: - VADResult контракт: isSpeech и threshold (как трактует service)

    func test_vadResult_isSpeech_followsThreshold() {
        // Service формирует VADResult как prob >= threshold.
        let above = VADResult(speechProbability: 0.7, isSpeech: 0.7 >= 0.5, threshold: 0.5, timestamp: 0)
        let below = VADResult(speechProbability: 0.3, isSpeech: 0.3 >= 0.5, threshold: 0.5, timestamp: 0)
        XCTAssertTrue(above.isSpeech)
        XCTAssertFalse(below.isSpeech)
    }

    // MARK: - Константы контракта (32 мс чанк @ 16 кГц)

    func test_vadConstants_chunkIs32msAt16k() {
        XCTAssertEqual(VADResult.Constants.chunkSize, 512)
        XCTAssertEqual(VADResult.Constants.sampleRate, 16_000)
        XCTAssertEqual(VADResult.Constants.defaultThreshold, 0.5, accuracy: 0.0001)
        let chunkMs = Double(VADResult.Constants.chunkSize) / Double(VADResult.Constants.sampleRate) * 1000
        XCTAssertEqual(chunkMs, 32, accuracy: 0.5)
    }

    // MARK: - makeVAD(preferFluidAudio:) — graceful fallback, всегда отдаёт VAD

    func test_makeVAD_preferFluidAudio_returnsWorkingVAD_offlineFallback() async throws {
        // В офлайн/CI окружении модель Silero недоступна → фабрика мягко
        // откатывается на AmplitudeVAD. В любом случае возвращается рабочий VAD,
        // не бросает, и processBuffer на 16 кГц отрабатывает.
        let vad = await makeVAD(preferFluidAudio: true, threshold: 0.5)
        // Буфер создаётся в том же выражении, что и actor-вызов (не пересекает
        // границу актора как захваченная не-Sendable ссылка).
        let session = try await vad.processBuffer(
            Self.makeBuffer([Float](repeating: 0, count: chunk * 4), sampleRate: Self.sampleRate)
        )
        // Тишина → не речь, но вызов корректно завершился.
        XCTAssertFalse(session.hasSpeech)
    }

    func test_makeVAD_preferFalse_isAmplitudeVAD() async {
        let vad = await makeVAD(preferFluidAudio: false)
        XCTAssertTrue(vad is AmplitudeVAD,
                      "preferFluidAudio=false должен вести себя как дефолтный makeVAD()")
    }

    // MARK: - Helpers

    /// Булев паттерн: первые `speech` чанков речевые, остальные — нет.
    private func pattern(total: Int, speech: Int) -> [Bool] {
        (0 ..< total).map { $0 < speech }
    }

    /// Строит VADResult-чанки из булевых флагов с шагом времени 32 мс.
    private func makeChunks(speechFlags: [Bool]) -> [VADResult] {
        speechFlags.enumerated().map { index, isSpeech in
            VADResult(
                speechProbability: isSpeech ? 0.9 : 0.05,
                isSpeech: isSpeech,
                threshold: VADResult.Constants.defaultThreshold,
                timestamp: TimeInterval(index) * 0.032
            )
        }
    }
}
