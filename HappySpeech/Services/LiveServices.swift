import AsyncAlgorithms
@preconcurrency import AVFoundation
import Collections
import Foundation
import os
import OSLog
import UIKit

// MARK: - LiveAudioService
// AVAudioEngine is used on main thread — @unchecked Sendable.

public final class LiveAudioService: AudioService, @unchecked Sendable {

    nonisolated(unsafe) private let engine = AVAudioEngine()
    nonisolated(unsafe) private var audioFile: AVAudioFile?
    nonisolated(unsafe) private var recordingURL: URL?
    nonisolated(unsafe) private let playerNode = AVAudioPlayerNode()

    /// Формат последнего соединения playerNode → mainMixer. Нужен, чтобы
    /// переподключать узел только при смене формата файла (P2-12) и не плодить
    /// висячие соединения. Доступ — только с MainActor (playAudio/stopPlayback).
    nonisolated(unsafe) private var connectedPlaybackFormat: AVAudioFormat?

    // P2-5/P2-12: общее состояние амплитуды пишется из realtime-потока tap'а и
    // читается с main. Защищаем `OSAllocatedUnfairLock` — короткий невытесняемый
    // лок, корректный для realtime-аудио (удержание на единицы операций).
    private struct AmplitudeState: Sendable {
        var current: Float = 0
        var history: [Float] = Array(repeating: 0, count: 60)
        var index: Int = 0
        var isRecording: Bool = false
    }
    private let amplitudeState = OSAllocatedUnfairLock(initialState: AmplitudeState())

    public var amplitude: Float {
        amplitudeState.withLock { $0.current }
    }

    public var isRecording: Bool {
        amplitudeState.withLock { $0.isRecording }
    }

    public var isPermissionGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    public func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    public func startRecording() async throws {
        guard isPermissionGranted else { throw AppError.audioPermissionDenied }

        // P1-1: гард от повторного старта без stop. Двойной installTap на bus 0
        // бросает NSException, поэтому отказываемся, если запись уже идёт.
        guard !amplitudeState.withLock({ $0.isRecording }) else {
            throw AppError.audioRecordingFailed("Recording already in progress")
        }

        // P1-1 (ядро «Повтори за моделью» на ЖЕЛЕЗЕ): перед записью переводим
        // AVAudioSession в `.playAndRecord`. До этого фикса запись стартовала без
        // настройки сессии, а `LessonVoiceWorker` перед каждым словом Ляли ставит
        // категорию `.playback` → на устройстве inputNode не отдаёт входной формат
        // (sampleRate 0 / тишина), installTap/engine.start падают или пишут пустоту.
        // Симулятор это скрывает, поэтому баг проявлялся только на устройстве.
        // `.measurement` mode + `.defaultToSpeaker` — корректный режим для записи
        // речи с одновременным воспроизведением эталона.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker]
            )
            try session.setActive(true, options: [])
        } catch {
            HSLogger.audio.error("Failed to configure AVAudioSession for recording: \(error.localizedDescription)")
            throw AppError.audioRecordingFailed("Audio session setup failed")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        recordingURL = url

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard let recordFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AppError.audioFormatUnsupported
        }

        audioFile = try AVAudioFile(forWriting: url, settings: recordFormat.settings)

        let converter = AVAudioConverter(from: format, to: recordFormat)
        let amplitudeState = self.amplitudeState

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let converter, let audioFile = self.audioFile else { return }

            let channelData = buffer.floatChannelData?[0]
            let frameCount = Int(buffer.frameLength)
            if let data = channelData {
                let amp = (0..<frameCount).map { abs(data[$0]) }.max() ?? 0
                // P2-5/P2-12: атомарно обновляем амплитуду и кольцевой буфер под
                // локом — устраняет гонку записи (tap) ↔ чтения (main).
                amplitudeState.withLock { state in
                    state.current = amp
                    state.history[state.index % 60] = amp
                    state.index += 1
                }
            }

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: recordFormat,
                frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * (16000.0 / format.sampleRate))
            ) else { return }

            // Копируем samples до Sendable-замыкания чтобы избежать захвата non-Sendable AVAudioPCMBuffer
            let sourceBuffer = buffer
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, status in
                status.pointee = .haveData
                return sourceBuffer
            }

            try? audioFile.write(from: convertedBuffer)
        }

        do {
            try engine.start()
        } catch {
            // Откат при провале старта движка: снимаем tap, не оставляем «висящую» запись.
            inputNode.removeTap(onBus: 0)
            self.audioFile = nil
            HSLogger.audio.error("AVAudioEngine start failed: \(error.localizedDescription)")
            throw AppError.audioRecordingFailed("Audio engine start failed")
        }
        amplitudeState.withLock { $0.isRecording = true }
        HSLogger.audio.info("Recording started at 16kHz mono")
    }

    public func stopRecording() async throws -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        amplitudeState.withLock { state in
            state.isRecording = false
            state.current = 0
        }
        // P1-1: деактивируем запись-сессию, отдавая аудиофокус. Воспроизведение
        // эталона (LessonVoiceWorker) затем само выставит `.playback`.
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            HSLogger.audio.warning("Failed to deactivate recording session: \(error.localizedDescription)")
        }
        guard let url = recordingURL else {
            throw AppError.audioRecordingFailed("Recording URL missing")
        }
        HSLogger.audio.info("Recording stopped: \(url.lastPathComponent)")
        return url
    }

    public func playAudio(url: URL) async throws {
        let file = try AVAudioFile(forReading: url)

        // На устройстве запись могла деактивировать сессию (P1-1). Гарантируем
        // воспроизводимую категорию `.playback` перед стартом движка.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            HSLogger.audio.warning("Failed to configure AVAudioSession for playback: \(error.localizedDescription)")
        }

        // Подключаем playerNode к движку только один раз. P2-12: переподключаем
        // соединение playerNode → mainMixer ТОЛЬКО при смене формата файла —
        // иначе повторные `connect` с разными форматами плодят висячие соединения.
        if playerNode.engine == nil {
            engine.attach(playerNode)
        }
        let newFormat = file.processingFormat
        if connectedPlaybackFormat != newFormat {
            // Снимаем прежнее соединение по формату перед новым (избегаем накопления).
            if connectedPlaybackFormat != nil {
                engine.disconnectNodeOutput(playerNode)
            }
            engine.connect(playerNode, to: engine.mainMixerNode, format: newFormat)
            connectedPlaybackFormat = newFormat
        }

        // ВАЖНО (P0): движок и узел должны быть запущены ДО ожидания завершения.
        // `scheduleFile` completion вызывается лишь по факту воспроизведения, поэтому
        // если ждать его перед `play()`, проигрывание никогда не начнётся и await
        // зависает навсегда. Порядок: start engine → schedule → play → await.
        if !engine.isRunning {
            try engine.start()
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            playerNode.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { _ in
                continuation.resume()
            }
            playerNode.play()
        }
    }

    public func stopPlayback() {
        playerNode.stop()
    }

    public func amplitudeBuffer() -> [Float] {
        // P2-12: снимаем кольцевой буфер и индекс ОДНИМ атомарным чтением под
        // локом, чтобы tap-поток не сдвинул index между двумя срезами.
        let (history, index) = amplitudeState.withLock { ($0.history, $0.index) }
        let pivot = index % 60
        var result = Array(history[pivot ..< 60])
        result += Array(history[0 ..< pivot])
        return result
    }
}

