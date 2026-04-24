import Foundation
import OSLog
import WhisperKit

// MARK: - WhisperKitModelPack

/// Три варианта WhisperKit-моделей. Пользователь выбирает один в onboarding / настройках.
/// Размеры приблизительные (реальные файлы из HuggingFace могут немного отличаться).
public enum WhisperKitModelPack: String, CaseIterable, Sendable, Codable {
    case tiny  = "tiny"
    case base  = "base"
    case small = "small"

    /// Название в UI (с размером в скобках).
    public var displayName: String {
        switch self {
        case .tiny:  return String(localized: "modelManager.whisperkit.pack.tiny.name")
        case .base:  return String(localized: "modelManager.whisperkit.pack.base.name")
        case .small: return String(localized: "modelManager.whisperkit.pack.small.name")
        }
    }

    /// Приблизительный размер загрузки в байтах.
    public var sizeBytes: Int64 {
        switch self {
        case .tiny:  return 150 * 1024 * 1024
        case .base:  return 290 * 1024 * 1024
        case .small: return 780 * 1024 * 1024
        }
    }

    /// HuggingFace репозиторий, содержащий все паки.
    public var huggingFaceRepo: String { "argmaxinc/whisperkit-coreml" }

    /// Путь к конкретной модели внутри репозитория (variant для `WhisperKit.download`).
    public var huggingFacePath: String { "openai_whisper-\(rawValue)" }

    /// Пак по умолчанию для первичного онбординга (самый быстрый / лёгкий).
    public static let `default`: WhisperKitModelPack = .tiny
}

// MARK: - ModelDownloadState

/// Публикуемое состояние загрузки модели (для UI через AsyncStream).
public enum ModelDownloadState: Sendable, Equatable {
    case idle
    case downloading(pack: WhisperKitModelPack, progress: Double, bytesDownloaded: Int64, totalBytes: Int64)
    case installing(pack: WhisperKitModelPack)
    case completed(pack: WhisperKitModelPack)
    case failed(pack: WhisperKitModelPack, error: String)
}

// MARK: - ModelDownloadError

public enum ModelDownloadError: LocalizedError, Sendable {
    case cellularNotAllowed
    case notConnected
    case cancelled
    case integrityCheckFailed(expectedBytes: Int64, actualBytes: Int64)
    case whisperKitFailure(String)
    case fileSystem(String)
    case packInUse(pack: WhisperKitModelPack)

    public var errorDescription: String? {
        switch self {
        case .cellularNotAllowed:
            return String(localized: "modelManager.error.cellularNotAllowed")
        case .notConnected:
            return String(localized: "modelManager.error.notConnected")
        case .cancelled:
            return String(localized: "modelManager.error.cancelled")
        case .integrityCheckFailed:
            return String(localized: "modelManager.error.integrityCheckFailed")
        case .whisperKitFailure(let msg):
            return msg
        case .fileSystem(let msg):
            return msg
        case .packInUse:
            return String(localized: "modelManager.error.packInUse")
        }
    }
}

// MARK: - WhisperKitModelManagerProtocol

public protocol WhisperKitModelManagerProtocol: AnyObject, Sendable {
    /// Стрим состояний загрузки (single consumer).
    var downloadProgress: AsyncStream<ModelDownloadState> { get async }

    /// Пак, который сейчас считается активным (последний полностью установленный).
    func currentlyInstalledPack() async -> WhisperKitModelPack?

    /// Все установленные паки (готовые к использованию ASR).
    func installedPacks() async -> [WhisperKitModelPack]

    /// Скачать пак. `allowCellular=false` блокирует загрузку на сотовой сети.
    func download(pack: WhisperKitModelPack, allowCellular: Bool) async throws

    /// Удалить пак с диска. Нельзя удалить активно используемый пак.
    func deletePack(_ pack: WhisperKitModelPack) async throws

    /// Проверить, используется ли пак в данный момент (например, загружен в ASRService).
    func isCurrentlyInUse(_ pack: WhisperKitModelPack) async -> Bool
}

public extension WhisperKitModelManagerProtocol {
    /// Удобный дефолт — Wi-Fi only.
    func download(pack: WhisperKitModelPack) async throws {
        try await download(pack: pack, allowCellular: false)
    }
}

// MARK: - WhisperKitModelManagerLive

