import Foundation
import Network
import OSLog

// MARK: - LiveNetworkMonitor

public final class LiveNetworkMonitor: NetworkMonitorService, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    nonisolated(unsafe) private var path: NWPath?

    public var isConnected: Bool { path?.status == .satisfied }

    public var connectionType: ConnectionType {
        guard let path, path.status == .satisfied else { return .none }
        if path.usesInterfaceType(.wifi)     { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        return .none
    }

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.path = path
            if path.status == .satisfied {
                HSLogger.network.info("Network: connected (\(path.usesInterfaceType(.wifi) ? "wifi" : "cellular"))")
            } else {
                HSLogger.network.warning("Network: disconnected")
            }
        }
        monitor.start(queue: DispatchQueue(label: "ru.happyspeech.network"))
    }
}
