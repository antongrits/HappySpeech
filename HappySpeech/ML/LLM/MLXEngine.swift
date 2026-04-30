// MARK: - MLXEngine
// ==================================================================================
// Singleton actor для прямого доступа к MLX Qwen2.5-1.5B inference.
//
// Отделён от LLMInferenceActor (который сохраняет typed-endpoints архитектуру).
// LocalLLMServiceLive использует MLXEngine.shared для raw text generation.
//
// Жизненный цикл:
//   1. Первый вызов generate() → lazy load модели из localModelURL
//   2. Последующие вызовы — модель уже в памяти
//   3. Актор сериализует доступ (MLX не реентерабелен)
//
// Поддерживается ТОЛЬКО на Apple Silicon (arm64).
// На x86_64 симуляторе — любой вызов бросает LLMError.unsupportedArchitecture.
// ==================================================================================

#if arch(arm64)
import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import OSLog

public actor MLXEngine {

    // MARK: - Singleton

    public static let shared = MLXEngine()

    // MARK: - State

    private var modelContainer: ModelContainer?
    private var isLoaded = false

    private init() {}

    // MARK: - Generation

    /// Генерирует текст по произвольному промпту.
    /// Lazy-загружает модель при первом вызове.
    ///
    /// - Parameters:
    ///   - prompt: Полный промпт (инструкция + контекст)
    ///   - maxTokens: Максимум генерируемых токенов
    ///   - temperature: Температура сэмплирования
    /// - Returns: Сгенерированный текст
    public func generate(
        prompt: String,
        maxTokens: Int = 256,
        temperature: Float = 0.7
    ) async throws -> String {
        try await ensureLoaded()
        guard let container = modelContainer else {
            throw LLMError.notLoaded
        }
        let params = GenerateParameters(maxTokens: maxTokens, temperature: temperature)
        let output: String = try await container.perform { context in
            let userInput = UserInput(prompt: .text(prompt))
            let input = try await context.processor.prepare(input: userInput)
            let stream = try MLXLMCommon.generate(
                input: input,
                parameters: params,
                context: context
            )
            var collected = ""
            for await generation in stream {
                switch generation {
                case .chunk(let text):
                    collected += text
                case .info(let info):
                    HSLogger.llm.debug("MLXEngine: \(info.tokensPerSecond, format: .fixed(precision: 1)) tok/s")
                default:
                    break
                }
            }
            return collected
        }
        return output
    }

    // MARK: - Model Loading

    private func ensureLoaded() async throws {
        guard !isLoaded else { return }
        guard let localURL = LLMModelManager.localMLXModelURL() else {
            throw LLMError.notLoaded
        }
        HSLogger.llm.info("MLXEngine: loading model from \(localURL.path)")
        let loader = LocalTokenizerLoader()
        modelContainer = try await LLMModelFactory.shared.loadContainer(
            from: localURL,
            using: loader
        )
        isLoaded = true
        HSLogger.llm.info("MLXEngine: model ready")
    }

    /// Сбросить загруженную модель из памяти (например, при memory warning).
    public func unload() {
        modelContainer = nil
        isLoaded = false
        HSLogger.llm.info("MLXEngine: model unloaded")
    }
}

#else

// MARK: - Stub for x86_64

import Foundation

public actor MLXEngine {
    public static let shared = MLXEngine()
    private init() {}

    public func generate(prompt: String, maxTokens: Int = 256, temperature: Float = 0.7) async throws -> String {
        throw LLMError.unsupportedArchitecture
    }

    public func unload() {}
}

#endif
