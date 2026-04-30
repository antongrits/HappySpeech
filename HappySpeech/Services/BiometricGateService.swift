import Foundation
import LocalAuthentication
import OSLog

// MARK: - LiveBiometricGateService
//
// Реальная реализация BiometricGateService через LAContext / LocalAuthentication.
// Протокол BiometricGateService и AuthResult определены в Core/Security/BiometricGate.swift.
//
// actor — гарантирует Swift 6 strict concurrency: один LAContext за раз.

public actor LiveBiometricGateService: BiometricGateService {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "BiometricGate")

    public init() {}

    // MARK: - BiometricGateService

    public func canUseBiometric() async -> Bool {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        if let err = error {
            logger.info("BiometricGate: canUseBiometric=false — \(err.localizedDescription)")
        }
        return available && error == nil
    }

    public func authenticate(reason: String) async -> AuthResult {
        let context = LAContext()
        // Скрываем кнопку «Введите пароль» — используем собственный резервный механизм (math gate).
        context.localizedFallbackTitle = ""
        context.localizedCancelTitle = String(localized: "parental_gate.cancel")

        var policyError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &policyError
        ) else {
            logger.info("BiometricGate: policy unavailable — falling back to math gate")
            return .fallback
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success {
                logger.info("BiometricGate: authentication succeeded")
                return .success
            } else {
                // evaluatePolicy возвращает false только теоретически (обычно бросает ошибку)
                logger.warning("BiometricGate: evaluatePolicy returned false without error")
                return .denied(reason: String(localized: "parental_gate.biometric.denied_generic"))
            }
        } catch let laError as LAError {
            return handleLAError(laError)
        } catch {
            logger.error("BiometricGate: unexpected error — \(error.localizedDescription)")
            return .denied(reason: error.localizedDescription)
        }
    }

    // MARK: - Private

    private func handleLAError(_ laError: LAError) -> AuthResult {
        switch laError.code {
        case .userCancel:
            logger.info("BiometricGate: user cancelled")
            return .cancelled
        case .systemCancel:
            logger.info("BiometricGate: system cancelled")
            return .cancelled
        case .appCancel:
            logger.info("BiometricGate: app cancelled")
            return .cancelled
        case .biometryNotAvailable:
            logger.info("BiometricGate: biometry not available — fallback")
            return .fallback
        case .biometryNotEnrolled:
            logger.info("BiometricGate: biometry not enrolled — fallback")
            return .fallback
        case .biometryLockout:
            logger.warning("BiometricGate: biometry locked out — fallback")
            return .fallback
        case .userFallback:
            // Пользователь нажал кнопку fallback (мы её скрываем — на всякий случай)
            logger.info("BiometricGate: user requested fallback")
            return .fallback
        default:
            logger.warning("BiometricGate: LAError \(laError.code.rawValue) — \(laError.localizedDescription)")
            return .denied(reason: laError.localizedDescription)
        }
    }
}
