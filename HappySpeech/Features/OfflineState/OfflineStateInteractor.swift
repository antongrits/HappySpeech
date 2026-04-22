import Foundation

// MARK: - OfflineStateBusinessLogic

@MainActor
protocol OfflineStateBusinessLogic: AnyObject {
    func fetch(_ request: OfflineStateModels.Fetch.Request) async
    func update(_ request: OfflineStateModels.Update.Request) async
}

// MARK: - OfflineStateInteractor

@MainActor
final class OfflineStateInteractor: OfflineStateBusinessLogic {

    var presenter: (any OfflineStatePresentationLogic)?

    private let childRepository: any ChildRepository
    private let syncService: any SyncService
    private let networkMonitor: any NetworkMonitorService
    private let preferredChildIdProvider: @Sendable () -> String?

    init(
        childRepository: any ChildRepository,
        syncService: any SyncService,
        networkMonitor: any NetworkMonitorService,
        preferredChildIdProvider: @escaping @Sendable () -> String? = { ActiveChildStore.shared.id }
    ) {
        self.childRepository = childRepository
        self.syncService = syncService
        self.networkMonitor = networkMonitor
        self.preferredChildIdProvider = preferredChildIdProvider
    }

    // MARK: - fetch

    func fetch(_ request: OfflineStateModels.Fetch.Request) async {
        let preferredId = preferredChildIdProvider()
        let activeChildId = await resolveActiveChildId(preferred: preferredId)
        let pending = await syncService.pendingCount()
        let response = OfflineStateModels.Fetch.Response(
            activeChildId: activeChildId,
            pendingCount: pending
        )
        presenter?.presentFetch(response)
    }

    // MARK: - update

    func update(_ request: OfflineStateModels.Update.Request) async {
        let isConnected = networkMonitor.isConnected
        let response = OfflineStateModels.Update.Response(kind: request.kind, isConnected: isConnected)
        presenter?.presentUpdate(response)
    }

    // MARK: - Helpers

    private func resolveActiveChildId(preferred: String?) async -> String? {
        if let preferred, !preferred.isEmpty {
            // Verify the preferred id still exists in local storage.
            if let _ = try? await childRepository.fetch(id: preferred) {
                return preferred
            }
        }
        if let first = try? await childRepository.fetchAll().first {
            return first.id
        }
        return nil
    }
}

// MARK: - ActiveChildStore

/// Lightweight, thread-safe store of the currently active child id.
/// Written by ChildProfile selection flow, read by coordinators / interactors.
/// Persisted in UserDefaults so the app remembers the selection across launches.
public final class ActiveChildStore: @unchecked Sendable {
    public static let shared = ActiveChildStore()

    private static let key = "hs.active.child.id"
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "ru.happyspeech.activechild", attributes: .concurrent)

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var id: String? {
        queue.sync { defaults.string(forKey: Self.key) }
    }

    public func set(_ id: String?) {
        queue.async(flags: .barrier) { [defaults] in
            if let id, !id.isEmpty {
                defaults.set(id, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}
