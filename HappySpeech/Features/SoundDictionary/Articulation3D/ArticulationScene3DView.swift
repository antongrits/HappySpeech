import OSLog
import SceneKit
import SwiftUI
import UIKit

// MARK: - ArticulationScene3DView
//
// Интерактивная 3D-модель реалистичного рта (вращаемая жестом) — режим
// «Настоящий рот» в карточке артикуляции. Даёт ребёнку рассмотреть рот со всех
// сторон; конкретную позу языка по звуку подсказывает текст под сценой и (если
// есть) профессиональное Veo-видео в режиме «Видео».
//
// Геометрия — текстурированная модель «Human mouth detailed» (автор Mince,
// CC-BY 4.0), сконвертированная в `articulation_mouth.usdz` (Resources/Models/).
// Модель показывается КАК ЕСТЬ, с родными PBR-текстурами: процедурный накладной
// язык убран (он выглядел как отдельный плавающий объект). В самой usdz язык слит
// с мешем рта и неподвижен — это нормально, поза языка передаётся текстовой
// подсказкой и видео.
//
// Камера смотрит фронтально на открытый рот с лёгким наклоном сверху, чтобы было
// видно язык и нёбо внутри. `allowsCameraControl` включён — вращение/зум жестом.
// Свет мягкий, без defaultLighting (иначе текстуры выгорают): 1 key directional +
// ambient. Фон прозрачный, multisampling 4x.

private let articulationLog = Logger(subsystem: "ru.happyspeech.app", category: "Articulation3D")

// Хелпер: UIColor из colorset-токена (SCNLight не принимает SwiftUI Color).
// Fallback некритичен — colorset всегда в бандле.
private func uiColor(_ name: String) -> UIColor {
    UIColor(named: name) ?? .systemPink
}

struct ArticulationScene3DView: UIViewRepresentable {

    /// Учитывать Reduced Motion: при `true` инерция вращения отключается.
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.scene = context.coordinator.makeScene()
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = !reduceMotion
        scnView.isJitteringEnabled = true
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = false
        context.coordinator.scnView = scnView
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.defaultCameraController.inertiaEnabled = !reduceMotion
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {

        weak var scnView: SCNView?

        func makeScene() -> SCNScene {
            let scene = SCNScene()
            scene.background.contents = UIColor.clear

            let container = SCNNode()
            container.name = "articulationContainer"
            scene.rootNode.addChildNode(container)

            if let modelRoot = loadModelRoot() {
                normalize(modelRoot, into: container)
            } else {
                articulationLog.error("articulation_mouth.usdz not found in bundle — showing empty scene")
            }

            addCamera(to: scene)
            addSoftLighting(to: scene)
            return scene
        }

        // MARK: USDZ loading

        /// Загружает корневой узел текстурированной модели рта из
        /// `articulation_mouth.usdz`, СОХРАНЯЯ её родные PBR-материалы/текстуры.
        /// Ищет ресурс и по имени, и в подпапке Models.
        private func loadModelRoot() -> SCNNode? {
            let url = Bundle.main.url(forResource: "articulation_mouth", withExtension: "usdz")
                ?? Bundle.main.url(forResource: "articulation_mouth", withExtension: "usdz", subdirectory: "Models")
            guard let url else { return nil }
            guard let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) else {
                articulationLog.error("Failed to parse articulation_mouth.usdz scene")
                return nil
            }
            let loadedRoot = SCNNode()
            loadedRoot.name = "articulationModel"
            // Переносим всех детей корня загруженной сцены в наш узел (материалы
            // мешей не трогаем — они текстурированы в самой модели).
            for child in scene.rootNode.childNodes {
                loadedRoot.addChildNode(child)
            }
            return loadedRoot
        }

        // MARK: Framing