// LiveHapticService и FallbackHapticService перемещены в HapticService.swift (Block T v12).

// MARK: - LocalAnalyticsService

public final class LocalAnalyticsService: AnalyticsService, @unchecked Sendable {
    // P2-5: `track` может вызываться конкурентно из разных потоков — буфер событий
    // защищаем локом, иначе одновременные append/removeFirst дают data race (UB).
    private let events = OSAllocatedUnfairLock(initialState: [AnalyticsEvent]())
    private let maxEvents = 1000

    public func track(event: AnalyticsEvent) {
        events.withLock { buffer in
            if buffer.count >= maxEvents { buffer.removeFirst() }
            buffer.append(event)
        }
        HSLogger.analytics.debug("Event: \(event.name) \(event.parameters)")
    }
}

// MARK: - LiveARService

public final class LiveARService: ARService {
    public var isSupported: Bool { true }

    public var isCameraPermissionGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    public func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

// MARK: - LiveContentService

/// Loads content packs from the bundled `Content/Seed/*.json` resources.
public final class LiveContentService: ContentService, @unchecked Sendable {

    private let decoder: JSONDecoder

    public init() {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
    }

    public func loadPack(id: String) async throws -> ContentPack {
        // Pack id format: "sound-<letter>-<stage>-<template>-v1" or "sound_<letter>_v1" for bundled file name.
        // Strategy: map to bundled file and filter by stage+template inside ContentEngine.
        //
        // Resolution order:
        //   1. Explicit registry (multi-letter / differentiation packs whose id
        //      does not encode a single sound letter — e.g. "pack_diff_s_sh_v1").
        //   2. Legacy romanize path ("sound_<letter>_pack") for single-letter packs.
        let fileName = Self.fileName(for: id)
        guard let url = Self.resolveResourceURL(fileName: fileName, ext: "json") else {
            HSLogger.content.error("Pack resource missing: \(fileName).json")
            throw AppError.contentPackNotFound(id)
        }
        do {
            let data = try Data(contentsOf: url)
            let raw = try decoder.decode(RawContentPack.self, from: data)
            return raw.toContentPack(requestedID: id)
        } catch let error as AppError {
            throw error
        } catch {
            HSLogger.content.error("Pack decode failed for \(id): \(error)")
            throw AppError.contentPackNotFound(id)
        }
    }

    public func loadStagedPack(soundCode: String) async throws -> StagedContentPack {
        // Резолвим к каноническому файлу `sound_<latin>_pack.json`.
        let latin = SoundRomanizer.latinCode(for: soundCode)
        let fileName = "sound_\(latin)_pack"
        guard let url = Self.resolveResourceURL(fileName: fileName, ext: "json") else {
            HSLogger.content.error("Staged pack resource missing: \(fileName).json")
            throw AppError.contentPackNotFound(fileName)
        }
        do {
            let data = try Data(contentsOf: url)
            let raw = try decoder.decode(RawContentPack.self, from: data)
            return raw.toStagedPack()
        } catch let error as AppError {
            throw error
        } catch {
            HSLogger.content.error("Staged pack decode failed for \(fileName): \(error)")
            throw AppError.contentPackNotFound(fileName)
        }
    }

    public func allPacks() async throws -> [ContentPackMeta] {
        bundledPacks()
    }

    public func bundledPacks() -> [ContentPackMeta] {
        // Legacy single-letter packs (id encodes the sound letter directly).
        let legacy = ["s", "sh", "r", "l", "k"].compactMap { letter -> ContentPackMeta? in
            metaFromBundle(
                id: "sound_\(letter)_v1",
                soundTarget: letter.uppercased(),
                templateType: .listenAndChoose
            )
        }
        // New focus / differentiation packs registered via the explicit registry.
        let registered = Self.packRegistry.compactMap { descriptor -> ContentPackMeta? in
            metaFromBundle(
                id: descriptor.id,
                soundTarget: descriptor.soundTarget,
                templateType: descriptor.templateType
            )
        }
        return legacy + registered
    }

    /// Builds a `ContentPackMeta` for a pack id by resolving its bundled file.
    /// Returns `nil` if the JSON resource is not present in the bundle.
    private func metaFromBundle(
        id: String,
        soundTarget: String,
        templateType: TemplateType
    ) -> ContentPackMeta? {
        let fileName = Self.fileName(for: id)
        guard let url = Self.resolveResourceURL(fileName: fileName, ext: "json") else { return nil }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return ContentPackMeta(
            id: id,
            soundTarget: soundTarget,
            stage: CorrectionStage.wordInit.rawValue,
            templateType: templateType.rawValue,
            version: "1",
            isDownloaded: true,
            isBundled: true,
            storageUrl: url.absoluteString,
            sizeBytes: size
        )
    }

    // MARK: - Pack registry

    /// Descriptor for packs whose id does not encode a single sound letter
    /// (multi-letter focus packs and differentiation packs).
    struct PackDescriptor: Sendable {
        let id: String
        let fileName: String
        let soundTarget: String
        let templateType: TemplateType
    }