/// Actor, управляющий загрузкой и удалением WhisperKit-моделей.
///
/// Особенности:
///   * Wi-Fi по умолчанию — сотовая сеть отдельным флагом;
///   * Прогресс публикуется через `AsyncStream` (single consumer — UI);
///   * Файлы хранятся в `Application Support/WhisperKitModels/{pack}/`;
///   * Папка `_resume/` хранит `resumeData` для продолжения после отмены (пока не используется WhisperKit-загрузкой, но зарезервирована);
///   * Интеграция с WhisperKit через публичный `WhisperKit.download(variant:downloadBase:progressCallback:)`.
public actor WhisperKitModelManagerLive: WhisperKitModelManagerProtocol {

    // MARK: - Dependencies

    private let networkMonitor: any NetworkMonitorService

    // MARK: - State

    private var currentActivePack: WhisperKitModelPack?
    private var activeDownloadTask: Task<Void, Error>?
    private var activeDownloadPack: WhisperKitModelPack?

    // MARK: - Progress stream

    private var progressContinuation: AsyncStream<ModelDownloadState>.Continuation?
    private lazy var progressStream: AsyncStream<ModelDownloadState> = {
        AsyncStream { continuation in
            self.progressContinuation = continuation
            continuation.onTermination = { _ in
                HSLogger.asr.debug("WhisperKit progress stream terminated")
            }
        }
    }()

    // MARK: - Init

    public init(networkMonitor: any NetworkMonitorService) {
        self.networkMonitor = networkMonitor
    }

    // MARK: - Paths

    private var rootDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WhisperKitModels", isDirectory: true)
    }

    private var resumeDirectory: URL {
        rootDirectory.appendingPathComponent("_resume", isDirectory: true)
    }

    private func directory(for pack: WhisperKitModelPack) -> URL {
        rootDirectory.appendingPathComponent(pack.rawValue, isDirectory: true)
    }

    // MARK: - Protocol: progress stream

    public var downloadProgress: AsyncStream<ModelDownloadState> {
        get async { progressStream }
    }

    // MARK: - Protocol: installed state

    public func currentlyInstalledPack() async -> WhisperKitModelPack? {
        if let currentActivePack, isPackInstalledOnDisk(currentActivePack) {
            return currentActivePack
        }
        // Фолбэк: найти любой установленный пак (приоритет — больше к меньше).
        let order: [WhisperKitModelPack] = [.small, .base, .tiny]
        return order.first { isPackInstalledOnDisk($0) }
    }

    public func installedPacks() async -> [WhisperKitModelPack] {
        WhisperKitModelPack.allCases.filter { isPackInstalledOnDisk($0) }
    }

    public func isCurrentlyInUse(_ pack: WhisperKitModelPack) async -> Bool {
        currentActivePack == pack || activeDownloadPack == pack
    }

    /// Пометить пак как активно используемый (вызывается `ASRService` при `loadModel`).
    public func markActivePack(_ pack: WhisperKitModelPack) {
        currentActivePack = pack
    }

    // MARK: - Protocol: download

    public func download(pack: WhisperKitModelPack, allowCellular: Bool) async throws {
        // Если уже установлен — no-op + сообщить в стрим.
        if isPackInstalledOnDisk(pack) {
            HSLogger.asr.info("WhisperKit pack \(pack.rawValue) already installed")
            emit(.completed(pack: pack))
            return
        }

        // Проверка состояния сети.
        guard networkMonitor.isConnected else {
            emit(.failed(pack: pack, error: ModelDownloadError.notConnected.localizedDescription))
            throw ModelDownloadError.notConnected
        }

        if networkMonitor.connectionType == .cellular, !allowCellular {
            HSLogger.asr.info("WhisperKit download blocked — cellular without consent")
            emit(.failed(pack: pack, error: ModelDownloadError.cellularNotAllowed.localizedDescription))
            throw ModelDownloadError.cellularNotAllowed
        }

        // Параллельные загрузки запрещены.
        if let activeDownloadPack {
            HSLogger.asr.info("WhisperKit download already in progress: \(activeDownloadPack.rawValue)")
            throw ModelDownloadError.whisperKitFailure("Another download is already in progress")
        }

        activeDownloadPack = pack
        defer {
            activeDownloadPack = nil
            activeDownloadTask = nil
        }

        try createDirectoriesIfNeeded()

        HSLogger.asr.info("Starting WhisperKit download: \(pack.rawValue)")
        emit(.downloading(pack: pack, progress: 0, bytesDownloaded: 0, totalBytes: pack.sizeBytes))

        let targetDir = directory(for: pack)

        do {
            // WhisperKit сам управляет скачиванием файлов пака (HubApi snapshot).
            // downloadBase — корневая директория, куда WhisperKit складывает <repo>/<variant>/<files>.
            _ = try await WhisperKit.download(
                variant: pack.huggingFacePath,
                downloadBase: targetDir,
                useBackgroundSession: false,
                from: pack.huggingFaceRepo,
                progressCallback: { [weak self] progress in
                    guard let self else { return }
                    let fraction = progress.fractionCompleted
                    let completed = progress.completedUnitCount
                    let total = max(progress.totalUnitCount, 1)
                    Task {
                        await self.emit(.downloading(
                            pack: pack,
                            progress: fraction,
                            bytesDownloaded: completed,
                            totalBytes: total
                        ))
                    }
                }
            )

            emit(.installing(pack: pack))

            // Проверка целостности по размеру (грубо).
            try verifyIntegrity(pack: pack)

            currentActivePack = pack
            emit(.completed(pack: pack))
            HSLogger.asr.info("WhisperKit pack \(pack.rawValue) downloaded successfully")
        } catch is CancellationError {
            emit(.failed(pack: pack, error: ModelDownloadError.cancelled.localizedDescription))
            throw ModelDownloadError.cancelled
        } catch let err as ModelDownloadError {
            emit(.failed(pack: pack, error: err.localizedDescription))
            throw err
        } catch {
            let wrapped = ModelDownloadError.whisperKitFailure(error.localizedDescription)
            emit(.failed(pack: pack, error: wrapped.localizedDescription))
            HSLogger.asr.error("WhisperKit download failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    // MARK: - Protocol: delete

    public func deletePack(_ pack: WhisperKitModelPack) async throws {
        if await isCurrentlyInUse(pack) {
            HSLogger.asr.info("Cannot delete \(pack.rawValue) — currently in use")
            throw ModelDownloadError.packInUse(pack: pack)
        }
        let dir = directory(for: pack)
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: dir)
            if currentActivePack == pack { currentActivePack = nil }
            HSLogger.asr.info("WhisperKit pack \(pack.rawValue) deleted")
        } catch {
            throw ModelDownloadError.fileSystem(error.localizedDescription)
        }
    }

    // MARK: - Cancel

    /// Отменить текущую загрузку (если есть).
    public func cancelActiveDownload() {
        guard let task = activeDownloadTask else { return }
        task.cancel()
        HSLogger.asr.info("WhisperKit download cancel requested")
    }

    // MARK: - Private helpers

    private func isPackInstalledOnDisk(_ pack: WhisperKitModelPack) -> Bool {
        // Стратегия B (см. план): наличие config.json внутри папки пака.
        // WhisperKit раскладывает файлы как <downloadBase>/<repo-slug>/<variant>/<files>.
        // Поэтому ищем `config.json` рекурсивно (не дороже пары десятков entries).
        let dir = directory(for: pack)
        guard FileManager.default.fileExists(atPath: dir.path) else { return false }
        return fileExistsRecursively(named: "config.json", in: dir)
    }

    private func fileExistsRecursively(named fileName: String, in dir: URL, maxDepth: Int = 4) -> Bool {
        guard maxDepth > 0 else { return false }
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return false
        }
        for url in contents {
            if url.lastPathComponent == fileName { return true }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if fileExistsRecursively(named: fileName, in: url, maxDepth: maxDepth - 1) {
                    return true
                }
            }
        }
        return false
    }

    private func createDirectoriesIfNeeded() throws {
        do {
            try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: resumeDirectory, withIntermediateDirectories: true)
        } catch {
            throw ModelDownloadError.fileSystem(error.localizedDescription)
        }
    }

    /// Сверяем суммарный размер папки пака с `pack.sizeBytes` (±20% допуск).
    /// SHA-256 checksum пока не реализован — файлы HuggingFace не имеют стабильного hash.
    private func verifyIntegrity(pack: WhisperKitModelPack) throws {
        let dir = directory(for: pack)
        let actualBytes = directorySize(at: dir)
        let expected = pack.sizeBytes
        let lowerBound = Int64(Double(expected) * 0.8)

        if actualBytes < lowerBound {
            HSLogger.asr.error("WhisperKit integrity check failed: expected ~\(expected), got \(actualBytes)")
            throw ModelDownloadError.integrityCheckFailed(expectedBytes: expected, actualBytes: actualBytes)
        }
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }

    private func emit(_ state: ModelDownloadState) {
        progressContinuation?.yield(state)
    }
}
