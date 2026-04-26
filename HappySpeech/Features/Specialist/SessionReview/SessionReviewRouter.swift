import Foundation
import OSLog
import SwiftUI

// MARK: - SessionReviewRoutingLogic

@MainActor
protocol SessionReviewRoutingLogic: AnyObject {
    /// Возвращает специалиста на предыдущий экран (список занятий).
    func routeBack()
    /// Открывает share-sheet с PDF-документом отчёта.
    func presentShare(url: URL)
}

// MARK: - SessionReviewRouter

/// Навигация для экрана детального обзора сессии. Может работать в двух
/// режимах:
///   • per-attempt флоу (старый) — управляется через колбэки
///     `onDone` / `onCancel`,
///   • B1-флоу — управляется через `coordinator` и локальные `dismiss`-action'ы
///     внутри `NavigationStack` родителя.
///
/// Share-sheet — состояние, которое держит сам экран (через `@State
/// shareItem: ShareItem?`); router выставляет `pendingShareURL`, view
/// биндится через onChange.
@MainActor
final class SessionReviewRouter: SessionReviewRoutingLogic {

    weak var coordinator: AppCoordinator?

    /// Закрытие экрана. View подписывается через колбэк, чтобы можно было
    /// корректно работать и через NavigationStack (`dismiss()`), и через
    /// AppCoordinator (`pop()`).
    var onBack: (() -> Void)?

    /// View подписывается, чтобы принять URL и показать ShareSheet.
    var onShare: ((URL) -> Void)?

    // Existing per-attempt callbacks (kept for backward compatibility).
    var onDone: ((Date) -> Void)?
    var onCancel: (() -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SessionReview.Router")

    // MARK: - Routing

    func routeBack() {
        if let onBack {
            onBack()
        } else if let coordinator {
            coordinator.pop()
        } else {
            logger.warning("routeBack: no callback or coordinator wired")
        }
    }

    func presentShare(url: URL) {
        if let onShare {
            onShare(url)
        } else {
            logger.warning("presentShare: no callback wired, url=\(url.lastPathComponent, privacy: .public)")
        }
    }
}