    /// Explicit registry: pack id → bundled file + metadata. Covers the 11
    /// content packs added in Sprint 12 (489 exercises). Single-letter legacy
    /// packs keep using the `sound_<letter>_pack` romanize path.
    static let packRegistry: [PackDescriptor] = [
        // Focus packs — concentrated drills per sound.
        PackDescriptor(id: "sound_cfocus_v1",  fileName: "sound_cfocus_pack",  soundTarget: "Ц",     templateType: .listenAndChoose),
        PackDescriptor(id: "sound_shchfocus_v1", fileName: "sound_shchfocus_pack", soundTarget: "Щ", templateType: .listenAndChoose),
        PackDescriptor(id: "sound_rsoft_v1",   fileName: "sound_rsoft_pack",   soundTarget: "Рь",    templateType: .listenAndChoose),
        PackDescriptor(id: "sound_lsoft_v1",   fileName: "sound_lsoft_pack",   soundTarget: "Ль",    templateType: .listenAndChoose),
        PackDescriptor(id: "sound_velars_v1",  fileName: "sound_velars_pack",  soundTarget: "К/Г/Х", templateType: .listenAndChoose),
        PackDescriptor(id: "sound_yfocus_v1",  fileName: "sound_yfocus_pack",  soundTarget: "Й",     templateType: .listenAndChoose),
        PackDescriptor(id: "sound_rclusters_v1", fileName: "sound_rclusters_pack", soundTarget: "Р", templateType: .listenAndChoose),
        // Differentiation packs — minimal pairs / paronyms / voicing.
        PackDescriptor(id: "pack_diff_s_sh_v1",     fileName: "pack_diff_s_sh_pack",     soundTarget: "С–Ш",                 templateType: .minimalPairs),
        PackDescriptor(id: "pack_diff_r_l_v1",      fileName: "pack_diff_r_l_pack",      soundTarget: "Р–Л",                 templateType: .minimalPairs),
        PackDescriptor(id: "pack_diff_paronyms_v1", fileName: "pack_diff_paronyms_pack", soundTarget: "З–Ж/Ш–Ж/С–З/Ч–Щ",     templateType: .minimalPairs),
        PackDescriptor(id: "pack_diff_voicing_v1",  fileName: "pack_diff_voicing_pack",  soundTarget: "Б-П/Д-Т/Г-К/В-Ф/З-С/Ж-Ш", templateType: .minimalPairs),
        // Звуковые паки Ц/Х/Й — реальный контент (~290 слов на пак). Доступны и через
        // `SoundRomanizer` (sound_c/kh/y), но регистрируем явно, чтобы они попадали в
        // `bundledPacks()` / `allPacks()` (каталог контента для родителя/специалиста).
        PackDescriptor(id: "sound_c_v1",  fileName: "sound_c_pack",  soundTarget: "Ц", templateType: .listenAndChoose),
        PackDescriptor(id: "sound_kh_v1", fileName: "sound_kh_pack", soundTarget: "Х", templateType: .listenAndChoose),
        PackDescriptor(id: "sound_y_v1",  fileName: "sound_y_pack",  soundTarget: "Й", templateType: .listenAndChoose),
        // Паки-сироты с реальным контентом, чьи id не кодируют один звук-букву и потому
        // не резолвились legacy-путём `sound_<letter>_pack`. Регистрируем явно.
        PackDescriptor(id: "sound_diffrl_v1",               fileName: "sound_diff_rl_pack",          soundTarget: "Р/Л",         templateType: .minimalPairs),
        PackDescriptor(id: "pack_diff_whistling_hissing_v1", fileName: "pack_diff_whistling_hissing", soundTarget: "С-Ш/З-Ж/Ц-Ч", templateType: .minimalPairs),
        PackDescriptor(id: "pack_general_phonemic_v1",      fileName: "pack_general_phonemic",       soundTarget: "Фонематика",  templateType: .soundHunter),
        PackDescriptor(id: "pack_narrative_v1",             fileName: "pack_narrative",              soundTarget: "Рассказ",     templateType: .narrativeQuest),
        PackDescriptor(id: "sound_br_v1",                   fileName: "pack_breathing",              soundTarget: "Дыхание",     templateType: .breathing),
        PackDescriptor(id: "sound_ag_v1", fileName: "pack_articulation_gymnastics", soundTarget: "Артикуляция", templateType: .articulationImitation),
        // Нейролингвистический продвинутый пак: фонематический анализ, рифмовые пары,
        // слогораздел, скороговорки. 661 pre-rendered m4a (`Audio/Content/NL/`) подключены
        // через `audio_file` → `ContentItem.audioAsset` → `LessonVoiceWorker.speakAsset`.
        // Реальный методический материал для родителя/специалиста (Spotlight + loadPack by id).
        PackDescriptor(id: "pack_neurolinguist_advanced_v1", fileName: "pack_neurolinguist_advanced", soundTarget: "Фонематика", templateType: .soundHunter)
        // NB: pack_lexical (575 слов словаря) НЕ регистрируется как playable-пак, пока
        // не закрыты ~152 картинко-пробела (Image отсутствующего ассета рендерит пусто).
        // +50 свежих слов уже отдают пользу глобально через word_manifest (резолв картинок
        // для любого пака). Регистрировать только после доукомплектации картинками.
    ]

    /// Quick lookup id → fileName for the registry.
    private static let registryFileNameByID: [String: String] = Dictionary(
        uniqueKeysWithValues: packRegistry.map { ($0.id, $0.fileName) }
    )

    // MARK: - Private

    /// Resolves a pack id to its bundled JSON file name (without extension).
    static func fileName(for id: String) -> String {
        // 1. Explicit registry wins (multi-letter / differentiation packs).
        if let registered = registryFileNameByID[id] { return registered }
        // 2. Legacy single-letter path.
        return "sound_\(extractSoundLetter(from: id))_pack"
    }

    private static func extractSoundLetter(from id: String) -> String {
        // Accepts "С-wordInit-listen-and-choose-v1" or "sound_s_v1".
        // Через `SoundRomanizer` нормализуем уже-латинский токен тоже (например,
        // legacy `sound_ts_v1` → `c`, `sound_h_v1` → `kh`), чтобы старые id
        // продолжали резолвиться в реальные файлы `sound_<code>_pack.json`.
        if id.hasPrefix("sound_") {
            let parts = id.split(separator: "_")
            guard parts.count >= 2 else { return "s" }
            return SoundRomanizer.latinCode(for: String(parts[1]))
        }
        guard let first = id.split(separator: "-").first else { return "s" }
        return SoundRomanizer.latinCode(for: String(first))
    }

    private static func resolveResourceURL(fileName: String, ext: String) -> URL? {
        // Try several likely subpaths — we ship seed packs inside the source tree, they may end up flat in the bundle.
        let bundle = Bundle.main
        if let url = bundle.url(forResource: fileName, withExtension: ext) { return url }
        if let url = bundle.url(forResource: fileName, withExtension: ext, subdirectory: "Content/Seed") { return url }
        if let url = bundle.url(forResource: fileName, withExtension: ext, subdirectory: "Seed") { return url }
        return nil
    }
}

// MARK: - RawContentPack (decoding helper for JSON seed files)

private struct RawContentPack: Decodable {
    let id: String
    let soundTarget: String
    let group: String
    let version: Int
    let stages: [String: RawStage]

