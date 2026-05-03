import FirebaseMessaging
import OSLog
import UIKit
import UserNotifications

// MARK: - FCMNotificationHandler

/// Singleton UNUserNotificationCenter + Messaging delegate.
///
/// Responsibilities:
/// - Foreground notification display (banner + sound when app is active)
/// - Background / tap-action deep link routing to ProgressDashboard
/// - FCM token refresh → forwarded to AppContainer.fcmService
///
/// COPPA / Kids Category:
/// - Notifications are only sent to authenticated parents with opt-in.
/// - FCM token stored only via LiveFCMService (guarded by parent role check).
/// - Kid circuit screens NEVER request or display push notifications.
///
/// ## Activation
/// Call `FCMNotificationHandler.shared.attach(coordinator:fcmService:)`
/// once from `HappySpeechApp.bootstrapApp()` after Realm is open.
@MainActor
final class FCMNotificationHandler: NSObject {

    // MARK: - Singleton

    static let shared = FCMNotificationHandler()

    // MARK: - Private

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "FCM")
    private weak var coordinator: AppCoordinator?
    private var fcmService: (any FCMService)?

    private override init() {
        super.init()
    }

    // MARK: - Attach

    /// Wires the handler into UNUserNotificationCenter and FirebaseMessaging.
    /// Safe to call multiple times — subsequent calls are no-ops.
    func attach(coordinator: AppCoordinator, fcmService: any FCMService) {
        guard self.coordinator == nil else { return }
        self.coordinator = coordinator
        self.fcmService = fcmService

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        logger.info("FCMNotificationHandler attached")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension FCMNotificationHandler: UNUserNotificationCenterDelegate {

    /// Shows notification banner even when the app is in foreground.
    /// Only banner + sound — no badge increment to avoid confusion for child users.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handles notification tap — deep links to ProgressDashboard.
    /// Extracts `type` and `childId` from userInfo without logging PII.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Extract primitive values before crossing actor boundary to avoid Sendable warnings.
        let notificationType = response.notification.request.content.userInfo["type"] as? String ?? "unknown"
        let childId = response.notification.request.content.userInfo["childId"] as? String ?? ""

        Task { @MainActor in
            switch notificationType {
            case "weekly_summary", "daily_reminder":
                // Навигация на дашборд прогресса родительского контура.
                if !childId.isEmpty {
                    self.coordinator?.navigate(to: .progressDashboard(childId: childId))
                } else {
                    // Fallback: родительский home
                    self.coordinator?.navigate(to: .parentHome)
                }
                self.logger.info("FCM tap → navigate for type=\(notificationType, privacy: .public)")
            default:
                self.logger.info("FCM tap — unhandled type=\(notificationType, privacy: .public)")
            }
        }
        completionHandler()
    }
}

// MARK: - MessagingDelegate

extension FCMNotificationHandler: MessagingDelegate {

    /// Called when FCM token is refreshed.
    /// Token is NOT persisted here — persisting is done explicitly by
    /// `LiveFCMService.syncTokenToFirestore()` only after parent opt-in.
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Log only the fact that token refreshed — never log the token value.
        Task { @MainActor in
            self.logger.info("FCM registration token refreshed (parent sync pending opt-in)")
        }
    }
}
