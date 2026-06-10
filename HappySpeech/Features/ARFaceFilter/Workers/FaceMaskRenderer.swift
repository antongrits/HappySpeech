import ARKit
import OSLog
import RealityKit
import SwiftUI

// MARK: - FaceMaskRenderer
//
// A-03 / RealityKit-миграция: маска теперь это 3D-аксессуар, привязанный к
// `AnchorEntity(.face)` — едет за лицом ребёнка (раньше был 2D SF-Symbol на
// спроецированной точке, помеченный «MVP», не прилипал к лицу).
//
// Аксессуары собираются из RealityKit-примитивов (`FaceMaskEntityBuilder`),
// внешние .usdz/.reality ассеты не требуются. Реактивность на мимику —
// `react(to:)` шевелит ушки/клапаны по `jawOpen` и улыбке.
//
// 2D-методы (`overlayOffset`, `glowColor`) сохранены как лёгкий fallback для
// устройств без TrueDepth (`isFaceTrackingSupported == false`), где AR-сцены
// нет и маска показывается 2D-оверлеем поверх тёплого фона.

@MainActor
final class FaceMaskRenderer: NSObject {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "FaceMaskRenderer")

    // MARK: - Public state

    /// Текущая маска. Обновляется через VIP.
    var currentMask: FaceMaskKind = .kitten

    /// Состояние подсветки.
    var glowState: FaceMaskState = .idle

    // MARK: - RealityKit anchor

    /// Текущий face-anchor с прикреплённой маской. Держим ссылку, чтобы
    /// реагировать на мимику и корректно снимать при смене маски.
    private weak var attachedArView: ARView?
    private var faceAnchor: AnchorEntity?
    private var maskEntity: Entity?
    private var reactiveLeftEar: Entity?
    private var reactiveRightEar: Entity?

    /// Базовые повороты ушек, чтобы реактивность отклоняла относительно них.
    private var leftEarBaseOrientation: simd_quatf = .init(angle: 0, axis: SIMD3(0, 0, 1))
    private var rightEarBaseOrientation: simd_quatf = .init(angle: 0, axis: SIMD3(0, 0, 1))

    // MARK: - Public API

    /// Доступность face tracking на устройстве (TrueDepth-камера / A12+).
    static var isFaceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    /// Стандартная конфигурация face tracking. Используется ARView wrapper.
    func makeConfiguration() -> ARFaceTrackingConfiguration {
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        return config
    }

    // MARK: - RealityKit: привязка маски к лицу

    /// Привязывает 3D-аксессуар выбранной маски к `AnchorEntity(.face)` в
    /// переданном `ARView`. Перед добавлением снимает прежний anchor, чтобы
    /// маски не стакались (`scene.anchors.removeAll()` + повторный append).
    func attachMask(_ mask: FaceMaskKind, to arView: ARView) {
        currentMask = mask
        attachedArView = arView

        // Снимаем всё прежнее — иначе при смене маски аксессуары накапливаются.
        arView.scene.anchors.removeAll()

        let anchor = AnchorEntity(.face)
        let entity = FaceMaskEntityBuilder.makeEntity(for: mask)
        anchor.addChild(entity)
        arView.scene.anchors.append(anchor)

        faceAnchor = anchor
        maskEntity = entity
        reactiveLeftEar = entity.findEntity(named: FaceMaskEntityBuilder.PartName.leftEar)
        reactiveRightEar = entity.findEntity(named: FaceMaskEntityBuilder.PartName.rightEar)
        leftEarBaseOrientation = reactiveLeftEar?.orientation ?? .init(angle: 0, axis: SIMD3(0, 0, 1))
        rightEarBaseOrientation = reactiveRightEar?.orientation ?? .init(angle: 0, axis: SIMD3(0, 0, 1))

        logger.debug("Attached 3D face mask \(mask.rawValue, privacy: .public) to face anchor")
    }

    /// Реакция аксессуара на мимику: ушки/клапаны слегка отклоняются, когда
    /// ребёнок открывает рот (`jawOpen`) или улыбается. Тонкая, не пугающая.
    /// Безопасно вызывать без присоединённой маски (no-op).
    func react(to blendshapes: FaceBlendshapes) {
        guard reactiveLeftEar != nil || reactiveRightEar != nil else { return }

        let smile = (blendshapes.mouthSmileLeft + blendshapes.mouthSmileRight) / 2
        // Сила «шевеления» 0…1: открытие рта + улыбка.
        let energy = min(1, blendshapes.jawOpen + smile)
        // Максимальное отклонение — мягкие ~17°.
        let maxSwing: Float = 0.3
        let swing = energy * maxSwing

        if let left = reactiveLeftEar {
            let delta = simd_quatf(angle: -swing, axis: SIMD3(0, 0, 1))
            left.orientation = leftEarBaseOrientation * delta
        }
        if let right = reactiveRightEar {
            let delta = simd_quatf(angle: swing, axis: SIMD3(0, 0, 1))
            right.orientation = rightEarBaseOrientation * delta
        }
    }

    /// Снимает маску и очищает сцену (вызывать при закрытии экрана).
    func detach() {
        attachedArView?.scene.anchors.removeAll()
        faceAnchor = nil
        maskEntity = nil
        reactiveLeftEar = nil
        reactiveRightEar = nil
        attachedArView = nil
    }

    // MARK: - 2D fallback (устройства без TrueDepth)

    /// Предустановки 2D-overlay для каждой маски (yOffset относительно центра
    /// лица). Используется ТОЛЬКО на устройствах без face tracking, где 3D-сцены
    /// нет и маска рисуется SF-Symbol-оверлеем поверх тёплого фона.
    func overlayOffset(for mask: FaceMaskKind) -> CGSize {
        switch mask {
        case .kitten:  return CGSize(width: 0, height: -90)    // ушки сверху
        case .fox:     return CGSize(width: 0, height: -90)    // мордочка сверху
        case .crown:   return CGSize(width: 0, height: -110)   // корона выше
        case .ushanka: return CGSize(width: 0, height: -100)   // шапка сверху
        case .glasses: return CGSize(width: 0, height: -25)    // очки на уровне глаз
        }
    }

    /// Цвет glow для выбранной маски (2D fallback + подсветка совпадения).
    func glowColor(for mask: FaceMaskKind) -> Color {
        switch mask {
        case .kitten:  return ColorTokens.Brand.butter
        case .fox:     return ColorTokens.Brand.rose
        case .crown:   return ColorTokens.Brand.gold
        case .ushanka: return ColorTokens.Brand.lilac
        case .glasses: return ColorTokens.Brand.primary
        }
    }
}
