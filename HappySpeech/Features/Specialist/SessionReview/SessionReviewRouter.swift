import Foundation

// MARK: - SessionReviewRouter

@MainActor
final class SessionReviewRouter {
    var onDone: ((Date) -> Void)?
    var onCancel: (() -> Void)?
}
