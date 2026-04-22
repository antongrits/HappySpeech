import Foundation
import OSLog

// MARK: - NetworkError

/// Transient errors are retried; permanent errors surface immediately.
public enum NetworkError: Error, Sendable, Equatable {
    case transient(String)
    case permanent(String)
    case timeout
    case unauthorized
    case rateLimited(retryAfterSec: Int?)

    public var isTransient: Bool {
        switch self {
        case .transient, .timeout, .rateLimited: return true
        case .permanent, .unauthorized: return false
        }
    }
}

// MARK: - RetryPolicy

public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let baseDelaysMs: [UInt64]   // 1s, 2s, 4s
    public let jitterMs: UInt64         // ±250ms

    public init(maxAttempts: Int = 3, baseDelaysMs: [UInt64] = [1000, 2000, 4000], jitterMs: UInt64 = 250) {
        self.maxAttempts = maxAttempts
        self.baseDelaysMs = baseDelaysMs
        self.jitterMs = jitterMs
    }

    public static let `default` = RetryPolicy()

    func delayNanos(forAttempt attempt: Int) -> UInt64 {
        let base = baseDelaysMs[min(attempt, baseDelaysMs.count - 1)]
        let jitterRange = Int64(jitterMs)
        let raw = Int64.random(in: -jitterRange...jitterRange)
        let total = Int64(base) + raw
        let clamped = max(0, total)
        return UInt64(clamped) * 1_000_000
    }
}

// MARK: - NetworkClient

/// Actor-isolated URLSession wrapper with a retry policy for transient failures.
/// All methods are Swift 6 strict-concurrency safe.
public actor NetworkClient {

    private let session: URLSession
    private let retryPolicy: RetryPolicy

    public init(session: URLSession = .shared, retryPolicy: RetryPolicy = .default) {
        self.session = session
        self.retryPolicy = retryPolicy
    }

    // MARK: - Perform

    /// Performs `request` with retry on transient failures. Returns raw body + HTTP response.
    @discardableResult
    public func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error = NetworkError.permanent("no attempts executed")

        for attempt in 0..<retryPolicy.maxAttempts {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: retryPolicy.delayNanos(forAttempt: attempt - 1))
            }
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw NetworkError.permanent("non-HTTP response")
                }
                switch http.statusCode {
                case 200..<300:
                    return (data, http)
                case 401, 403:
                    throw NetworkError.unauthorized
                case 408, 429:
                    let retryAfter = Self.parseRetryAfter(http.value(forHTTPHeaderField: "Retry-After"))
                    lastError = NetworkError.rateLimited(retryAfterSec: retryAfter)
                case 500..<600:
                    lastError = NetworkError.transient("HTTP \(http.statusCode)")
                case 400..<500:
                    throw NetworkError.permanent("HTTP \(http.statusCode)")
                default:
                    throw NetworkError.permanent("HTTP \(http.statusCode)")
                }
                HSLogger.network.warning("Transient network failure: \(String(describing: lastError)) (attempt \(attempt + 1)/\(self.retryPolicy.maxAttempts))")
            } catch let urlError as URLError where urlError.code == .timedOut {
                lastError = NetworkError.timeout
                HSLogger.network.warning("Timeout (attempt \(attempt + 1)/\(self.retryPolicy.maxAttempts))")
            } catch let netError as NetworkError where !netError.isTransient {
                throw netError
            } catch {
                lastError = NetworkError.transient(error.localizedDescription)
                HSLogger.network.warning("Transport failure (attempt \(attempt + 1)): \(error.localizedDescription)")
            }
        }

        throw lastError
    }

    // MARK: - Helpers

    private static func parseRetryAfter(_ raw: String?) -> Int? {
        guard let raw, let value = Int(raw.trimmingCharacters(in: .whitespaces)) else { return nil }
        return value
    }
}
