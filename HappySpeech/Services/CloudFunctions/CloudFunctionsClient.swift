import Foundation

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
