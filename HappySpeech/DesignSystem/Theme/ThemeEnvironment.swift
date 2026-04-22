import SwiftUI

// MARK: - AppTheme

/// The user-selectable theme preference, persisted to UserDefaults.
public enum AppTheme: String, CaseIterable, Sendable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    public var displayName: String {
        switch self {
        case .system: return "Как в системе"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - ThemeManager

/// Observable theme manager. Injected as @Environment via AppContainer.
@Observable
public final class ThemeManager {
    private static let key = "hs.theme.preference"

    public var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: ThemeManager.key)
        }
    }

    public init() {
        let stored = UserDefaults.standard.string(forKey: ThemeManager.key) ?? ""
        self.selectedTheme = AppTheme(rawValue: stored) ?? .system
    }

    public var preferredColorScheme: ColorScheme? {
        selectedTheme.colorScheme
    }
}

// MARK: - CircuitContext

/// Describes which user circuit is active — affects component colours.
public enum CircuitContext: Sendable {
    case kid
    case parent
    case specialist
}

// MARK: - Environment Keys

private struct CircuitContextKey: EnvironmentKey {
    static let defaultValue: CircuitContext = .kid
}

public extension EnvironmentValues {
    var circuitContext: CircuitContext {
        get { self[CircuitContextKey.self] }
        set { self[CircuitContextKey.self] = newValue }
    }
}

// MARK: - ThemeApplier ViewModifier

public struct ThemeApplier: ViewModifier {
    @State private var themeManager = ThemeManager()

    public func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.preferredColorScheme)
            .environment(themeManager)
    }
}

public extension View {
    func applyHSTheme() -> some View {
        modifier(ThemeApplier())
    }
}