        /// Детерминированная нормализация размера модели через двухуровневый
        /// контейнер (см. geometryBounds). Габарит и центр берём ТОЛЬКО по узлам
        /// с геометрией, игнорируя камеры/свет/пустые Xform Sketchfab.
        private func normalize(_ model: SCNNode, into container: SCNNode) {
            let (minBox, maxBox): (SCNVector3, SCNVector3)
            if let geom = geometryBounds(model) {
                (minBox, maxBox) = geom
            } else {
                articulationLog.error("artic geometry bounds empty — fallback to node boundingBox")
                (minBox, maxBox) = model.boundingBox
            }
            let center = SCNVector3(
                (minBox.x + maxBox.x) / 2,
                (minBox.y + maxBox.y) / 2,
                (minBox.z + maxBox.z) / 2
            )
            let centerer = SCNNode()
            centerer.name = "articulationCenterer"
            model.position = SCNVector3(-center.x, -center.y, -center.z)
            centerer.addChildNode(model)

            let dx = maxBox.x - minBox.x
            let dy = maxBox.y - minBox.y
            let dz = maxBox.z - minBox.z
            let maxDim = max(dx, max(dy, dz))
            let s: Float = maxDim > 0 ? 2.0 / maxDim : 1
            container.scale = SCNVector3(s, s, s)
            container.addChildNode(centerer)
        }

        /// Union axis-aligned bounding box ТОЛЬКО по узлам с геометрией, выраженный
        /// в системе координат `root`. Камеры/свет/пустые Xform пропускаются.
        private func geometryBounds(_ root: SCNNode) -> (SCNVector3, SCNVector3)? {
            var hasMesh = false
            var mn = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
            var mx = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

            root.enumerateHierarchy { node, _ in
                guard node.geometry != nil else { return }
                let (lmin, lmax) = node.boundingBox
                let corners = [
                    SCNVector3(lmin.x, lmin.y, lmin.z),
                    SCNVector3(lmax.x, lmin.y, lmin.z),
                    SCNVector3(lmin.x, lmax.y, lmin.z),
                    SCNVector3(lmax.x, lmax.y, lmin.z),
                    SCNVector3(lmin.x, lmin.y, lmax.z),
                    SCNVector3(lmax.x, lmin.y, lmax.z),
                    SCNVector3(lmin.x, lmax.y, lmax.z),
                    SCNVector3(lmax.x, lmax.y, lmax.z)
                ]
                for corner in corners {
                    let p = node.convertPosition(corner, to: root)
                    mn.x = min(mn.x, p.x); mn.y = min(mn.y, p.y); mn.z = min(mn.z, p.z)
                    mx.x = max(mx.x, p.x); mx.y = max(mx.y, p.y); mx.z = max(mx.z, p.z)
                    hasMesh = true
                }
            }
            return hasMesh ? (mn, mx) : nil
        }

        // MARK: Camera

        /// Фиксированная камера для нормированного объекта размера 2.0 юнита.
        /// FOV 42°, чуть сверху-фронтально (видно язык/нёбо внутри), ~75% кадра.
        private func addCamera(to scene: SCNScene) {
            let cameraNode = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 42
            camera.wantsHDR = false
            camera.wantsExposureAdaptation = false
            camera.zNear = 0.05
            camera.zFar = 100
            cameraNode.camera = camera

            cameraNode.position = SCNVector3(0, 0.5, 3.2)
            cameraNode.look(at: SCNVector3Zero)
            cameraNode.name = "camera"
            scene.rootNode.addChildNode(cameraNode)
            scnView?.pointOfView = cameraNode
        }

        // MARK: Lighting (мягкий, без пересвета)

        private func addSoftLighting(to scene: SCNScene) {
            let keyNode = SCNNode()
            let key = SCNLight()
            key.type = .directional
            key.color = uiColor("KidSurface")
            key.intensity = 450
            key.castsShadow = false
            keyNode.light = key
            keyNode.position = SCNVector3(0.8, 1.8, 2.0)
            keyNode.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(keyNode)

            let ambientNode = SCNNode()
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = uiColor("KidSurface")
            ambient.intensity = 280
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)
        }
    }
}
