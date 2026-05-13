import Foundation
@testable import HappySpeech

// MARK: - MockChildRepository (test-target copy with spy capabilities)
//
// Production code already has MockChildRepository in ChildRepository.swift.
// This test-only variant adds spy properties (callCount, lastSaved, etc.)
// so test assertions can inspect call sites without subclassing.

public final class SpyChildRepository: ChildRepository, @unchecked Sendable {
    public var children: [ChildProfileDTO]
    public var shouldFail: Bool = false

    // Spy counters
    public private(set) var fetchAllCallCount: Int = 0
    public private(set) var saveCallCount: Int = 0
    public private(set) var deleteCallCount: Int = 0
    public private(set) var lastSaved: ChildProfileDTO?
    public private(set) var lastDeletedId: String?

    public init(children: [ChildProfileDTO] = [TestDataBuilder.childProfile()]) {
        self.children = children
    }

    public func fetchAll() async throws -> [ChildProfileDTO] {
        fetchAllCallCount += 1
        if shouldFail { throw AppError.realmReadFailed("SpyChildRepository forced failure") }
        return children
    }

    public func fetch(id: String) async throws -> ChildProfileDTO {
        guard let found = children.first(where: { $0.id == id }) else {
            throw AppError.entityNotFound(id)
        }
        return found
    }

    public func save(_ profile: ChildProfileDTO) async throws {
        saveCallCount += 1
        lastSaved = profile
        if shouldFail { throw AppError.realmWriteFailed("SpyChildRepository forced failure") }
        children.removeAll { $0.id == profile.id }
        children.append(profile)
    }

    public func delete(id: String) async throws {
        deleteCallCount += 1
        lastDeletedId = id
        if shouldFail { throw AppError.realmWriteFailed("SpyChildRepository forced failure") }
        children.removeAll { $0.id == id }
    }

    public func updateProgress(childId: String, sound: String, rate: Double) async throws {}
    public func updateStreak(childId: String, streak: Int) async throws {}
}

// MARK: - SpySessionRepository

public final class SpySessionRepository: SessionRepository, @unchecked Sendable {
    public var sessions: [SessionDTO]
    public var shouldFail: Bool = false

    public private(set) var saveCallCount: Int = 0
    public private(set) var lastSaved: SessionDTO?

    public init(sessions: [SessionDTO] = [TestDataBuilder.session()]) {
        self.sessions = sessions
    }

    public func fetchAll(childId: String) async throws -> [SessionDTO] {
        if shouldFail { throw AppError.realmReadFailed("SpySessionRepository forced failure") }
        return sessions.filter { $0.childId == childId }
    }

    public func fetch(id: String) async throws -> SessionDTO {
        guard let found = sessions.first(where: { $0.id == id }) else {
            throw AppError.entityNotFound(id)
        }
        return found
    }

    public func save(_ session: SessionDTO) async throws {
        saveCallCount += 1
        lastSaved = session
        if shouldFail { throw AppError.realmWriteFailed("SpySessionRepository forced failure") }
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
    }

    public func fetchRecent(childId: String, limit: Int) async throws -> [SessionDTO] {
        if shouldFail { throw AppError.realmReadFailed("SpySessionRepository forced failure") }
        return Array(sessions.filter { $0.childId == childId }.suffix(limit))
    }
}

// MARK: - SpyAuthService
//
// Wraps the existing MockAuthService with additional spy counters.
// Use this in tests where you need to assert method call counts.

public final class SpyAuthService: AuthService, @unchecked Sendable {

    public var shouldFail: Bool = false
    public var stubbedUser: AuthUser? = TestDataBuilder.authUser()
    public var currentUser: AuthUser? { stubbedUser }

    public private(set) var signInCallCount: Int = 0
    public private(set) var signOutCallCount: Int = 0
    public private(set) var signUpCallCount: Int = 0
    public private(set) var lastSignInEmail: String?

    nonisolated(unsafe) private var listeners: [UUID: @Sendable (AuthUser?) -> Void] = [:]
    private let lock = NSLock()

    public init() {}

    public func signIn(email: String, password: String) async throws -> AuthUser {
        signInCallCount += 1
        lastSignInEmail = email
        if shouldFail { throw AppError.authInvalidCredential }
        let user = stubbedUser ?? TestDataBuilder.authUser(email: email)
        notifyListeners(user)
        return user
    }

    public func signUp(email: String, password: String, displayName: String) async throws -> AuthUser {
        signUpCallCount += 1
        if shouldFail { throw AppError.authEmailAlreadyInUse }
        let user = TestDataBuilder.authUser(uid: "spy-signup", email: email, displayName: displayName, isEmailVerified: false)
        notifyListeners(user)
        return user
    }

    public func sendPasswordReset(email: String) async throws {
        if shouldFail { throw AppError.authUserNotFound }
    }

    public func sendEmailVerification() async throws {
        if shouldFail { throw AppError.authSignInFailed("spy verification fail") }
    }

    public func reloadCurrentUser() async throws -> AuthUser? { stubbedUser }

