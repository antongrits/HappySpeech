import Foundation
import OSLog

// MARK: - UniversalLinkHandler

/// Parses Apple Universal Links (`https://happyspeech.app/...`) into ``DeepLinkAction``
/// values and routes them through ``DeepLinkRouter``.
///
/// The AASA file must be hosted at:
///   `https://happyspeech.app/.well-known/apple-app-site-association`
///
/// Paths declared in the AASA (see `Resources/apple-app-site-association.json`):
///   - `/invite/<token>`  — family invite
///   - `/share/<type>/<id>` — shared content
///   - `/lesson/<soundId>` — direct lesson entry
///
/// If the incoming URL does not match a known path the handler returns `false`
/// so the caller can fall back to Firebase Dynamic Links while migration is in
/// progress.
@MainActor
public struct UniversalLinkHandler {

    // MARK: - Constants

    private static let expectedHost = "happyspeech.app"
    private static let logger = Logger(
        subsystem: "ru.happyspeech.app",
        category: "UniversalLinkHandler"
    )

    // MARK: - API

    /// Attempt to handle `url` as a Universal Link.
    ///
    /// - Parameter url: The URL received in `onOpenURL` / `application(_:continue:)`.
    /// - Returns: `true` if the URL was recognised and dispatched; `false` otherwise.
    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == "https" || components.scheme == "http",
            components.host == expectedHost
        else {
            logger.debug("UniversalLinkHandler: не наш хост — \(url.absoluteString, privacy: .public)")
            return false
        }

        let path = components.path
        logger.info("UniversalLinkHandler: обрабатываем путь \(path, privacy: .public)")

        if let action = action(for: path, queryItems: components.queryItems ?? []) {
            DeepLinkRouter.shared.dispatch(action)
            return true
        }

        logger.warning("UniversalLinkHandler: неизвестный путь \(path, privacy: .public)")
        return false
    }

    // MARK: - Private

    private static func action(
        for path: String,
        queryItems: [URLQueryItem]
    ) -> DeepLinkAction? {
        let segments = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        switch segments.first {
        case "lesson":
            let soundId = segments.dropFirst().first ?? ""
            let difficulty = queryItems.value(for: "difficulty") ?? "medium"
            return soundId.isEmpty ? nil : .openLesson(soundId: soundId, difficulty: difficulty)

        case "invite":
            // Invite links open the parent home so the coordinator shows the
            // family-invite sheet. The token is forwarded via the progress action
            // (reuse existing action — coordinator checks query params via URL).
            return .showProgress(childName: nil)

        case "share":
            guard segments.count >= 3 else { return nil }
            let shareType = segments[1]
            let shareId   = segments[2]
            switch shareType {
            case "lesson":  return .openLesson(soundId: shareId, difficulty: "medium")
            case "album":   return .openRewardAlbum
            default:        return nil
            }

        default:
            return nil
        }
    }
}

// MARK: - [URLQueryItem] helper

private extension [URLQueryItem] {
    func value(for name: String) -> String? {
        first(where: { $0.name == name })?.value
    }
}
