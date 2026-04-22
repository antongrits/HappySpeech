import Foundation
import OSLog

// MARK: - HFInferenceClient
// ==================================================================================
// Thin wrapper around https://api-inference.huggingface.co/models/{model}.
// Used ONLY by parent / specialist circuits — NEVER by kid circuit (COPPA).
// Retries: 3 attempts, exponential backoff (200ms, 400ms, 800ms).
// Auth: bearer token read from Keychain — never hardcoded.
// ==================================================================================

public protocol HFInferenceClientProtocol: Sendable {
    var isConfigured: Bool { get }
    func generate(model: String, prompt: String, maxTokens: Int, timeoutMs: Int) async throws -> String
}

public struct HFInferenceClient: HFInferenceClientProtocol {

    public static let modelVikhrNemo = "Vikhrmodels/Vikhr-Nemo-12B-Instruct-R-21-09-24"
    public static let modelVikhr7B   = "Vikhrmodels/Vikhr-7B-instruct_0.4"

    private let baseURL = URL(string: "https://api-inference.huggingface.co/models/")!
    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?

    public init(
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () -> String? = HFInferenceClient.defaultTokenProvider
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    public var isConfigured: Bool { tokenProvider() != nil }

    public func generate(model: String, prompt: String, maxTokens: Int, timeoutMs: Int) async throws -> String {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw AppError.llmNotDownloaded // Reuse the same user-facing error
        }

        let url = baseURL.appendingPathComponent(model)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(timeoutMs) / 1000.0
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "inputs": prompt,
            "parameters": [
                "max_new_tokens": maxTokens,
                "temperature": 0.4,
                "top_p": 0.9,
                "return_full_text": false
            ],
            "options": [
                "wait_for_model": true,
                "use_cache": false
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let backoffsMs: [UInt64] = [200, 400, 800]
        var lastError: Error?

        for (attempt, delayMs) in backoffsMs.enumerated() {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AppError.networkServerError(-1)
                }
                if http.statusCode == 503 {
                    // HF "model loading" — backoff & retry.
                    lastError = AppError.networkServerError(503)
                    continue
                }
                if !(200..<300).contains(http.statusCode) {
                    throw AppError.networkServerError(http.statusCode)
                }
                return try parseGeneratedText(data)
            } catch {
                if (error as? URLError)?.code == .timedOut {
                    throw AppError.llmTimeout
                }
                lastError = error
                HSLogger.llm.warning("HF attempt \(attempt + 1) failed: \(error.localizedDescription)")
            }
        }
        throw lastError ?? AppError.unknown("HFInferenceClient: unknown failure")
    }

    // MARK: - JSON Parse

    private func parseGeneratedText(_ data: Data) throws -> String {
        // Typical HF response: [{"generated_text": "..."}]
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let first = array.first,
           let text = first["generated_text"] as? String {
            return text
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = obj["generated_text"] as? String { return text }
            if let error = obj["error"] as? String {
                throw AppError.llmInvalidJSON(error)
            }
        }
        throw AppError.llmInvalidJSON("HFInferenceClient: unexpected response shape")
    }

    // MARK: - Keychain

    public static let defaultTokenProvider: @Sendable () -> String? = {
        HFInferenceClient.readTokenFromKeychain()
    }

    private static func readTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ru.happyspeech.hf",
            kSecAttrAccount as String: "inference-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Write an HF token into the Keychain — used by Settings.
    @discardableResult
    public static func storeTokenInKeychain(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ru.happyspeech.hf",
            kSecAttrAccount as String: "inference-token"
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}
