import SwiftUI

// MARK: - View Extensions

public extension View {

    /// Apply a modifier conditionally.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Overlay a loading spinner when `isLoading` is true.
    func loadingOverlay(_ isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                }
            }
        }
    }

    /// Adds standard CTA safe-scaling behaviour.
    func ctaTextStyle() -> some View {
        self
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Tap with visual feedback (scale + opacity).
    func tapFeedback(scale: CGFloat = 0.96) -> some View {
        modifier(TapFeedbackModifier(scale: scale))
    }

    /// Corner radius with a specific set of corners.
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    /// Hide view but keep its layout space.
    func hiddenKeepingLayout(_ hidden: Bool) -> some View {
        opacity(hidden ? 0 : 1)
    }
}

// MARK: - TapFeedbackModifier

private struct TapFeedbackModifier: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? scale : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - RoundedCorner Shape

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
