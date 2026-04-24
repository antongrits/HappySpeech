import Foundation

// MARK: - MockLLMModelManager
//
// Используется в `AppContainer.preview()` и в юнит-тестах LLM-пайплайна.
// Симулирует установленные паки без сетевых операций.

public actor MockLLMModelManager: LLMModelManagerProtocol {

    private var installed: Set<LLMModelPack>
    private var progressContinuation: AsyncStream<ModelDownloadState>.Continuation?
    private lazy var progressStream: AsyncStream<ModelDownloadState> = {
        AsyncStream { continuation in
            self.progressContinuation = continuation
        }
    }()

    public init(installed: [LLMModelPack] = [.qwen15b]) {
        self.installed = Set(installed)
    }

    public var downloadProgress: AsyncStream<ModelDownloadState> {
        get async { progressStream }
    }

    public func isModelInstalled(_ pack: LLMModelPack) async -> Bool {
        installed.contains(pack)
    }

    public func installedModels() async -> [LLMModelPack] {
        LLMModelPack.allCases.filter { installed.contains($0) }
    }

    public func isCurrentlyInUse(_ pack: LLMModelPack) async -> Bool {
        installed.contains(pack) && pack == .qwen15b
    }

    public func downloadIfNeeded(_ pack: LLMModelPack) async throws {
        progressContinuation?.yield(.completed(pack: .tiny))
        installed.insert(pack)
    }

    public func deleteModel(_ pack: LLMModelPack) async throws {
        installed.remove(pack)
    }
}
