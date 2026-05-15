import Foundation
@testable import HappySpeech

// MARK: - URLProtocolStub
//
// Перехватывает все URLSession-запросы для unit-тестов сетевых клиентов.
// Использование:
//   let session = URLProtocolStub.makeSession()
//   URLProtocolStub.setHandler { request in (data, httpResponse) }
//   ... выполнить запрос ...
//   URLProtocolStub.reset()

final class URLProtocolStub: URLProtocol {

    /// Результат одного перехваченного запроса.
    struct Stub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    /// Замыкание, формирующее ответ на основе запроса. Может бросать ошибку транспорта.
    nonisolated(unsafe) private static var handler: (@Sendable (URLRequest) throws -> Stub)?
    nonisolated(unsafe) private(set) static var capturedRequests: [URLRequest] = []
    private static let lock = NSLock()

    static func setHandler(_ handler: @escaping @Sendable (URLRequest) throws -> Stub) {
        lock.lock(); defer { lock.unlock() }
        Self.handler = handler
        Self.capturedRequests = []
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        capturedRequests = []
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    /// Удобный конструктор JSON-ответа с заданным статусом.
    static func jsonResponse(_ json: String, status: Int, url: URL) -> Stub {
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        return Stub(data: Data(json.utf8), response: response, error: nil)
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.capturedRequests.append(request)
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let stub = try handler(request)
            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response = stub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - MockKeychainStore
//
// In-memory реализация KeychainStoreProtocol для unit-тестов API-клиентов.

final class MockKeychainStore: KeychainStoreProtocol, @unchecked Sendable {

    private var storage: [String: String] = [:]
    private let lock = NSLock()

    init(seed: [KeychainKey: String] = [:]) {
        for (key, value) in seed {
            storage[Self.compositeKey(service: key.service, account: key.account)] = value
        }
    }

    private static func compositeKey(service: String, account: String) -> String {
        "\(service)|\(account)"
    }

    func read(service: String, account: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return storage[Self.compositeKey(service: service, account: account)]
    }

    @discardableResult
    func write(_ value: String, service: String, account: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        storage[Self.compositeKey(service: service, account: account)] = value
        return true
    }

    @discardableResult
    func delete(service: String, account: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: Self.compositeKey(service: service, account: account))
        return true
    }
}