    func toContentPack(requestedID: String) -> ContentPack {
        // P0-3: разворачиваем стадии в ДЕТЕРМИНИРОВАННОМ методическом порядке
        // (`CorrectionStage.allCases`: prep → isolated → … → diff), а не в порядке
        // итерации Swift Dictionary (он случаен per-launch). Раньше из-за этого
        // потребители брали `prefix(N)` из случайной смеси — в «слова» викторины
        // попадали артикуляционные инструкции и целые предложения.
        let allItems: [ContentItem] = CorrectionStage.allCases.flatMap { stageEnum -> [ContentItem] in
            guard let rawStage = stages[stageEnum.rawValue] else { return [] }
            return rawStage.items.map { raw in
                ContentItem(
                    id: raw.id,
                    word: raw.word,
                    imageAsset: raw.imageAsset,
                    audioAsset: raw.audioAsset,
                    hint: raw.hint,
                    stage: stageEnum,
                    difficulty: raw.difficulty
                )
            }
        }
        // Deterministic template/stage inference from requestedID if parsable, fallback otherwise.
        let (stage, template) = Self.parseStageTemplate(from: requestedID)
        return ContentPack(
            id: id,
            soundTarget: soundTarget,
            stage: stage,
            templateType: template,
            items: allItems.filter { $0.stage == stage || stage == .isolated }
        )
    }

    private static func parseStageTemplate(from id: String) -> (CorrectionStage, TemplateType) {
        let parts = id.split(separator: "-")
        guard parts.count >= 3 else { return (.isolated, .listenAndChoose) }
        let stage = CorrectionStage(rawValue: String(parts[1])) ?? .isolated
        let template = TemplateType(rawValue: String(parts[2])) ?? .listenAndChoose
        return (stage, template)
    }

    /// Разворачивает пак во ВСЕ этапы (для ``ContentVariationGenerator``).
    /// Порядок items внутри этапа — как в JSON (детерминированный).
    func toStagedPack() -> StagedContentPack {
        var byStage: [CorrectionStage: [ContentItem]] = [:]
        for stageEnum in CorrectionStage.allCases {
            guard let rawStage = stages[stageEnum.rawValue] else { continue }
            byStage[stageEnum] = rawStage.items.map { raw in
                ContentItem(
                    id: raw.id,
                    word: raw.word,
                    imageAsset: raw.imageAsset,
                    audioAsset: raw.audioAsset,
                    hint: raw.hint,
                    stage: stageEnum,
                    difficulty: raw.difficulty
                )
            }
        }
        return StagedContentPack(
            id: id,
            soundTarget: soundTarget,
            group: group,
            itemsByStage: byStage
        )
    }
}

private struct RawStage: Decodable {
    let stageId: String
    let note: String?
    let items: [RawItem]
}

private struct RawItem: Decodable {
    let id: String
    let word: String
    let imageAsset: String?
    let audioAsset: String?
    let hint: String?
    let difficulty: Int

    private enum CodingKeys: String, CodingKey {
        case id, word, imageAsset, audioAsset, hint, difficulty
        case audioFile = "audio_file"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        word = try c.decode(String.self, forKey: .word)
        imageAsset = try c.decodeIfPresent(String.self, forKey: .imageAsset)
        hint = try c.decodeIfPresent(String.self, forKey: .hint)
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 1
        // Seed packs ship pre-rendered narration under the `audio_file` key
        // (relative path под `Resources/Audio/`, напр. `Audio/Content/NL/nl-fs-00.m4a`).
        // Legacy `audioAsset` (имя ассета в каталоге) тоже поддерживаем; `audio_file`
        // приоритетнее, т.к. это реальный путь к bundled m4a.
        let explicitAsset = try c.decodeIfPresent(String.self, forKey: .audioAsset)
        let bundledFile = try c.decodeIfPresent(String.self, forKey: .audioFile)
        audioAsset = bundledFile ?? explicitAsset
    }
}

// MARK: - LiveAdaptivePlannerService

/// Data-driven adaptive planner.
///
/// Обязанности:
///   1. Прочитать профиль ребёнка и 5–10 последних сессий.
///   2. Для каждого `targetSound` собрать SM-2 state (`SoundProgressState`).
///   3. Выбрать звук с максимальным приоритетом повторения (самый просроченный).
///   4. Оценить уровень усталости (fatigue) из `consecutiveWrong` и времени суток.
///   5. Собрать маршрут через `composeRoute()` с учётом stage и fatigue.
///   6. Ограничить суммарную длительность максимумом по возрасту.
///
/// Если репозитории не переданы (тестовое поведение) — возвращает fallback маршрут.
public final class LiveAdaptivePlannerService: AdaptivePlannerService, @unchecked Sendable {

    private let childRepository: (any ChildRepository)?
    private let sessionRepository: (any SessionRepository)?
    /// F1-016: единый планировщик интервальных повторов слов-ошибок. Опционален —
    /// при отсутствии маршрут собирается без подмешивания due-повторов (back-compat).
    private let reviewScheduler: (any ReviewSchedulerService)?
    /// v17 «Фонемный паспорт»: источник слабейшей confusion-пары ребёнка для
    /// адресной вставки упражнения minimal-pairs. Опционален — при отсутствии /
    /// нехватке данных маршрут не меняется (graceful).
    private let phonemeProfileService: (any PhonemeProfileServiceProtocol)?

    public init(
        childRepository: (any ChildRepository)? = nil,
        sessionRepository: (any SessionRepository)? = nil,
        reviewScheduler: (any ReviewSchedulerService)? = nil,
        phonemeProfileService: (any PhonemeProfileServiceProtocol)? = nil
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.reviewScheduler = reviewScheduler
        self.phonemeProfileService = phonemeProfileService
    }

    // MARK: buildDailyRoute

    public func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
        // F1-021: профиль нарушения определяет акценты дневного маршрута.
        let disorder = SpeechDisorderStore.load(childId: childId)

        guard let childRepository, let sessionRepository else {
            return fallbackRoute(for: childId, disorder: disorder)
        }

        let profile = try await childRepository.fetch(id: childId)
        let recentSessions = (try? await sessionRepository.fetchRecent(childId: childId, limit: 10)) ?? []
        let targets = profile.targetSounds.isEmpty ? ["С"] : profile.targetSounds