    public func signInWithGoogle() async throws -> AuthUser {
        if shouldFail { throw AppError.authGoogleCancelled }
        return stubbedUser ?? TestDataBuilder.authUser()
    }

    public func signInAnonymously() async throws -> AuthUser {
        if shouldFail { throw AppError.authSignInFailed("spy anon fail") }
        return TestDataBuilder.authUser(uid: "spy-anon", email: nil, displayName: nil, isAnonymous: true, isEmailVerified: false)
    }

    public func linkAnonymousWithEmail(email: String, password: String) async throws -> AuthUser {
        if shouldFail { throw AppError.authEmailAlreadyInUse }
        return TestDataBuilder.authUser(email: email)
    }

    public func signOut() throws {
        signOutCallCount += 1
        if shouldFail { throw AppError.authSignOutFailed }
        stubbedUser = nil
        notifyListeners(nil)
    }

    public func deleteAccount() async throws {
        if shouldFail { throw AppError.authSignInFailed("spy delete fail") }
        stubbedUser = nil
        notifyListeners(nil)
    }

    @discardableResult
    public func addAuthStateListener(_ listener: @escaping @Sendable (AuthUser?) -> Void) -> Any {
        let id = UUID()
        lock.lock()
        listeners[id] = listener
        let snapshot = stubbedUser
        lock.unlock()
        listener(snapshot)
        return id
    }

    public func removeAuthStateListener(_ handle: Any) {
        guard let id = handle as? UUID else { return }
        lock.lock()
        listeners.removeValue(forKey: id)
        lock.unlock()
    }

    private func notifyListeners(_ user: AuthUser?) {
        lock.lock()
        let callbacks = Array(listeners.values)
        lock.unlock()
        for cb in callbacks { cb(user) }
    }
}

// MARK: - SpySyncService

public actor SpySyncService: SyncService {
    private var _pendingCount: Int = 0
    private var _isSyncing: Bool = false
    public private(set) var enqueueCallCount: Int = 0
    public private(set) var drainCallCount: Int = 0
    public var shouldFail: Bool = false

    public init() {}

    public func pendingCount() async -> Int { _pendingCount }
    public func isSyncing() async -> Bool { _isSyncing }

    public func drainQueue() async throws {
        drainCallCount += 1
        if shouldFail { throw AppError.syncUploadFailed("SpySyncService forced failure") }
        _pendingCount = 0
    }

    public func enqueue(operation: SyncOperation) async throws {
        enqueueCallCount += 1
        if shouldFail { throw AppError.syncUploadFailed("SpySyncService forced failure") }
        _pendingCount += 1
    }
}

// MARK: - SpyAnalyticsService

public final class SpyAnalyticsService: AnalyticsService, @unchecked Sendable {
    public private(set) var trackedEvents: [AnalyticsEvent] = []
    public private(set) var trackCallCount: Int = 0

    public func track(event: AnalyticsEvent) {
        trackCallCount += 1
        trackedEvents.append(event)
    }

    public func lastEvent() -> AnalyticsEvent? { trackedEvents.last }
}

// MARK: - SpyAdaptivePlannerService

public final class SpyAdaptivePlannerService: AdaptivePlannerService, @unchecked Sendable {
    public var stubbedRoute: AdaptiveRoute
    public var stubbedFatigue: FatigueLevel = .fresh
    public var shouldFail: Bool = false
    public var forcedBreak: Bool = false

    public private(set) var buildRouteCallCount: Int = 0
    public private(set) var recordCompletionCallCount: Int = 0
    public private(set) var recordedQualities: [(childId: String, soundTarget: String, quality: SM2Quality)] = []

    public init(route: AdaptiveRoute? = nil, fatigue: FatigueLevel = .fresh) {
        let defaultRoute = AdaptiveRoute(
            steps: [
                RouteStepItem(
                    templateType: .listenAndChoose,
                    targetSound: "Р",
                    stage: .wordInit,
                    difficulty: 2,
                    wordCount: 10,
                    durationTargetSec: 180
                ),
                RouteStepItem(
                    templateType: .repeatAfterModel,
                    targetSound: "Р",
                    stage: .wordInit,
                    difficulty: 2,
                    wordCount: 8,
                    durationTargetSec: 240
                )
            ],
            maxDurationSec: 900,
            fatigueLevel: fatigue
        )
        self.stubbedRoute = route ?? defaultRoute
        self.stubbedFatigue = fatigue
    }

    public func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
        buildRouteCallCount += 1
        if shouldFail { throw AppError.realmReadFailed("SpyAdaptivePlannerService forced failure") }
        return stubbedRoute
    }

    public func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {
        recordCompletionCallCount += 1
    }

    public func recordSessionResult(
        childId: String,
        soundTarget: String,
        qualityScore: SM2Quality
    ) async throws {
        recordedQualities.append((childId: childId, soundTarget: soundTarget, quality: qualityScore))
    }

    public func shouldTakeBreak(
        consecutiveWrong: Int,
        sessionDurationSec: Int,
        childAge: Int
    ) -> Bool {
        if forcedBreak { return true }
        return consecutiveWrong >= 3
    }
}
