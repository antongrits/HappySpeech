import Foundation
import UIKit

// MARK: - BreathingHapticWorkerProtocol

protocol BreathingHapticWorkerProtocol: AnyObject, Sendable {
    func petalBlown()
    func blowStart()
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
        haptic.impact(.light)
    }

    public func blowStart() {
        haptic.impact(.soft)
    }

    public func success() {
        haptic.notification(.success)
    }

    public func failure() {
        haptic.notification(.warning)
    }
}

// MARK: - Mock (tests)

public final class MockBreathingHapticWorker: BreathingHapticWorkerProtocol, @unchecked Sendable {
    public private(set) var petalCount: Int = 0
    public private(set) var blowStartCount: Int = 0
    public private(set) var successCount: Int = 0
    public private(set) var failureCount: Int = 0

    public init() {}

    public func petalBlown() { petalCount += 1 }
    public func blowStart()  { blowStartCount += 1 }
    public func success()    { successCount += 1 }
    public func failure()    { failureCount += 1 }
}
