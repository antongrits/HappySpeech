import Foundation
import OSLog

// MARK: - LLMError

public enum LLMError: Error, LocalizedError {
    case notLoaded
    case generationFailed(String)
    case unsupportedArchitecture

    public var errorDescription: String? {
        switch self {
        case .notLoaded:
            return "Модель не загружена"
        case .generationFailed(let reason):
            return "Ошибка генерации: \(reason)"
        case .unsupportedArchitecture:
            return "MLX требует Apple Silicon (arm64)"
        }
    }
}

// MARK: - LLMInferenceActor
// ==================================================================================
// Сериализует доступ к on-device LLM typed-endpoints.
//
// Typed endpoints (generateParentSummary / generateRoute / generateMicroStory)
// делегируют в LocalLLMService, который внутри использует MLXEngine для inference.
//
// MLXEngine.shared — отдельный актор для raw MLX text generation.
// LLMInferenceActor — сериализует typed-endpoint вызовы + хранит isReady.
//
// Kid circuit ВСЕГДА на Tier A или C — НИКОГДА Tier B (COPPA).
// ==================================================================================

public actor LLMInferenceActor {

    // MARK: - Identity
    public static let modelId = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"

    // MARK: - State
    private let localLLM: any LocalLLMService
    private var isBusy: Bool = false

    public init(localLLM: any LocalLLMService) {
        self.localLLM = localLLM
    }

    // MARK: - Readiness

    public var isReady: Bool {
        localLLM.isModelDownloaded || LLMModelManager.localMLXModelURL() != nil
    }

    // MARK: - Typed Endpoints

    public func generateParentSummary(_ request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
        try await serialized {
            try await self.localLLM.generateParentSummary(request: request)
        }
    }

    public func generateRoute(_ request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
        try await serialized {
            try await self.localLLM.generateRoute(request: request)
        }
    }

    public func generateMicroStory(_ request: MicroStoryRequest) async throws -> MicroStoryResponse {
        try await serialized {
            try await self.localLLM.generateMicroStory(request: request)
        }
    }

    // MARK: - Serialization

    private func serialized<T: Sendable>(_ work: @Sendable () async throws -> T) async throws -> T {
        while isBusy {
            try await Task.sleep(nanoseconds: 30_000_000) // 30 ms
            try Task.checkCancellation()
        }
        isBusy = true
        defer { isBusy = false }
        HSLogger.llm.debug("LLMInferenceActor: inference acquired")
        return try await work()
    }
}
