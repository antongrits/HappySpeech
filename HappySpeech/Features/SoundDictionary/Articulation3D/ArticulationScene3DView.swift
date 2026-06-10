import OSLog
import SceneKit
import SwiftUI
import UIKit

// MARK: - ArticulationScene3DView
//
// Интерактивная 3D-модель сагиттального разреза головы (вращаемая жестом).
// Геометрия — РЕАЛЬНАЯ анатомическая модель из атласа Z-Anatomy (CC-BY-SA 4.0),
// сконвертированная в `articulation_head.usdz` (Resources/Models/).
//
// Модель: сагиттальный разрез, upAxis = Y, фронт лица → +Z, плоскость среза = X = 0,
// показана половина X ≤ 0. Узлы под корнем `ArticulationHead`: Tongue (двигаем под
// звуки), Palate, Teeth, Lips, JawLower/Upper, Pharynx, Larynx, Nasal, Hyoid,
// HeadContour (полупрозрачный силуэт). Материалы тёплые заданы в usdz.
//
// Крупный белый череп (HeadContour) и носовая полость скрыты — фокус на речевом
// аппарате (язык/нёбо/зубы/губы/челюсть/глотка/гортань). Камера смотрит на срез в
// боковой сагиттальный профиль, кадрирование считается по bounding box ТОЛЬКО узлов
// речевого тракта, чтобы рот заполнял кадр. `allowsCameraControl` включён —
// вращение/зум жестом. Свет — мягкий тёплый 3-точечный, БЕЗ defaultLighting (иначе
// пересвет в белый). Под Reduced Motion смена позы языка мгновенная, без вибрации Р.

private let articulationLog = Logger(subsystem: "ru.happyspeech.app", category: "Articulation3D")

// Хелпер: UIColor из colorset-токена (SCNLight не принимает SwiftUI Color).
// Fallback некритичен — colorset всегда в бандле.
private func uiColor(_ name: String) -> UIColor {
    UIColor(named: name) ?? .systemPink
}

struct ArticulationScene3DView: UIViewRepresentable {

    /// Текущая поза (выбранный звук).
    let sound: ArticulationSound
    /// Учитывать Reduced Motion: при true — без анимации позы и без вибрации Р.
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

