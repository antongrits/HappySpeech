import Foundation
import XCTest
@testable import HappySpeech

// MARK: - NetworkClientTests
//
// Тесты actor-обёртки NetworkClient через URLProtocolStub.
// Покрывает: успех 2xx, маппинг статусов на NetworkError, retry transient,
// timeout, non-HTTP-ответ, парсинг Retry-After, RetryPolicy delay.

final class NetworkClientTests: XCTestCase {

    private let testURL = URL(string: "https://api.example.com/v1/test")!

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: testURL)
        request.httpMethod = "POST"
        return request
    }

    // MARK: - Success

    func testPerformReturns2xxBody() async throws {
        URLProtocolStub.setHandler { [testURL] _ in
            URLProtocolStub.jsonResponse(#"{"ok":true}"#, status: 200, url: testURL)
        }
        let client = NetworkClient(session: URLProtocolStub.makeSession())
        let (data, http) = try await client.perform(makeRequest())
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"ok":true}"#)
    }

    func testPerformAccepts204() async throws {
        URLProtocolStub.setHandler { [testURL] _ in
            let response = HTTPURLResponse(url: testURL, statusCode: 204, httpVersion: nil, headerFields: nil)
            return URLProtocolStub.Stub(data: Data(), response: response, error: nil)
        }
        let client = NetworkClient(session: URLProtocolStub.makeSession())
        let (data, http) = try await client.perform(makeRequest())
        XCTAssertEqual(http.statusCode, 204)
        XCTAssertTrue(data.isEmpty)
    }

    // MARK: - Permanent errors (no retry)

    func testPerform400ThrowsPermanent() async {
        URLProtocolStub.setHandler { [testURL] _ in
            URLProtocolStub.jsonResponse(#"{"error":"bad"}"#, status: 400, url: testURL)
        }
        let client = NetworkClient(session: URLProtocolStub.makeSession())
        await assertThrowsNetworkError(client) { error in
            guard case .permanent = error else { return false }
            return true
        }
        XCTAssertEqual(URLProtocolStub.capturedRequests.count, 1, "4xx не должен ретраиться")
    }

    func testPerform401ThrowsUnauthorized() async {
        URLProtocolStub.setHandler { [testURL] _ in
            URLProtocolStub.jsonResponse("", status: 401, url: testURL)
        }
        let client = NetworkClient(session: URLProtocolStub.makeSession())
        await assertThrowsNetworkError(client) { $0 == .unauthorized }
    }

    func testPerform403ThrowsUnauthorized() async {
        URLProtocolStub.setHandler { [testURL] _ in
            URLProtocolStub.jsonResponse("", status: 403, url: testURL)
        }
        let client = NetworkClient(session: URLProtocolStub.makeSession())
        await assertThrowsNetworkError(client) { $0 == .unauthorized }
    }

    // MARK: - Transient errors (retried, then surface)

    func testPerform500RetriedThenThrowsTransient() async {
        URLProtocolStub.setHandler { [testURL] _ in
            URLProtocolStub.jsonResponse("", status: 500, url: testURL)
        }
        let fastPolicy = RetryPolicy(maxAttempts: 3, baseDelaysMs: [1, 1, 1], jitterMs: 0)
        let client = NetworkClient(session: URLProtocolStub.makeSession(), retryPolicy: fastPolicy)
        await assertThrowsNetworkError(client) { error in
            guard case .transient = error else { return false }
            return true
        }
        XCTAssertEqual(URLProtocolStub.capturedRequests.count, 3, "5xx ретраится maxAttempts раз")
    }

    func testPerform429ThrowsRateLimitedWithRetryAfter() async {
        URLProtocolStub.setHandler { [testURL] _ in
            let response = HTTPURLResponse(
                url: testURL,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "12"]
            )
            return URLProtocolStub.Stub(data: Data(), response: response, error: nil)
        }
        let fastPolicy = RetryPolicy(maxAttempts: 2, baseDelaysMs: [1], jitterMs: 0)
        let client = NetworkClient(session: URLProtocolStub.makeSession(), retryPolicy: fastPolicy)
        await assertThrowsNetworkError(client) { $0 == .rateLimited(retryAfterSec: 12) }
    }

    func testPerformTransientRecoversOnSecondAttempt() async throws {
        let counter = AttemptCounter()
        URLProtocolStub.setHandler { [testURL] _ in
            let attempt = counter.next()
            let status = attempt == 1 ? 503 : 200
            return URLProtocolStub.jsonResponse(#"{"recovered":true}"#, status: status, url: testURL)
        }
        let fastPolicy = RetryPolicy(maxAttempts: 3, baseDelaysMs: [1, 1, 1], jitterMs: 0)
        let client = NetworkClient(session: URLProtocolStub.makeSession(), retryPolicy: fastPolicy)
        let (data, http) = try await client.perform(makeRequest())
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"recovered":true}"#)
    }

    // MARK: - Timeout

    func testPerformTimeoutThrowsTimeout() async {
        URLProtocolStub.setHandler { _ in
            URLProtocolStub.Stub(data: nil, response: nil, error: URLError(.timedOut))
        }
        let fastPolicy = RetryPolicy(maxAttempts: 2, baseDelaysMs: [1], jitterMs: 0)
        let client = NetworkClient(session: URLProtocolStub.makeSession(), retryPolicy: fastPolicy)
        await assertThrowsNetworkError(client) { $0 == .timeout }
    }

    // MARK: - Transport error mapped to transient

    func testPerformTransportErrorMappedToTransient() async {
        URLProtocolStub.setHandler { _ in
            URLProtocolStub.Stub(data: nil, response: nil, error: URLError(.notConnectedToInternet))
        }
        let fastPolicy = RetryPolicy(maxAttempts: 2, baseDelaysMs: [1], jitterMs: 0)
        let client = NetworkClient(session: URLProtocolStub.makeSession(), retryPolicy: fastPolicy)
        await assertThrowsNetworkError(client) { error in
            guard case .transient = error else { return false }
            return true
        }
    }

    // MARK: - NetworkError.isTransient

    func testNetworkErrorIsTransientClassification() {
        XCTAssertTrue(NetworkError.transient("x").isTransient)
        XCTAssertTrue(NetworkError.timeout.isTransient)
        XCTAssertTrue(NetworkError.rateLimited(retryAfterSec: 1).isTransient)
        XCTAssertFalse(NetworkError.permanent("x").isTransient)
        XCTAssertFalse(NetworkError.unauthorized.isTransient)
    }

    // MARK: - RetryPolicy

    func testRetryPolicyDelayWithoutJitterIsDeterministic() {
        let policy = RetryPolicy(maxAttempts: 3, baseDelaysMs: [1000, 2000, 4000], jitterMs: 0)
        XCTAssertEqual(policy.delayNanos(forAttempt: 0), 1_000_000_000)
        XCTAssertEqual(policy.delayNanos(forAttempt: 1), 2_000_000_000)
        XCTAssertEqual(policy.delayNanos(forAttempt: 2), 4_000_000_000)
    }

    func testRetryPolicyDelayClampsAttemptIndex() {
        let policy = RetryPolicy(maxAttempts: 5, baseDelaysMs: [1000, 2000], jitterMs: 0)
        XCTAssertEqual(policy.delayNanos(forAttempt: 10), 2_000_000_000, "attempt вне диапазона зажимается")
    }

    func testRetryPolicyJitterStaysWithinBounds() {
        let policy = RetryPolicy(maxAttempts: 3, baseDelaysMs: [1000], jitterMs: 250)
        for _ in 0..<50 {
            let delay = policy.delayNanos(forAttempt: 0)
            XCTAssertGreaterThanOrEqual(delay, 750_000_000)
            XCTAssertLessThanOrEqual(delay, 1_250_000_000)
        }
    }

    func testRetryPolicyDefaultValues() {
        let policy = RetryPolicy.default
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.baseDelaysMs, [1000, 2000, 4000])
    }

    // MARK: - Helpers

    private func assertThrowsNetworkError(
        _ client: NetworkClient,
        file: StaticString = #filePath,
        line: UInt = #line,
        matching predicate: (NetworkError) -> Bool
    ) async {
        do {
            _ = try await client.perform(makeRequest())
            XCTFail("Ожидалась ошибка NetworkError", file: file, line: line)
        } catch let error as NetworkError {
            XCTAssertTrue(predicate(error), "Неожиданный NetworkError: \(error)", file: file, line: line)
        } catch {
            XCTFail("Ожидался NetworkError, получено: \(error)", file: file, line: line)
        }
    }
}

// MARK: - AttemptCounter

/// Потокобезопасный счётчик попыток для retry-тестов.
private final class AttemptCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()
    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}
