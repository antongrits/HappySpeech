import Foundation

// MARK: - MockLLMModelManager
//
// Используется в `AppContainer.preview()` и в юнит-тестах LLM-пайплайна.
// Симулирует встроенную (бандлированную) модель без файловых операций.

public actor MockLLMModelManager: LLMModelManagerProtocol {

    private var installed: Set<LLMModelPack>

    public init(installed: [LLMModelPack] = [.qwen15b]) {
        self.installed = Set(installed)
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
}
