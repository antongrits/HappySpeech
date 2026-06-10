import SceneKit
import UIKit

// MARK: - ArticulationSound
//
// Звук → артикуляционная поза языка (morph target). Кириллица фонемы из
// SoundDictionary маппится на одну из научных поз укладов (отчёт A-06).
// Каждый case несёт: индекс morph-target языка, флаг звонкости (волнистая
// глотта), флаг тёплой/холодной струи и нужно ли рисовать индикатор струи.

enum ArticulationSound: String, CaseIterable, Sendable {

    case neutral   // нейтральная поза покоя
    case s         // С/Сь/Ц — кончик у нижних зубов, горка + желобок, холодная узкая струя
    case z         // З/Зь — как С, звонкий
    case sh        // Ш/Ч/Щ — двугорбый, чашечка к альвеолам, тёплая широкая струя
    case zh        // Ж — как Ш, звонкий
    case r         // Р/Рь — ложечка, вибрация кончика у альвеол, звонкий
    case soundL    // Л/Ль — кончик к верхним резцам, седло, латеральный воздух, звонкий
    case k         // К — задняя спинка смыкается с мягким нёбом, глухой
    case g         // Г — как К, звонкий
    case kh        // Х — задняя спинка образует щель с мягким нёбом, глухой

    // MARK: Кириллица → поза

    /// Маппинг кириллической буквы фонемы (как в SoundDictionary title) на позу.
    /// Возвращает `nil`, если для звука нет научной 3D-позы (гласные/прочее) —
    /// тогда показывается видео-фоллбэк.
    static func fromCyrillic(_ cyrillic: String) -> ArticulationSound? {
        let normalized = cyrillic
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ь", with: "")
        switch normalized {
        case "с", "ц": return .s
        case "з": return .z
        case "ш", "ч", "щ": return .sh
        case "ж": return .zh
        case "р": return .r
        case "л": return .soundL
        case "к": return .k
        case "г": return .g
        case "х": return .kh
        default: return nil
        }
    }

    /// Индекс morph-target языка в порядке `ArticulationSound.morphOrder`.
    var morphIndex: Int {
        ArticulationSound.morphOrder.firstIndex(of: self) ?? 0
    }

    /// Порядок morph-целей в `SCNMorpher` (нейтраль базовая, не входит в morph-список).
    static let morphOrder: [ArticulationSound] = [
        .s, .z, .sh, .zh, .r, .soundL, .k, .g, .kh
    ]

    /// Звонкий звук → показывать волнистую глотту (голосовые связки вибрируют).
    var isVoiced: Bool {
        switch self {
        case .z, .zh, .r, .soundL, .g: return true
        case .neutral, .s, .sh, .k, .kh: return false
        }
    }

    /// Воздушная струя: тёплая широкая (Ш-группа) / холодная узкая (С-группа) / нет.
    var airstream: Airstream {
        switch self {
        case .s, .z: return .coldNarrow
        case .sh, .zh, .kh: return .warmWide
        case .r, .soundL, .k, .g, .neutral: return .none
        }
    }

    /// Подпись позы для SwiftUI-оверлея (краткая, без текста внутри 3D).
    var localizedHint: String {
        switch self {
        case .neutral:
            return String(localized: "articulation3d.pose.neutral")
        case .s, .z:
            return String(localized: "articulation3d.pose.s")
        case .sh, .zh:
            return String(localized: "articulation3d.pose.sh")
        case .r:
            return String(localized: "articulation3d.pose.r")
        case .soundL:
            return String(localized: "articulation3d.pose.l")
        case .k, .g:
            return String(localized: "articulation3d.pose.k")
        case .kh:
            return String(localized: "articulation3d.pose.kh")
        }
    }

    enum Airstream: Sendable {
        case none
        case coldNarrow
        case warmWide
    }
}

// MARK: - Цветовой хелпер
//
// SceneKit-материалам нужен UIColor, а не SwiftUI Color. Берём цвета из
// токен-colorset'ов через `UIColor(named:)` — те же ассеты, что и у DesignSystem.
// Fallback `.systemPink` некритичен (срабатывает только если colorset отсутствует
// в бандле, что в норме невозможно).

