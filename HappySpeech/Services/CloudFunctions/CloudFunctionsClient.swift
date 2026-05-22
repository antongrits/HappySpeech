import FirebaseFunctions
import Foundation
import OSLog

// MARK: - Region

/// Cloud Functions region — Europe West 3 (Frankfurt). Ближайший к RU/BY-аудитории.
public enum CloudFunctionsRegion {
    public static let `default`: String = "europe-west3"
}

// MARK: - Errors

/// Унифицированная ошибка для всех HTTPSCallable-клиентов HappySpeech.
public enum CloudFunctionsClientError: LocalizedError, Sendable {
    case appCheckFailed
    case unauthenticated
    case invalidArgument(String)
    case permissionDenied(String)
    case invalidResponse(String)
    case serverError(String)
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .appCheckFailed:
            return "Проверка устройства не прошла. Попробуйте позже."
        case .unauthenticated:
            return "Необходимо войти в аккаунт."
        case .invalidArgument(let detail):
            return "Неверные аргументы запроса: \(detail)"
        case .permissionDenied(let detail):
            return "Нет доступа: \(detail)"
        case .invalidResponse(let detail):
            return "Неверный ответ сервера: \(detail)"
        case .serverError(let detail):
            return "Ошибка сервера: \(detail)"
        case .networkUnavailable:
            return "Нет соединения с интернетом."
        }
    }
}

// MARK: - Base protocol

/// Базовый протокол для всех HTTPSCallable-обёрток.
///
/// Конкретные клиенты (см. ``ScoreSpeechQualityClient``,
/// ``NeurolinguistSummaryClient``, ``FamilyInviteClient``) реализуют
/// типизированные методы поверх общего mapping ошибок.
public protocol CloudFunctionsClient: AnyObject, Sendable {
    /// Регион Cloud Functions, который использует клиент.
    var region: String { get }
}

// MARK: - Live base implementation

/// Общая база для Live-реализаций клиентов.
///
/// Хранит инстанс `Functions` и предоставляет helpers для маппинга
/// `FunctionsErrorDomain` → ``CloudFunctionsClientError``.
public class LiveCloudFunctionsClientBase: @unchecked Sendable {

    public let region: String
    public let functions: Functions
    public let logger: Logger

    public init(
        region: String = CloudFunctionsRegion.default,
        category: String
    ) {
        self.region = region
        self.functions = Functions.functions(region: region)
        self.logger = Logger(subsystem: "com.happyspeech", category: category)
    }

    /// Маппинг NSError из Firebase Functions в типизированную ошибку.
    public func mapError(_ error: Error) -> CloudFunctionsClientError {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain else {
            return .serverError(error.localizedDescription)
        }
        let code = FunctionsErrorCode(rawValue: nsError.code) ?? .internal
        switch code {
        case .unauthenticated:
            return .unauthenticated
        case .permissionDenied:
            return .permissionDenied(nsError.localizedDescription)
        case .invalidArgument:
            return .invalidArgument(nsError.localizedDescription)
        case .unavailable, .deadlineExceeded:
            return .networkUnavailable
        case .failedPrecondition:
            return .appCheckFailed
        default:
            return .serverError(nsError.localizedDescription)
        }
    }

    /// Безопасная распаковка `[String: Any]` из callable response.
    public func extractDictionary(from data: Any) throws -> [String: Any] {
        guard let dict = data as? [String: Any] else {
            throw CloudFunctionsClientError.invalidResponse(
                "ожидался объект, получено: \(type(of: data))"
            )
        }
        return dict
    }
}
