import Foundation
import OSLog

// MARK: - CircuitType

/// Identifies which user circuit a caller belongs to.
/// COPPA — `kid` circuits MUST NEVER hit external LLM APIs. `ClaudeAPIClient` enforces this.
public enum CircuitType: String, Sendable {
    case kid
    case parent
    case specialist
}

// MARK: - ClaudeChatMessage

public struct ClaudeChatMessage: Sendable, Equatable {
    public enum Role: String, Sendable { case user, assistant }
    public let role: Role
    public let content: String
    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - ClaudeAPIClientProtocol

public protocol ClaudeAPIClientProtocol: Sendable {
    var isConfigured: Bool { get }
    func send(
        circuit: CircuitType,
        system: String?,
        messages: [ClaudeChatMessage],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String
}

// MARK: - ClaudeAPIClient

/// Posts to `https://api.anthropic.com/v1/messages` with `claude-haiku-4-5`.
/// Reads API key from Keychain via `KeychainStoreProtocol`.
/// Enforces COPPA: calls from `.kid` are rejected with `AppError.notAllowedInChildCircuit`.
public struct ClaudeAPIClient: ClaudeAPIClientProtocol {

    public static let defaultModel = "claude-haiku-4-5"
    public static let defaultEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let apiVersionHeader = "2023-06-01"

    private let endpoint: URL
    private let model: String
    private let networkClient: NetworkClient
    private let keychain: any KeychainStoreProtocol
    private let keychainKey: KeychainKey

    public init(
        endpoint: URL = ClaudeAPIClient.defaultEndpoint,
        model: String = ClaudeAPIClient.defaultModel,
        networkClient: NetworkClient,
        keychain: any KeychainStoreProtocol = KeychainStore(),
        keychainKey: KeychainKey = .anthropicAPIToken
    ) {
        self.endpoint = endpoint
        self.model = model
        self.networkClient = networkClient
        self.keychain = keychain
        self.keychainKey = keychainKey
    }

    public var isConfigured: Bool {
        (keychain.read(keychainKey)?.isEmpty == false)
    }

    public func send(
        circuit: CircuitType,
        system: String?,
        messages: [ClaudeChatMessage],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        guard circuit != .kid else {
            HSLogger.llm.error("Claude API blocked: kid circuit")
            throw AppError.notAllowedInChildCircuit
        }
        guard let token = keychain.read(keychainKey), !token.isEmpty else {
            throw AppError.llmNotDownloaded
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(token, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersionHeader, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "system": system ?? NSNull(),
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, http) = try await networkClient.perform(request)
            HSLogger.llm.debug("Claude /messages status=\(http.statusCode) bytes=\(data.count)")
            return try Self.extractText(from: data)
        } catch let netError as NetworkError {
            throw Self.mapNetworkError(netError)
        }
    }

    // MARK: - Helpers

    private static func extractText(from data: Data) throws -> String {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.llmInvalidJSON("non-object response")
        }
        if let error = obj["error"] as? [String: Any], let message = error["message"] as? String {
            throw AppError.llmInvalidJSON(message)
        }
        guard let content = obj["content"] as? [[String: Any]] else {
            throw AppError.llmInvalidJSON("missing content array")
        }
        let text = content
            .compactMap { block -> String? in
                guard (block["type"] as? String) == "text" else { return nil }
                return block["text"] as? String
            }
            .joined(separator: "\n")
        guard !text.isEmpty else {
            throw AppError.llmInvalidJSON("empty text content")
        }
        return text
    }

    private static func mapNetworkError(_ error: NetworkError) -> AppError {
        switch error {
        case .timeout:             return .llmTimeout
        case .unauthorized:        return .authTokenExpired
        case .rateLimited:         return .networkTransient("rate limited")
        case .transient(let info): return .networkTransient(info)
        case .permanent(let info): return .networkPermanent(info)
        }
    }
}
