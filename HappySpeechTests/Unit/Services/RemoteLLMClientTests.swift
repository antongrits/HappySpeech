import Foundation
import XCTest
@testable import HappySpeech

// MARK: - RemoteLLMClientTests
//
// Тесты HTTP-клиента remote LLM API через URLProtocolStub + MockKeychainStore.
// Покрывает: COPPA-блокировку kid-контура, отсутствие токена, построение запроса,
// парсинг ответа, обработку error-объекта, маппинг NetworkError → AppError.

final class RemoteLLMClientTests: XCTestCase {

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    private func makeClient(
        token: String? = "sk-test-token",
        session: URLSession? = nil
    ) -> RemoteLLMClient {
        var seed: [KeychainKey: String] = [:]
        if let token { seed[.remoteLLMAPIToken] = token }
        let keychain = MockKeychainStore(seed: seed)
        let networkClient = NetworkClient(
            session: session ?? URLProtocolStub.makeSession(),
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelaysMs: [1], jitterMs: 0)
        )
        return RemoteLLMClient(
            endpoint: endpoint,
            networkClient: networkClient,
            keychain: keychain
        )
    }

    private let sampleMessages = [RemoteLLMChatMessage(role: .user, content: "Привет")]

    // MARK: - isConfigured

    func testIsConfiguredTrueWhenTokenPresent() {
        let client = makeClient(token: "sk-abc")
        XCTAssertTrue(client.isConfigured)
    }

    func testIsConfiguredFalseWhenTokenMissing() {
        let client = makeClient(token: nil)
        XCTAssertFalse(client.isConfigured)
    }

    func testIsConfiguredFalseWhenTokenEmpty() {
        let client = makeClient(token: "")
        XCTAssertFalse(client.isConfigured)
    }

    // MARK: - COPPA: kid circuit blocked

    func testKidCircuitIsRejected() async {
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .kid,
                system: nil,
                messages: sampleMessages,
                maxTokens: 100,
                temperature: 0.5
            )
        ) { $0 == .notAllowedInChildCircuit }
        XCTAssertTrue(URLProtocolStub.capturedRequests.isEmpty, "Kid-запрос не должен уходить в сеть")
    }

    // MARK: - Missing token

    func testMissingTokenThrowsLLMNotDownloaded() async {
        let client = makeClient(token: nil)
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent,
                system: nil,
                messages: sampleMessages,
                maxTokens: 100,
                temperature: 0.5
            )
        ) { $0 == .llmNotDownloaded }
    }

    // MARK: - Request building

    func testRequestContainsAuthAndVersionHeaders() async throws {
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse(Self.validResponse, status: 200, url: endpoint)
        }
        let client = makeClient(token: "sk-header-test")
        _ = try await client.send(
            circuit: .parent,
            system: "system prompt",
            messages: sampleMessages,
            maxTokens: 256,
            temperature: 0.7
        )
        let request = try XCTUnwrap(URLProtocolStub.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-header-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), RemoteLLMClient.apiVersionHeader)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testRequestBodyContainsModelAndMessages() async throws {
        URLProtocolStub.setHandler { [endpoint] request in
            // URLProtocol даёт httpBodyStream — читаем поток.
            let body = Self.readBody(from: request)
            let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            XCTAssertEqual(json?["model"] as? String, RemoteLLMClient.defaultModel)
            XCTAssertEqual(json?["max_tokens"] as? Int, 512)
            XCTAssertEqual(json?["system"] as? String, "роль")
            let messages = json?["messages"] as? [[String: Any]]
            XCTAssertEqual(messages?.first?["content"] as? String, "Привет")
            return URLProtocolStub.jsonResponse(Self.validResponse, status: 200, url: endpoint)
        }
        let client = makeClient()
        _ = try await client.send(
            circuit: .specialist,
            system: "роль",
            messages: sampleMessages,
            maxTokens: 512,
            temperature: 0.3
        )
    }

    // MARK: - Response parsing

    func testValidResponseReturnsText() async throws {
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse(Self.validResponse, status: 200, url: endpoint)
        }
        let client = makeClient()
        let text = try await client.send(
            circuit: .parent,
            system: nil,
            messages: sampleMessages,
            maxTokens: 100,
            temperature: 0.5
        )
        XCTAssertEqual(text, "Здравствуйте!")
    }

    func testMultiBlockResponseJoinsTextBlocks() async throws {
        let json = """
        {"content":[{"type":"text","text":"Первая"},{"type":"text","text":"Вторая"}]}
        """
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse(json, status: 200, url: endpoint)
        }
        let client = makeClient()
        let text = try await client.send(
            circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
        )
        XCTAssertEqual(text, "Первая\nВторая")
    }

    func testErrorObjectInResponseThrowsInvalidJSON() async {
        let json = #"{"error":{"type":"invalid_request","message":"bad request"}}"#
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse(json, status: 200, url: endpoint)
        }
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
            )
        ) { error in
            guard case .llmInvalidJSON(let message) = error else { return false }
            return message == "bad request"
        }
    }

    func testMissingContentArrayThrowsInvalidJSON() async {
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse(#"{"id":"msg_1"}"#, status: 200, url: endpoint)
        }
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
            )
        ) { error in
            guard case .llmInvalidJSON = error else { return false }
            return true
        }
    }

    func testNonObjectResponseThrowsInvalidJSON() async {
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse("[1,2,3]", status: 200, url: endpoint)
        }
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
            )
        ) { error in
            guard case .llmInvalidJSON = error else { return false }
            return true
        }
    }

    func testEmptyTextContentThrowsInvalidJSON() async {
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse(#"{"content":[{"type":"image"}]}"#, status: 200, url: endpoint)
        }
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
            )
        ) { error in
            guard case .llmInvalidJSON = error else { return false }
            return true
        }
    }

    // MARK: - Network error mapping

    func testUnauthorizedMappedToTokenExpired() async {
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse("", status: 401, url: endpoint)
        }
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
            )
        ) { $0 == .authTokenExpired }
    }

    func testTimeoutMappedToLLMTimeout() async {
        URLProtocolStub.setHandler { _ in
            URLProtocolStub.Stub(data: nil, response: nil, error: URLError(.timedOut))
        }
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
            )
        ) { $0 == .llmTimeout }
    }

    func testServerErrorMappedToNetworkTransient() async {
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse("", status: 500, url: endpoint)
        }
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
            )
        ) { error in
            guard case .networkTransient = error else { return false }
            return true
        }
    }

    func testClientErrorMappedToNetworkPermanent() async {
        URLProtocolStub.setHandler { [endpoint] _ in
            URLProtocolStub.jsonResponse("", status: 404, url: endpoint)
        }
        let client = makeClient()
        await assertThrowsAppError(
            try await client.send(
                circuit: .parent, system: nil, messages: sampleMessages, maxTokens: 100, temperature: 0.5
            )
        ) { error in
            guard case .networkPermanent = error else { return false }
            return true
        }
    }

    // MARK: - Static constants

    func testDefaultConstants() {
        XCTAssertEqual(RemoteLLMClient.defaultModel, "claude-haiku-4-5")
        XCTAssertEqual(RemoteLLMClient.apiVersionHeader, "2023-06-01")
        XCTAssertEqual(RemoteLLMClient.defaultEndpoint.absoluteString, "https://api.anthropic.com/v1/messages")
    }

    // MARK: - RemoteLLMChatMessage

    func testChatMessageEquatable() {
        let a = RemoteLLMChatMessage(role: .user, content: "x")
        let b = RemoteLLMChatMessage(role: .user, content: "x")
        let c = RemoteLLMChatMessage(role: .assistant, content: "x")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCircuitTypeRawValues() {
        XCTAssertEqual(CircuitType.kid.rawValue, "kid")
        XCTAssertEqual(CircuitType.parent.rawValue, "parent")
        XCTAssertEqual(CircuitType.specialist.rawValue, "specialist")
    }

    // MARK: - Fixtures & helpers

    private static let validResponse = """
    {"content":[{"type":"text","text":"Здравствуйте!"}]}
    """

    private static func readBody(from request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    private func assertThrowsAppError(
        _ expression: @autoclosure () async throws -> String,
        file: StaticString = #filePath,
        line: UInt = #line,
        matching predicate: (AppError) -> Bool
    ) async {
        do {
            _ = try await expression()
            XCTFail("Ожидалась ошибка AppError", file: file, line: line)
        } catch let error as AppError {
            XCTAssertTrue(predicate(error), "Неожиданный AppError: \(error)", file: file, line: line)
        } catch {
            XCTFail("Ожидался AppError, получено: \(error)", file: file, line: line)
        }
    }
}
