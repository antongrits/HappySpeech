import OSLog
import SceneKit
import SwiftUI
import UIKit

// MARK: - ArticulationScene3DView
//
// Интерактивная 3D-модель реалистичного рта (вращаемая жестом) для карточки
// SoundDictionary. Геометрия — текстурированная модель «Human mouth detailed»
// (автор Mince, CC-BY 4.0), сконвертированная в `articulation_mouth.usdz`
// (Resources/Models/).
//
// Модель: фронтальный открытый рот (glTF, Y-up). Три меша — губы/дёсны/язык
// (mouth), зубы (teeth), влажная внутренняя поверхность (wet) — с РЕАЛЬНЫМИ
// PBR-текстурами. Их сохраняем как есть (свои материалы НЕ навешиваем). Рига и
// blend-shapes нет, отдельной ноды языка нет — модель ОДИНАКОВА для всех звуков,
// это объект для рассматривания; позу языка по звуку показывает текстовая
// подсказка и 2D/видео-схема в карточке.
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

    /// Текущий выбранный звук (влияет только на подсказку в карточке; 3D-модель
    /// одинакова для всех звуков).
    let sound: ArticulationSound
    /// Учитывать Reduced Motion (для совместимости вызова; 3D статична).
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
        scnView.defaultCameraController.inertiaEnabled = true
        scnView.isJitteringEnabled = true
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = false
        context.coordinator.scnView = scnView

        context.coordinator.apply(sound: sound)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(sound: sound)
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
            // НЕ запекаем flattenedClone: usdz Sketchfab/glTF содержит посторонние
            // узлы (камера/свет/пустой «Sketchfab_model»/«root» далеко от геометрии),
            // которые раздувают мировой bbox корня — нормировка такого bbox оставляла
            // рот крошечной точкой. Габарит считаем geometry-only (см. normalize),
            // вложенные xform'ы glTF учитываются через convertPosition углов мешей.
            return loadedRoot
        }

        // MARK: Framing

        /// Детерминированная нормализация размера модели — НЕ полагаемся на
        /// радиус-дистанцию (вложенные glTF-xform'ы переоценивают мировой габарит,
        /// рот выходил ~8% кадра). Вместо этого жёстко приводим модель к
        /// фиксированному размеру 2.0 юнита через двухуровневый контейнер:
        ///   container (внешний, нормирует scale = 2/maxDim)
        ///     └─ centerer (внутренний, сдвигает центр bbox в origin)
        ///          └─ model (запечённый узел)
        /// Сдвиг центра делается ДО масштаба (внутренним узлом), затем весь
        /// центрированный узел масштабируется внешним контейнером. Камера затем
        /// кадрирует объект размера 2.0 с фиксированной дистанции.
        /// Ориентацию НЕ меняем (фронтальная +Z верна).
        ///
        /// Габарит и центр берём ТОЛЬКО по узлам с геометрией (geometryBounds),
        /// игнорируя камеры/свет/пустые Xform Sketchfab — иначе раздутый bbox
        /// оставлял рот крошечной точкой.
        private func normalize(_ model: SCNNode, into container: SCNNode) {
            let (minBox, maxBox): (SCNVector3, SCNVector3)
            if let geom = geometryBounds(model) {
                (minBox, maxBox) = geom
            } else {
                // Fallback: мешей не нашли — старый путь по bbox узла.
                articulationLog.error("artic geometry bounds empty — fallback to node boundingBox")
                (minBox, maxBox) = model.boundingBox
            }
            let center = SCNVector3(
                (minBox.x + maxBox.x) / 2,
                (minBox.y + maxBox.y) / 2,
                (minBox.z + maxBox.z) / 2
            )
            // Внутренний узел сдвигает geometry-центр модели в собственный origin
            // (в родных единицах модели, ДО масштаба).
            let centerer = SCNNode()
            centerer.name = "articulationCenterer"
            model.position = SCNVector3(-center.x, -center.y, -center.z)
            centerer.addChildNode(model)

            // Внешний контейнер нормирует наибольший geometry-габарит к 2.0 юнита.
            let dx = maxBox.x - minBox.x
            let dy = maxBox.y - minBox.y
            let dz = maxBox.z - minBox.z
            let maxDim = max(dx, max(dy, dz))
            let s: Float = maxDim > 0 ? 2.0 / maxDim : 1
            container.scale = SCNVector3(s, s, s)
            container.addChildNode(centerer)
        }

        /// Union axis-aligned bounding box ТОЛЬКО по узлам с геометрией, выраженный
        /// в системе координат `root`. Камеры/свет/пустые Xform (без `geometry`)
        /// пропускаются. Для каждого меша берём его локальный `boundingBox`,
        /// разворачиваем в 8 углов и переводим в координаты `root` через
        /// `convertPosition(_:to:)` — это учитывает все вложенные glTF-xform'ы
        /// (scale ×100, повороты Y-up→Z-up) без запекания геометрии.
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

        /// Фиксированная камера для нормированного объекта размера 2.0 юнита —
        /// детерминированна, не зависит от мировых единиц glTF. FOV 42°, чуть
        /// сверху-фронтально (видно язык/нёбо внутри), кадрирует объект к ~75%.
        private func addCamera(to scene: SCNScene) {
            let cameraNode = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 42
            camera.wantsHDR = false
            camera.wantsExposureAdaptation = false
            camera.zNear = 0.05
            camera.zFar = 100
            cameraNode.camera = camera

            // Дистанция 3.2 кадрирует 2-юнитовый объект к ~75% (если потребуется —
            // диапазон 2.6–3.6). Y=0.5 — лёгкий наклон сверху.
            cameraNode.position = SCNVector3(0, 0.5, 3.2)
            cameraNode.look(at: SCNVector3Zero)
            cameraNode.name = "camera"
            scene.rootNode.addChildNode(cameraNode)
            scnView?.pointOfView = cameraNode
        }

        // MARK: Lighting (мягкий, без пересвета)

        private func addSoftLighting(to scene: SCNScene) {
            // Ключевой нейтральный directional — мягкий объём, реалистичные
            // PBR-текстуры рта читаются естественно (не желтит, не выбеливает).
            let keyNode = SCNNode()
            let key = SCNLight()
            key.type = .directional
            key.color = uiColor("KidSurface")
            key.intensity = 450
            key.castsShadow = false
            keyNode.light = key
            // Позиция для нормированного объекта размера 2.0 (направление важнее
            // дистанции для directional-света).
            keyNode.position = SCNVector3(0.8, 1.8, 2.0)
            keyNode.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(keyNode)

            // Мягкий ambient — равномерная база, чтобы внутренняя поверхность не
            // проваливалась в чёрный.
            let ambientNode = SCNNode()
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = uiColor("KidSurface")
            ambient.intensity = 280
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)
        }

        // MARK: Sound selection

        /// 3D-модель рта одинакова для всех звуков (нет ноды языка/рига): поза по
        /// звуку показывается текстом и 2D/видео-схемой в карточке. Метод сохранён
        /// для стабильного интерфейса вызова из `ArticulationScene3DView`.
        func apply(sound: ArticulationSound) {
            _ = sound
        }
    }
}
