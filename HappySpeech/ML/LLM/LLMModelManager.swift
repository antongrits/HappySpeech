import Foundation
import OSLog

// MARK: - LLMModelPack

/// Пакеты локальной LLM. Пользователь может скачать несколько.
/// `qwen15b` — детский tier A (on-device, COPPA-safe).
/// `qwen3b` — opt-in tier B для аналитики родителей / специалистов.
public enum LLMModelPack: String, CaseIterable, Sendable, Codable {
    case qwen15b = "qwen2.5-1.5b"
    case qwen3b  = "qwen2.5-3b"

    public var displayName: String {
        switch self {
        case .qwen15b: return String(localized: "modelManager.llm.pack.qwen15b.name")
        case .qwen3b:  return String(localized: "modelManager.llm.pack.qwen3b.name")
        }
    }

    public var sizeBytes: Int64 {
        switch self {
        case .qwen15b: return 900 * 1024 * 1024
        case .qwen3b:  return Int64(1.8 * 1024 * 1024 * 1024)
        }
    }

    public var isDefault: Bool { self == .qwen15b }

    public var tierDescription: String {
        switch self {
        case .qwen15b: return String(localized: "modelManager.llm.pack.qwen15b.tier")
        case .qwen3b:  return String(localized: "modelManager.llm.pack.qwen3b.tier")
        }
    }

    /// Имя файла модели на диске (gguf q4 — лёгкий, работает на iPhone).
    fileprivate var fileName: String {
        switch self {
        case .qwen15b: return "qwen2.5-1.5b-instruct-q4_k_m.gguf"
        case .qwen3b:  return "qwen2.5-3b-instruct-q4_k_m.gguf"
        }
    }

    /// URL для скачивания (CDN). Для 3B пака заглушка — реальный URL появится при релизе.
    fileprivate var remoteURL: URL? {
        switch self {
        case .qwen15b:
            return URL(string: "https://storage.googleapis.com/happyspeech-models/qwen2.5-1.5b-instruct-q4_k_m.gguf")
        case .qwen3b:
            return URL(string: "https://storage.googleapis.com/happyspeech-models/qwen2.5-3b-instruct-q4_k_m.gguf")
        }
    }
}

// MARK: - LLMModelManagerProtocol

public protocol LLMModelManagerProtocol: AnyObject, Sendable {
    var downloadProgress: AsyncStream<ModelDownloadState> { get async }

    func isModelInstalled(_ pack: LLMModelPack) async -> Bool
    func installedModels() async -> [LLMModelPack]

    /// Скачать пак, если не установлен. Wi-Fi-only жёстко.
    func downloadIfNeeded(_ pack: LLMModelPack) async throws

    /// Удалить пак с диска (нельзя, если активно используется).
    func deleteModel(_ pack: LLMModelPack) async throws

    /// Проверить, используется ли пак (например, загружен в `LocalLLMService`).
    func isCurrentlyInUse(_ pack: LLMModelPack) async -> Bool
}

// MARK: - LLMModelManager (actor)

