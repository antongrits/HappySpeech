import AVFoundation
import Foundation
import OSLog

// MARK: - LiveVoiceCloneService

/// Production-реализация ``VoiceCloneService``.
///
/// Предоставляет реально работающий синтез/воспроизведение речи с трёхуровневым fallback:
/// 1. ``VoiceSynthesisMode/familyVoice(audioFilePath:)`` — чтение записанного семейного `.m4a`.
/// 2. ``VoiceSynthesisMode/systemTTS(locale:)`` — `AVSpeechSynthesizer` + рендер в `.m4a`.
/// 3. ``VoiceSynthesisMode/bundledAudio(resourceName:)`` — pre-rendered `.m4a` из бандла.
/// 4. ``VoiceSynthesisMode/personalVoice(voiceIdentifier:)`` — Apple Personal Voice (только en-локали).
///
/// `actor` обеспечивает потокобезопасность вокруг `AVSpeechSynthesizer`, который не Sendable.
public actor LiveVoiceCloneService: VoiceCloneService {

    // MARK: - Dependencies

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "VoiceClone")

    /// Удерживаем синтезатор живым на время `write(...)` — иначе callback может не прийти.
    private var synthesizer: AVSpeechSynthesizer?

    /// Длина одного 1.5-секундного буфера в кадрах при 16 кГц (только для логов прогресса).
    private static let ttsSampleRate: Double = 16_000

    public init() {}

    // MARK: - isCloneSupported

    /// `true` — TTS и fallback-цепочка функциональны (это не заглушка).
    public nonisolated var isCloneSupported: Bool { true }

    // MARK: - Personal Voice status

    public nonisolated var personalVoiceAuthorizationStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        AVSpeechSynthesizer.personalVoiceAuthorizationStatus
    }

    public func requestPersonalVoiceAuthorization() async -> AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        let status = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
        logger.info("Personal Voice authorization status: \(String(describing: status), privacy: .public)")
        return status
    }

    // MARK: - availableModes

    public func availableModes(for locale: String) async -> [VoiceSynthesisMode] {
        var modes: [VoiceSynthesisMode] = []

        // Personal Voice — только en-локали и только если пользователь авторизовал.
        if locale.lowercased().hasPrefix("en"),
           personalVoiceAuthorizationStatus == .authorized,
           !Self.personalVoices().isEmpty {
            modes.append(.personalVoice(voiceIdentifier: nil))
        }

        // systemTTS — если на устройстве есть голос для запрошенной локали.
        if Self.bestVoice(for: locale) != nil {
            modes.append(.systemTTS(locale: locale))
        }

        return modes
    }

    // MARK: - synthesize

    public func synthesize(text: String, mode: VoiceSynthesisMode) async throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .familyVoice(let audioFilePath):
            return try Self.readFamilyVoice(at: audioFilePath, logger: logger)

        case .bundledAudio(let resourceName):
            return try Self.readBundledAudio(named: resourceName, logger: logger)

        case .systemTTS(let locale):
            guard !trimmed.isEmpty else { throw VoiceCloneError.emptyText }
            return try await synthesizeWithSystemTTS(text: trimmed, locale: locale, voice: nil)

        case .personalVoice(let voiceIdentifier):
            guard !trimmed.isEmpty else { throw VoiceCloneError.emptyText }
            guard personalVoiceAuthorizationStatus == .authorized else {
                logger.warning("personalVoice requested but not authorized — caller should fall back")
                throw VoiceCloneError.personalVoiceNotAuthorized
            }
            let voice = Self.personalVoice(matching: voiceIdentifier)
            guard let voice else {
                logger.warning("personalVoice: no matching personal voice found")
                throw VoiceCloneError.voiceUnavailable(locale: "personal")
            }
            return try await synthesizeWithSystemTTS(text: trimmed, locale: voice.language, voice: voice)
        }
    }

    // MARK: - loadReference / cloneVoice

    public func loadReference(speakerIndex: Int) async throws -> URL {
        guard speakerIndex >= 0, speakerIndex < VoiceCloneSpeaker.allCases.count else {
            logger.warning("loadReference: unsupported speakerIndex=\(speakerIndex)")
            throw VoiceCloneError.unsupportedSpeaker(speakerIndex)
        }
        guard let url = Bundle.main.url(
            forResource: "voice_clone_reference",
            withExtension: "wav",
            subdirectory: "Models"
        ) else {
            logger.error("loadReference: voice_clone_reference.wav not found in bundle")
            throw VoiceCloneError.referenceNotFound
        }
        logger.debug("loadReference: speakerIndex=\(speakerIndex) → \(url.lastPathComponent, privacy: .public)")
        return url
    }

    /// Подлинное zero-shot ML-клонирование голоса не реализуется on-device (вне объёма
    /// диплома, NC-лицензии моделей). Метод маршрутизирует синтез в системный TTS —
    /// это даёт работающий результат вместо безусловного отказа.
    public func cloneVoice(text: String, speakerIndex: Int) async throws -> Data {
        guard speakerIndex >= 0, speakerIndex < VoiceCloneSpeaker.allCases.count else {
            throw VoiceCloneError.unsupportedSpeaker(speakerIndex)
        }
        logger.info("cloneVoice → routing to systemTTS(ru-RU) (on-device ML cloning out of scope)")
        return try await synthesize(text: text, mode: .systemTTS(locale: "ru-RU"))
    }

    // MARK: - System TTS rendering

    /// Синтезирует речь через `AVSpeechSynthesizer.write(_:toBufferCallback:)`, собирает
    /// PCM-буферы и конвертирует их в `.m4a` (AAC) через `AVAudioFile`. Возвращает Data.
    private func synthesizeWithSystemTTS(
        text: String,
        locale: String,
        voice explicitVoice: AVSpeechSynthesisVoice?
    ) async throws -> Data {
        let voice = explicitVoice ?? Self.bestVoice(for: locale)
        guard let voice else {
            logger.warning("systemTTS: no voice for locale \(locale, privacy: .public)")
            throw VoiceCloneError.voiceUnavailable(locale: locale)
        }

        let outputURL = Self.makeTemporaryOutputURL()
        let synth = AVSpeechSynthesizer()
        self.synthesizer = synth

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice

        let collector = PCMCollector()

        // write(...) вызывает callback синхронно множество раз; финальный буфер имеет 0 кадров.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didFinish = false
            synth.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    // Финальный пустой буфер — синтез завершён.
                    if !didFinish {
                        didFinish = true
                        continuation.resume()
                    }
                    return
                }
                collector.append(pcm)
            }
        }

        self.synthesizer = nil

        guard let format = collector.format, collector.totalFrames > 0 else {
            logger.error("systemTTS: no PCM frames produced")
            throw VoiceCloneError.synthesisFailed
        }

        try Self.writeM4A(from: collector, sourceFormat: format, to: outputURL)

        let data = try Data(contentsOf: outputURL)
        try? FileManager.default.removeItem(at: outputURL)

        logger.info("systemTTS: \(collector.totalFrames, privacy: .public) frames → \(data.count, privacy: .public) bytes m4a")
        guard !data.isEmpty else { throw VoiceCloneError.audioConversionFailed }
        return data
    }

    // MARK: - Family / bundled readers

    private static func readFamilyVoice(at path: String, logger: Logger) throws -> Data {
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
        } else {
            url = try FamilyVoiceRecorderWorker.resolveFilePath(path)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.warning("familyVoice: file not found at \(url.lastPathComponent, privacy: .public)")
            throw VoiceCloneError.fileNotFound(path)
        }
        return try Data(contentsOf: url)
    }

    private static func readBundledAudio(named name: String, logger: Logger) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio") else {
            logger.warning("bundledAudio: \(name, privacy: .public).m4a not found in bundle")
            throw VoiceCloneError.fileNotFound("\(name).m4a")
        }
        return try Data(contentsOf: url)
    }

    // MARK: - M4A writing

    /// Записывает собранные PCM-буферы в `.m4a` (AAC) через `AVAudioFile`, при необходимости
    /// конвертируя в выходной 16 кГц mono формат с помощью `AVAudioConverter`.
    private static func writeM4A(
        from collector: PCMCollector,
        sourceFormat: AVAudioFormat,
        to url: URL
    ) throws {
        // Целевой формат файла: AAC (.m4a), 16 кГц, mono.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: ttsSampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let audioFile = try AVAudioFile(forWriting: url, settings: settings)
        let processingFormat = audioFile.processingFormat

        // Конвертер из формата синтезатора в формат файла (ресемплинг + downmix при необходимости).
        guard let converter = AVAudioConverter(from: sourceFormat, to: processingFormat) else {
            throw VoiceCloneError.audioConversionFailed
        }

        // Очередь буферов скрыта за reference-обёрткой `@unchecked Sendable`, чтобы
        // `@Sendable` input-block конвертера захватывал только её (Sendable), а не
        // отдельные non-Sendable `AVAudioPCMBuffer` и mutable-флаги.
        let feeder = BufferFeeder(buffers: collector.buffers)
        let ratio = processingFormat.sampleRate / sourceFormat.sampleRate

        while feeder.hasMore {
            let remaining = feeder.remainingFrames
            let capacity = AVAudioFrameCount(Double(remaining) * ratio) + 1024
            guard let outBuffer = AVAudioPCMBuffer(
                pcmFormat: processingFormat,
                frameCapacity: max(capacity, 1024)
            ) else {
                throw VoiceCloneError.audioConversionFailed
            }

            var conversionError: NSError?
            let status = converter.convert(to: outBuffer, error: &conversionError) { _, inputStatus in
                if let next = feeder.next() {
                    inputStatus.pointee = .haveData
                    return next
                }
                inputStatus.pointee = .noDataNow
                return nil
            }

            if let conversionError {
                throw conversionError
            }
            if status == .error {
                throw VoiceCloneError.audioConversionFailed
            }
            if outBuffer.frameLength > 0 {
                try audioFile.write(from: outBuffer)
            }
            // Защита от зацикливания: если данных больше нет и конвертер ничего не отдал.
            if status == .endOfStream || (!feeder.hasMore && outBuffer.frameLength == 0) {
                break
            }
        }
    }

    // MARK: - Voice helpers

    /// Возвращает наиболее подходящий голос для локали (предпочитая enhanced/premium качество).
    static func bestVoice(for locale: String) -> AVSpeechSynthesisVoice? {
        let normalizedPrefix = locale.lowercased().replacingOccurrences(of: "_", with: "-")
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            let lang = $0.language.lowercased().replacingOccurrences(of: "_", with: "-")
            return lang == normalizedPrefix
                || lang.hasPrefix(String(normalizedPrefix.prefix(2)) + "-")
        }
        // Предпочитаем более высокое качество (premium > enhanced > default).
        let ranked = candidates.sorted { lhs, rhs in
            qualityRank(lhs.quality) > qualityRank(rhs.quality)
        }
        return ranked.first ?? AVSpeechSynthesisVoice(language: locale)
    }

    private static func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium:  return 2
        case .enhanced: return 1
        default:        return 0
        }
    }

    /// Все голоса с трейтом Personal Voice.
    static func personalVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.voiceTraits.contains(.isPersonalVoice)
        }
    }

    /// Personal voice по идентификатору, либо первый доступный personal voice.
    static func personalVoice(matching identifier: String?) -> AVSpeechSynthesisVoice? {
        let voices = personalVoices()
        if let identifier {
            return voices.first { $0.identifier == identifier } ?? voices.first
        }
        return voices.first
    }

    private static func makeTemporaryOutputURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hs_tts_\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }
}