        context.coordinator.apply(sound: sound, animated: false, reduceMotion: reduceMotion)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(
            sound: sound,
            animated: !reduceMotion,
            reduceMotion: reduceMotion
        )
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {

        weak var scnView: SCNView?
        private var tongueNode: SCNNode?
        /// Базовый трансформ языка из usdz (нейтральная поза «как есть»).
        private var tongueBasePosition = SCNVector3Zero
        private var tongueBaseEuler = SCNVector3Zero
        private var tongueBaseScale = SCNVector3(1, 1, 1)
        /// Габарит речевого тракта — масштаб для пропорциональных смещений языка.
        private var modelSpan: Float = 0.25
        private var currentSound: ArticulationSound?

        /// Узлы речевого аппарата — видимые, тёплые.
        private static let tractNodeNames = [
            "Tongue", "Palate", "Teeth", "Lips",
            "JawLower", "JawUpper", "Pharynx", "Larynx"
        ]
        /// Узлы для кадрирования: мягкие ткани + зубы + глотка. БЕЗ JawUpper —
        /// верхняя кость тянет габарит вверх к носу и уводит язык из центра.
        private static let framingNodeNames = [
            "Tongue", "Palate", "Teeth", "Lips", "Pharynx"
        ]
        /// Крупные «черепные» узлы — скрываем, чтобы не было белого пятна.
        private static let hiddenNodeNames = ["HeadContour", "Nasal", "Hyoid"]

        func makeScene() -> SCNScene {
            let scene = SCNScene()
            scene.background.contents = UIColor.clear

            let container = SCNNode()
            container.name = "articulationContainer"
            scene.rootNode.addChildNode(container)

            if let modelRoot = loadModelRoot() {
                container.addChildNode(modelRoot)
                hideSkullNodes(in: modelRoot)
                applyWarmMaterials(in: modelRoot)
                centerAndFrameMouth(modelRoot, container: container)
                tongueNode = modelRoot.childNode(withName: "Tongue", recursively: true)
                if let tongue = tongueNode {
                    tongueBasePosition = tongue.position
                    tongueBaseEuler = tongue.eulerAngles
                    tongueBaseScale = tongue.scale
                } else {
                    articulationLog.error("Tongue node not found in articulation_head.usdz")
                }
            } else {
                articulationLog.error("articulation_head.usdz not found in bundle — showing empty scene")
            }

            addCamera(to: scene)
            addWarmLighting(to: scene)
            return scene
        }

        // MARK: Скрытие черепа

        /// Прячет крупный силуэт черепа и носовую полость (белое пятно во весь кадр).
        /// Сопоставляет по префиксу имени (usdz может добавлять суффиксы/дубли).
        private func hideSkullNodes(in model: SCNNode) {
            model.enumerateHierarchy { node, _ in
                guard let nodeName = node.name else { return }
                for hidden in Self.hiddenNodeNames where nodeName.hasPrefix(hidden) {
                    node.isHidden = true
                }
            }
        }

        // MARK: Тёплые опаковые материалы органов

        /// Назначает тёплые опаковые PBR-материалы органам речи, полностью
        /// перекрывая материалы usdz (которые рендерились бледно-жёлтыми).
        /// Цвета — только из палитры приложения. Мягкие ткани — насыщенные и
        /// опаковые (доминируют), кость (Jaw*) — полупрозрачный тёплый контур,
        /// чтобы язык/нёбо/губы читались на её фоне.
        private func applyWarmMaterials(in model: SCNNode) {
            // (Xform-имя органа, цвет-токен, прозрачность: 0 = опаковый, кость полупрозрачная)
            let map: [(name: String, color: String, transparency: CGFloat)] = [
                ("Tongue", "BrandRose", 0.0),       // главный орган — ярко
                ("Palate", "BrandLilac", 0.0),
                ("Teeth", "KidSurface", 0.0),       // кремово-белый
                ("Lips", "BrandPrimary", 0.0),      // коралл
                ("Pharynx", "BrandPrimaryLo", 0.0), // приглушённый коралл
                ("Larynx", "BrandPrimaryLo", 0.0),
                ("JawLower", "BrandButter", 0.45),  // кость — полупрозрачный контур
                ("JawUpper", "BrandButter", 0.45)
            ]
            for entry in map {
                applyMaterial(
                    color: uiColor(entry.color),
                    transparency: entry.transparency,
                    toNodeNamed: entry.name,
                    in: model
                )
            }
        }

        /// Материал вешается на ГЕОМЕТРИЮ дочерних mesh-нод (`<Organ>_mesh_001`),
        /// а не на Xform-ноду органа (у неё `geometry == nil`). Перебираем всю
        /// иерархию узла и красим каждую найденную геометрию новым PBR-материалом.
        private func applyMaterial(
            color: UIColor,
            transparency: CGFloat,
            toNodeNamed name: String,
            in model: SCNNode
        ) {
            guard let node = model.childNode(withName: name, recursively: true) else {
                articulationLog.error("Articulation organ node not found: \(name, privacy: .public)")
                return
            }
            var paintedMeshes = 0
            node.enumerateHierarchy { child, _ in
                guard let geometry = child.geometry else { return }
                let material = SCNMaterial()
                material.lightingModel = .physicallyBased
                material.diffuse.contents = color
                material.roughness.contents = NSNumber(value: 0.6)
                material.metalness.contents = NSNumber(value: 0.0)
                material.transparency = 1.0 - transparency
                material.isDoubleSided = true
                if transparency > 0 {
                    material.blendMode = .alpha
                    material.writesToDepthBuffer = false
                }
                // Перекрываем ВСЕ материалы геометрии (usdz мог иметь несколько).
                let count = max(geometry.materials.count, 1)
                geometry.materials = Array(repeating: material, count: count)
                paintedMeshes += 1
            }
            if paintedMeshes == 0 {
                articulationLog.error("No mesh geometry under organ node: \(name, privacy: .public)")
            }
        }

        // MARK: USDZ loading

        /// Загружает корневой узел реальной модели из `articulation_head.usdz`.
        /// Ищет ресурс и по имени, и в подпапке Models — в зависимости от того,
        /// как сложилась структура бандла.
        private func loadModelRoot() -> SCNNode? {
            let url = Bundle.main.url(forResource: "articulation_head", withExtension: "usdz")
                ?? Bundle.main.url(forResource: "articulation_head", withExtension: "usdz", subdirectory: "Models")
            guard let url else { return nil }
            guard let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) else {
                articulationLog.error("Failed to parse articulation_head.usdz scene")
                return nil
            }
            let root = SCNNode()
            root.name = "articulationModel"
            // Реальный контент usdz может лежать под defaultPrim ArticulationHead —
            // переносим всех детей корня загруженной сцены в наш узел.
            for child in scene.rootNode.childNodes {
                root.addChildNode(child)
            }
            return root
        }

