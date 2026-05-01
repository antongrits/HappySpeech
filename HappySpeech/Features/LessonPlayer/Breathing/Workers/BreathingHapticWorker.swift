import Foundation
import UIKit

// MARK: - BreathingHapticWorkerProtocol

protocol BreathingHapticWorkerProtocol: AnyObject, Sendable {
    func petalBlown()
    func blowStart()
    func inhale()
    func exhale()
    func success()
    func failure()
}

// MARK: - BreathingHapticWorker

public final class BreathingHapticWorker: BreathingHapticWorkerProtocol, @unchecked Sendable {

    private let haptic: HapticService

    public init(haptic: HapticService) {
        self.haptic = haptic
    }

    public func petalBlown() {
        Task { await haptic.play(pattern: .buttonTap) }
    }

    public func blowStart() {
        Task { await haptic.play(pattern: .breathingExhale) }
    }

    /// Вдох — нарастающий 2-секундный паттерн (синхронизировать с UI-анимацией).
    public func inhale() {
        Task { await haptic.play(pattern: .breathingInhale) }
    }

    /// Выдох — спадающий 2-секундный паттерн (синхронизировать с UI-анимацией).
    public func exhale() {
        Task { await haptic.play(pattern: .breathingExhale) }
    }

    public func success() {
        Task { await haptic.play(pattern: .celebration) }
    }

    public func failure() {
        Task { await haptic.play(pattern: .wrong) }
    }
}

// MARK: - Mock (tests)

public final class MockBreathingHapticWorker: BreathingHapticWorkerProtocol, @unchecked Sendable {
    public private(set) var petalCount: Int = 0
    public private(set) var blowStartCount: Int = 0
    public private(set) var inhaleCount: Int = 0
    public private(set) var exhaleCount: Int = 0
    public private(set) var successCount: Int = 0
    public private(set) var failureCount: Int = 0

    public init() {}

    public func petalBlown() { petalCount += 1 }
    public func blowStart() { blowStartCount += 1 }
    public func inhale() { inhaleCount += 1 }
    public func exhale() { exhaleCount += 1 }
    public func success() { successCount += 1 }
    public func failure() { failureCount += 1 }
}
