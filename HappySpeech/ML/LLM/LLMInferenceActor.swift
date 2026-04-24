import Foundation
import OSLog

// MARK: - LLMInferenceActor
// ==================================================================================
// Serializes access to the on-device LLM (Qwen2.5-1.5B via MLC / llama.cpp).
// MLC/llama.cpp engines are not reentrant — only ONE inference may run at a time.
// The actor guarantees FIFO ordering and prevents GPU/ANE contention crashes.
//
// The actor does NOT own model lifecycle — that's LLMModelManager.
// It only holds a reference to the underlying LocalLLMService (SPI into the engine).
// ==================================================================================

public actor LLMInferenceActor {

    // MARK: - Model Identity
    public static let modelId = "Qwen/Qwen2.5-1.5B-Instruct-q4"

    // MARK: - State
    private let localLLM: any LocalLLMService
    private var isBusy: Bool = false

    public init(localLLM: any LocalLLMService) {
        self.localLLM = localLLM
    }

    // MARK: - Readiness
    public var isReady: Bool {
        localLLM.isModelDownloaded && localLLM.isModelLoaded
    }

    // MARK: - Raw generation
    // The underlying LocalLLMService exposes 3 typed endpoints (parentSummary/route/microStory).
    // For the other 9 decision points we use rule-based inside LiveLLMDecisionService and
    // escalate ONLY the three native-typed endpoints to the on-device model.
    // This keeps the actor minimal and avoids a free-form prompt/response layer that would
    // require a JSON parser for every kind of output.

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
        HSLogger.llm.debug("Inference acquired")
        return try await work()
    }
}