        /// Центрирует и масштабирует контейнер по bounding box ТОЛЬКО узлов речевого
        /// тракта (язык/нёбо/зубы/губы/челюсть/глотка), чтобы рот заполнял ~70% кадра,
        /// а не терялся внутри габарита всей головы.
        private func centerAndFrameMouth(_ model: SCNNode, container: SCNNode) {
            let bounds = mouthBoundingBox(in: model)
            let (minBox, maxBox) = bounds.valid
                ? (bounds.min, bounds.max)
                : model.boundingBox

            let center = SCNVector3(
                (minBox.x + maxBox.x) / 2,
                (minBox.y + maxBox.y) / 2,
                (minBox.z + maxBox.z) / 2
            )
            // Сдвигаем геометрию так, чтобы центр РТА оказался в origin контейнера.
            model.position = SCNVector3(-center.x, -center.y, -center.z)

            let span = max(maxBox.x - minBox.x, maxBox.y - minBox.y, maxBox.z - minBox.z)
            modelSpan = span > 0 ? span : 0.25

            // Рот заполняет ~70% единичного кадра камеры → нормируем к ~0.7.
            let targetSpan: Float = 0.7
            let scale = span > 0 ? targetSpan / span : 1.0
            container.scale = SCNVector3(scale, scale, scale)
        }

        /// Union bounding box узлов речевого тракта в координатах `model`.
        private func mouthBoundingBox(in model: SCNNode)
            -> (min: SCNVector3, max: SCNVector3, valid: Bool) {
            var lo = SCNVector3(Float.greatestFiniteMagnitude,
                                Float.greatestFiniteMagnitude,
                                Float.greatestFiniteMagnitude)
            var hi = SCNVector3(-Float.greatestFiniteMagnitude,
                                -Float.greatestFiniteMagnitude,
                                -Float.greatestFiniteMagnitude)
            var found = false

            for name in Self.framingNodeNames {
                guard let node = model.childNode(withName: name, recursively: true) else { continue }
                let (nMin, nMax) = node.boundingBox
                // 8 углов локального бокса узла → в координаты model.
                let corners = [
                    SCNVector3(nMin.x, nMin.y, nMin.z),
                    SCNVector3(nMin.x, nMin.y, nMax.z),
                    SCNVector3(nMin.x, nMax.y, nMin.z),
                    SCNVector3(nMin.x, nMax.y, nMax.z),
                    SCNVector3(nMax.x, nMin.y, nMin.z),
                    SCNVector3(nMax.x, nMin.y, nMax.z),
                    SCNVector3(nMax.x, nMax.y, nMin.z),
                    SCNVector3(nMax.x, nMax.y, nMax.z)
                ]
                for corner in corners {
                    let world = node.convertPosition(corner, to: model)
                    lo = SCNVector3(min(lo.x, world.x), min(lo.y, world.y), min(lo.z, world.z))
                    hi = SCNVector3(max(hi.x, world.x), max(hi.y, world.y), max(hi.z, world.z))
                    found = true
                }
            }
            return (lo, hi, found)
        }

        // MARK: Camera

        private func addCamera(to scene: SCNScene) {
            let cameraNode = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 40
            camera.zNear = 0.01
            camera.zFar = 100
            camera.wantsHDR = false
            camera.wantsExposureAdaptation = false
            cameraNode.camera = camera

            // Боковой сагиттальный профиль: камера со стороны среза (+X), смотрит на
            // плоскость X = 0. Язык виден в профиль, нёбо дугой сверху, зубы и губы
            // (фронт +Z) — слева в кадре. Лёгкий подъём и сдвиг к +Z для естественного
            // ракурса. Контейнер нормирован (рот ~0.7) и отцентрирован в origin.
            cameraNode.position = SCNVector3(1.7, 0.18, 0.35)
            cameraNode.look(at: SCNVector3Zero)
            cameraNode.name = "camera"
            scene.rootNode.addChildNode(cameraNode)
            scnView?.pointOfView = cameraNode
        }

