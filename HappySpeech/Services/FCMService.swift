import FirebaseFirestore
import FirebaseMessaging
import Foundation
import OSLog
import UserNotifications

// MARK: - Protocol

/// Firebase Cloud Messaging сервис — только для родительского контура (COPPA).
///
/// `FCMService` управляет регистрацией push-уведомлений через FCM и синхронизацией
/// токена в Firestore. FCM-токен сохраняется **только** при выполнении трёх условий:
///
/// 1. Пользователь аутентифицирован (не anonymous)
/// 2. Роль пользователя — parent
/// 3. Уведомления явно включены в Settings (`notificationsEnabled = true`)
///
/// > Important: Детские профили и анонимные сессии **никогда** не получают
/// > FCM-токен — это требование COPPA и Kids Category.
///
/// ## Пример
/// ```swift
/// let fcm: FCMService = LiveFCMService()
/// let granted = await fcm.requestPermission()
/// if granted {
///     await fcm.registerForRemoteNotifications()
///     try await fcm.syncTokenToFirestore(userId: currentUserId)
/// }
///
/// // При выходе
/// try await fcm.unregisterToken(userId: currentUserId)
/// ```
///
/// ## See Also
/// - ``NotificationService``
/// - ``RemoteConfigService``
public protocol FCMService: AnyObject, Sendable {
    /// Запрашивает разрешение UNUserNotificationCenter.
    /// Возвращает true если разрешение выдано.
    func requestPermission() async -> Bool

    /// Регистрирует устройство для remote notifications (UIApplication.registerForRemoteNotifications).
    /// Вызывать после requestPermission() == true.
    func registerForRemoteNotifications() async

    /// Синхронизирует FCM-токен в Firestore /users/{userId}.fcmToken.
    /// Вызывать ТОЛЬКО для parent после явного opt-in.
    func syncTokenToFirestore(userId: String) async throws

    /// Удаляет FCM-токен из Firestore при выходе / отзыве разрешения.
    func unregisterToken(userId: String) async throws
}

// MARK: - Live Implementation

public final class LiveFCMService: NSObject, FCMService, MessagingDelegate, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "FCM")
    private let db = Firestore.firestore()

    public override init() {
        super.init()
        Messaging.messaging().delegate = self
    }

    // MARK: - FCMService

    public func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("FCM permission granted: \(granted)")
            return granted
        } catch {
            logger.error("FCM permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    public func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        logger.info("Registered for remote notifications")
    }

    public func syncTokenToFirestore(userId: String) async throws {
        guard let token = Messaging.messaging().fcmToken else {
            logger.warning("FCM token not yet available — skipping sync for user \(userId, privacy: .public)")
            return
        }
        try await db.collection("users").document(userId).setData(
            ["fcmToken": token, "fcmTokenUpdatedAt": FieldValue.serverTimestamp()],
            merge: true
        )
        logger.info("FCM token synced to Firestore for parent")
    }

    public func unregisterToken(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "fcmToken": FieldValue.delete(),
            "fcmTokenUpdatedAt": FieldValue.delete()
        ])
        logger.info("FCM token removed from Firestore")
    }

    // MARK: - MessagingDelegate

    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        logger.info("FCM registration token refreshed")
    }
}

// MARK: - Mock

public final class MockFCMService: FCMService, @unchecked Sendable {
    public var permissionGranted: Bool = true
    public var didSyncToken: Bool = false
    public var didUnregister: Bool = false

    public init() {}

    public func requestPermission() async -> Bool { permissionGranted }
    public func registerForRemoteNotifications() async {}

    public func syncTokenToFirestore(userId: String) async throws {
        didSyncToken = true
    }

    public func unregisterToken(userId: String) async throws {
        didUnregister = true
    }
}
