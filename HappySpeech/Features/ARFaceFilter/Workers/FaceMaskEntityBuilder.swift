import RealityKit
import UIKit

// MARK: - FaceMaskEntityBuilder
//
// A-03 / RealityKit-миграция: собирает 3D-аксессуар маски из примитивов
// RealityKit, доступных на iOS 13+ (generateBox, generateSphere, generatePlane).
// generateCone / generateCylinder НЕ используются — они требуют iOS 18+.
//
// Аппроксимации:
//   • конус-ушко  → узкий вытянутый box с corner radius (мультяшный треугольник)
//   • цилиндр     → сфера со scale(x:1, y:<0.3, z:1) даёт плоский диск / обод
//
// Координаты — face-anchor (метры): +X вправо, +Y вверх, +Z к камере.

@MainActor
enum FaceMaskEntityBuilder {

    // MARK: - Named reactive parts

    /// Имена дочерних сущностей, которыми управляет реактивность на мимику.
    enum PartName {
        static let leftEar  = "mask.part.leftEar"
        static let rightEar = "mask.part.rightEar"
        static let flaps    = "mask.part.flaps"
    }

    // MARK: - Public

    /// Собирает корневой аксессуар для выбранной маски.
    static func makeEntity(for mask: FaceMaskKind) -> Entity {
        let root = Entity()
        root.name = "mask.\(mask.rawValue)"
        switch mask {
        case .kitten:  buildKitten(into: root)
        case .fox:     buildFox(into: root)
        case .crown:   buildCrown(into: root)
        case .ushanka: buildUshanka(into: root)
        case .glasses: buildGlasses(into: root)
        }
        return root
    }

    // MARK: - Color helper

    /// `UIColor` из именованного colorset DesignSystem. Фолбэк — systemPink
    /// (сразу виден отсутствующий ассет, не прозрачный цвет).
    private static func uiColor(_ name: String) -> UIColor {
        UIColor(named: name) ?? .systemPink
    }

    // MARK: - Materials