private func uiColor(_ name: String) -> UIColor {
    UIColor(named: name) ?? .systemPink
}

// Семантическое именование → colorset.
// Язык         : BrandRose
// Твёрдое нёбо : BrandLilac
// Мягкое нёбо  : BrandButter
// Зубы         : KidSurface  (кремово-белый)
// Кожа-контур  : BrandButter (полупрозрачный, opacity 0.22)
// Губы         : BrandPrimary (коралл)
// Нижняя челюсть: BrandPrimaryLo (светлый коралл)
// Глотка       : BrandPrimaryLo
// Голосовые связки (звонкость): BrandPrimary
// Холодная струя: BrandSky
// Тёплая струя : BrandGold

// MARK: - ArticulationModelBuilder
//
// Процедурная сборка сагиттального разреза головы из 2D-профилей органов.
// Каждый орган — `SCNShape(path: UIBezierPath, extrusionDepth:)` (экструзия
// профиля в объём + chamferRadius для скруглённых краёв) → объёмный слой-разрез.
// Язык — деформируемый меш с `SCNMorpher`: базовая геометрия + по одной
// morph-target-позе на звук (профили из укладов A-06).
//
// Профиль смотрит ВЛЕВО (как в Remotion-видео): передние зубы/губы слева,
// глотка справа. Координаты в «модельных миллиметрах» (~ -50…50 по X/Y).

@MainActor
enum ArticulationModelBuilder {

    // Глубина экструзии разреза (мм). Профиль смотрит влево, толщина — по Z.
    private static let sliceDepth: CGFloat = 11.0
    private static let chamfer: CGFloat = 1.6

    /// Корневой узел сцены: силуэт + все органы + язык. Возвращается готовым к
    /// добавлению в `SCNScene.rootNode`. Поза языка задаётся через morpher извне.
    static func buildModelNode() -> (root: SCNNode, tongue: SCNNode, glottis: SCNNode, airNodes: [ArticulationSound.Airstream: SCNNode]) {
        let root = SCNNode()
        root.name = "articulationModel"

        // Лёгкий наклон 3/4, чтобы читался объём разреза.
        root.eulerAngles = SCNVector3(-0.06, 0.42, 0.0)

        root.addChildNode(makeHeadSilhouette())
        root.addChildNode(makeHardPalate())
        root.addChildNode(makeSoftPalate())
        root.addChildNode(makeUpperTeeth())
        root.addChildNode(makeLowerTeeth())
        root.addChildNode(makeLips())
        root.addChildNode(makeLowerJaw())
        root.addChildNode(makePharynxWall())

        let glottis = makeGlottis()
        root.addChildNode(glottis)

        let tongue = makeTongueNode()
        root.addChildNode(tongue)

        // Индикаторы струй (скрыты по умолчанию, включаются под позу).
        var airNodes: [ArticulationSound.Airstream: SCNNode] = [:]
        let cold = makeAirstreamNode(.coldNarrow)
        let warm = makeAirstreamNode(.warmWide)
        airNodes[.coldNarrow] = cold
        airNodes[.warmWide] = warm
        root.addChildNode(cold)
        root.addChildNode(warm)

        return (root, tongue, glottis, airNodes)
    }

    // MARK: - Material helper

