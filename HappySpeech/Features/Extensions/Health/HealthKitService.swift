import Foundation
import HealthKit
import OSLog

// MARK: - MindfulSessionType

/// Тип mindful-сессии, записываемой в Apple Health.
public enum MindfulSessionType: String, Sendable, CaseIterable {
    case breathing
    case stutteringPractice
    case meditation
}

// MARK: - HealthKitError

public enum HealthKitError: LocalizedError, Sendable {
    case notAvailable
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return String(localized: "healthkit.error.not_available")
        case .notAuthorized:
            return String(localized: "healthkit.error.not_authorized")
        }
    }
}

// MARK: - HealthKitServiceProtocol

/// Протокол сервиса HealthKit.
/// COPPA-safe: только parent opt-in. Kid sessions НЕ логируются.
public protocol HealthKitServiceProtocol: Sendable {
    func isAvailable() -> Bool
    func isAuthorized() async -> Bool
    func requestAuthorization() async throws
    func logMindfulSession(start: Date, end: Date, sessionType: MindfulSessionType) async throws
}

// MARK: - LiveHealthKitService

/// Production-реализация. Пишет mindful sessions (write-only) в HealthKit.
/// Actor обеспечивает Swift 6 strict concurrency.
public actor LiveHealthKitService: HealthKitServiceProtocol {

    private let store = HKHealthStore()
    private let logger = Logger(subsystem: "ru.happyspeech", category: "HealthKitService")

    public init() {}

    public nonisolated func isAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func isAuthorized() async -> Bool {
        guard isAvailable() else { return false }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return false
        }
        return store.authorizationStatus(for: mindfulType) == .sharingAuthorized
    }

    public func requestAuthorization() async throws {
        guard isAvailable() else { throw HealthKitError.notAvailable }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.notAvailable
        }
        try await store.requestAuthorization(toShare: [mindfulType], read: [])
        logger.info("HealthKit authorization requested for mindfulSession")
    }

    public func logMindfulSession(start: Date, end: Date, sessionType: MindfulSessionType) async throws {
        guard isAvailable() else { throw HealthKitError.notAvailable }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.notAvailable
        }
        guard await isAuthorized() else { throw HealthKitError.notAuthorized }

        // Metadata: только тип сессии. НЕТ детских данных, НЕТ имени ребёнка (COPPA).
        let metadata: [String: Any] = [
            "HappySpeechSessionType": sessionType.rawValue
        ]
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end,
            metadata: metadata
        )
        try await store.save(sample)
        logger.info("Logged mindful session: \(sessionType.rawValue, privacy: .public), duration: \(end.timeIntervalSince(start), privacy: .private)s")
    }
}

// MARK: - MockHealthKitService

/// Mock-реализация для preview и unit-тестов.
public actor MockHealthKitService: HealthKitServiceProtocol {

    public var simulateAuthorized: Bool = true
    public private(set) var savedSessions: [(MindfulSessionType, Date, Date)] = []
    public private(set) var authorizationRequestCount: Int = 0

    public init() {}

    public nonisolated func isAvailable() -> Bool { true }

    public func isAuthorized() async -> Bool { simulateAuthorized }

    public func requestAuthorization() async throws {
        authorizationRequestCount += 1
        simulateAuthorized = true
    }

    public func logMindfulSession(start: Date, end: Date, sessionType: MindfulSessionType) async throws {
        guard simulateAuthorized else { throw HealthKitError.notAuthorized }
        savedSessions.append((sessionType, start, end))
    }

    /// Вспомогательный метод для тестов — сбрасывает состояние.
    public func reset() {
        simulateAuthorized = true
        savedSessions = []
        authorizationRequestCount = 0
    }
}