        let states = targets.map { sound in
            SoundProgressAggregator.aggregate(soundTarget: sound, sessions: recentSessions)
        }
        let primary = Self.selectPrimaryState(from: states)
            ?? SoundProgressState(soundTarget: targets[0], stage: .isolated)

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let fatigue = Self.computeFatigue(state: primary, hour: hour)

        // F1-014: откат стадии на шаг назад при регрессе/долгом перерыве.
        let primarySessions = recentSessions.filter { $0.targetSound == primary.soundTarget }
        let decision = StageProgressionPlanner.recommendedStage(
            current: primary.stage,
            soundSessions: primarySessions,
            now: now
        )
        let workingStage = decision.stage

        // F1-021/F1-013: стратегия по нарушению накладывает доп-треки на звуковой маршрут.
        var steps = DisorderRouteStrategy.composeRoute(
            soundTarget: primary.soundTarget,
            stage: workingStage,
            fatigue: fatigue,
            disorder: disorder
        )
        // F1-014: если был откат — первый основной шаг помечаем как rollback («повторим прошлое»).
        if decision.didRollback {
            steps = Self.markFirstSoundStepRollback(steps)
        }

        // F1-016: due-повторы слов-ошибок подмешиваем В НАЧАЛО маршрута.
        let reviewSteps = await reviewSteps(for: childId, sound: primary.soundTarget, now: now)
        // F1-015: ретроспективный старт — 2–3 задания предыдущей стадии перед основной работой.
        let retroSteps = StageProgressionPlanner.retrospectiveSteps(
            currentStage: workingStage,
            soundTarget: primary.soundTarget,
            fatigue: fatigue
        )
        let intro = Self.dedupeIntro(reviewSteps + retroSteps)
        // v17: адресная дифференциация слабейшей confusion-пары из «Фонемного
        // паспорта» (если данные есть и пара имеет реальный minimal-pairs контент).
        let confusionStep = await weakestConfusionMinimalPairsStep(for: childId)
        let combined = (confusionStep.map { [$0] } ?? []) + intro + steps

        let stepsTotal = combined.reduce(0) { $0 + $1.durationTargetSec }
        let cap = DisorderRouteStrategy.sessionCap(for: profile.age, disorder: disorder)
        let maxDuration = min(stepsTotal, cap)

        logPlannedRoute(
            PlannedRouteLog(
                childId: childId,
                primary: primary,
                fatigue: fatigue,
                now: now,
                stepsCount: combined.count,
                stepsTotal: stepsTotal,
                cap: cap,
                disorder: disorder
            )
        )
        if decision.didRollback {
            HSLogger.planner.notice(
                """
                Stage rollback childId=\(childId, privacy: .private) \
                sound=\(primary.soundTarget, privacy: .public) \
                from=\(primary.stage.rawValue, privacy: .public) \
                to=\(workingStage.rawValue, privacy: .public) \
                trigger=\(decision.trigger.rawValue, privacy: .public)
                """
            )
        }

        return AdaptiveRoute(
            steps: combined,
            maxDurationSec: maxDuration,
            fatigueLevel: fatigue,
            disorder: disorder
        )
    }

    /// v17 «Фонемный паспорт»: строит шаг minimal-pairs на слабейшую confusion-пару
    /// ребёнка (target ↔ dominantCompetitor из topProblems). Возвращает nil, если:
    ///   • профиль-сервис не подключён;
    ///   • профиль пуст / нет проблемной фонемы с доминирующим конкурентом;
    ///   • пара не имеет реального контента minimal-pairs (см. `MinimalPairRound`).
    /// В этих случаях план не меняется (graceful).
    private func weakestConfusionMinimalPairsStep(for childId: String) async -> RouteStepItem? {
        guard let phonemeProfileService, !childId.isEmpty else { return nil }
        guard let profile = try? await phonemeProfileService.profile(childId: childId) else { return nil }

        // Слабейшая проблема с конкурентом-заменой (topProblems отсортированы по
        // возрастанию уровня — первый подходящий и есть слабейшая confusion-пара).
        for problem in profile.topProblems {
            guard let competitor = problem.dominantCompetitor else { continue }
            guard let contrast = Self.minimalPairsContrast(
                targetIPA: problem.phoneme,
                competitorIPA: competitor
            ) else { continue }

            return RouteStepItem(
                templateType: .minimalPairs,
                targetSound: contrast,
                stage: .diff,
                difficulty: 3,
                wordCount: 8,
                durationTargetSec: 150,
                track: .phonemic
            )
        }
        return nil
    }

    /// Сопоставляет confusion-пару (target IPA, competitor IPA) с реальным
    /// контрастом minimal-pairs из каталога `MinimalPairRound.extendedCatalog`.
    /// Проверяет обе ориентации ("Р-Л" и "Л-Р"). nil — если контента под пару нет.
    static func minimalPairsContrast(targetIPA: String, competitorIPA: String) -> String? {
        guard
            let targetLetter = IPADictionary.info(for: targetIPA)?.cyrillic.uppercased(),
            let competitorLetter = IPADictionary.info(for: competitorIPA)?.cyrillic.uppercased(),
            targetLetter != competitorLetter
        else { return nil }

        let supported = Set(MinimalPairRound.extendedCatalog.map(\.soundContrast))
        let direct = "\(targetLetter)-\(competitorLetter)"
        let reversed = "\(competitorLetter)-\(targetLetter)"
        if supported.contains(direct) { return direct }
        if supported.contains(reversed) { return reversed }
        return nil
    }

    /// F1-016: собирает шаги due-повторов через `ReviewSchedulerService` (если подключён).
    private func reviewSteps(for childId: String, sound: String, now: Date) async -> [RouteStepItem] {
        guard let reviewScheduler else { return [] }
        let due = await reviewScheduler.dueReviews(
            for: childId,
            sound: sound,
            now: now,
            limit: 3
        )
        return due.map { StageProgressionPlanner.reviewStep(for: $0) }
    }

    /// Помечает первый звуковой (`.sound`) шаг маршрута как rollback-шаг.
    static func markFirstSoundStepRollback(_ steps: [RouteStepItem]) -> [RouteStepItem] {
        guard let idx = steps.firstIndex(where: { $0.track == .sound }) else { return steps }
        var copy = steps
        let s = copy[idx]
        copy[idx] = RouteStepItem(
            templateType: s.templateType,
            targetSound: s.targetSound,
            stage: s.stage,
            difficulty: s.difficulty,
            wordCount: s.wordCount,
            durationTargetSec: s.durationTargetSec,
            track: s.track,
            isRetrospective: s.isRetrospective,
            isRollback: true
        )
        return copy
    }