/// Рефактор предыдущего `LLMModelDownloadManager` в мульти-пак actor.
///
/// Ключевые свойства:
///   * Wi-Fi-only (LLM > 900 МБ — сотовая сеть недопустима).
///   * `AsyncStream` для UI прогресса.
///   * Проверка свободного места перед загрузкой.
///   * `deleteModel` защищает активно используемый пак.
public actor LLMModelManager: LLMModelManagerProtocol {

    // MARK: - Dependencies

    private let networkMonitor: any NetworkMonitorService
    /// Ссылка на основной LLM-сервис — чтобы вызвать `downloadModel()` и знать, какой пак сейчас загружен.
    private let primaryLLM: any LocalLLMService

    // MARK: - State

    private var activeDownloadPack: LLMModelPack?
    private var activePack: LLMModelPack = .qwen15b

    // MARK: - Progress stream

    private var progressContinuation: AsyncStream<ModelDownloadState>.Continuation?
    private lazy var progressStream: AsyncStream<ModelDownloadState> = {
        AsyncStream { continuation in
            self.progressContinuation = continuation
        }
    }()

    // MARK: - Init

    public init(primaryLLM: any LocalLLMService, networkMonitor: any NetworkMonitorService) {
        self.primaryLLM = primaryLLM
        self.networkMonitor = networkMonitor
    }

    // MARK: - Paths

    private var rootDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("HappySpeech/Models", isDirectory: true)
    }

    private func fileURL(for pack: LLMModelPack) -> URL {
        rootDirectory.appendingPathComponent(pack.fileName)
    }

    // MARK: - Protocol: stream

    public var downloadProgress: AsyncStream<ModelDownloadState> {
        get async { progressStream }
    }

    // MARK: - Protocol: installed state

    public func isModelInstalled(_ pack: LLMModelPack) async -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: pack).path)
    }

    public func installedModels() async -> [LLMModelPack] {
        var result: [LLMModelPack] = []
        for pack in LLMModelPack.allCases where await isModelInstalled(pack) {
            result.append(pack)
        }
        return result
    }

    public func isCurrentlyInUse(_ pack: LLMModelPack) async -> Bool {
        activePack == pack && primaryLLM.isModelLoaded
    }

    /// Пометить пак как активно используемый (вызывается при загрузке модели в runtime).
    public func markActive(_ pack: LLMModelPack) {
        activePack = pack
    }

    // MARK: - Protocol: download

    public func downloadIfNeeded(_ pack: LLMModelPack) async throws {
        // Если для `qwen15b` уже скачано (через primaryLLM на этапе инициализации) — no-op.
        if await isModelInstalled(pack) {
            HSLogger.llm.info("LLM pack \(pack.rawValue) already installed")
            emit(.completed(pack: convertToWhisperStatePlaceholder(pack: pack, progress: 1.0)))
            return
        }

        // Сеть: только Wi-Fi (жёстко для LLM, минимум 900 МБ).
        guard networkMonitor.isConnected else {
            emitLLM(.failed(pack: .tiny, error: ModelDownloadError.notConnected.localizedDescription))
            throw ModelDownloadError.notConnected
        }
        guard networkMonitor.connectionType == .wifi else {
            HSLogger.llm.info("LLM download blocked — not on Wi-Fi (pack: \(pack.rawValue))")
            emitLLM(.failed(pack: .tiny, error: ModelDownloadError.cellularNotAllowed.localizedDescription))
            throw ModelDownloadError.cellularNotAllowed
        }

        // Свободное место.
        if let freeBytes = freeDiskSpaceBytes(), freeBytes < pack.sizeBytes + (200 * 1024 * 1024) {
            HSLogger.llm.error("Not enough disk space: free=\(freeBytes), need=\(pack.sizeBytes)")
            throw ModelDownloadError.fileSystem(String(localized: "modelManager.error.notEnoughSpace"))
        }

        if activeDownloadPack != nil {
            throw ModelDownloadError.whisperKitFailure("Another LLM download is already in progress")
        }

        activeDownloadPack = pack
        defer { activeDownloadPack = nil }

        try createDirectoryIfNeeded()

        HSLogger.llm.info("Starting LLM download: \(pack.rawValue)")

        // Прогресс-эмиттер: у `LocalLLMServiceLive.downloadModel()` нет колбэка,
        // поэтому симулируем плавное нарастание от 0 до 0.97 (как в предыдущей реализации).
        let progressTask = Task { [weak self] in
            guard let self else { return }
            var fake: Double = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                fake = min(0.97, fake + 0.02)
                let bytes = Int64(Double(pack.sizeBytes) * fake)
                await self.emitLLM(.downloading(
                    pack: .tiny, // state использует WhisperKit enum; UI проверяет activeDownloadPack отдельно
                    progress: fake,
                    bytesDownloaded: bytes,
                    totalBytes: pack.sizeBytes
                ))
            }
        }

        do {
            // Для qwen15b делегируем уже существующему `LocalLLMService.downloadModel()` —
            // он знает точный URL и имя файла.
            if pack == .qwen15b {
                try await primaryLLM.downloadModel()
            } else {
                // Для дополнительных паков (qwen3b) — прямая загрузка через URLSession.
                try await directDownload(pack: pack)
            }

            progressTask.cancel()
            emitLLM(.completed(pack: .tiny))
            markActive(pack)
            HSLogger.llm.info("LLM pack \(pack.rawValue) downloaded")
        } catch is CancellationError {
            progressTask.cancel()
            emitLLM(.failed(pack: .tiny, error: ModelDownloadError.cancelled.localizedDescription))
            throw ModelDownloadError.cancelled
        } catch {
            progressTask.cancel()
            emitLLM(.failed(pack: .tiny, error: error.localizedDescription))
            HSLogger.llm.error("LLM download failed: \(error.localizedDescription)")
            throw ModelDownloadError.whisperKitFailure(error.localizedDescription)
        }
    }

    // MARK: - Protocol: delete

    public func deleteModel(_ pack: LLMModelPack) async throws {
        if await isCurrentlyInUse(pack) {
            throw ModelDownloadError.fileSystem(String(localized: "modelManager.error.packInUse"))
        }
        let url = fileURL(for: pack)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
            HSLogger.llm.info("LLM pack \(pack.rawValue) deleted")
        } catch {
            throw ModelDownloadError.fileSystem(error.localizedDescription)
        }
    }

    // MARK: - Private helpers

    private func createDirectoryIfNeeded() throws {
        do {
            try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        } catch {
            throw ModelDownloadError.fileSystem(error.localizedDescription)
        }
    }

    private func freeDiskSpaceBytes() -> Int64? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage
        } catch {
            return nil
        }
    }

    private func directDownload(pack: LLMModelPack) async throws {
        guard let remote = pack.remoteURL else {
            throw ModelDownloadError.whisperKitFailure("No remote URL for pack \(pack.rawValue)")
        }
        let (tempURL, _) = try await URLSession.shared.download(from: remote)
        let dest = fileURL(for: pack)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
    }

    // `ModelDownloadState` типизирован под `WhisperKitModelPack`; для LLM-потока мы
    // переиспользуем этот же стрим (UI различает LLM vs WhisperKit по отдельным менеджерам),
    // поэтому используем плейсхолдер-пак `.tiny` как неинформативный.
    private func emitLLM(_ state: ModelDownloadState) {
        progressContinuation?.yield(state)
    }

    private func emit(_ state: ModelDownloadState) {
        progressContinuation?.yield(state)
    }

    /// Не создаёт состояния; оставлен для совместимости сигнатуры `emit`.
    private func convertToWhisperStatePlaceholder(pack: LLMModelPack, progress: Double) -> ModelDownloadState {
        .completed(pack: .tiny)
    }
}

// MARK: - Legacy alias

/// Старое имя для совместимости со ссылками в коде (`AppContainer.llmDownloadManager`).
/// Новый код должен использовать `LLMModelManager`.
public typealias LLMModelDownloadManagerLegacy = LLMModelManager