    private static func material(_ color: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: 0.9, isMetallic: false)
    }

    private static func glassMaterial(_ color: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: 0.1, isMetallic: false)
    }

    // MARK: - Primitive helpers (iOS 13+ only)

    private static func sphere(radius: Float, color: UIColor) -> ModelEntity {
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material(color)])
    }

    private static func box(size: SIMD3<Float>, corner: Float, color: UIColor) -> ModelEntity {
        ModelEntity(mesh: .generateBox(size: size, cornerRadius: corner), materials: [material(color)])
    }

    /// Аппроксимация цилиндра: сфера, сплющенная по Y до плоского диска.
    /// `height` — толщина диска, `radius` — радиус.
    private static func diskSphere(radius: Float, height: Float, color: UIColor) -> ModelEntity {
        let entity = sphere(radius: radius, color: color)
        let scaleY = height / (2 * radius)   // сплюснуть до нужной высоты
        entity.scale = SIMD3(1, scaleY, 1)
        return entity
    }

    // MARK: - Kitten (котёнок)
    //
    // Мех — BrandButter, внутренность ушка / носик — BrandRose.
    // Ушко: два вложенных боксика с corner radius — мультяшный треугольник.

    private static func buildKitten(into root: Entity) {
        let furColor   = uiColor("BrandButter")
        let innerColor = uiColor("BrandRose")

        let leftEar = makeBoxEar(color: furColor, inner: innerColor)
        leftEar.name = PartName.leftEar
        leftEar.position = SIMD3(-0.055, 0.085, 0.02)
        leftEar.orientation = simd_quatf(angle: -0.25, axis: SIMD3(0, 0, 1))

        let rightEar = makeBoxEar(color: furColor, inner: innerColor)
        rightEar.name = PartName.rightEar
        rightEar.position = SIMD3(0.055, 0.085, 0.02)
        rightEar.orientation = simd_quatf(angle: 0.25, axis: SIMD3(0, 0, 1))

        let nose = sphere(radius: 0.009, color: innerColor)
        nose.position = SIMD3(0, -0.01, 0.075)

        root.addChild(leftEar)
        root.addChild(rightEar)
        root.addChild(nose)
    }

    /// Ушко из двух box'ов: широкий наружный + узкий внутренний (контраст цвета).
    private static func makeBoxEar(color: UIColor, inner: UIColor) -> Entity {
        let ear = Entity()
        // Наружный: вытянутый по Y, слегка скруглённый → мультяшное ушко.
        let outer = box(size: SIMD3(0.03, 0.05, 0.016), corner: 0.006, color: color)
        // Внутренний: чуть меньше, смещён вперёд.
        let innerBox = box(size: SIMD3(0.018, 0.034, 0.010), corner: 0.004, color: inner)
        innerBox.position = SIMD3(0, 0.002, 0.006)
        ear.addChild(outer)
        ear.addChild(innerBox)
        return ear
    }

    // MARK: - Fox (лиса)
    //
    // Мех — BrandPrimary, внутренность — KidSurface, нос — KidInk.
    // Мордочка: сплющенная сфера (имитирует округлый пятак) вместо конуса.

    private static func buildFox(into root: Entity) {
        let furColor   = uiColor("BrandPrimary")
        let creamColor = uiColor("KidSurface")
        let darkColor  = uiColor("KidInk")

        let leftEar = makeBoxEar(color: furColor, inner: creamColor)
        leftEar.name = PartName.leftEar
        leftEar.position = SIMD3(-0.05, 0.09, 0.02)
        leftEar.orientation = simd_quatf(angle: -0.2, axis: SIMD3(0, 0, 1))

        let rightEar = makeBoxEar(color: furColor, inner: creamColor)
        rightEar.name = PartName.rightEar
        rightEar.position = SIMD3(0.05, 0.09, 0.02)
        rightEar.orientation = simd_quatf(angle: 0.2, axis: SIMD3(0, 0, 1))

        // Мордочка: сфера, вытянутая по Z — выступает чуть вперёд.
        let snout = sphere(radius: 0.018, color: creamColor)
        snout.scale = SIMD3(0.8, 0.6, 1.2)
        snout.position = SIMD3(0, -0.005, 0.078)

        let nose = sphere(radius: 0.008, color: darkColor)
        nose.position = SIMD3(0, 0.0, 0.098)

        root.addChild(leftEar)
        root.addChild(rightEar)
        root.addChild(snout)
        root.addChild(nose)
    }

    // MARK: - Crown (корона)
    //
    // BrandGold — обруч + зубцы, BrandPrimary — самоцвет.
    // Обруч: тонкий горизонтальный box (охватывает лоб).
    // Зубцы: маленькие вертикальные box'ы по кругу.

    private static func buildCrown(into root: Entity) {
        let goldColor = uiColor("BrandGold")
        let gemColor  = uiColor("BrandPrimary")

        // Обруч — широкий тонкий горизонтальный бокс.
        let band = box(size: SIMD3(0.13, 0.022, 0.024), corner: 0.006, color: goldColor)
        band.position = SIMD3(0, 0.1, 0)

        // 6 зубцов: маленькие вертикальные боксики, расставленные по ширине обруча.
        let spikeCount = 6
        for i in 0..<spikeCount {
            let angle = Float(i) / Float(spikeCount) * 2 * .pi
            let spike = box(size: SIMD3(0.016, 0.03, 0.016), corner: 0.004, color: goldColor)
            let r: Float = 0.055
            spike.position = SIMD3(cos(angle) * r, 0.122, sin(angle) * r * 0.3)
            band.addChild(spike)
        }

        // Самоцвет — маленькая сфера спереди.
        let gem = sphere(radius: 0.01, color: gemColor)
        gem.position = SIMD3(0, 0.005, 0.014)
        band.addChild(gem)

        root.addChild(band)
    }

    // MARK: - Ushanka (шапка-ушанка)
    //
    // Купол — BrandLilac (сфера, сплющена по Y).
    // Меховой околыш — BrandButter (тонкий широкий бокс вместо цилиндра).
    // Клапаны — BrandButter box, подвижные.

    private static func buildUshanka(into root: Entity) {
        let clothColor = uiColor("BrandLilac")
        let furColor   = uiColor("BrandButter")

        // Купол: сфера, сплющенная по Y → полусфера-шапка.
        let dome = sphere(radius: 0.065, color: clothColor)
        dome.position = SIMD3(0, 0.085, 0)
        dome.scale = SIMD3(1.05, 0.65, 0.9)

        // Меховой околыш: тонкий горизонтальный бокс (вместо цилиндра).
        let band = box(size: SIMD3(0.14, 0.022, 0.05), corner: 0.006, color: furColor)
        band.position = SIMD3(0, 0.06, 0)

        // Боковые клапаны — подвижные (PartName.leftEar/rightEar).
        let leftFlap = box(size: SIMD3(0.022, 0.05, 0.02), corner: 0.008, color: furColor)
        leftFlap.name = PartName.leftEar
        leftFlap.position = SIMD3(-0.068, 0.035, 0)

        let rightFlap = box(size: SIMD3(0.022, 0.05, 0.02), corner: 0.008, color: furColor)
        rightFlap.name = PartName.rightEar
        rightFlap.position = SIMD3(0.068, 0.035, 0)

        root.addChild(dome)
        root.addChild(band)
        root.addChild(leftFlap)
        root.addChild(rightFlap)
    }

    // MARK: - Glasses (очки)
    //
    // Оправа — BrandGold, линзы — BrandSky (полупрозрачный, withAlphaComponent).
    // Кольцо оправы: сплющенная по Z сфера (diskSphere) → плоский диск-кольцо.
    // «Стекло»: такой же диск, но glassMaterial и чуть меньше.

    private static func buildGlasses(into root: Entity) {
        let frameColor = uiColor("BrandGold")
        let lensTint   = uiColor("BrandSky").withAlphaComponent(0.35)

        let lensRadius: Float = 0.022
        let leftRing = ringEntity(radius: lensRadius, color: frameColor, tint: lensTint)
        leftRing.position = SIMD3(-0.03, 0.0, 0.07)
        let rightRing = ringEntity(radius: lensRadius, color: frameColor, tint: lensTint)
        rightRing.position = SIMD3(0.03, 0.0, 0.07)

        let bridge = box(size: SIMD3(0.018, 0.004, 0.004), corner: 0.002, color: frameColor)
        bridge.position = SIMD3(0, 0.002, 0.07)

        root.addChild(leftRing)
        root.addChild(rightRing)
        root.addChild(bridge)
    }

    /// Кольцо очков: плоский диск-оправа (diskSphere) + стекло (glassMaterial).
    /// Обе части — сплющенные сферы (iOS 13+), без generateCylinder.
    private static func ringEntity(radius: Float, color: UIColor, tint: UIColor) -> Entity {
        let ring = Entity()

        // Оправа: диск толщиной 4 мм — сфера, сплющенная по Z.
        let frame = diskSphere(radius: radius, height: 0.004, color: color)

        // «Стекло»: тот же диск, чуть меньше радиус, glassMaterial.
        let glassEntity = sphere(radius: radius * 0.85, color: tint)
        glassEntity.scale = SIMD3(1, 1, 0.004 / (2 * radius * 0.85))
        // Меняем материал на glassMaterial для прозрачного вида.
        glassEntity.model?.materials = [glassMaterial(tint)]
        glassEntity.position = SIMD3(0, 0, 0)

        ring.addChild(frame)
        ring.addChild(glassEntity)
        return ring
    }
}
