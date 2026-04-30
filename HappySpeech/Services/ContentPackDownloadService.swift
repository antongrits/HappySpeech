import FirebaseStorage
import Foundation
import OSLog

// MARK: - Protocol

/// Загружает и кэширует контент-паки из Firebase Storage.
///
/// `ContentPackDownloadService` обеспечивает OTA (over-the-air) обновление контента
/// без релиза в App Store. Загрузки возобновляемы — Firebase SDK автоматически
/// использует HTTP range requests, прерванная загрузка продолжается с места остановки.
///
/// ### Storage структура
/// ```
/// /content_packs/{packId}/words.json
/// /content_packs/{packId}/audio/
/// ```
///
/// ### Кэш
/// `Documents/ContentPacks/{packId}/` — сохраняется между запусками,
/// `cachedURL(for:)` возвращает локальный URL если пак уже скачан.
///
/// ## Пример
/// ```swift
/// let service: ContentPackDownloadService = LiveContentPackDownloadService()
///
/// // Скачать с прогрессом
/// Task {
///     for await progress in service.downloadProgress(id: "sound_r_pack") {
///         updateProgressBar(progress)
///     }
/// }
/// let url = try await service.downloadPack(id: "sound_r_pack")
/// ```
///
/// ## See Also
/// - ``RemoteConfigService``
/// - ``SyncService``
public protocol ContentPackDownloadService: AnyObject, Sendable {
    /// Downloads the pack with given id. Returns cached URL if already downloaded.
    /// Throws StorageError or ContentPackError on failure.
    func downloadPack(id: String) async throws -> URL

    /// Returns an AsyncStream of progress values [0.0 ... 1.0] during download.
    /// Completes when download finishes or fails.
    func downloadProgress(id: String) -> AsyncStream<Double>

    /// Returns the local cached URL for a pack id if it exists on disk.
    func cachedURL(for id: String) -> URL?

    /// Removes all cached packs from Documents/ContentPacks/.
    func clearCache() throws
}

// MARK: - Error

public enum ContentPackError: LocalizedError {
    case packNotFound(String)
    case diskWriteFailed(Error)
    case alreadyDownloading(String)

    public var errorDescription: String? {
        switch self {
        case .packNotFound(let id):
            return String(localized: "content_pack.error.not_found \(id)")
        case .diskWriteFailed(let err):
            return String(localized: "content_pack.error.disk_write \(err.localizedDescription)")
        case .alreadyDownloading(let id):
            return String(localized: "content_pack.error.already_downloading \(id)")
        }
    }
}

// MARK: - Live Implementation

public final class LiveContentPackDownloadService: ContentPackDownloadService, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "ContentPackDownload")
    private let storage = Storage.storage()
    private let cacheRoot: URL

    // Active download continuations keyed by packId.
    private var progressContinuations: [String: AsyncStream<Double>.Continuation] = [:]
    private var activeDownloads: [String: StorageDownloadTask] = [:]
    private let lock = NSLock()

    public init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheRoot = docs.appendingPathComponent("ContentPacks", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    // MARK: - ContentPackDownloadService

    public func downloadPack(id: String) async throws -> URL {
        // Return cached version if fresh (< 7 days old).
        if let cached = cachedURL(for: id) {
            logger.info("ContentPack \(id, privacy: .public) served from cache")
            return cached
        }

        let destination = packDirectory(for: id).appendingPathComponent("pack.json")
        try FileManager.default.createDirectory(
            at: packDirectory(for: id),
            withIntermediateDirectories: true
        )

        let ref = storage.reference(withPath: "content_packs/\(id)/pack.json")

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            guard activeDownloads[id] == nil else {
                lock.unlock()
                continuation.resume(throwing: ContentPackError.alreadyDownloading(id))
                return
            }

            let task = ref.write(toFile: destination) { [weak self] url, error in
                guard let self else { return }
                self.lock.lock()
                self.activeDownloads.removeValue(forKey: id)
                self.lock.unlock()

                if let error {
                    self.logger.error("ContentPack download failed \(id, privacy: .public): \(error.localizedDescription)")
                    self.progressContinuations[id]?.finish()
                    continuation.resume(throwing: error)
                } else if let url {
                    self.logger.info("ContentPack \(id, privacy: .public) downloaded to \(url.lastPathComponent)")
                    self.progressContinuations[id]?.finish()
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ContentPackError.packNotFound(id))
                }
            }

            task.observe(.progress) { [weak self] snapshot in
                guard let self, let progress = snapshot.progress else { return }
                let fraction = progress.totalUnitCount > 0
                    ? Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    : 0
                self.lock.lock()
                self.progressContinuations[id]?.yield(fraction)
                self.lock.unlock()
            }

            activeDownloads[id] = task
            lock.unlock()
        }
    }

    public func downloadProgress(id: String) -> AsyncStream<Double> {
        AsyncStream<Double> { continuation in
            lock.lock()
            progressContinuations[id] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.progressContinuations.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }

    public func cachedURL(for id: String) -> URL? {
        let candidate = packDirectory(for: id).appendingPathComponent("pack.json")
        guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }

        // Invalidate if older than 7 days.
        let attrs = try? FileManager.default.attributesOfItem(atPath: candidate.path)
        if let modified = attrs?[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) > 7 * 24 * 3600 {
            try? FileManager.default.removeItem(at: packDirectory(for: id))
            return nil
        }

        return candidate
    }

    public func clearCache() throws {
        if FileManager.default.fileExists(atPath: cacheRoot.path) {
            try FileManager.default.removeItem(at: cacheRoot)
        }
        try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
        logger.info("ContentPack cache cleared")
    }

    // MARK: - Private

    private func packDirectory(for id: String) -> URL {
        cacheRoot.appendingPathComponent(id, isDirectory: true)
    }
}

// MARK: - Mock

public final class MockContentPackDownloadService: ContentPackDownloadService, @unchecked Sendable {
    public var shouldFail: Bool = false
    public var downloadedPacks: [String] = []

    public init() {}

    public func downloadPack(id: String) async throws -> URL {
        if shouldFail { throw ContentPackError.packNotFound(id) }
        downloadedPacks.append(id)
        return FileManager.default.temporaryDirectory.appendingPathComponent("\(id).json")
    }

    public func downloadProgress(id: String) -> AsyncStream<Double> {
        AsyncStream { continuation in
            continuation.yield(1.0)
            continuation.finish()
        }
    }

    public func cachedURL(for id: String) -> URL? { nil }

    public func clearCache() throws { downloadedPacks.removeAll() }
}
