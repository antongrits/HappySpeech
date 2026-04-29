import FirebasePerformance
import Foundation
import OSLog

// MARK: - Protocol

/// Firebase Performance monitoring service — PARENT OPT-IN ONLY (COPPA).
///
/// Rules:
/// - Default OFF. Enabled only when parent explicitly consents in Settings.
/// - Metrics collected ONLY on parent-facing screens (ParentHome, ChildProgress, Reports, Settings).
/// - NEVER enabled during kid-circuit screens (ChildHome, LessonPlayer, ARZone, etc.).
/// - On anonymous sessions: always disabled, no token storage.
///
/// Usage:
/// ```swift
/// let trace = performanceMonitorService.trace(name: "parent_dashboard_load")
/// trace.start()
/// // ... work ...
/// trace.stop()
/// ```
public protocol PerformanceMonitorService: AnyObject, Sendable {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool)
    func trace(name: String) -> any PerformanceTrace
}

// MARK: - Trace Protocol

/// Wraps a Firebase Performance custom trace.
public protocol PerformanceTrace: Sendable {
    func start()
    func stop()
    func setValue(_ value: Int64, forAttribute attribute: String)
}

// MARK: - Live Implementation

public final class LivePerformanceMonitorService: PerformanceMonitorService, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.happyspeech", category: "Performance")
    private let userDefaultsKey = "happyspeech.performance.enabled"

    public var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: userDefaultsKey) }
    }

    public init() {
        // Mirror stored consent into Firebase SDK on launch.
        let stored = UserDefaults.standard.bool(forKey: userDefaultsKey)
        Performance.sharedInstance().isDataCollectionEnabled = stored
        logger.info("PerformanceMonitor initialised, enabled=\(stored)")
    }

    public func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: userDefaultsKey)
        Performance.sharedInstance().isDataCollectionEnabled = enabled
        logger.info("PerformanceMonitor setEnabled: \(enabled)")
    }

    public func trace(name: String) -> any PerformanceTrace {
        guard isEnabled else {
            return NoOpPerformanceTrace()
        }
        return FirebasePerformanceTrace(name: name)
    }
}

// MARK: - Firebase Trace Wrapper

private final class FirebasePerformanceTrace: PerformanceTrace, @unchecked Sendable {
    private let trace: Trace?

    init(name: String) {
        trace = Performance.startTrace(name: name)
    }

    func start() {
        trace?.start()
    }

    func stop() {
        trace?.stop()
    }

    func setValue(_ value: Int64, forAttribute attribute: String) {
        trace?.setValue(value, forMetric: attribute)
    }
}

// MARK: - No-Op Trace (when disabled)

private final class NoOpPerformanceTrace: PerformanceTrace, @unchecked Sendable {
    func start() {}
    func stop() {}
    func setValue(_ value: Int64, forAttribute attribute: String) {}
}

// MARK: - Mock

public final class MockPerformanceMonitorService: PerformanceMonitorService, @unchecked Sendable {
    public var isEnabled: Bool = false
    public var startedTraces: [String] = []

    public init() {}

    public func setEnabled(_ enabled: Bool) { isEnabled = enabled }

    public func trace(name: String) -> any PerformanceTrace {
        startedTraces.append(name)
        return MockPerformanceTrace()
    }
}

private final class MockPerformanceTrace: PerformanceTrace, @unchecked Sendable {
    func start() {}
    func stop() {}
    func setValue(_ value: Int64, forAttribute attribute: String) {}
}
