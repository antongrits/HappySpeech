import AVFoundation
import Foundation
import OSLog

// MARK: - TongueTwistersSpeechWorker
//
// Изолированный воркер записи и мягкой ASR-проверки для «Чистоговорок».
//   • playModel       — образец чистоговорки голосом Ляли (LessonVoiceWorker).
//   • recordPhrase    — запись проговаривания (AudioService, 16 kHz mono WAV);
//                       аудио живёт временно в caches, НЕ выгружается (COPPA).
//   • detectTargetSound — мягкая проверка наличия целевого звука в записи через
//                       ASRService: подсказка-поддержка, а НЕ штраф/оценка.
//
// Interactor не касается AVFoundation/ASR напрямую — вся низкоуровневая работа
// здесь. Kid circuit: ASR — только on-device (Tier A), HF/Tier B недоступен.

@MainActor
final class TongueTwistersSpeechWorker {

    // MARK: - Dependencies

    /// Запись микрофона. Опционален: при nil (Preview / неполная среда) запись
    /// недоступна — Interactor отдаёт мягкий результат без фабрикации.
    private let audioService: (any AudioService)?
    /// Распознавание для проверки целевого звука. Опционален.
    private let asrService: (any ASRService)?
    /// Озвучка образца чистоговорки голосом Ляли.
    private let voice: LessonVoiceWorker

    /// Длительность записи проговаривания (детский UX, без таймера-стрессора).
    private let recordDurationSec: TimeInterval = 3.0

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "TongueTwisters.Speech"
    )

    // MARK: - Init

    init(
        audioService: (any AudioService)? = nil,
        asrService: (any ASRService)? = nil,
        voice: LessonVoiceWorker = .shared
    ) {
        self.audioService = audioService
        self.asrService = asrService
        self.voice = voice
    }

    /// Доступна ли реальная запись (микрофон-сервис внедрён).
    var isRecordingAvailable: Bool { audioService != nil }

    /// Мгновенная амплитуда микрофона 0…1 для live-пульса кнопки записи.
    var liveAmplitude: Float { audioService?.amplitude ?? 0 }

    // MARK: - Playback (образец)

    /// Озвучивает образец чистоговорки голосом Ляли. Тихо завершается, если
    /// записи нет (строка видна на экране).
    func playModel(_ line: String) async {
        await voice.speak(line, lessonType: "tongue_twisters")
    }

    /// Останавливает любую озвучку (уход со стадии / новая запись).
    func stopPlayback() {
        voice.stop()
        audioService?.stopPlayback()
    }

    // MARK: - Record

    /// Записывает проговаривание чистоговорки. Лениво запрашивает разрешение
    /// микрофона (в проде уже выдано на PermissionsView). Возвращает реальный
    /// файл или бросает ``TongueTwistersError`` — без фабрикации.
    func recordPhrase() async throws -> URL {
        guard let audioService else {
            throw TongueTwistersError.recordingUnavailable
        }
        if !audioService.isPermissionGranted {
            let granted = await audioService.requestPermission()
            guard granted else {
                Self.logger.info("микрофон не разрешён")
                throw TongueTwistersError.recordingUnavailable
            }
        }
        do {
            try await audioService.startRecording()
            try await Task.sleep(for: .seconds(recordDurationSec))
            try Task.checkCancellation()
            let url = try await audioService.stopRecording()
            Self.logger.info("чистоговорка записана")
            return url
        } catch is CancellationError {
            if audioService.isRecording { _ = try? await audioService.stopRecording() }
            throw CancellationError()
        } catch {
            Self.logger.error("запись упала: \(error.localizedDescription, privacy: .public)")
            throw TongueTwistersError.recordingFailed
        }
    }

    // MARK: - Target-sound check (мягкая проверка, не штраф)

    /// Мягко проверяет наличие целевого звука в записи через ASR. Возвращает:
    ///   • soundHeard — целевой звук присутствует в транскрипте/ожидаемой фразе;
    ///   • inconclusive — ASR недоступен/тих → статус-чип скрываем (первично —
    ///     старание ребёнка, а не машинная оценка).
    /// Это поддержка, а не оценка: никаких порогов «провала».
    func detectTargetSound(in url: URL, targetSound: String, expectedLine: String) async -> (soundHeard: Bool, inconclusive: Bool) {
        guard let asrService else { return (false, true) }
        let transcript: String
        let confidence: Double
        do {
            let result = try await asrService.transcribe(url: url, expectedWord: expectedLine)
            transcript = result.transcript
            confidence = result.confidence
        } catch {
            Self.logger.debug("ASR упал — без статуса")
            return (false, true)
        }
        // Слишком тихо/невнятно → не выносим суждение (поддержка, не штраф).
        guard confidence >= 0.2, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (false, true)
        }
        let heard = Self.containsSound(transcript, sound: targetSound)
        return (heard, false)
    }

    /// Присутствует ли целевой звук в тексте (без регистра, с учётом мягкой пары
    /// и буквы-знака мягкости). «Р» матчит р/р'; «С» — с/сь и т. д.
    static func containsSound(_ text: String, sound: String) -> Bool {
        let lowered = text.lowercased()
        let base = sound.lowercased()
            .replacingOccurrences(of: "ь", with: "")
            .replacingOccurrences(of: "'", with: "")
        guard let first = base.first else { return false }
        return lowered.contains(first)
    }
}

// MARK: - TongueTwistersError

enum TongueTwistersError: LocalizedError, Equatable {
    case recordingUnavailable
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .recordingUnavailable:
            return String(localized: "tongueTwisters.error.micUnavailable",
                          defaultValue: "Микрофон сейчас недоступен. Можно играть и без записи.")
        case .recordingFailed:
            return String(localized: "tongueTwisters.error.recordFailed",
                          defaultValue: "Не получилось записать. Попробуй ещё разок!")
        }
    }
}
