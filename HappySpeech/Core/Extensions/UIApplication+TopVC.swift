import UIKit

// MARK: - UIApplication.topViewController()

public extension UIApplication {

    /// Returns the top-most presented view controller in the active window scene.
    /// Used to obtain a presenting UIViewController for UIKit APIs (e.g. GoogleSignIn)
    /// from SwiftUI code which only has access to the `UIApplication` singleton.
    @MainActor
    static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController? = base ?? Self.keyWindowRootViewController()

        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }

    @MainActor
    private static func keyWindowRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        let keyWindow = scenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? scenes.first?.windows.first

        return keyWindow?.rootViewController
    }
}
