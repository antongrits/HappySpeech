import Foundation
import OSLog

// MARK: - LiveAnalyticsService

/// No-op live analytics service. All events logged locally via OSLog per ADR-004.
public final class LiveAnalyticsService: AnalyticsService, @unchecked Sendable {

    public init() {}

    public func track(event: AnalyticsEvent) {
        HSLogger.analytics.info("[\(event.name)] \(event.parameters)")
    }
}

// MARK: - AnalyticsEvent Names

public extension AnalyticsEvent {
    static func sessionStarted(childId: String, sound: String, template: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "session_started", parameters: [
            "child_id": childId,
            "sound": sound,
            "template": template
        ])
    }

    static func sessionCompleted(childId: String, successRate: Double, durationSec: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "session_completed", parameters: [
            "child_id": childId,
            "success_rate": String(format: "%.2f", successRate),
            "duration_sec": "\(durationSec)"
        ])
    }

    static func lessonAttempted(word: String, isCorrect: Bool, score: Double) -> AnalyticsEvent {
        AnalyticsEvent(name: "lesson_attempted", parameters: [
            "word": word,
            "is_correct": isCorrect ? "1" : "0",
            "score": String(format: "%.2f", score)
        ])
    }

    static func rewardEarned(type: String, rewardId: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "reward_earned", parameters: [
            "type": type,
            "reward_id": rewardId
        ])
    }

    static func demoModeEntered() -> AnalyticsEvent {
        AnalyticsEvent(name: "demo_mode_entered")
    }

    static func onboardingCompleted(role: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "onboarding_completed", parameters: ["role": role])
    }
}
