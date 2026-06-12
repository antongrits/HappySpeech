import AVFoundation
import Foundation
import OSLog

// MARK: - LessonVoiceWorker
//
// Общий helper для озвучки слов в уроках.
// Приоритет: семейная запись родителя → голос Ляли (m4a из Audio/Lyalya/lessons/) → silent fail.
//
// ADR-V31-AVSpeechSynthesizer-FALLBACK: Siri TTS полностью удалён.
// При отсутствии m4a-файла — silent skip + Logger.warning.
// Покрытие: 1200+ ключевых слов в Lyalya/lessons/; новые слова из v31 G-02 корпуса
// будут добавлены в будущей звуковой волне. До тех пор — silent fail приемлем,
// т.к. слово отображается на экране (текстовый label).
//
// Использование:
//   await LessonVoiceWorker.shared.speak("сани")
//   await LessonVoiceWorker.shared.speak("коса", lessonType: "bingo")
//   LessonVoiceWorker.shared.stop()
//
// Thread-safety: @MainActor — вызывать только из main thread.
//
// Async semantics: speak() реально ждёт завершения воспроизведения (m4a).
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

    /// Continuation для m4a-воспроизведения (resume по AVAudioPlayerDelegate).
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    /// text (нормализованный) → phrase_id
    private let phraseMapping: [String: String]

    /// Lazy-cached curriculum manifest: key "bucketId|slug" → relative path
    /// (под `Audio/Narration/`). Загружается один раз при первом обращении и
    /// замораживается. Источник — `Resources/Audio/Narration/curriculum_manifest.json`.
    private lazy var curriculumIndex: [String: String] = Self.loadCurriculumIndex()

    /// RealmActor для поиска семейных записей (Priority 1). Устанавливается из AppContainer.
    var realmActor: RealmActor?

    /// parentId для поиска семейных записей.
    var familyParentId: String = "local-parent"

    // MARK: - Init

    override init() {
        phraseMapping = Self.loadPhraseMapping()
        super.init()
        let count = phraseMapping.count
        logger.info("LessonVoiceWorker init: \(count, privacy: .public) phrases loaded")
    }

    // MARK: - Public API

    /// Воспроизводит текст голосом Ляли (m4a). Если файл не найден — silent skip.
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

        // No file found — silent skip (word is visible on screen as text label).
        logger.warning("\(logContext, privacy: .public)No Lyalya m4a for '\(text, privacy: .private)' — silent skip (record missing phrase)")
        #if DEBUG
        // В debug-сборках помогает находить непокрытые слова при тестировании.
        assertionFailure("LessonVoiceWorker: missing Lyalya audio for '\(text)'")
        #endif
    }

    /// Воспроизводит pre-rendered m4a контент-пака по относительному пути из
    /// `ContentItem.audioAsset` (например `Audio/Content/NL/nl-fs-00.m4a`).
    /// Эти файлы лежат в bundled folder-reference `Resources/Audio/` (Chirp3-HD-Aoede,
    /// голос Ляли). Если ассет не найден — graceful fallback на `speak(fallbackText:)`.
    ///
    /// - Parameters:
    ///   - assetPath: относительный путь под `Resources/` (с `Audio/...` или без
    ///     расширения; принимаем оба варианта).
    ///   - fallbackText: текст для озвучивания через `speak(_:)`, если ассет
    ///     отсутствует. `nil` → silent skip.
    ///   - rate: мультипликатор скорости.
    ///   - lessonType: опциональная метка для логов.
    func speakAsset(
        _ assetPath: String,
        fallbackText: String? = nil,
        rate: Float = 1.0,
        lessonType: String? = nil
    ) async {
        ensurePlaybackSession()
        let logContext = lessonType.map { "[\($0)] " } ?? ""

        if let url = Self.contentAssetURL(forRelativePath: assetPath) {
            await playFileURL(url, rate: rate, logContext: logContext + "[content] ")
            return
        }

        if let fallbackText, !fallbackText.isEmpty {
            await speak(fallbackText, lessonType: lessonType, rate: rate)
            return
        }

        logger.warning("\(logContext, privacy: .public)content asset miss: \(assetPath, privacy: .public) — silent skip")
    }

    /// Воспроизводит готовый curriculum-narration по `bucketId` + `slug`.
    /// Источник — `Resources/Audio/Narration/curriculum/.../{slug}.m4a`
    /// (Google Chirp3-HD-Aoede voice, голос Ляли).
    ///
    /// Если запись не найдена в curriculum-манифесте — graceful fallback:
    /// если задан `fallbackText`, воспроизводим его через стандартный
    /// `speak(_:)` (семейная запись / Lyalya phrase mapping). Иначе — silent
    /// skip + log warning.
    ///
    /// - Parameters:
    ///   - bucketId: идентификатор бакета (например
    ///     `"dyslalia_С_Изолированный звук_RAM"`).
    ///   - slug: slug записи внутри бакета (например `"skazhi_s_sa"`).
    ///   - fallbackText: текст для озвучивания через `speak(_:)` если
    ///     curriculum-запись отсутствует. `nil` → silent skip.
    ///   - lessonType: опциональная метка для логов.
    func speakCurriculum(
        bucketId: String,
        slug: String,
        fallbackText: String? = nil,
        lessonType: String? = nil
    ) async {
        ensurePlaybackSession()

        let logContext = lessonType.map { "[\($0)] " } ?? ""
        let key = Self.curriculumKey(bucketId: bucketId, slug: slug)

        if let relativePath = curriculumIndex[key],
           let url = Self.curriculumURL(forRelativePath: relativePath) {
            logger.debug("\(logContext, privacy: .public)curriculum: \(key, privacy: .public)")
            await playFileURL(url, rate: 1.0, logContext: logContext + "[curriculum] ")
            return
        }

        if let fallbackText, !fallbackText.isEmpty {
            await speak(fallbackText, lessonType: lessonType)
            return
        }

        logger.warning(
            "\(logContext, privacy: .public)curriculum miss: bucketId=\(bucketId, privacy: .public) slug=\(slug, privacy: .public) — silent skip"
        )
    }

    /// Останавливает воспроизведение m4a.
    /// Уже ожидающие `await speak(...)` получат resume немедленно.
    func stop() {
        player?.stop()
        player = nil
        let pc = playbackContinuation
        playbackContinuation = nil
        pc?.resume()
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
        let store = FamilyRecordingStoreWorker(realmActor: realm)
        let dtos = await store.fetchAll(parentId: familyParentId)
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
        // Audio/ подключён в project.yml как folder reference (type: folder),
        // поэтому структура подпапок сохраняется внутри .app bundle:
        // <bundle>/Audio/Lyalya/lessons/<phraseId>.m4a
        Bundle.main.url(
            forResource: phraseId,
            withExtension: "m4a",
            subdirectory: "Audio/Lyalya/lessons"
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

    // MARK: - Private: mapping load

    private static func curriculumKey(bucketId: String, slug: String) -> String {
        bucketId + "|" + slug
    }

    /// Резолвит относительный путь контент-ассета (`Audio/Content/NL/nl-fs-00.m4a`
    /// или `Content/NL/nl-fs-00`) в URL внутри bundled folder-reference `Audio/`.
    private static func contentAssetURL(forRelativePath relativePath: String) -> URL? {
        var path = relativePath
        // Нормализуем: убираем ведущий `Audio/` (folder reference уже подмонтирован
        // как подкаталог бандла `Audio/`) и расширение.
        if path.hasPrefix("Audio/") {
            path = String(path.dropFirst("Audio/".count))
        }
        let withoutExt = (path as NSString).deletingPathExtension
        let subdirectory = "Audio/" + (withoutExt as NSString).deletingLastPathComponent
        let name = (withoutExt as NSString).lastPathComponent
        guard !name.isEmpty else { return nil }
        return Bundle.main.url(
            forResource: name,
            withExtension: "m4a",
            subdirectory: subdirectory
        )
    }

    private static func curriculumURL(forRelativePath relativePath: String) -> URL? {
        // Audio/ — folder reference в project.yml, поэтому подпапки
        // (`Audio/Narration/curriculum/…`) сохраняются в .app bundle.
        let withoutExt = (relativePath as NSString).deletingPathExtension
        let subdirectory = "Audio/Narration/" + (withoutExt as NSString).deletingLastPathComponent
        let name = (withoutExt as NSString).lastPathComponent
        return Bundle.main.url(
            forResource: name,
            withExtension: "m4a",
            subdirectory: subdirectory
        )
    }

    private static func loadCurriculumIndex() -> [String: String] {
        // Manifest: Resources/Audio/Narration/curriculum_manifest.json
        // Структура: { version, voice, entries: [{ bucketId, slug, fileName, ... }] }
        guard let url = Bundle.main.url(
            forResource: "curriculum_manifest",
            withExtension: "json",
            subdirectory: "Audio/Narration"
        ),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = json["entries"] as? [[String: Any]]
        else {
            Logger(subsystem: "ru.happyspeech.app", category: "LessonVoiceWorker")
                .warning("curriculum_manifest.json missing or malformed — curriculum playback disabled")
            return [:]
        }

        var result: [String: String] = [:]
        for entry in entries {
            guard let bucketId = entry["bucketId"] as? String,
                  let slug = entry["slug"] as? String,
                  let fileName = entry["fileName"] as? String
            else { continue }
            result[curriculumKey(bucketId: bucketId, slug: slug)] = fileName
        }

        Logger(subsystem: "ru.happyspeech.app", category: "LessonVoiceWorker")
            .info("LessonVoiceWorker curriculum: \(result.count, privacy: .public) entries indexed")
        return result
    }

    private static func loadPhraseMapping() -> [String: String] {
        // 3.G v23: lyalya-phrase-mapping.json содержит гетерогенные значения —
        // legacy записи "key": "filename.m4a" (String) и v18c записи
        // "key": { "text": "...", "voice": "..." } (Object). Старый strict
        // JSONDecoder([String:String]) бросал DecodingError → silent return [:]
        // → fallback на TTS Siri вместо m4a Lyalya voice.
        guard let url = Bundle.main.url(forResource: "lyalya-phrase-mapping", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in json {
            if let stringValue = value as? String {
                result[key] = stringValue
            } else if let object = value as? [String: Any],
                      let text = object["text"] as? String {
                result[key] = text
            }
        }
        return result
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
