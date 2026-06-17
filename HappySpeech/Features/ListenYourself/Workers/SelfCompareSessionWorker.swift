import AVFoundation
import Foundation
import OSLog

// MARK: - SelfCompareSessionWorker
//
// Изолированный сервисный воркер «Послушай себя» (Clean Swift / VIP).
// Инкапсулирует РЕАЛЬНУЮ работу с микрофоном и аудио:
//   • запись дубля ребёнка через `AudioService` (16 kHz mono WAV);
//   • воспроизведение записанного дубля и эталона Ляли (TTS / Personal Voice);
//   • вычисление длительности записанного файла;
//   • опциональный ASR-«секретный совет» (подсказка, не оценка).
//
// Аудио дублей живёт временно в caches, не выгружается (COPPA). Interactor не
// касается AVFoundation напрямую — вся низкоуровневая логика здесь.

@MainActor
final class SelfCompareSessionWorker {

    // MARK: - Dependencies

    /// Запись/воспроизведение. Опционален: при nil (Preview / неполная среда)
    /// запись недоступна — Interactor отдаёт мягкую ошибку без фабрикации.
    private let audioService: (any AudioService)?
    /// Распознавание для «секретного совета». Опционален.
    private let asrService: (any ASRService)?
    /// On-device скоринг произношения для совета. Опционален.
    private let scorer: (any PronunciationScorerService)?
    /// TTS-озвучка эталона слова (Personal Voice → системный ru-RU). Опционален.
    private let voiceService: (any PersonalVoiceServicing)?

    /// Минимальная длительность записи дубля (детский UX, без таймера-стрессора).
    private let takeDurationSec: TimeInterval = 2.0

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ListenYourself.Worker"
    )

    // MARK: - Init

    init(
        audioService: (any AudioService)? = nil,
        asrService: (any ASRService)? = nil,
        scorer: (any PronunciationScorerService)? = nil,
        voiceService: (any PersonalVoiceServicing)? = nil
    ) {
        self.audioService = audioService
        self.asrService = asrService
        self.scorer = scorer
        self.voiceService = voiceService
    }

    /// Доступна ли реальная запись (микрофон-сервис внедрён).
    var isRecordingAvailable: Bool { audioService != nil }

    // MARK: - Live amplitude

    /// Текущая мгновенная амплитуда микрофона 0…1 для live-волны во время записи.
    /// 0 — сервис недоступен (статичная волна вместо «живой»).
    var liveAmplitude: Float { audioService?.amplitude ?? 0 }

    /// Снимок последних амплитуд (40 баров) для отрисовки волны.
    func amplitudeSnapshot() -> [Float] {
        audioService?.amplitudeBuffer() ?? []
    }

    // MARK: - Record a take

    /// Записывает один дубль ребёнка. Лениво запрашивает разрешение микрофона
    /// (в проде оно уже выдано на PermissionsView). Возвращает реальный файл +
    /// длительность. Бросает ``ListenYourselfError`` при недоступности/сбое —
    /// никаких сфабрикованных дублей.
    func recordTake() async throws -> RecordedTake {
        guard let audioService else {
            throw ListenYourselfError.recordingUnavailable
        }

        if !audioService.isPermissionGranted {
            let granted = await audioService.requestPermission()
            guard granted else {
                Self.logger.info("ListenYourself: микрофон не разрешён")
                throw ListenYourselfError.recordingUnavailable
            }
        }

        do {
            try await audioService.startRecording()
            try await Task.sleep(for: .seconds(takeDurationSec))
            try Task.checkCancellation()
            let url = try await audioService.stopRecording()
            let duration = Self.duration(of: url)
            Self.logger.info("ListenYourself: дубль записан dur=\(duration, format: .fixed(precision: 2))")
            return RecordedTake(url: url, durationSec: duration)
        } catch is CancellationError {
            // Уход с экрана во время записи — освобождаем микрофон, без ошибки UI.
            if audioService.isRecording { _ = try? await audioService.stopRecording() }
            throw CancellationError()
        } catch {
            Self.logger.error("ListenYourself: запись упала: \(error.localizedDescription, privacy: .public)")
            throw ListenYourselfError.recordingFailed
        }
    }

    // MARK: - Playback

    /// Воспроизводит записанный дубль ребёнка. Тихо завершается, если сервис
    /// недоступен или файл нечитаем.
    func playTake(url: URL) async {
        guard let audioService else { return }
        do {
            try await audioService.playAudio(url: url)
        } catch {
            Self.logger.debug("ListenYourself: playTake не удалось (\(error.localizedDescription, privacy: .public))")
        }
    }

    /// Озвучивает эталон слова голосом Ляли (Personal Voice → системный ru-RU).
    /// Тихо завершается, если TTS недоступен.
    func playReference(word: String) async {
        await voiceService?.speak(word)
    }

    /// Останавливает любое текущее воспроизведение (уход с экрана / новая запись).
    func stopPlayback() {
        audioService?.stopPlayback()
        voiceService?.stop()
    }

    // MARK: - Secret tip (опциональный ASR-совет)

    /// Готовит «секретный совет» по выбранному дублю: артикуляционная подсказка
    /// (а НЕ оценка). Использует тот же on-device скоринг и rule-based разбор по
    /// группам звуков, что и основной контур. Возвращает nil, если материала нет
    /// (нет ASR/скорера, звук вне поддержанных групп, запись нечитаема) — тогда
    /// плашку совета не показываем (первично — суждение ребёнка).
    func makeSecretTip(takeURL: URL, word: String, targetSound: String, age: Int) async -> String? {
        guard let asrService, let scorer else { return nil }

        let score: PronunciationScore
        do {
            score = try await scorer.score(audioURL: takeURL, targetSound: targetSound)
        } catch {
            Self.logger.debug("ListenYourself: скоринг для совета упал — без совета")
            return nil
        }
        guard score.isScored else { return nil }

        let transcript: String
        let confidence: Double
        do {
            let result = try await asrService.transcribe(url: takeURL, expectedWord: word)
            transcript = result.transcript
            confidence = result.confidence
        } catch {
            transcript = ""
            confidence = 0
        }

        // Тёплый rule-based разбор по группе звука: даёт реальную
        // артикуляционную подсказку (childHint), поданную как «секретик».
        let request = ChildErrorHintRequest(
            word: word,
            targetSound: targetSound,
            asrTranscript: transcript,
            asrConfidence: confidence,
            pronunciationScore: score.value,
            age: age,
            policyCategory: ""
        )
        let hint = ChildErrorHintResponse.ruleBased(for: request)
        // Совет = похвала (если уже хорошо) + конкретная подсказка ребёнку.
        let praise = score.value >= 0.65
            ? String(localized: "listenYourself.secret.praiseGood")
            : String(localized: "listenYourself.secret.praiseTry")
        return "\(praise) \(hint.childHint)"
    }

    // MARK: - Duration

    /// Длительность аудиофайла в секундах (0, если файл нечитаем).
    private static func duration(of url: URL) -> Double {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        let frames = Double(file.length)
        let rate = file.fileFormat.sampleRate
        guard rate > 0 else { return 0 }
        return frames / rate
    }
}

// MARK: - RecordedTake

/// Результат одной записи: реальный файл + измеренная длительность.
struct RecordedTake: Sendable, Equatable {
    let url: URL
    let durationSec: Double
}