    /// Ограничивает вступительную часть (повторы + ретроспектива) 3-мя шагами,
    /// чтобы сессия не раздувалась перед основной работой.
    static func dedupeIntro(_ intro: [RouteStepItem]) -> [RouteStepItem] {
        Array(intro.prefix(3))
    }

    private func fallbackRoute(for childId: String, disorder: SpeechDisorder) -> AdaptiveRoute {
        let fatigue: FatigueLevel = .fresh
        let steps = DisorderRouteStrategy.composeRoute(
            soundTarget: "С",
            stage: .wordInit,
            fatigue: fatigue,
            disorder: disorder
        )
        let total = steps.reduce(0) { $0 + $1.durationTargetSec }
        let cap = DisorderRouteStrategy.sessionCap(for: 6, disorder: disorder)
        HSLogger.planner.info(
            """
            AdaptiveRoute (fallback) childId=\(childId, privacy: .private) \
            disorder=\(disorder.rawValue, privacy: .public) steps=\(steps.count) total=\(total)s
            """
        )
        return AdaptiveRoute(
            steps: steps,
            maxDurationSec: min(total, cap),
            fatigueLevel: fatigue,
            disorder: disorder
        )
    }

    private struct PlannedRouteLog {
        let childId: String
        let primary: SoundProgressState
        let fatigue: FatigueLevel
        let now: Date
        let stepsCount: Int
        let stepsTotal: Int
        let cap: Int
        let disorder: SpeechDisorder
    }

    private func logPlannedRoute(_ log: PlannedRouteLog) {
        let ef = String(format: "%.2f", log.primary.easinessFactor)
        let overdue = log.primary.overdueDays(now: log.now)
        HSLogger.planner.info(
            """
            AdaptiveRoute childId=\(log.childId, privacy: .private) \
            disorder=\(log.disorder.rawValue, privacy: .public) \
            sound=\(log.primary.soundTarget, privacy: .public) \
            stage=\(log.primary.stage.rawValue, privacy: .public) \
            fatigue=\(log.fatigue.rawValue) EF=\(ef, privacy: .public) \
            overdue=\(overdue) steps=\(log.stepsCount) total=\(log.stepsTotal)s cap=\(log.cap)s
            """
        )
        if log.primary.needsSpecialistReview {
            HSLogger.planner.warning(
                "Low EF (\(ef, privacy: .public)) for sound=\(log.primary.soundTarget, privacy: .public) — recommend specialist review"
            )
        }
    }

    public func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {
        HSLogger.planner.info("Route completed session=\(sessionId, privacy: .private) steps=\(route.steps.count)")
    }

    // MARK: recordSessionResult

    public func recordSessionResult(
        childId: String,
        soundTarget: String,
        qualityScore: SM2Quality
    ) async throws {
        guard let childRepository, let sessionRepository else {
            HSLogger.planner.notice("recordSessionResult: repositories not wired, skipping persistence")
            return
        }

        let profile = try await childRepository.fetch(id: childId)
        let recent = (try? await sessionRepository.fetchRecent(childId: childId, limit: 20)) ?? []
        let state = SoundProgressAggregator.aggregate(soundTarget: soundTarget, sessions: recent)

        let result = SM2Engine.calculate(
            quality: qualityScore,
            currentEF: state.easinessFactor,
            repetitions: state.repetitions,
            lastInterval: max(1, state.lastIntervalDays)
        )

        // EF мапится в progressSummary как нормализованный показатель уверенности 0…1
        // (EF диапазон ~1.3…3.0 → сдвиг и масштаб).
        let normalized = Self.normalize(ef: result.easinessFactor)
        try await childRepository.updateProgress(
            childId: profile.id,
            sound: soundTarget,
            rate: normalized
        )

        HSLogger.planner.info(
            """
            SM-2 updated childId=\(childId, privacy: .private) \
            sound=\(soundTarget, privacy: .public) \
            q=\(qualityScore.rawValue) \
            EF=\(String(format: "%.2f", result.easinessFactor), privacy: .public) \
            interval=\(result.intervalDays)d \
            reps=\(result.repetitions) \
            needsSpecialist=\(result.needsSpecialistReview)
            """
        )
    }

    // MARK: recordItemOutcome (F1-016)

    public func recordItemOutcome(
        childId: String,
        itemId: String,
        sound: String,
        correct: Bool
    ) async {
        guard let reviewScheduler else { return }
        await reviewScheduler.recordOutcome(
            childId: childId,
            itemId: itemId,
            sound: sound,
            correct: correct
        )
    }

    // MARK: shouldTakeBreak

    public func shouldTakeBreak(
        consecutiveWrong: Int,
        sessionDurationSec: Int,
        childAge: Int
    ) -> Bool {
        if consecutiveWrong >= 3 { return true }
        let cap = Self.sessionMaxSec(for: childAge)
        if Double(sessionDurationSec) > Double(cap) * 0.9 { return true }
        return false
    }

    // MARK: - Helpers

    /// Допустимый максимум длительности сессии (секунды) по возрасту ребёнка.
    /// Основано на `ResearchDocs/fatigue-and-session-rules.md`:
    ///   • 5 лет → 5–8 минут (берём верхнюю границу — 480 с)
    ///   • 6–7 лет → 10–12 минут (720 с)
    ///   • 8+ → 15–20 минут (1200 с)
    static func sessionMaxSec(for age: Int) -> Int {
        switch age {
        case ..<6:  return 480   // 8 мин
        case 6...7: return 720   // 12 мин
        default:    return 1200  // 20 мин
        }
    }

    /// Нормализует EF (1.3…3.0) в диапазон 0…1 для `progressSummary`.
    static func normalize(ef: Double) -> Double {
        let minEF = SM2Engine.minimumEF       // 1.3
        let maxEF = 3.0
        let clamped = min(maxEF, max(minEF, ef))
        return (clamped - minEF) / (maxEF - minEF)
    }

    /// Выбирает звук с наивысшим приоритетом повтора.
    /// Приоритет = (overdueDays, -EF, -repetitions).
    static func selectPrimaryState(from states: [SoundProgressState]) -> SoundProgressState? {
        states.max { lhs, rhs in
            let lo = lhs.overdueDays()
            let ro = rhs.overdueDays()
            if lo != ro { return lo < ro }
            if lhs.easinessFactor != rhs.easinessFactor { return lhs.easinessFactor > rhs.easinessFactor }
            return lhs.repetitions > rhs.repetitions
        }
    }

