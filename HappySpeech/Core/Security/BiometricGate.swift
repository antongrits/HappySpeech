import Foundation

// MARK: - AuthResult

/// Результат биометрической аутентификации.
public enum AuthResult: Sendable, Equatable {
    /// Аутентификация прошла успешно.
    case success
    /// Аутентификация отклонена (неверный биометрический образец или политика запрещает).
    case denied(reason: String)
    /// Биометрия недоступна или заблокирована — необходим резервный механизм (ParentalGate math).
    case fallback
    /// Пользователь отменил запрос аутентификации.
    case cancelled
}

// MARK: - BiometricGateService Protocol

/// Сервис биометрической аутентификации для родительского gate.
/// Протокол размещён в Core — доступен DesignSystem, Services, Features.
public protocol BiometricGateService: Sendable {
    /// Проверяет, доступна ли биометрия (Face ID / Touch ID) на устройстве.
    func canUseBiometric() async -> Bool

    /// Запускает биометрическую аутентификацию с указанной причиной.
    /// - Parameter reason: Строка причины, отображаемая системным диалогом.
    /// - Returns: `AuthResult` — результат попытки аутентификации.
    func authenticate(reason: String) async -> AuthResult
}

// MARK: - MockBiometricGateService

/// Мок-реализация для тестов и SwiftUI Preview.
/// Детерминирована: возвращает заданный `AuthResult` при любом вызове.
/// Размещена в Core чтобы быть доступной DesignSystem без импорта Services.
public struct MockBiometricGateService: BiometricGateService {

    private let availableResult: Bool
    private let authResult: AuthResult

    public init(available: Bool = true, result: AuthResult = .success) {
        self.availableResult = available
        self.authResult = result
    }

    public func canUseBiometric() async -> Bool {
        availableResult
    }

    public func authenticate(reason: String) async -> AuthResult {
        authResult
    }
}
