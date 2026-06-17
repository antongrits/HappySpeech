import AVFoundation
import Foundation
import OSLog
import WhisperKit

// MARK: - WhisperTranscript

struct WhisperTranscript: Sendable {
    let fullText: String
    let segments: [WhisperSegment]
}

// MARK: - WhisperSegment

struct WhisperSegment: Sendable {
    let text: String
    let startMs: Int
    let endMs: Int
}

// MARK: - WhisperTranscriptionWorker

/// Транскрибирует записанный аудиофайл через WhisperKit (bundled whisper-base, offline).
/// При любой ошибке возвращает nil — вызывающий код обязан делать graceful fallback к stub.
/// Паттерн @unchecked Sendable + nonisolated(unsafe) по аналогии с ASRServiceLive:
/// WhisperKit не имеет формального Sendable, мутации только через @MainActor.
final class WhisperTranscriptionWorker: @unchecked Sendable {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "WhisperTranscription")
    nonisolated(unsafe) private var whisperKit: WhisperKit?

    /// Путь к bundled whisper-base (Resources/Models/Whisper/whisper-base/) — offline.
    private static var bundledBaseModelFolder: URL? {
        Bundle.main.url(
            forResource: "whisper-base",
            withExtension: nil,
            subdirectory: "Models/Whisper"
        )
    }

    // MARK: - Public API

    /// Загружает WhisperKit (bundled whisper-base, offline) при первом вызове и
    /// транскрибирует аудиофайл. Возвращает nil при отсутствии модели или ошибке.
    /// Сеть не задействуется — модель грузится из bundle по локальному пути.
    func transcribe(audioURL: URL) async -> WhisperTranscript? {
        do {
            if whisperKit == nil {
                guard let folder = Self.bundledBaseModelFolder,
                      FileManager.default.fileExists(atPath: folder.path) else {
                    logger.warning("WhisperTranscriptionWorker: bundled whisper-base не найден — fallback к stub")
                    return nil
                }
                let config = WhisperKitConfig(modelFolder: folder.path)
                let kit = try await WhisperKit(config)
                whisperKit = kit
                logger.info("WhisperTranscriptionWorker: bundled whisper-base загружена (offline)")
            }
            return try await runTranscription(audioURL: audioURL)
        } catch {
            logger.warning("WhisperTranscriptionWorker: ошибка — \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Private

    private func runTranscription(audioURL: URL) async throws -> WhisperTranscript? {
        guard let kit = whisperKit else { return nil }

        let options = DecodingOptions(
            task: .transcribe,
            language: "ru",
            temperatureFallbackCount: 2
        )
        let results = try await kit.transcribe(audioPath: audioURL.path, decodeOptions: options)

        guard !results.isEmpty else {
            logger.info("WhisperTranscriptionWorker: пустой результат транскрипции")
            return nil
        }

        let fullText = results
            .compactMap { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Собираем пословные тайм-штампы из WordTimingResult если доступны,
        // иначе берём сегментные тайм-штампы как приближение.
        let segments: [WhisperSegment] = results.flatMap { result in
            if let words = result.segments.first?.words, !words.isEmpty {
                return words.map { word in
                    WhisperSegment(
                        text: word.word,
                        startMs: Int(word.start * 1000),
                        endMs: Int(word.end * 1000)
                    )
                }
            }
            return result.segments.map { seg in
                WhisperSegment(
                    text: seg.text,
                    startMs: Int(seg.start * 1000),
                    endMs: Int(seg.end * 1000)
                )
            }
        }

        logger.info(
            "WhisperTranscriptionWorker: транскрипция завершена — \(fullText.prefix(60), privacy: .public)"
        )
        return WhisperTranscript(fullText: fullText, segments: segments)
    }
}
