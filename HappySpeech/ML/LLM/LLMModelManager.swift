import Foundation
import OSLog

// MARK: - LLMModelPack

/// Локальная LLM-модель приложения.
///
/// `qwen15b` — единственная встроенная модель (детский tier A, on-device, COPPA-safe).
/// Модель поставляется внутри бандла приложения — никаких загрузок во время работы.
public enum LLMModelPack: String, CaseIterable, Sendable, Codable {
    case qwen15b = "qwen2.5-1.5b"

    public var displayName: String {
        switch self {
        case .qwen15b: return String(localized: "modelManager.llm.pack.qwen15b.name")
        }
    }

    /// Приблизительный размер встроенной модели (4-bit safetensors).
    public var sizeBytes: Int64 {
        switch self {
        case .qwen15b: return 900 * 1024 * 1024
        }
    }

    public var isDefault: Bool { self == .qwen15b }

    public var tierDescription: String {
        switch self {
        case .qwen15b: return String(localized: "modelManager.llm.pack.qwen15b.tier")
        }
    }

    /// Имя директории модели внутри бандла (`Resources/Models/LLM/`).
    fileprivate var bundleDirectoryName: String {
        switch self {
        case .qwen15b: return "Qwen2.5-1.5B-Instruct-4bit"
        }
    }
}

// MARK: - LLMModelManagerProtocol

/// Управление встроенными LLM-моделями.
///
/// Все модели поставляются внутри бандла приложения. Протокол сохранён для DI
/// и для отображения статуса модели в настройках — операций загрузки нет.
public protocol LLMModelManagerProtocol: AnyObject, Sendable {
    /// Возвращает `true`, если модель присутствует в бандле приложения.
    func isModelInstalled(_ pack: LLMModelPack) async -> Bool

    /// Список встроенных моделей.
    func installedModels() async -> [LLMModelPack]

    /// Используется ли модель прямо сейчас (загружена в `LocalLLMService`).
    func isCurrentlyInUse(_ pack: LLMModelPack) async -> Bool
}

// MARK: - LLMModelManager (actor)

/// Менеджер встроенных LLM-моделей.
///
/// Модель Qwen2.5-1.5B-Instruct-4bit поставляется внутри бандла приложения
/// (`Resources/Models/LLM/`). Загрузок во время работы приложения нет —
/// модель всегда доступна offline.
public actor LLMModelManager: LLMModelManagerProtocol {

    // MARK: - Dependencies

    /// Ссылка на основной LLM-сервис — чтобы знать, загружена ли модель в память.
    private let primaryLLM: any LocalLLMService

    // MARK: - State

    private var activePack: LLMModelPack = .qwen15b

    // MARK: - Init

    public init(primaryLLM: any LocalLLMService) {
        self.primaryLLM = primaryLLM
    }

    // MARK: - Protocol: installed state

    public func isModelInstalled(_ pack: LLMModelPack) async -> Bool {
        Self.bundledModelURL(for: pack) != nil
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

    // MARK: - Bundled model location

    /// URL директории встроенной MLX-модели внутри бандла приложения.
    /// Возвращает `nil`, только если модель отсутствует в бандле (ошибка сборки).
    static func bundledModelURL(for pack: LLMModelPack) -> URL? {
        let name = pack.bundleDirectoryName
        if let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Models/LLM") {
            return directoryIfExists(url)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: nil) {
            return directoryIfExists(url)
        }
        return nil
    }

    private static func directoryIfExists(_ url: URL) -> URL? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return url
    }
}

// MARK: - MLX Model Helpers (static)

extension LLMModelManager {

    /// URL встроенной MLX-модели (safetensors + tokenizer) внутри бандла приложения.
    /// Используется `MLXEngine` для загрузки модели в память.
    public static func localMLXModelURL(
        modelId: String = LocalLLMServiceLive.mlxModelId
    ) -> URL? {
        _ = modelId
        return bundledModelURL(for: .qwen15b)
    }
}
