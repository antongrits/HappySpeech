import ARKit
import RealityKit
import SwiftUI

// MARK: - ARFaceViewContainer

/// Общий UIViewRepresentable для AR-игр. Оборачивает `ARView` и привязывает его
/// к сессии, которой уже управляет `ARSessionService`.
/// Если сессия не запущена — игра вызывает `service.startSession()`
/// перед показом, а не внутри updateUIView.
struct ARFaceViewContainer: UIViewRepresentable {

    let session: ARSession?

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.backgroundColor = .black
        if let session {
            // ARView использует переданный ARSession вместо своего.
            view.session = session
        }
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if let session, uiView.session !== session {
            uiView.session = session
        }
    }
}

// MARK: - ARUnsupportedView

/// Отображается на устройствах без TrueDepth камеры.
struct ARUnsupportedView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "ar.error.notSupported.title"),
            systemImage: "arkit",
            description: Text("ar.error.notSupported.body")
        )
    }
}

// MARK: - ARGameHUD

/// Единый top-HUD для AR-игр: кнопка закрытия + заголовок + опциональный счёт.
struct ARGameHUD: View {

    let title: LocalizedStringKey
    let scoreText: String?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(SpacingTokens.small)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel(Text("common.close"))

            Text(title)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(.white)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .background(.black.opacity(0.35), in: Capsule())

            Spacer()

            if let scoreText {
                Text(scoreText)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, SpacingTokens.tiny)
                    .background(ColorTokens.Brand.primary.opacity(0.9), in: Capsule())
            }
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.top, SpacingTokens.small)
    }
}