    /// Оценивает уровень усталости по consecutiveWrong и времени суток.
    /// Правила:
    ///   • consecutiveWrong >= 3 → .tired
    ///   • consecutiveWrong >= 2 → .normal
    ///   • Вечер (21:00–06:00) и не-новый ребёнок → как минимум .normal
    static func computeFatigue(state: SoundProgressState, hour: Int) -> FatigueLevel {
        var level: FatigueLevel = .fresh
        if state.consecutiveWrong >= 3 { level = .tired } else if state.consecutiveWrong >= 2 { level = .normal }

        let isLateHour = hour >= 21 || hour < 6
        if isLateHour, level == .fresh, state.lastReviewDate != nil {
            level = .normal
        }
        return level
    }

    // MARK: - Rule-based matrix

    /// Core decision matrix: produces a 3–5 step sequence for a daily session.
    /// Principles:
    /// - Start gentle (warm-up or low-cognitive template).
    /// - Core drill uses the template most suited for the stage.
    /// - If fatigue is high, prefer puzzle-reveal / breathing near the end.
    /// - Always cap at ~10 minutes total.
    public static func composeRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        let difficulty: Int = {
            switch stage {
            case .prep, .isolated: return 1
            case .syllable, .wordInit: return 2
            case .wordMed, .wordFinal, .phrase: return 3
            case .sentence, .story, .diff: return 4
            }
        }()

        let warmUp = RouteStepItem(
            templateType: .breathing,
            targetSound: soundTarget,
            stage: .prep,
            difficulty: 1,
            wordCount: 1,
            durationTargetSec: 90
        )

        let coreTemplate: TemplateType = primaryTemplate(for: stage)
        let core = RouteStepItem(
            templateType: coreTemplate,
            targetSound: soundTarget,
            stage: stage,
            difficulty: difficulty,
            wordCount: stage >= .wordInit ? 8 : 6,
            durationTargetSec: fatigue == .tired ? 150 : 210
        )

        let consolidation = RouteStepItem(
            templateType: consolidationTemplate(for: stage, fatigue: fatigue),
            targetSound: soundTarget,
            stage: stage,
            difficulty: max(1, difficulty - 1),
            wordCount: 6,
            durationTargetSec: 120
        )

        let reward = RouteStepItem(
            templateType: .puzzleReveal,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 90
        )

        switch fatigue {
        case .fresh:
            return [warmUp, core, consolidation, reward]
        case .normal:
            return [warmUp, core, reward]
        case .tired:
            return [warmUp, reward]
        }
    }

    private static func primaryTemplate(for stage: CorrectionStage) -> TemplateType {
        switch stage {
        case .prep: return .articulationImitation
        case .isolated: return .repeatAfterModel
        case .syllable: return .repeatAfterModel
        case .wordInit, .wordMed, .wordFinal: return .listenAndChoose
        case .phrase: return .storyCompletion
        case .sentence: return .storyCompletion
        case .story: return .narrativeQuest
        case .diff: return .minimalPairs
        }
    }

    private static func consolidationTemplate(for stage: CorrectionStage, fatigue: FatigueLevel) -> TemplateType {
        if fatigue == .tired { return .puzzleReveal }
        switch stage {
        case .prep: return .breathing
        case .isolated: return .sorting
        case .syllable: return .bingo
        case .wordInit, .wordMed, .wordFinal: return .dragAndMatch
        case .phrase, .sentence: return .sorting
        case .story: return .storyCompletion
        case .diff: return .memory
        }
    }

    // MARK: - Story recommendation

    /// Возвращает случайную анимированную историю для заданного целевого звука.
    /// Используется AdaptivePlannerService для вставки сторис-активности в маршрут.
    func recommendedStory(for sound: String) -> AnimatedStory? {
        StoryLibrary.shared.stories(for: sound).randomElement()
    }
}

// MARK: - DisorderRouteStrategy (F1-021 / F1-013)

/// Стратегия сборки дневного маршрута под тип речевого нарушения.
///
/// База — звуковой маршрут (`LiveAdaptivePlannerService.composeRoute`), затем
/// в зависимости от `SpeechDisorder` добавляются параллельные методические
/// треки. Новые игровые механики (Звуковой детектив, Слоговая улитка, Чей хвост,
/// Конструктор предложения, Понимание-детектив) — это отдельные coordinator-routes,
/// поэтому в `RouteStepItem` они представлены ближайшими по дидактике `TemplateType`
/// (фонематика → minimalPairs/soundHunter/sorting; грамматика → dragAndMatch/
/// storyCompletion; связная речь → narrativeQuest/storyCompletion).
///
/// Методическое обоснование маршрутов — `wiki/concepts/speech-methodology.md`:
///   • дислалия    → звуковой трек (постановка/автоматизация);
///   • ФФН         → + фонематический трек (дифференциация, минимальные пары);
///   • ОНР III–IV  → 4 трека (произношение + фонематика + грамматика + связная речь);
///   • ЗРР         → «медленный старт»: короткие сессии, звукоподражание, называние;
///   • заикание    → дыхание/темп/плавность, без таймеров/скороговорок/соревнований;
///   • дизартрия   → удлинённая артикуляц. гимнастика + Visual-Acoustic + звук.
enum DisorderRouteStrategy {

