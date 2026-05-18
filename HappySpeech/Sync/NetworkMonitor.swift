import Foundation
import Network
import OSLog

// MARK: - LiveNetworkMonitor

public final class LiveNetworkMonitor: NetworkMonitorService, @unchecked Sendable {
    private let monitor = NWPathMonitor()

    /// `path` пишется из фоновой очереди `NWPathMonitor` и читается из
    /// произвольных потоков (`isConnected`/`connectionType`). Доступ
    /// синхронизируется `lock` — иначе это гонка данных (UB).
    private let lock = NSLock()
    private var _path: NWPath?

    private var path: NWPath? {
        lock.lock(); defer { lock.unlock() }
        return _path
    }

    public var isConnected: Bool { path?.status == .satisfied }

    public var connectionType: ConnectionType {
        guard let path, path.status == .satisfied else { return .none }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        return .none
    }

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self._path = path
            self.lock.unlock()
            if path.status == .satisfied {
                HSLogger.network.info("Network: connected (\(path.usesInterfaceType(.wifi) ? "wifi" : "cellular"))")
            } else {
                HSLogger.network.warning("Network: disconnected")
            }
        }
        monitor.start(queue: DispatchQueue(label: "ru.happyspeech.network"))
    }
}