    private static func volumeMaterial(
        color: UIColor,
        transparency: CGFloat = 1.0,
        metalness: CGFloat = 0.0,
        roughness: CGFloat = 0.85
    ) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.metalness.contents = metalness
        m.roughness.contents = roughness
        m.transparency = transparency
        if transparency < 1.0 {
            m.blendMode = .alpha
            m.writesToDepthBuffer = false
            m.isDoubleSided = true
        }
        return m
    }

    private static func shapeNode(
        path: UIBezierPath,
        depth: CGFloat = sliceDepth,
        material: SCNMaterial,
        name: String
    ) -> SCNNode {
        path.flatness = 0.05
        let shape = SCNShape(path: path, extrusionDepth: depth)
        shape.chamferRadius = chamfer
        shape.materials = [material]
        let node = SCNNode(geometry: shape)
        node.name = name
        // Центрируем экструзию по Z, чтобы наклон смотрелся симметрично.
        node.position = SCNVector3(0, 0, Float(-depth / 2))
        return node
    }

    // MARK: - Head silhouette (полупрозрачный контур кожи)

    private static func makeHeadSilhouette() -> SCNNode {
        let p = UIBezierPath()
        // Профиль головы влево: лоб → нос → губы → подбородок → шея → затылок.
        p.move(to: CGPoint(x: -46, y: 6))      // кончик носа
        p.addCurve(to: CGPoint(x: -30, y: 40),  // лоб
                   controlPoint1: CGPoint(x: -48, y: 24),
                   controlPoint2: CGPoint(x: -44, y: 38))
        p.addCurve(to: CGPoint(x: 20, y: 46),   // макушка
                   controlPoint1: CGPoint(x: -12, y: 50),
                   controlPoint2: CGPoint(x: 6, y: 50))
        p.addCurve(to: CGPoint(x: 40, y: 6),    // затылок
                   controlPoint1: CGPoint(x: 38, y: 40),
                   controlPoint2: CGPoint(x: 42, y: 22))
        p.addCurve(to: CGPoint(x: 36, y: -34),  // шея сзади
                   controlPoint1: CGPoint(x: 38, y: -10),
                   controlPoint2: CGPoint(x: 38, y: -22))
        p.addLine(to: CGPoint(x: 14, y: -42))   // низ шеи
        p.addCurve(to: CGPoint(x: -26, y: -22), // подбородок
                   controlPoint1: CGPoint(x: -2, y: -40),
                   controlPoint2: CGPoint(x: -18, y: -30))
        p.addCurve(to: CGPoint(x: -44, y: -6),  // нижняя губа → нос снизу
                   controlPoint1: CGPoint(x: -34, y: -16),
                   controlPoint2: CGPoint(x: -42, y: -12))
        p.close()

        let mat = volumeMaterial(
            color: uiColor("BrandButter"),
            transparency: 0.22,
            roughness: 0.95
        )
        // Силуэт делаем глубже остальных слоёв, чтобы все органы «внутри» него.
        let node = shapeNode(path: p, depth: sliceDepth + 7, material: mat, name: "headSilhouette")
        node.renderingOrder = -10
        return node
    }

    // MARK: - Hard palate (твёрдое нёбо, lilac)

    private static func makeHardPalate() -> SCNNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -30, y: 16))
        p.addCurve(to: CGPoint(x: 4, y: 20),
                   controlPoint1: CGPoint(x: -18, y: 22),
                   controlPoint2: CGPoint(x: -8, y: 23))
        p.addLine(to: CGPoint(x: 6, y: 14))
        p.addCurve(to: CGPoint(x: -30, y: 10),
                   controlPoint1: CGPoint(x: -8, y: 16),
                   controlPoint2: CGPoint(x: -18, y: 15))
        p.close()
        let mat = volumeMaterial(color: uiColor("BrandLilac"), roughness: 0.7)
        return shapeNode(path: p, material: mat, name: "hardPalate")
    }

    // MARK: - Soft palate / velum (мягкое нёбо поднято, rose-butter)

    private static func makeSoftPalate() -> SCNNode {
        let p = UIBezierPath()
        // Поднятое велум: закрывает носоглотку (научный индикатор ротового звука).
        p.move(to: CGPoint(x: 4, y: 20))
        p.addCurve(to: CGPoint(x: 22, y: 22),
                   controlPoint1: CGPoint(x: 12, y: 24),
                   controlPoint2: CGPoint(x: 18, y: 26))
        p.addCurve(to: CGPoint(x: 24, y: 6),
                   controlPoint1: CGPoint(x: 26, y: 16),
                   controlPoint2: CGPoint(x: 26, y: 12))
        p.addCurve(to: CGPoint(x: 6, y: 14),
                   controlPoint1: CGPoint(x: 18, y: 10),
                   controlPoint2: CGPoint(x: 12, y: 12))
        p.close()
        let mat = volumeMaterial(color: uiColor("BrandRose"), roughness: 0.72)
        return shapeNode(path: p, material: mat, name: "softPalate")
    }

    // MARK: - Teeth (кремово-белые)

    private static func makeUpperTeeth() -> SCNNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -38, y: 8))
        p.addLine(to: CGPoint(x: -30, y: 9))
        p.addLine(to: CGPoint(x: -31, y: -1))
        p.addCurve(to: CGPoint(x: -38, y: 0),
                   controlPoint1: CGPoint(x: -33, y: -3),
                   controlPoint2: CGPoint(x: -36, y: -3))
        p.close()
        let mat = volumeMaterial(color: uiColor("KidSurface"), roughness: 0.35)
        let node = shapeNode(path: p, depth: sliceDepth + 1, material: mat, name: "upperTeeth")
        return node
    }

    private static func makeLowerTeeth() -> SCNNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -38, y: -8))
        p.addLine(to: CGPoint(x: -30, y: -9))
        p.addLine(to: CGPoint(x: -31, y: 0))
        p.addCurve(to: CGPoint(x: -38, y: -1),
                   controlPoint1: CGPoint(x: -33, y: -2),
                   controlPoint2: CGPoint(x: -36, y: -2))
        p.close()
        let mat = volumeMaterial(color: uiColor("KidSurface"), roughness: 0.35)
        let node = shapeNode(path: p, depth: sliceDepth + 1, material: mat, name: "lowerTeeth")
        return node
    }

    // MARK: - Lips (губы, коралл)

    private static func makeLips() -> SCNNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -44, y: 12))
        p.addCurve(to: CGPoint(x: -38, y: 6),
                   controlPoint1: CGPoint(x: -40, y: 11),
                   controlPoint2: CGPoint(x: -38, y: 9))
        p.addLine(to: CGPoint(x: -38, y: -6))
        p.addCurve(to: CGPoint(x: -44, y: -12),
                   controlPoint1: CGPoint(x: -38, y: -9),
                   controlPoint2: CGPoint(x: -40, y: -11))
        p.addCurve(to: CGPoint(x: -46, y: 0),
                   controlPoint1: CGPoint(x: -48, y: -8),
                   controlPoint2: CGPoint(x: -48, y: 8))
        p.close()
        let mat = volumeMaterial(color: uiColor("BrandPrimary"), roughness: 0.6)
        return shapeNode(path: p, material: mat, name: "lips")
    }

    // MARK: - Lower jaw (нижняя челюсть, коралл-кость)

    private static func makeLowerJaw() -> SCNNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -38, y: -12))
        p.addLine(to: CGPoint(x: 6, y: -16))
        p.addCurve(to: CGPoint(x: 14, y: -28),
                   controlPoint1: CGPoint(x: 12, y: -18),
                   controlPoint2: CGPoint(x: 14, y: -22))
        p.addLine(to: CGPoint(x: -34, y: -22))
        p.addCurve(to: CGPoint(x: -40, y: -14),
                   controlPoint1: CGPoint(x: -38, y: -20),
                   controlPoint2: CGPoint(x: -40, y: -17))
        p.close()
        let mat = volumeMaterial(color: uiColor("BrandPrimaryLo"), transparency: 0.55, roughness: 0.8)
        return shapeNode(path: p, material: mat, name: "lowerJaw")
    }

    // MARK: - Pharynx wall (задняя стенка глотки)

    private static func makePharynxWall() -> SCNNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 24, y: 22))
        p.addLine(to: CGPoint(x: 30, y: 22))
        p.addLine(to: CGPoint(x: 28, y: -32))
        p.addLine(to: CGPoint(x: 22, y: -32))
        p.close()
        let mat = volumeMaterial(color: uiColor("BrandPrimaryLo"), transparency: 0.7, roughness: 0.85)
        return shapeNode(path: p, depth: sliceDepth - 2, material: mat, name: "pharynxWall")
    }

    // MARK: - Glottis (индикатор звонкости — волнистая глотта)

    private static func makeGlottis() -> SCNNode {
        // Небольшая «волнистая лента» в нижней части глотки. Скрыта по умолчанию,
        // включается setVoiced(true) для звонких звуков.
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 22, y: -28))
        p.addCurve(to: CGPoint(x: 28, y: -34),
                   controlPoint1: CGPoint(x: 24, y: -30),
                   controlPoint2: CGPoint(x: 26, y: -30))
        p.addCurve(to: CGPoint(x: 22, y: -40),
                   controlPoint1: CGPoint(x: 26, y: -36),
                   controlPoint2: CGPoint(x: 24, y: -38))
        p.addCurve(to: CGPoint(x: 28, y: -46),
                   controlPoint1: CGPoint(x: 26, y: -42),
                   controlPoint2: CGPoint(x: 26, y: -44))
        p.addLine(to: CGPoint(x: 24, y: -46))
        p.addCurve(to: CGPoint(x: 19, y: -40),
                   controlPoint1: CGPoint(x: 21, y: -44),
                   controlPoint2: CGPoint(x: 21, y: -42))
        p.addCurve(to: CGPoint(x: 24, y: -34),
                   controlPoint1: CGPoint(x: 21, y: -38),
                   controlPoint2: CGPoint(x: 22, y: -36))
        p.addCurve(to: CGPoint(x: 18, y: -28),
                   controlPoint1: CGPoint(x: 21, y: -31),
                   controlPoint2: CGPoint(x: 20, y: -30))
        p.close()
        let glottisColor = uiColor("BrandPrimary")
        let mat = volumeMaterial(color: glottisColor, roughness: 0.5)
        mat.emission.contents = glottisColor.withAlphaComponent(0.35)
        let node = shapeNode(path: p, depth: sliceDepth - 3, material: mat, name: "glottis")
        node.opacity = 0.0   // по умолчанию глухой
        return node
    }

    // MARK: - Airstream indicators

    private static func makeAirstreamNode(_ kind: ArticulationSound.Airstream) -> SCNNode {
        let p = UIBezierPath()
        let color: UIColor
        switch kind {
        case .coldNarrow:
            // Узкая струя по центру через желобок (С): тонкая полоса вперёд-вниз.
            p.move(to: CGPoint(x: -30, y: 4))
            p.addLine(to: CGPoint(x: -52, y: -2))
            p.addLine(to: CGPoint(x: -52, y: -5))
            p.addLine(to: CGPoint(x: -30, y: 1))
            p.close()
            color = uiColor("BrandSky")
        case .warmWide:
            // Широкая тёплая струя (Ш): шире и выше.
            p.move(to: CGPoint(x: -28, y: 8))
            p.addLine(to: CGPoint(x: -52, y: 2))
            p.addLine(to: CGPoint(x: -52, y: -6))
            p.addLine(to: CGPoint(x: -28, y: 0))
            p.close()
            color = uiColor("BrandGold")
        case .none:
            color = .clear
        }
        let mat = volumeMaterial(color: color, transparency: 0.55, roughness: 0.4)
        mat.emission.contents = color.withAlphaComponent(0.3)
        let node = shapeNode(path: p, depth: sliceDepth - 4, material: mat, name: "airstream_\(kind)")
        node.opacity = 0.0
        return node
    }

    // MARK: - Tongue (деформируемый меш + morph targets)

    /// Узел языка с `SCNMorpher`. Базовая геометрия = нейтральная поза,
    /// morph-цели = по одной геометрии на звук (в порядке `morphOrder`).
    private static func makeTongueNode() -> SCNNode {
        let base = tongueGeometry(for: .neutral)
        let mat = volumeMaterial(color: uiColor("BrandRose"), roughness: 0.65)
        mat.specular.contents = uiColor("KidSurface").withAlphaComponent(0.25)
        base.materials = [mat]

        let node = SCNNode(geometry: base)
        node.name = "tongue"
        node.position = SCNVector3(0, 0, Float(-sliceDepth / 2))

        let morpher = SCNMorpher()
        morpher.targets = ArticulationSound.morphOrder.map { tongueGeometry(for: $0) }
        morpher.calculationMode = .normalized
        node.morpher = morpher

        return node
    }

    /// Геометрия профиля языка для конкретной позы (укладов A-06).
    /// Все позы строятся из ОДНОГО числа сегментов и контрольных точек, чтобы
    /// morph-цели были топологически совместимы (одинаковое число вершин).
    private static func tongueGeometry(for sound: ArticulationSound) -> SCNGeometry {
        let path = tonguePath(for: sound)
        // Фиксированная flatness → одинаковая тесселяция всех поз →
        // совместимая топология (одинаковое число вершин) для morph-целей.
        path.flatness = 0.05
        let shape = SCNShape(path: path, extrusionDepth: sliceDepth - 2)
        shape.chamferRadius = chamfer
        return shape
    }

    // Кол-во сэмплов на каждую из 4 quad-кривых верхнего контура языка.
    // Фиксировано → ВСЕ позы дают одинаковое число вершин → корректный morph
    // (SCNMorpher требует совпадения числа вершин базы и всех целей).
    private static let tongueCurveSamples = 14

    /// Профиль языка как UIBezierPath ИЗ ПРЯМЫХ СЕГМЕНТОВ (квад-кривые верхнего
    /// контура заранее сэмплированы в фикс. число точек). Прямые линии исключают
    /// зависимость тесселяции `SCNShape` от кривизны → одинаковая топология всех
    /// morph-целей. Меняются только координаты опорных точек спинки/кончика.
    private static func tonguePath(for sound: ArticulationSound) -> UIBezierPath {
        let pts = tongueControlPoints(for: sound)
        let p = UIBezierPath()
        p.move(to: pts.tip)
        appendQuadSamples(into: p, to: pts.front, control: pts.tipFrontCtrl, from: pts.tip)
        appendQuadSamples(into: p, to: pts.mid, control: pts.frontMidCtrl, from: pts.front)
        appendQuadSamples(into: p, to: pts.back, control: pts.midBackCtrl, from: pts.mid)
        appendQuadSamples(into: p, to: pts.root, control: pts.backRootCtrl, from: pts.back)
        // Низ языка (общий для всех поз — дно ротовой полости).
        p.addLine(to: CGPoint(x: 18, y: -16))
        p.addLine(to: CGPoint(x: -30, y: -14))
        p.close()
        return p
    }

    /// Сэмплирует квадратичную кривую Безье в `tongueCurveSamples` прямых
    /// отрезков (точка `from` уже добавлена вызывающим как текущая позиция).
    private static func appendQuadSamples(
        into path: UIBezierPath,
        to end: CGPoint,
        control: CGPoint,
        from start: CGPoint
    ) {
        for step in 1...tongueCurveSamples {
            let t = CGFloat(step) / CGFloat(tongueCurveSamples)
            let mt = 1 - t
            let x = mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x
            let y = mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }

    private struct TonguePoints {
        var tip: CGPoint
        var tipFrontCtrl: CGPoint
        var front: CGPoint
        var frontMidCtrl: CGPoint
        var mid: CGPoint
        var midBackCtrl: CGPoint
        var back: CGPoint
        var backRootCtrl: CGPoint
        var root: CGPoint
    }

    private static func tongueControlPoints(for sound: ArticulationSound) -> TonguePoints {
        switch sound {
        case .neutral:
            // Плоский язык покоя.
            return TonguePoints(
                tip: CGPoint(x: -32, y: -4),
                tipFrontCtrl: CGPoint(x: -26, y: -2),
                front: CGPoint(x: -18, y: -3),
                frontMidCtrl: CGPoint(x: -8, y: -2),
                mid: CGPoint(x: 2, y: -3),
                midBackCtrl: CGPoint(x: 10, y: -3),
                back: CGPoint(x: 16, y: -4),
                backRootCtrl: CGPoint(x: 20, y: -8),
                root: CGPoint(x: 20, y: -14)
            )
        case .s, .z:
            // С/З: кончик ВНИЗ к нижним резцам, передняя часть спинки ГОРКОЙ
            // вверх к твёрдому нёбу (с желобком), задняя опущена.
            return TonguePoints(
                tip: CGPoint(x: -34, y: -7),
                tipFrontCtrl: CGPoint(x: -28, y: 2),
                front: CGPoint(x: -20, y: 6),
                frontMidCtrl: CGPoint(x: -12, y: 4),
                mid: CGPoint(x: -2, y: -2),
                midBackCtrl: CGPoint(x: 8, y: -4),
                back: CGPoint(x: 16, y: -5),
                backRootCtrl: CGPoint(x: 20, y: -9),
                root: CGPoint(x: 20, y: -14)
            )
        case .sh, .zh:
            // Ш/Ж: двугорбый — кончик-«чашечка» ВВЕРХ к альвеолам, средняя
            // ПРОГНУТА, задняя ПРИПОДНЯТА к мягкому нёбу.
            return TonguePoints(
                tip: CGPoint(x: -32, y: 7),
                tipFrontCtrl: CGPoint(x: -27, y: 9),
                front: CGPoint(x: -22, y: 6),
                frontMidCtrl: CGPoint(x: -14, y: -1),
                mid: CGPoint(x: -2, y: -2),
                midBackCtrl: CGPoint(x: 8, y: 4),
                back: CGPoint(x: 16, y: 8),
                backRootCtrl: CGPoint(x: 20, y: 0),
                root: CGPoint(x: 20, y: -14)
            )
        case .r:
            // Р: «ложечка» — кончик ВВЕРХ к альвеолам (вибрирует), средняя
            // опущена, задняя приподнята.
            return TonguePoints(
                tip: CGPoint(x: -31, y: 9),
                tipFrontCtrl: CGPoint(x: -28, y: 10),
                front: CGPoint(x: -24, y: 4),
                frontMidCtrl: CGPoint(x: -14, y: -3),
                mid: CGPoint(x: -2, y: -4),
                midBackCtrl: CGPoint(x: 8, y: 0),
                back: CGPoint(x: 16, y: 4),
                backRootCtrl: CGPoint(x: 20, y: -4),
                root: CGPoint(x: 20, y: -14)
            )
        case .soundL:
            // Л: кончик ВВЕРХ к верхним резцам (смычка по центру), средняя
            // прогнута седлом, корень приподнят.
            return TonguePoints(
                tip: CGPoint(x: -33, y: 8),
                tipFrontCtrl: CGPoint(x: -29, y: 8),
                front: CGPoint(x: -24, y: 0),
                frontMidCtrl: CGPoint(x: -14, y: -5),
                mid: CGPoint(x: -2, y: -6),
                midBackCtrl: CGPoint(x: 8, y: -2),
                back: CGPoint(x: 16, y: 2),
                backRootCtrl: CGPoint(x: 20, y: -5),
                root: CGPoint(x: 20, y: -14)
            )
        case .k, .g:
            // К/Г: кончик ВНИЗ, ЗАДНЯЯ часть спинки СМЫКАЕТСЯ с мягким нёбом.
            return TonguePoints(
                tip: CGPoint(x: -32, y: -6),
                tipFrontCtrl: CGPoint(x: -26, y: -6),
                front: CGPoint(x: -18, y: -5),
                frontMidCtrl: CGPoint(x: -8, y: -3),
                mid: CGPoint(x: 2, y: 2),
                midBackCtrl: CGPoint(x: 12, y: 10),
                back: CGPoint(x: 20, y: 16),
                backRootCtrl: CGPoint(x: 22, y: 4),
                root: CGPoint(x: 20, y: -14)
            )
        case .kh:
            // Х: кончик ВНИЗ, задняя часть образует ЩЕЛЬ с мягким нёбом
            // (приподнята, но не смыкается).
            return TonguePoints(
                tip: CGPoint(x: -32, y: -6),
                tipFrontCtrl: CGPoint(x: -26, y: -6),
                front: CGPoint(x: -18, y: -5),
                frontMidCtrl: CGPoint(x: -8, y: -3),
                mid: CGPoint(x: 2, y: 0),
                midBackCtrl: CGPoint(x: 12, y: 6),
                back: CGPoint(x: 20, y: 11),
                backRootCtrl: CGPoint(x: 22, y: 0),
                root: CGPoint(x: 20, y: -14)
            )
        }
    }
}
