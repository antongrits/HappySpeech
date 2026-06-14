import FirebaseFirestore
import FirebaseMessaging
import Foundation
import OSLog

// MARK: - DeviceRegistrationService
//
// Регистрирует устройство для адресных push-напоминаний: связывает стабильный
// Firebase Installation ID с текущим FCM-токеном и пишет их в Firestore под
// `users/{uid}/devices/{installationId}`.
//
// Зачем отдельный субколлекшн (а не одно поле `users/{uid}.fcmToken`):
//   • у родителя может быть несколько устройств (iPhone + iPad) — каждое со
//     своим токеном; одно поле затирало бы предыдущее;
//   • Cloud Functions (sendDailyReminder / sendWeeklySummary) могут разослать
//     пуш на ВСЕ активные устройства родителя;
//   • при логауте/смене токена адресно удаляется/обновляется конкретный
//     device-документ, а не глобальное поле.
//
// COPPA / Kids Category:
//   • вызывается ТОЛЬКО для аутентифицированного НЕ-анонимного родителя;
//   • Installation ID и FCM-токен — технические идентификаторы без PII, не
//     привязаны к детскому профилю (см. ``InstallationsService``);
//   • детский/анонимный контур НИКОГДА не регистрирует устройство.

public protocol DeviceRegistrationServiceProtocol: AnyObject, Sendable {

    /// Регистрирует текущее устройство (installationId + fcmToken) для адресных
    /// уведомлений родителя. Идемпотентно: повторный вызов обновляет токен и
    /// `updatedAt` того же device-документа.
    ///
    /// - Parameter userId: auth UID родителя (не анонимный).
    /// - Throws: `DeviceRegistrationError`.
    func registerCurrentDevice(userId: String) async throws

    /// Удаляет device-документ текущего устройства при выходе из аккаунта или
    /// отзыве разрешения на уведомления.
    ///
    /// - Parameter userId: auth UID родителя.
    func unregisterCurrentDevice(userId: String) async
}

// MARK: - Errors

public enum DeviceRegistrationError: LocalizedError, Sendable {
    case notAuthenticated
    case tokenUnavailable
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Регистрация устройства доступна только авторизованному родителю."
        case .tokenUnavailable:
            return "Токен push-уведомлений недоступен."
        case .writeFailed(let detail):
            return "Не удалось зарегистрировать устройство: \(detail)"
        }
    }
}

// MARK: - Live Implementation

/// Продакшн-реализация: Firebase Installations (стабильный device-id) +
/// Firebase Messaging (FCM-токен) → Firestore `users/{uid}/devices/{installationId}`.
///
/// `@unchecked Sendable` оправдан: `Firestore`/`Messaging` — thread-safe
/// синглтоны Firebase, `installations` инжектится один раз.
public final class LiveDeviceRegistrationService: DeviceRegistrationServiceProtocol, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "DeviceRegistration")
    private let installations: any InstallationsServiceProtocol
    private let db: Firestore

    /// - Parameter installations: источник стабильного Installation ID.
    public init(installations: any InstallationsServiceProtocol) {
        self.installations = installations
        self.db = Firestore.firestore()
    }

    // MARK: - DeviceRegistrationServiceProtocol

    public func registerCurrentDevice(userId: String) async throws {
        // Защита от случайного вызова в guest/kid-сессии: пустой или анонимный
        // (Firebase anonymous uid) аккаунт устройство не регистрирует.
        guard !userId.isEmpty, !userId.contains("anon") else {
            logger.warning("Device registration skipped — userId empty or anonymous")
            return
        }

        let installationId = try await installations.currentInstallationID()
        guard let fcmToken = Messaging.messaging().fcmToken, !fcmToken.isEmpty else {
            logger.warning("Device registration skipped — FCM token not yet available")
            throw DeviceRegistrationError.tokenUnavailable
        }

        // Технические поля только: токен, platform, версия sdk-стиля устройства,
        // временные метки. Никакого имени/PII.
        let payload: [String: Any] = [
            "installationId": installationId,
            "fcmToken": fcmToken,
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await db
                .collection("users")
                .document(userId)
                .collection("devices")
                .document(installationId)
                .setData(payload, merge: true)
            logger.info("Device registered for parent (installationId present, token redacted)")
        } catch {
            logger.error("Device registration write failed: \(error.localizedDescription)")
            throw DeviceRegistrationError.writeFailed(error.localizedDescription)
        }
    }

    public func unregisterCurrentDevice(userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            let installationId = try await installations.currentInstallationID()
            try await db
                .collection("users")
                .document(userId)
                .collection("devices")
                .document(installationId)
                .delete()
            logger.info("Device unregistered for parent")
        } catch {
            // Best-effort: при оффлайне/уже-удалённом документе молча выходим.
            logger.notice("Device unregister best-effort failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Mock

/// Preview / test реализация — без сети, детерминированные счётчики.
public final class MockDeviceRegistrationService: DeviceRegistrationServiceProtocol, @unchecked Sendable {

    public var shouldThrowError: DeviceRegistrationError?
    public private(set) var didRegister: Bool = false
    public private(set) var didUnregister: Bool = false
    public private(set) var lastRegisteredUserId: String?

    public init() {}

    public func registerCurrentDevice(userId: String) async throws {
        if let error = shouldThrowError { throw error }
        didRegister = true
        lastRegisteredUserId = userId
    }

    public func unregisterCurrentDevice(userId: String) async {
        didUnregister = true
    }
}
