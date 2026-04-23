import SwiftUI

// MARK: - SpotlightKey

/// Preference key used by views to publish their global frame under a string
/// key, so the `GuidedTourCoordinator` can draw a spotlight hole around the
/// right rect without holding direct references.
struct SpotlightKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - View helpers

extension View {

    /// Registers the current view under `key` for the guided tour overlay.
    /// The view's global frame is published through `SpotlightKey` and read by
    /// `GuidedTourContainer` via `onPreferenceChange`.
    func spotlightAnchor(key: String) -> some View {
        overlay(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: SpotlightKey.self,
                        value: [key: geo.frame(in: .global)]
                    )
            }
        )
    }
}