    /// Собирает маршрут с учётом нарушения.
    static func composeRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel,
        disorder: SpeechDisorder
    ) -> [RouteStepItem] {
        switch disorder {
        case .dyslalia:
            return baseSoundRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        case .ffn:
            return ffnRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        case .onr:
            return onrRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        case .zrr:
            return zrrRoute(soundTarget: soundTarget, fatigue: fatigue)
        case .stuttering:
            return stutteringRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        case .dysarthria:
            return dysarthriaRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        }
    }

    /// Лимит длительности сессии с учётом нарушения. ЗРР занижает базовый
    /// возрастной cap до 5 минут («медленный старт»); остальные — по возрасту.
    static func sessionCap(for age: Int, disorder: SpeechDisorder) -> Int {
        let base = LiveAdaptivePlannerService.sessionMaxSec(for: age)
        if disorder.isSlowStart {
            return min(base, 300) // 5 минут
        }
        return base
    }

    // MARK: - Base sound track (reuse existing matrix, tag track = .sound)

    /// Базовый звуковой маршрут — переиспользует существующую матрицу планировщика
    /// и помечает шаги треком `.sound`.
    private static func baseSoundRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        LiveAdaptivePlannerService.composeRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
            .map { tag($0, with: .sound) }
    }

    // MARK: - ФФН: звук + фонематика

    private static func ffnRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        var steps = baseSoundRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        // Фонематический трек: дифференциация / минимальные пары (профилактика дисграфии).
        steps.append(phonemicStep(soundTarget: soundTarget, fatigue: fatigue))
        return cappedAntiFatigue(steps, fatigue: fatigue)
    }

    // MARK: - ОНР III–IV: 4 параллельных трека (F1-013)

    private static func onrRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        // 1. Произношение (warm-up + core из базовой матрицы — берём первые 2 шага)
        let base = baseSoundRoute(soundTarget: soundTarget, stage: stage, fatigue: fatigue)
        var steps: [RouteStepItem] = Array(base.prefix(2))
        // 2. Фонематика
        steps.append(phonemicStep(soundTarget: soundTarget, fatigue: fatigue))
        // 3. Грамматика
        steps.append(grammarStep(soundTarget: soundTarget, fatigue: fatigue))
        // 4. Связная речь
        steps.append(coherentSpeechStep(soundTarget: soundTarget, fatigue: fatigue))
        return cappedAntiFatigue(steps, fatigue: fatigue)
    }

    // MARK: - ЗРР: «медленный старт»

    private static func zrrRoute(
        soundTarget: String,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        // Короткая сессия: вызов речи и называние, без давления на чистоту звука.
        // Звукоподражание / имитация (repeatAfterModel), называние (listenAndChoose).
        let imitation = RouteStepItem(
            templateType: .repeatAfterModel,
            targetSound: soundTarget,
            stage: .isolated,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 90,
            track: .sound
        )
        let naming = RouteStepItem(
            templateType: .listenAndChoose,
            targetSound: soundTarget,
            stage: .wordInit,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 90,
            track: .coherentSpeech
        )
        let reward = RouteStepItem(
            templateType: .puzzleReveal,
            targetSound: soundTarget,
            stage: .isolated,
            difficulty: 1,
            wordCount: 3,
            durationTargetSec: 60,
            track: .sound
        )
        // Усталость → ещё короче: имитация + награда.
        return fatigue == .tired ? [imitation, reward] : [imitation, naming, reward]
    }

    // MARK: - Заикание: дыхание / темп / плавность

    private static func stutteringRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        // Без таймеров/скороговорок/соревнований (hasFluencyGoal). Акцент на
        // дыхание и ритм; звуковая работа — мягко, без timed-mode.
        let breathing = RouteStepItem(
            templateType: .breathing,
            targetSound: soundTarget,
            stage: .prep,
            difficulty: 1,
            wordCount: 1,
            durationTargetSec: 120,
            track: .breathingFluency
        )
        let rhythm = RouteStepItem(
            templateType: .rhythm,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 1,
            wordCount: 6,
            durationTargetSec: 150,
            track: .breathingFluency
        )
        let gentleSound = RouteStepItem(
            templateType: .repeatAfterModel,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 1,
            wordCount: 6,
            durationTargetSec: 120,
            track: .sound
        )
        return fatigue == .tired ? [breathing, rhythm] : [breathing, rhythm, gentleSound]
    }

    // MARK: - Дизартрия: усиленная артикуляция + Visual-Acoustic

    private static func dysarthriaRoute(
        soundTarget: String,
        stage: CorrectionStage,
        fatigue: FatigueLevel
    ) -> [RouteStepItem] {
        // Удлинённая артикуляционная гимнастика (3–4 мин) + Visual-Acoustic
        // биообратная связь, затем звуковой трек.
        let articulation = RouteStepItem(
            templateType: .articulationImitation,
            targetSound: soundTarget,
            stage: .prep,
            difficulty: 1,
            wordCount: 4,
            durationTargetSec: 210,
            track: .articulation
        )
        let visualAcoustic = RouteStepItem(
            templateType: .visualAcoustic,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: 150,
            track: .articulation
        )
        let core = RouteStepItem(
            templateType: LiveAdaptivePlannerService.composeRoute(
                soundTarget: soundTarget, stage: stage, fatigue: fatigue
            ).first(where: { $0.stage == stage })?.templateType ?? .repeatAfterModel,
            targetSound: soundTarget,
            stage: stage,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: fatigue == .tired ? 120 : 180,
            track: .sound
        )
        return fatigue == .tired ? [articulation, visualAcoustic] : [articulation, visualAcoustic, core]
    }

    // MARK: - Track step factories

    private static func phonemicStep(soundTarget: String, fatigue: FatigueLevel) -> RouteStepItem {
        // Дифференциация / минимальные пары (фонемный анализ).
        RouteStepItem(
            templateType: .minimalPairs,
            targetSound: soundTarget,
            stage: .diff,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: fatigue == .tired ? 120 : 150,
            track: .phonemic
        )
    }

    private static func grammarStep(soundTarget: String, fatigue: FatigueLevel) -> RouteStepItem {
        // Словоизменение/словообразование/синтаксис — Grammar Games на dragAndMatch.
        RouteStepItem(
            templateType: .dragAndMatch,
            targetSound: soundTarget,
            stage: .phrase,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: fatigue == .tired ? 120 : 150,
            track: .grammar
        )
    }

    private static func coherentSpeechStep(soundTarget: String, fatigue: FatigueLevel) -> RouteStepItem {
        // Связная речь — пересказ/рассказ по серии картинок.
        RouteStepItem(
            templateType: .narrativeQuest,
            targetSound: soundTarget,
            stage: .story,
            difficulty: 2,
            wordCount: 6,
            durationTargetSec: fatigue == .tired ? 120 : 150,
            track: .coherentSpeech
        )
    }

    // MARK: - Helpers

    private static func tag(_ step: RouteStepItem, with track: RouteTrack) -> RouteStepItem {
        RouteStepItem(
            templateType: step.templateType,
            targetSound: step.targetSound,
            stage: step.stage,
            difficulty: step.difficulty,
            wordCount: step.wordCount,
            durationTargetSec: step.durationTargetSec,
            track: track
        )
    }

    /// Антифатиговое правило: при `.tired` ограничивает число шагов 3-мя
    /// (тяжёлый день — не перегружать), сохраняя разнообразие треков.
    private static func cappedAntiFatigue(_ steps: [RouteStepItem], fatigue: FatigueLevel) -> [RouteStepItem] {
        guard fatigue == .tired, steps.count > 3 else { return steps }
        return Array(steps.prefix(3))
    }
}
