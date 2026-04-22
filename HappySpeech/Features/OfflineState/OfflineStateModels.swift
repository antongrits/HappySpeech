import Foundation

// MARK: - OfflineState VIP Models

enum OfflineStateModels {

    // MARK: - Fetch
    enum Fetch {
        struct Request {}
        struct Response {
            let activeChildId: String?
            let pendingCount: Int
        }
        struct ViewModel {
            let activeChildId: String?
            let pendingCount: Int
            let pendingBadgeText: String
            let hasActiveChild: Bool
        }
    }

    // MARK: - Update
    enum Update {
        struct Request {
            enum Kind: Sendable {
                case retryConnection
                case continueOffline
            }
            let kind: Kind
        }
        struct Response {
            let kind: Request.Kind
            let isConnected: Bool
        }
        struct ViewModel {
            let kind: Request.Kind
            let isRetrying: Bool
            let isConnected: Bool
        }
    }
}
