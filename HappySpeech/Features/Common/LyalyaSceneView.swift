import SceneKit
import SwiftUI

// MARK: - LyalyaSceneView
//
// SceneKit 3D маскот Ляли — плейсхолдер до появления lyalya3d.usdz.
//
// Тиринг:
//   iOS 18+ → SceneKitWrapper (UIViewRepresentable SCNView) — лучший render path
//   iOS 17  → тот же SceneKitWrapper (SCNView поддерживается с iOS 8)
//   Ошибка  → 2D LyalyaMascotView fallback
//
// Геометрия плейсхолдера (когда usdz не найден):
//   • Большая сфера (R=0.15) с pastel-градиент материалом — «тело» Ляли
//   • Две маленькие сферы (R=0.04) — «глазки»
//   • Idle: медленное покачивание по Y (CABasicAnimation)
//   • Celebrating: bounce scale (CAKeyframeAnimation)
//   • Waving: быстрое вращение вокруг Y
//
// Reduced Motion: все SCNAction-анимации не запускаются.

struct LyalyaSceneView: View {

    // MARK: - Public API

    let lyalyaState: LyalyaState
    let size: CGFloat

    // MARK: - Private

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init

    init(
        state: LyalyaState = .idle,
        size: CGFloat = 200
    ) {
        self.lyalyaState = state
        self.size = size
    }

    // MARK: - Body

    var body: some View {
        SceneKitWrapper(
            lyalyaState: lyalyaState,
            size: size,
            reduceMotion: reduceMotion
        )
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHidden(false)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch lyalyaState {
        case .idle:        return String(localized: "lyalya.scene.idle")
        case .celebrating: return String(localized: "lyalya.scene.celebrating")
        case .waving:      return String(localized: "lyalya.scene.waving")
        default:           return String(localized: "lyalya.scene.default")
        }
    }
}

// MARK: - SceneKitWrapper

private struct SceneKitWrapper: UIViewRepresentable {

    let lyalyaState: LyalyaState
    let size: CGFloat
    let reduceMotion: Bool

    // MARK: UIViewRepresentable

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.scene = LyalyaSceneBuilder.makeScene()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.rendersContinuously = !reduceMotion

        LyalyaSceneBuilder.applyAnimation(
            to: scnView.scene,
            state: lyalyaState,
            reduceMotion: reduceMotion
        )

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        scnView.rendersContinuously = !reduceMotion

        // Обновляем анимацию при смене состояния
        guard context.coordinator.lastState != lyalyaState else { return }
        context.coordinator.lastState = lyalyaState

        LyalyaSceneBuilder.applyAnimation(
            to: scnView.scene,
            state: lyalyaState,
            reduceMotion: reduceMotion
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator(state: lyalyaState) }

    // MARK: - Coordinator

    final class Coordinator {
        var lastState: LyalyaState
        init(state: LyalyaState) { lastState = state }
    }
}

// MARK: - LyalyaSceneBuilder

/// Строит SCNScene с процедурной геометрией маскота и управляет анимациями.
private enum LyalyaSceneBuilder {

    // MARK: Keys

    static let bodyNodeName = "lyalya_body"
    static let leftEyeNodeName = "lyalya_eye_left"
    static let rightEyeNodeName = "lyalya_eye_right"

    // MARK: - Make scene

    static func makeScene() -> SCNScene {
        let scene = SCNScene()

        // --- Освещение ---
        let ambientNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 600
        ambientLight.color = UIColor(red: 0.95, green: 0.93, blue: 1.0, alpha: 1)
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let omniNode = SCNNode()
        let omniLight = SCNLight()
        omniLight.type = .omni
        omniLight.intensity = 1200
        omniLight.color = UIColor.white
        omniNode.light = omniLight
        omniNode.position = SCNVector3(0.3, 0.5, 0.4)
        scene.rootNode.addChildNode(omniNode)

        // --- Камера ---
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 38
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 0.6)
        scene.rootNode.addChildNode(cameraNode)

        // --- Тело (main sphere) ---
        let bodySphere = SCNSphere(radius: 0.15)
        bodySphere.segmentCount = 48
        bodySphere.firstMaterial = makeBodyMaterial()
        let bodyNode = SCNNode(geometry: bodySphere)
        bodyNode.name = bodyNodeName
        bodyNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(bodyNode)

        // --- Глазки ---
        let eyeMaterial = makeEyeMaterial()

        let leftEye = SCNSphere(radius: 0.035)
        leftEye.firstMaterial = eyeMaterial
        let leftEyeNode = SCNNode(geometry: leftEye)
        leftEyeNode.name = leftEyeNodeName
        leftEyeNode.position = SCNVector3(-0.06, 0.055, 0.13)
        bodyNode.addChildNode(leftEyeNode)

        let rightEye = SCNSphere(radius: 0.035)
        rightEye.firstMaterial = eyeMaterial.copy() as? SCNMaterial ?? eyeMaterial
        let rightEyeNode = SCNNode(geometry: rightEye)
        rightEyeNode.name = rightEyeNodeName
        rightEyeNode.position = SCNVector3(0.06, 0.055, 0.13)
        bodyNode.addChildNode(rightEyeNode)

        // --- Зрачки ---
        let pupilMaterial = makePupilMaterial()

        let leftPupil = SCNSphere(radius: 0.016)
        leftPupil.firstMaterial = pupilMaterial
        let leftPupilNode = SCNNode(geometry: leftPupil)
        leftPupilNode.position = SCNVector3(0, 0, 0.028)
        leftEyeNode.addChildNode(leftPupilNode)