// MARK: - PCMCollector

/// Накопитель PCM-буферов, приходящих из `AVSpeechSynthesizer.write`.
///
/// Класс (reference) — чтобы аккумулировать состояние внутри escaping-замыкания callback.
/// Используется строго в пределах одного `synthesize`-вызова на акторе, поэтому
/// гонок не возникает; помечен `@unchecked Sendable` для прохождения проверки замыкания.
private final class PCMCollector: @unchecked Sendable {
    private(set) var buffers: [AVAudioPCMBuffer] = []
    private(set) var format: AVAudioFormat?
    private(set) var totalFrames: AVAudioFrameCount = 0

    func append(_ buffer: AVAudioPCMBuffer) {
        if format == nil { format = buffer.format }
        buffers.append(buffer)
        totalFrames += buffer.frameLength
    }
}

// MARK: - BufferFeeder

/// Поочерёдно отдаёт накопленные PCM-буферы в `AVAudioConverter` input-block.
///
/// Скрывает non-Sendable `AVAudioPCMBuffer` и мутабельный индекс за reference-обёрткой,
/// чтобы `@Sendable` input-block захватывал только Sendable-объект. Используется строго
/// синхронно внутри одного `writeM4A`-вызова, поэтому `@unchecked Sendable` безопасен.
private final class BufferFeeder: @unchecked Sendable {
    private let buffers: [AVAudioPCMBuffer]
    private var index = 0

    init(buffers: [AVAudioPCMBuffer]) {
        self.buffers = buffers
    }

    var hasMore: Bool { index < buffers.count }

    var remainingFrames: AVAudioFrameCount {
        buffers[index...].reduce(0) { $0 + $1.frameLength }
    }

    func next() -> AVAudioPCMBuffer? {
        guard index < buffers.count else { return nil }
        defer { index += 1 }
        return buffers[index]
    }
}
