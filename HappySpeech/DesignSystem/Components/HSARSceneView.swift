import SwiftUI
import ARKit
import RealityKit

// MARK: - HSARSceneView

/// Wrapper around RealityKit `ARView` with a 2D fallback for the simulator
/// or devices that don't support world tracking. The `content` closure runs
/// on the main actor after the AR view is created so callers can attach
/// anchors, configure the session, and add gestures.
public struct HSARSceneView: View {

    private let content: @MainActor (ARView) -> Void
    private let fallback: AnyView
    private let frameSize: CGSize?

    public init(
        frame: CGSize? = nil,
        fallback: AnyView,
        content: @escaping @MainActor (ARView) -> Void
    ) {
        self.frameSize = frame
        self.fallback = fallback
        self.content = content
    }

    public var body: some View {
        Group {
            if Self.isARSupported {
                ARContainer(content: content)
                    .accessibilityLabel(String(localized: "ds.ar.scene.a11y_label"))
                    .accessibilityAddTraits(.isImage)
            } else {
                fallback
                    .accessibilityLabel(String(localized: "ds.ar.scene.fallback_a11y_label"))
            }
        }
        .modifier(OptionalFrameModifier(size: frameSize))
    }

    // MARK: - Capability check

    private static var isARSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return ARWorldTrackingConfiguration.isSupported
        #endif
    }
}

// MARK: - ARContainer

private struct ARContainer: UIViewRepresentable {

    let content: @MainActor (ARView) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        HSLogger.ar.info("HSARSceneView: ARKit initialized")
        content(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Caller is responsible for any state changes via captured bindings.
    }
}

// MARK: - OptionalFrameModifier

private struct OptionalFrameModifier: ViewModifier {
    let size: CGSize?

    func body(content: Content) -> some View {
        if let size {
            content.frame(width: size.width, height: size.height)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview("HSARSceneView fallback") {
    HSARSceneView(
        frame: CGSize(width: 320, height: 240),
        fallback: AnyView(
            ZStack {
                ColorTokens.Brand.lilac.opacity(0.2)
                Image(systemName: "arkit")
                    .font(.system(size: 48))
                    .foregroundStyle(ColorTokens.Brand.lilac)
            }
        ),
        content: { _ in }
    )
    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
    .padding()
    .background(ColorTokens.Kid.bg)
}
