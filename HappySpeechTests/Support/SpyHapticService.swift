import UIKit
@testable import HappySpeech

// MARK: - SpyHapticService
//
// Тестовый дубль HapticService со счётчиками вызовов — для проверки,
// что Interactor проигрывает тактильную обратную связь в нужных местах.
// Production-вариант `MockHapticService` намеренно не считает вызовы;
// этот spy дополняет его счётчиками без сабклассинга.

public final class SpyHapticService: HapticService, @unchecked Sendable {

    public private(set) var playedPatterns: [HapticPattern] = []
    public private(set) var selectionCount = 0
    public private(set) var notificationCount = 0
    public private(set) var impactCount = 0
    public private(set) var stopCount = 0
    public private(set) var intensityScale: Float = 1.0

    public var isAvailable: Bool { true }

    public init() {}

    public func play(pattern: HapticPattern) async {
        playedPatterns.append(pattern)
    }

    public func setIntensityScale(_ scale: Float) {
        intensityScale = max(0, min(1, scale))
    }

    public func stop() async {
        stopCount += 1
    }

    public func selection() {
        selectionCount += 1
    }

    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationCount += 1
    }

    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        impactCount += 1
    }
}
