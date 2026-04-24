import Foundation

// MARK: - MockWhisperKitModelManager
//
// Используется в `AppContainer.preview()` и в юнит-тестах.
// Симулирует успешную установку `tiny` пака без сетевых вызовов.

public actor MockWhisperKitModelManager: WhisperKitModelManagerProtocol {

    private var installed: Set<WhisperKitModelPack>
    private var active: WhisperKitModelPack?

    private var progressContinuation: AsyncStream<ModelDownloadState>.Continuation?
    private lazy var progressStream: AsyncStream<ModelDownloadState> = {
        AsyncStream { continuation in
            self.progressContinuation = continuation
        }
    }()

    public init(installed: [WhisperKitModelPack] = [.tiny]) {
        self.installed = Set(installed)
        self.active = installed.first
    }

    public var downloadProgress: AsyncStream<ModelDownloadState> {
        get async { progressStream }
    }

    public func currentlyInstalledPack() async -> WhisperKitModelPack? {
        active ?? installed.first
    }

    public func installedPacks() async -> [WhisperKitModelPack] {
        WhisperKitModelPack.allCases.filter { installed.contains($0) }
    }

    public func isCurrentlyInUse(_ pack: WhisperKitModelPack) async -> Bool {
        active == pack
    }

    public func download(pack: WhisperKitModelPack, allowCellular: Bool) async throws {
        progressContinuation?.yield(.downloading(pack: pack, progress: 0.3, bytesDownloaded: 0, totalBytes: pack.sizeBytes))
        progressContinuation?.yield(.installing(pack: pack))
        installed.insert(pack)
        active = pack
        progressContinuation?.yield(.completed(pack: pack))
    }

    public func deletePack(_ pack: WhisperKitModelPack) async throws {
        if await isCurrentlyInUse(pack) {
            throw ModelDownloadError.packInUse(pack: pack)
        }
        installed.remove(pack)
    }
}
