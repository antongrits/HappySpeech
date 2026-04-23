import Foundation

// MARK: - ReportsRouter

@MainActor
final class ReportsRouter {
    var onShareURL: ((URL) -> Void)?
    var onClose: (() -> Void)?
}
