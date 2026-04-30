// MARK: - MLXTokenizerBridge
// ==================================================================================
// Адаптер swift-transformers Tokenizer → MLXLMCommon.Tokenizer + TokenizerLoader.
//
// mlx-swift-lm 3.x требует собственный протокол MLXLMCommon.Tokenizer.
// swift-transformers уже подключён транзитивно (WhisperKit → swift-transformers).
// Этот файл оборачивает AutoTokenizer из Tokenizers в MLXLMCommon-совместимый тип.
//
// Используется ТОЛЬКО под #if arch(arm64) внутри LLMInferenceActor.
// ==================================================================================

#if arch(arm64)
import Foundation
import MLXLMCommon
import Tokenizers

// MARK: - SwiftTransformersTokenizer (адаптер)

/// Оборачивает `Tokenizers.Tokenizer` (swift-transformers) в `MLXLMCommon.Tokenizer`.
struct SwiftTransformersTokenizer: MLXLMCommon.Tokenizer, @unchecked Sendable {

    private let inner: any Tokenizers.Tokenizer

    init(_ inner: any Tokenizers.Tokenizer) {
        self.inner = inner
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        inner.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        inner.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        inner.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        inner.convertIdToToken(id)
    }

    var bosToken: String? { inner.bosToken }
    var eosToken: String? { inner.eosToken }
    var unknownToken: String? { inner.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        // swift-transformers принимает [Message] ([String: String]), преобразуем
        let typedMessages: [[String: String]] = messages.compactMap { dict in
            var result: [String: String] = [:]
            for (key, value) in dict {
                if let str = value as? String {
                    result[key] = str
                }
            }
            return result.isEmpty ? nil : result
        }
        return try inner.applyChatTemplate(messages: typedMessages)
    }
}

// MARK: - LocalTokenizerLoader

/// Загружает токенайзер из локальной директории через AutoTokenizer (swift-transformers).
struct LocalTokenizerLoader: MLXLMCommon.TokenizerLoader, Sendable {

    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(modelFolder: directory)
        return SwiftTransformersTokenizer(upstream)
    }
}
#endif
