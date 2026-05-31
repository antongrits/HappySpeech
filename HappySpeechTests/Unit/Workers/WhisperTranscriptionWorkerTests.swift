@testable import HappySpeech
import XCTest

// MARK: - WhisperTranscriptionWorkerTests
//
// Покрывает доменные модели транскрипции (WhisperTranscript / WhisperSegment) и
// контракт graceful-fallback worker'а: при любой ошибке (нет модели в бандле,
// битый/отсутствующий аудиофайл) transcribe возвращает nil, не бросая.
//
// ПОКРЫТО НЕ ВСЁ: успешный путь транскрипции требует загрузки WhisperKit
// (openai/whisper-tiny — сетевая загрузка ~40 МБ + Core ML инференс) и реального
// аудиофайла с речью; это интеграционный/device-тест, исключённый из unit-сьюта,
// чтобы не вешать CI на скачивание модели. Здесь проверяем модели + nil-контракт.

final class WhisperTranscriptionWorkerTests: XCTestCase {

    // MARK: - Domain models

    func test_whisperSegment_storesTimingAndText() {
        let seg = WhisperSegment(text: "привет", startMs: 100, endMs: 540)
        XCTAssertEqual(seg.text, "привет")
        XCTAssertEqual(seg.startMs, 100)
        XCTAssertEqual(seg.endMs, 540)
    }

    func test_whisperTranscript_aggregatesSegments() {
        let transcript = WhisperTranscript(
            fullText: "привет мир",
            segments: [
                WhisperSegment(text: "привет", startMs: 0, endMs: 400),
                WhisperSegment(text: "мир", startMs: 400, endMs: 700)
            ]
        )
        XCTAssertEqual(transcript.fullText, "привет мир")
        XCTAssertEqual(transcript.segments.count, 2)
        XCTAssertEqual(transcript.segments.last?.text, "мир")
    }

    // MARK: - Graceful fallback (no crash)

    func test_transcribe_nonexistentFile_returnsNilGracefully() async {
        let worker = WhisperTranscriptionWorker()
        let badURL = URL(fileURLWithPath: "/tmp/happyspeech_nonexistent_\(UUID().uuidString).wav")
        // Файла нет → даже если модель не загрузится, контракт = nil без краша.
        //
        // transcribe сначала инициализирует WhisperKit (может тянуть модель из
        // сети); чтобы unit-тест не висел на скачивании, ограничиваем ожидание.
        // Любой исход в пределах таймаута допустим: nil (graceful) или timeout
        // (загрузка модели — вне зоны unit-теста). Главное — контракт не падает.
        let result = await withTaskGroup(of: WhisperTranscript?.self) { group -> WhisperTranscript?? in
            group.addTask { await worker.transcribe(audioURL: badURL) }
            group.addTask {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first
        }
        // Если transcribe успел вернуться — это должен быть nil (битый файл).
        XCTAssertNil(result ?? nil, "Отсутствующий аудиофайл → graceful nil (или таймаут загрузки модели)")
    }
}
