import AVFoundation
import Foundation
import OSLog

// MARK: - LessonVoiceWorker
//
// Общий helper для озвучки слов в уроках.
// Приоритет: реальный голос Ляли (m4a из Audio/Lyalya/lessons/) → fallback Siri TTS (ru-RU).
//
// Использование:
//   await LessonVoiceWorker.shared.speak("сани")
//   await LessonVoiceWorker.shared.speak("коса", lessonType: "bingo")
//   LessonVoiceWorker.shared.stop()
//
// Thread-safety: @MainActor — вызывать только из main thread.
//
// Async semantics: speak() реально ждёт завершения воспроизведения (m4a или TTS).
// Чтобы прервать ожидание — вызови stop() и отмени Task на стороне вызывающего.

@MainActor
final class LessonVoiceWorker: NSObject {

    // MARK: - Shared instance
    //
    // Синглтон допустим здесь: worker не хранит пользовательское состояние,
    // только AVAudioPlayer + phraseMapping. DI через протокол не нужен,
    // т.к. это инфраструктурный helper (аналог Logger).

    static let shared = LessonVoiceWorker()

    // MARK: - Private state

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "LessonVoiceWorker")
    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()

    /// Continuation для m4a-воспроизведения (resume по AVAudioPlayerDelegate).
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    /// Continuation для TTS-воспроизведения (resume по AVSpeechSynthesizerDelegate).
    private var speechContinuation: CheckedContinuation<Void, Never>?

    /// text (нормализованный) → phrase_id
    private let phraseMapping: [String: String]

    /// RealmActor для поиска семейных записей (Priority 1). Устанавливается из AppContainer.
    var realmActor: RealmActor?

    /// parentId для поиска семейных записей.
    var familyParentId: String = "local-parent"

    // MARK: - TTS defaults

    private static let defaultTTSRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.9
    private static let defaultPitch: Float = 1.10
    private static let defaultVolume: Float = 1.0

    // MARK: - Init

    override init() {
        phraseMapping = Self.loadPhraseMapping()
        super.init()
        synthesizer.delegate = self
        let count = phraseMapping.count
        logger.info("LessonVoiceWorker init: \(count, privacy: .public) phrases loaded")
    }

    // MARK: - Public API

    /// Воспроизводит текст голосом Ляли (m4a). Если файл не найден — Siri TTS.
    /// Реально ждёт завершения воспроизведения перед возвратом.
    /// - Parameters:
    ///   - text: исходный текст (произвольный регистр, с пунктуацией)
    ///   - lessonType: опциональная метка для логов
    ///   - rate: мультипликатор скорости (1.0 = нормально, <1.0 = медленнее)
    func speak(
        _ text: String,
        lessonType: String? = nil,
        rate: Float = 1.0
    ) async {
        guard !text.isEmpty else { return }

        ensurePlaybackSession()

        let logContext = lessonType.map { "[\($0)] " } ?? ""

        // Priority 1: семейная запись родителя (если Realm доступен и запись найдена)
        if let familyURL = await familyRecordingURL(for: text) {
            await playFileURL(familyURL, rate: rate, logContext: logContext + "[family] ")
            return
        }

        // Priority 2: Lyalya m4a
        if let phraseId = phraseId(for: text),
           let url = Self.lyalyaURL(for: phraseId) {
            logger.debug("\(logContext, privacy: .public)Lyalya voice: '\(text, privacy: .private)' → \(phraseId, privacy: .public)")
            await playFileURL(url, rate: rate, logContext: logContext)
            return
        }

        // Priority 3 (TTS)
        logger.debug("\(logContext, privacy: .public)No Lyalya file for '\(text, privacy: .private)' — TTS fallback")
        await speakViaSynthesizer(text, rate: rate)
    }

    /// Останавливает воспроизведение (и m4a, и TTS).
    /// Уже ожидающие `await speak(...)` получат resume немедленно.
    func stop() {
        player?.stop()
        player = nil
        // Resume pending m4a continuation, если есть.
        let pc = playbackContinuation
        playbackContinuation = nil
        pc?.resume()

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        // Resume pending TTS continuation resume придёт через delegate (didCancel).
    }

    // MARK: - Private: audio session

    private func ensurePlaybackSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            logger.warning("Failed to set AVAudioSession to playback: \(error.localizedDescription)")
        }
    }

    // MARK: - Private: family recording lookup

    /// Ищет семейную запись для слова (точное совпадение после normalize).
    /// Возвращает URL если файл существует, иначе nil.
    private func familyRecordingURL(for text: String) async -> URL? {
        guard let realm = realmActor else { return nil }
        let normalized = Self.normalize(text)
        let dtos = await FamilyRecordingStore.fetchAll(parentId: familyParentId, realmActor: realm)
        guard let match = dtos.first(where: { Self.normalize($0.word) == normalized }) else {
            return nil
        }
        guard let url = try? FamilyVoiceRecorderWorker.resolveFilePath(match.audioFilePath),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    // MARK: - Private: shared file playback

    /// Воспроизводит файл по URL через AVAudioPlayer, ожидает завершения.
    private func playFileURL(_ url: URL, rate: Float, logContext: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            do {
                player?.stop()
                playbackContinuation?.resume()
                playbackContinuation = continuation
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                newPlayer.prepareToPlay()
                if rate != 1.0 {
                    newPlayer.enableRate = true
                    newPlayer.rate = max(0.5, min(2.0, rate))
                }
                player = newPlayer
                newPlayer.play()
                logger.debug("\(logContext, privacy: .public)playing: \(url.lastPathComponent, privacy: .public)")
            } catch {
                logger.warning("\(logContext, privacy: .public)AVAudioPlayer failed: \(error.localizedDescription)")
                playbackContinuation = nil
                continuation.resume()
            }
        }
    }

    // MARK: - Private: lookup

    private static func lyalyaURL(for phraseId: String) -> URL? {
        // Folder reference кладёт папку напрямую в корень .app bundle.
        Bundle.main.url(
            forResource: phraseId,
            withExtension: "m4a",
            subdirectory: "lessons"
        )
    }

    private func phraseId(for text: String) -> String? {
        let normalized = Self.normalize(text)

        // 1. Прямое совпадение.
        if let id = phraseMapping[normalized] { return id }

        // 2. Нормализация ё → е (входной текст без ё, JSON с ё).
        let withoutYo = normalized.replacingOccurrences(of: "ё", with: "е")
        if let id = phraseMapping[withoutYo] { return id }

        // 3. Нормализация е → ё (входной текст без ё, JSON с ё).
        let withYo = normalized.replacingOccurrences(of: "е", with: "ё")
        if let id = phraseMapping[withYo] { return id }

        return nil
    }

    private static func normalize(_ text: String) -> String {
        var result = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let punctuation = ["—", "–", "-", "?", "!", ".", ",", ";", ":", "\"", "'"]
        for ch in punctuation {
            result = result.replacingOccurrences(of: ch, with: "")
        }
        return result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Private: TTS fallback

    private func speakViaSynthesizer(_ text: String, rate: Float) async {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Завершаем предыдущий, если висит.
            speechContinuation?.resume()
            speechContinuation = continuation
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
            utterance.rate = max(
                AVSpeechUtteranceMinimumSpeechRate,
                min(AVSpeechUtteranceMaximumSpeechRate, Self.defaultTTSRate * rate)
            )
            utterance.pitchMultiplier = Self.defaultPitch
            utterance.volume = Self.defaultVolume
            synthesizer.speak(utterance)
            logger.debug("TTS fallback: '\(text, privacy: .private)'")
        }
    }

    // MARK: - Private: mapping load

    private static func loadPhraseMapping() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "lyalya-phrase-mapping", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return raw
    }
}

// MARK: - AVAudioPlayerDelegate

extension LessonVoiceWorker: AVAudioPlayerDelegate {

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let cont = self.playbackContinuation
            self.playbackContinuation = nil
            cont?.resume()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.logger.error("AVAudioPlayer decode error: \(error?.localizedDescription ?? "unknown")")
            let cont = self.playbackContinuation
            self.playbackContinuation = nil
            cont?.resume()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension LessonVoiceWorker: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let cont = self.speechContinuation
            self.speechContinuation = nil
            cont?.resume()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let cont = self.speechContinuation
            self.speechContinuation = nil
            cont?.resume()
        }
    }
}
