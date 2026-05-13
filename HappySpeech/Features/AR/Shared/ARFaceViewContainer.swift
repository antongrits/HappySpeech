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
    /// SF Symbol для иконки рядом со score (например, `star.fill`). Если nil — score
    /// рендерится как обычный текст без иконки.
    let scoreIcon: String?
    let onClose: () -> Void

    init(title: LocalizedStringKey,
         scoreText: String?,
         scoreIcon: String? = nil,
         onClose: @escaping () -> Void) {
        self.title = title
        self.scoreText = scoreText
        self.scoreIcon = scoreIcon
        self.onClose = onClose
    }

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .padding(SpacingTokens.small)
                    .background(ColorTokens.Overlay.dimmerHeavy, in: Circle())
            }
            .frame(minWidth: 56, minHeight: 56)
            .contentShape(Rectangle())
            .accessibilityLabel(Text("common.close"))

            Text(title)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .background(ColorTokens.Overlay.dimmer, in: Capsule())

            Spacer()

            if let scoreText {
                scoreBadge(text: scoreText, icon: scoreIcon)
            }
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.top, SpacingTokens.small)
    }

    @ViewBuilder
    private func scoreBadge(text: String, icon: String?) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Text(text)
                .font(TypographyTokens.headline(16))
            if let icon {
                Image(systemName: icon)
                    .font(TypographyTokens.headline(14))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(ColorTokens.Overlay.onAccent)
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.tiny)
        .background(ColorTokens.Brand.primary.opacity(0.9), in: Capsule())
    }
}
