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
// PBR-текстурами. Их сохраняем как есть (свои материалы НЕ навешиваем).
//
// Язык СЛИТ с мешем рта и неподвижен, поэтому поверх статичной модели мы строим
// ОТДЕЛЬНЫЙ процедурный язык (`buildTongueRig`) — объёмный, сегментированный риг
// из сглаженных капсул (корень → спинка → тело → кончик), с глянцевым розовым
// материалом (specular + лёгкий subsurface-оттенок). `apply(sound:)` гнёт суставы
// рига под научно-точный уклад каждого русского звука (отчёт A-06) с плавными
// переходами; для Р добавляется быстрая вибрация кончика. При Reduced Motion —
// мгновенная статичная корректная поза без переходов/осцилляций.
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

    /// Текущий выбранный звук — задаёт позу процедурного языка.
    let sound: ArticulationSound
    /// Учитывать Reduced Motion: при `true` поза ставится мгновенно, без
    /// переходов и вибрации кончика.
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

        context.coordinator.apply(sound: sound, reduceMotion: reduceMotion)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(sound: sound, reduceMotion: reduceMotion)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {

        weak var scnView: SCNView?

        // MARK: Tongue rig nodes
        //
        // Архитектура — минимальная: одна горизонтальная SCNCapsule (тело),
        // один SCNSphere-эллипсоид кончика (tipBlob), всё в одном узле tongueRoot.
        // Для поз «тело» вращается через jBody (= родитель capsule-узла),
        // кончик — через jTip (дочерний узел jBody у переднего торца капсулы).
        // dorsumSeg = задняя часть тела; для К/Г/Х поднимаем весь jBody назад и
        // вверх через backRaise на jBack.
        private weak var tongueRoot: SCNNode?
        private weak var jBack: SCNNode?   // задняя ось; Y-сдвиг = backRaise
        private weak var jBody: SCNNode?   // тело + капсула; вращается на bodyArch
        private weak var jTip: SCNNode?    // кончик; вращается на tipRaise
        private weak var dorsumSeg: SCNNode? // = jBack (для K/G/KH Y-подъём)

        /// Базовая Y для узла jBack.
        private let dorsumBaseY: Float = 0

        /// Базовая позиция корня языка в нормированной (2.0-юнит) модели.
        private let tongueBaseY: Float = 0.06
        private let tongueBaseZ: Float = -0.08

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

            buildTongueRig(in: scene)
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

        // MARK: Procedural tongue rig

        /// Строит сплошное объёмное тело языка и помещает его на дно полости рта.
        ///
        /// Архитектура — три уровня, каждый гарантированно сплошной (без дыр):
        ///   1. tongueBody   — одна широкая горизонтальная SCNCapsule, сплюснутая
        ///                     по Y: главная масса языка от корня до передних зубов.
        ///                     Единственная капсула всегда даёт сплошной купол.
        ///   2. dorsumBlob   — SCNSphere-эллипсоид поверх задней части; для К/Г/Х
        ///                     поднимается вверх как горб-смычка к нёбу.
        ///   3. tipBlob      — SCNSphere-эллипсоид у переднего края; поворачивается
        ///                     вверх/вниз для Р/Ш/Л/С.
        ///
        /// Все три формы перекрываются с телом, поэтому тёмная модель нигде не
        /// просвечивает сквозь язык.
        ///
        /// Иерархия нод для управления позами:
        ///   tongueRoot  — позиция языка в полости (rootLift меняет Y)
        ///     └─ jBack  — задняя ось; bodyArch поворачивает, dorsumBlob движется по Y
        ///          └─ jBody — тело; bodyArch вращает главную капсулу
        ///               └─ jTip — кончик; tipRaise вращает tipBlob
        private func buildTongueRig(in scene: SCNScene) {
            let mat = tongueMaterial()

            // ── tongueRoot ──────────────────────────────────────────────────────
            let root = SCNNode()
            root.name = "tongueRoot"
            root.position = SCNVector3(0, tongueBaseY, tongueBaseZ)

            // ── jBack ── задняя ось; Y меняется при backRaise (К/Г/Х смычка) ───
            // Этот узел является «дорсальным» суставом: его Y-подъём поднимает
            // весь язык сзади к нёбу без создания отдельного плавающего объекта.
            let back = SCNNode()
            back.name  = "tongueJBack"
            back.position = SCNVector3(0, dorsumBaseY, -0.06)
            dorsumSeg = back   // backRaise двигает back.position.y

            // ── jBody ── тело + главная ЕДИНСТВЕННАЯ капсула ────────────────────
            let body = SCNNode()
            body.name = "tongueJBody"
            // Смещение вперёд от back: суммарно язык оказывается между нижними
            // зубами (перёд) и задней стенкой глотки (зад).
            body.position = SCNVector3(0, 0, 0.06)

            // Одна горизонтальная SCNCapsule = гарантированно сплошной купол.
            // capRadius  — полукруглые торцы по оси Z.
            // height     — цилиндрическая часть между торцами.
            // Итоговая длина капсулы вдоль Z = height + 2 × capRadius.
            // scale(x) → расширяет вбок (язык шире, чем высок).
            // scale(y) → приплющивает по высоте.
            // Малый capRadius = скромные полукруглые торцы → не выступают отдельными
            // горбиками при сильном scale.y-сплющивании.
            // Длинный height = большое цилиндрическое тело заполняет полость.
            let capsuleGeo = SCNCapsule(capRadius: 0.20, height: 1.10)
            capsuleGeo.heightSegmentCount = 24
            capsuleGeo.radialSegmentCount = 44
            capsuleGeo.materials = [mat]
            let capsuleNode = SCNNode(geometry: capsuleGeo)
            // Повернуть ось капсулы Y → Z (лежит горизонтально вдоль рта).
            capsuleNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            // Расширить по X, приплюснуть по Y, вытянуть по Z — широкий плоский язык.
            capsuleNode.scale = SCNVector3(1.50, 0.62, 1.10)
            body.addChildNode(capsuleNode)

            // ── jTip ── кончик ───────────────────────────────────────────────────
            // Располагается у переднего торца капсулы: от centre body по Z =
            // height/2 + capRadius = 0.36 + 0.30 = 0.66; ставим чуть меньше,
            // чтобы tipBlob перекрывал торец (нет щели).
            let tip = SCNNode()
            tip.name = "tongueJTip"
            // Передний торец капсулы: half-length = 1.10/2 + 0.20 = 0.75,
            // со scale.z=1.10 → ~0.83 от centre body.
            // tip на z=0.70 → tipBlob врезается в торец на ~0.13.
            tip.position = SCNVector3(0, 0, 0.70)

            // tipBlob — небольшая сфера, врезается в передний торец капсулы.
            // Достаточно мал, чтобы не торчать отдельным шаром, и достаточно
            // широк (scale.x), чтобы перекрыть торец по всей ширине.
            let tipGeo = SCNSphere(radius: 0.26)
            tipGeo.segmentCount = 28
            tipGeo.materials = [mat]
            let tipBlob = SCNNode(geometry: tipGeo)
            tipBlob.name = "tipBlob"
            tipBlob.scale = SCNVector3(1.38, 0.64, 0.90)
            // z=0 → центр сферы ровно на передней границе tip-узла.
            tipBlob.position = SCNVector3(0, 0, 0)
            tip.addChildNode(tipBlob)

            // ── сборка иерархии ─────────────────────────────────────────────────
            body.addChildNode(tip)
            back.addChildNode(body)
            root.addChildNode(back)
            scene.rootNode.addChildNode(root)

            tongueRoot = root
            jBack      = back
            jBody      = body
            jTip       = tip
        }

        // capsuleSegment / sphereSegment удалены: риг перестроен на единую капсулу
        // + два эллипсоида-блоба (см. buildTongueRig).

        /// Глянцевый розовый материал языка: насыщенный diffuse из colorset,
        /// мягкий specular-блик и лёгкий emission-подсвет (имитация subsurface),
        /// чтобы тело читалось объёмно, а не плоским пятном.
        private func tongueMaterial() -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .blinn
            m.diffuse.contents = uiColor("ArticulationTongue")
            m.specular.contents = uiColor("ArticulationSpecular")
            m.shininess = 0.42
            // Лёгкий тёплый подсвет «изнутри» — subsurface-намёк.
            m.emission.contents = uiColor("ArticulationTongue")
            m.emission.intensity = 0.12
            m.isDoubleSided = false
            return m
        }

        // MARK: Sound selection / posing

        /// Научно-точная поза рига языка под русский звук (отчёт A-06).
        /// Поля — углы суставов (рад) и флаги. Углы подобраны под ориентацию
        /// рига (поворот +X = наклон сегмента вверх к нёбу).
        private struct TonguePose {
            var backRaise: Float = 0   // вертикальный подъём задней спинки к нёбу (К/Г/Х), рига-юниты
            var bodyArch: Float = 0    // изгиб тела (рад): + опускает перёд (горка), − задирает (чашечка)
            var tipRaise: Float = 0    // кончик (рад): + вверх, − вниз
            var rootLift: Float = 0    // общий вертикальный сдвиг языка
            var lateral: Float = 0     // лёгкий крен тела (латеральность, Л)
            var trills = false         // вибрация кончика (Р)
        }

        private func pose(for sound: ArticulationSound) -> TonguePose {
            switch sound {
            case .neutral:
                // Плоско на дне, кончик слегка опущен у нижних резцов.
                return TonguePose(bodyArch: 0.04, tipRaise: -0.06)
            case .s, .z:
                // Свистящие: тело горкой к альвеолам, кончик за нижними резцами
                // (опущен). Углы умеренные — крупная капсула читается чётко.
                return TonguePose(bodyArch: 0.20, tipRaise: -0.22, rootLift: 0.02)
            case .sh, .zh:
                // Шипящие: кончик вверх к альвеолам, тело «чашечкой».
                return TonguePose(bodyArch: -0.14, tipRaise: 0.36, rootLift: 0.04)
            case .r:
                // Кончик поднят к альвеолам и ВИБРИРУЕТ.
                return TonguePose(bodyArch: 0.04, tipRaise: 0.40, rootLift: 0.04, trills: true)
            case .soundL:
                // Кончик к верхним резцам, тело «ложкой», латеральный крен.
                return TonguePose(bodyArch: -0.22, tipRaise: 0.46, rootLift: 0.03, lateral: 0.10)
            case .k, .g:
                // Задняя часть языка (jBack) поднимается к нёбу — смычка.
                // Кончик внизу. backRaise двигает весь back-узел вверх.
                return TonguePose(backRaise: 0.22, bodyArch: -0.05, tipRaise: -0.18, rootLift: 0.02)
            case .kh:
                // Задняя часть почти к нёбу (узкая щель = трение).
                return TonguePose(backRaise: 0.16, bodyArch: -0.04, tipRaise: -0.16, rootLift: 0.02)
            }
        }

        /// Применяет позу языка под звук. Плавный переход через SCNTransaction;
        /// при Reduced Motion — мгновенно, без вибрации Р.
        func apply(sound: ArticulationSound, reduceMotion: Bool) {
            guard let root = tongueRoot,
                  let back = jBack,
                  let body = jBody,
                  let tip = jTip,
                  let dorsum = dorsumSeg else {
                return
            }
            let p = pose(for: sound)

            // Снимаем прежнюю вибрацию кончика.
            tip.removeAction(forKey: "trill")

            let duration: CFTimeInterval = reduceMotion ? 0 : 0.45
            SCNTransaction.begin()
            SCNTransaction.animationDuration = duration
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            root.position = SCNVector3(0, tongueBaseY + p.rootLift, tongueBaseZ)
            // К/Г/Х: поднимаем jBack вверх по Y — задний конец языка тянется к нёбу.
            // dorsum == jBack, поэтому меняем его position.y.
            dorsum.position = SCNVector3(0, dorsumBaseY + p.backRaise, -0.06)
            back.eulerAngles = SCNVector3(0, 0, 0)
            body.eulerAngles = SCNVector3(p.bodyArch, 0, p.lateral)
            tip.eulerAngles  = SCNVector3(p.tipRaise, 0, 0)

            SCNTransaction.commit()

            // Вибрация Р — быстрая мелкая осцилляция кончика поверх позы.
            if p.trills && !reduceMotion {
                let base = p.tipRaise
                let amp: Float = 0.10
                let up = SCNAction.rotateTo(
                    x: CGFloat(base + amp), y: 0, z: 0, duration: 0.05, usesShortestUnitArc: true
                )
                let down = SCNAction.rotateTo(
                    x: CGFloat(base - amp), y: 0, z: 0, duration: 0.05, usesShortestUnitArc: true
                )
                up.timingMode = .easeInEaseOut
                down.timingMode = .easeInEaseOut
                tip.runAction(.repeatForever(.sequence([up, down])), forKey: "trill")
            }
        }
    }
}