        // MARK: Lighting (тёплый 3-точечный)

        private func addWarmLighting(to scene: SCNScene) {
            // Ключевой тёплый directional (мягкий объём, без пересвета).
            let keyNode = SCNNode()
            let key = SCNLight()
            key.type = .directional
            key.color = uiColor("BrandButter")
            key.intensity = 320
            key.castsShadow = true
            key.shadowMode = .deferred
            key.shadowRadius = 6
            key.shadowColor = uiColor("KidInk").withAlphaComponent(0.16)
            keyNode.light = key
            keyNode.position = SCNVector3(1.2, 1.0, 0.9)
            keyNode.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(keyNode)

            // Заполняющий мягкий omni (убирает резкие тени со стороны среза).
            let fillNode = SCNNode()
            let fill = SCNLight()
            fill.type = .omni
            fill.color = uiColor("BrandButter")
            fill.intensity = 180
            fillNode.light = fill
            fillNode.position = SCNVector3(1.4, 0.3, -0.6)
            scene.rootNode.addChildNode(fillNode)

            // Слабый тёплый контровой rim (мягко отделяет от фона, без выбеливания).
            let rimNode = SCNNode()
            let rim = SCNLight()
            rim.type = .directional
            rim.color = uiColor("BrandRose")
            rim.intensity = 120
            rimNode.light = rim
            rimNode.position = SCNVector3(0.6, 0.7, -1.2)
            rimNode.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(rimNode)

            // Мягкий ambient (тёплая база).
            let ambientNode = SCNNode()
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = uiColor("KidSurface")
            ambient.intensity = 150
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)
        }

        // MARK: Pose application (трансформ узла Tongue под звук)

        func apply(sound: ArticulationSound, animated: Bool, reduceMotion: Bool) {
            guard let tongue = tongueNode else { return }
            let changed = currentSound != sound
            currentSound = sound

            // Смещения заданы в долях габарита модели → переводим в локальные единицы.
            let offset = sound.tongueOffset
            let targetPos = SCNVector3(
                tongueBasePosition.x + offset.x * modelSpan,
                tongueBasePosition.y + offset.y * modelSpan,
                tongueBasePosition.z + offset.z * modelSpan
            )
            let targetEuler = SCNVector3(
                tongueBaseEuler.x + sound.tonguePitch,
                tongueBaseEuler.y,
                tongueBaseEuler.z
            )
            let s = sound.tongueScale
            let targetScale = SCNVector3(
                tongueBaseScale.x * s.x,
                tongueBaseScale.y * s.y,
                tongueBaseScale.z * s.z
            )

            let applyTransform = {
                tongue.position = targetPos
                tongue.eulerAngles = targetEuler
                tongue.scale = targetScale
            }

            if animated && changed {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = MotionTokens.Duration.moderate
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(name: .easeInEaseOut)
                applyTransform()
                SCNTransaction.commit()
            } else {
                applyTransform()
            }

            // Вибрация кончика для Р (только если не reduceMotion).
            updateTongueVibration(active: sound == .r && !reduceMotion, basePosition: targetPos)
        }

        private func updateTongueVibration(active: Bool, basePosition: SCNVector3) {
            guard let tongue = tongueNode else { return }
            let key = "tipVibration"
            if active {
                guard tongue.action(forKey: key) == nil else { return }
                let amp = 0.004 * modelSpan
                let up = SCNAction.moveBy(x: 0, y: CGFloat(amp), z: 0, duration: 0.06)
                let down = SCNAction.moveBy(x: 0, y: CGFloat(-amp), z: 0, duration: 0.06)
                tongue.runAction(SCNAction.repeatForever(SCNAction.sequence([up, down])), forKey: key)
                scnView?.rendersContinuously = true
            } else {
                tongue.removeAction(forKey: key)
                tongue.position = basePosition
                scnView?.rendersContinuously = false
            }
        }
    }
}