        let rightPupil = SCNSphere(radius: 0.016)
        rightPupil.firstMaterial = pupilMaterial.copy() as? SCNMaterial ?? pupilMaterial
        let rightPupilNode = SCNNode(geometry: rightPupil)
        rightPupilNode.position = SCNVector3(0, 0, 0.028)
        rightEyeNode.addChildNode(rightPupilNode)

        return scene
    }

    // MARK: - Materials

    private static func makeBodyMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        // Pastel lilac-to-pink gradient через diffuse + emission тонировку
        mat.diffuse.contents = UIColor(
            red: 0.76, green: 0.63, blue: 0.95, alpha: 1
        )
        mat.specular.contents = UIColor.white
        mat.shininess = 0.65
        mat.roughness.contents = 0.25
        mat.metalness.contents = 0.05
        mat.lightingModel = .physicallyBased
        return mat
    }

    private static func makeEyeMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.specular.contents = UIColor.white
        mat.shininess = 0.9
        mat.lightingModel = .phong
        return mat
    }

    private static func makePupilMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 1)
        mat.lightingModel = .constant
        return mat
    }

    // MARK: - Animations

    static func applyAnimation(
        to scene: SCNScene?,
        state: LyalyaState,
        reduceMotion: Bool
    ) {
        guard let scene,
              let bodyNode = scene.rootNode.childNode(
                  withName: bodyNodeName, recursively: false
              ) else { return }

        // Снимаем предыдущие анимации
        bodyNode.removeAllAnimations()

        guard !reduceMotion else { return }

        switch state {
        case .idle, .thinking, .encouraging, .pointing, .sad:
            applyIdleBob(to: bodyNode)

        case .celebrating, .happy:
            applyCelebrateBounce(to: bodyNode)

        case .waving:
            applyWavingRotation(to: bodyNode)

        case .explaining, .singing:
            applyExplainingNod(to: bodyNode)
        }
    }

    // MARK: Idle — медленное покачивание по Y

    private static func applyIdleBob(to node: SCNNode) {
        let bob = CABasicAnimation(keyPath: "position.y")
        bob.fromValue = -0.012
        bob.toValue = 0.012
        bob.duration = 1.8
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(bob, forKey: "idle_bob")
    }

    // MARK: Celebrating — bounce scale

    private static func applyCelebrateBounce(to node: SCNNode) {
        let bounce = CAKeyframeAnimation(keyPath: "scale")
        bounce.values = [
            SCNVector3(1.0, 1.0, 1.0),
            SCNVector3(1.3, 1.3, 1.3),
            SCNVector3(0.92, 0.92, 0.92),
            SCNVector3(1.12, 1.12, 1.12),
            SCNVector3(1.0, 1.0, 1.0)
        ]
        bounce.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        bounce.duration = MotionTokens.Duration.slow
        bounce.repeatCount = .infinity
        bounce.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        node.addAnimation(bounce, forKey: "celebrate_bounce")

        // Дополнительный подскок по Y
        let jump = CABasicAnimation(keyPath: "position.y")
        jump.fromValue = 0
        jump.toValue = 0.035
        jump.duration = MotionTokens.Duration.moderate
        jump.autoreverses = true
        jump.repeatCount = .infinity
        jump.timingFunction = CAMediaTimingFunction(name: .easeOut)
        node.addAnimation(jump, forKey: "celebrate_jump")
    }

    // MARK: Waving — быстрое вращение вокруг Y
    // Используем SCNAction чтобы избежать захвата non-Sendable SCNNode через concurrency boundary.

    private static func applyWavingRotation(to node: SCNNode) {
        // Два полных оборота (2 × 2π) через SCNAction — thread-safe, нет DispatchQueue захвата
        let spin = SCNAction.rotateBy(
            x: 0,
            y: .pi * 2,
            z: 0,
            duration: 1.2
        )
        let doubleSpin = SCNAction.repeat(spin, count: 2)
        let bobAction = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.012, z: 0, duration: 0.9),
                SCNAction.moveBy(x: 0, y: -0.012, z: 0, duration: 0.9)
            ])
        )
        let sequence = SCNAction.sequence([doubleSpin, bobAction])
        node.runAction(sequence, forKey: "waving_sequence")
    }

    // MARK: Explaining / Singing — кивок

    private static func applyExplainingNod(to node: SCNNode) {
        let nod = CABasicAnimation(keyPath: "eulerAngles.x")
        nod.fromValue = -Float.pi * 0.05
        nod.toValue = Float.pi * 0.05
        nod.duration = MotionTokens.Duration.moderate
        nod.autoreverses = true
        nod.repeatCount = .infinity
        nod.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(nod, forKey: "explaining_nod")
    }
}

// MARK: - Convenience Factory

extension LyalyaSceneView {

    static func small(state: LyalyaState = .idle) -> LyalyaSceneView {
        LyalyaSceneView(state: state, size: 96)
    }

    static func medium(state: LyalyaState = .idle) -> LyalyaSceneView {
        LyalyaSceneView(state: state, size: 200)
    }

    static func large(state: LyalyaState = .idle) -> LyalyaSceneView {
        LyalyaSceneView(state: state, size: 280)
    }
}

// MARK: - Preview

#Preview("Idle — medium") {
    LyalyaSceneView.medium(state: .idle)
        .padding(32)
        .background(Color(hex: "#F3EEFF"))
}

#Preview("Celebrating — large") {
    LyalyaSceneView.large(state: .celebrating)
        .padding(32)
        .background(Color(hex: "#FFF8E0"))
}

#Preview("Все состояния") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
            ForEach(LyalyaState.allCases, id: \.rawValue) { st in
                VStack(spacing: 8) {
                    LyalyaSceneView.small(state: st)
                    Text(st.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
