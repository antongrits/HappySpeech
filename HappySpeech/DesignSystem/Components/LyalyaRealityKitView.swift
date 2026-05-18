import OSLog
import RealityKit
import simd
import SwiftUI

// MARK: - LyalyaViseme

/// 6 логопедических визем для lip-sync маскота Ляли.
///
/// Используется совместно с ``LyalyaLipSyncCoordinator`` и `MascotLipSyncState`.
/// 3D-модель `lyalya3d_v3.usdz` не содержит blendshapes рта, поэтому виземы
/// сейчас управляют только 2D-оверлеем `MouthBubbleOverlay` (см. ``LyalyaMascotView``).
///
/// Маппинг на русские фонемы:
/// - `.a` → А, О, Э (открытый рот)
/// - `.i` → И, Е (широкая улыбка)
/// - `.uSound` → У, Ю (вытянутые вперёд губы)
/// - `.consonantClosed` → М, П, Б (плотно закрытые губы)
/// - `.consonantOpen` → С, Ш, Ж, Р, Л, З, Ц, Щ, Ч (чуть приоткрытый рот)
public enum LyalyaViseme: String, CaseIterable, Sendable {
    /// Нейтраль — рот в покое.
    case rest
    /// А, О, Э — широко открытый рот.
    case a
    /// И, Е — широкая улыбка, зубы видны.
    case i
    /// У, Ю — губы вытянуты вперёд.
    case uSound
    /// М, П, Б — плотно сомкнутые губы.
    case consonantClosed
    /// С, Ш, Ж, Р, Л, З, Ц, Щ, Ч — чуть приоткрытый рот.
    case consonantOpen
}

// MARK: - LyalyaRealityKitView

/// 3D-рендер маскота Ляли — RealityKit-обёртка над `lyalya3d_v3.usdz`.
///
/// `LyalyaRealityKitView` рендерит профессиональную 3D-модель Ляли (создана
/// в Blender по канону `AppIcon`: кремово-белая пчёлка-фея с большими глазами,
/// антеннами, розовыми щёчками и янтарными крылышками). Модель содержит
/// **запечённую idle-анимацию** (мягкое покачивание + трепет крыльев, 120 кадров).
///
/// ### Архитектура (ADR-V29-MASCOT-3D)
/// 3D-слой компонуется поверх 2D PNG-канона внутри ``HSMascotView``:
/// 2D-иллюстрация `mascot_lyalya_*` остаётся fallback-слоем (показывается при
/// ошибке загрузки USDZ или при Reduce Motion), а `LyalyaRealityKitView`
/// рендерится сверху, когда модель доступна.
///
/// ### Рендер
/// `ARView(cameraMode: .nonAR)` с прозрачным фоном (`isOpaque = false`) —
/// 3D-маскот композитится поверх SwiftUI без AR-камеры.
///
/// ### Ориентация модели
/// USD-файл экспортирован из Blender с `upAxis = Z`. RealityKit ожидает Y-up,
/// поэтому корневой Entity получает компенсирующий поворот -90° вокруг X,
/// чтобы Ляля стояла лицом к зрителю (см. `Self.uprightRotation`).
///
/// ### Reduced Motion
/// При `accessibilityReduceMotion = true` запечённая idle-анимация не
/// запускается — модель замирает в статичной позе первого кадра.
///
/// ## Пример
/// ```swift
/// LyalyaRealityKitView(onLoadResult: { ok in is3DReady = ok })
///     .frame(width: 160, height: 160)
/// ```
///
/// ## See Also
/// - ``HSMascotView``
/// - ``LyalyaMascotView``
public struct LyalyaRealityKitView: UIViewRepresentable {

    // MARK: - Public API

    /// Колбэк результата загрузки USDZ: `true` — модель загружена, `false` — ошибка.
    /// Родитель использует его, чтобы решить, показывать ли 2D-fallback.
    public var onLoadResult: ((Bool) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init

    public init(onLoadResult: ((Bool) -> Void)? = nil) {
        self.onLoadResult = onLoadResult
    }

    // MARK: - UIViewRepresentable

    public func makeUIView(context: Context) -> ARView {
        let arView = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)
        arView.isOpaque = false
        arView.renderOptions = [
            .disableAREnvironmentLighting,
            .disableDepthOfField,
            .disableMotionBlur,
            .disablePersonOcclusion
        ]

        context.coordinator.setup(
            into: arView,
            reduceMotion: reduceMotion,
            onLoadResult: onLoadResult
        )
        return arView
    }

    public func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.applyReduceMotion(reduceMotion)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.cleanup()
    }
}

// MARK: - Coordinator

public extension LyalyaRealityKitView {

    /// Coordinator управляет асинхронной загрузкой USDZ, кадрированием модели
    /// в кадре и запуском зацикленной запечённой idle-анимации.
    @MainActor
    final class Coordinator {

        // MARK: - Constants

        /// USD-файл собран в Blender с Z-up. RealityKit рендерит в Y-up,
        /// поэтому корневой Entity поворачивается на -90° вокруг X — модель
        /// встаёт вертикально лицом к камере.
        static let uprightRotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

        /// Дистанция камеры по Z — подобрана так, чтобы маскот занимал кадр
        /// целиком с небольшими полями (антенны и ножки не обрезаются).
        private static let cameraDistance: Float = 3.4

        // MARK: - State

        private var rootEntity: Entity?
        private var idleAnimation: AnimationResource?
        private var idleController: AnimationPlaybackController?
        private var reduceMotionEnabled = false

        private let logger = Logger(
            subsystem: "ru.happyspeech",
            category: "LyalyaRealityKitView"
        )

        // MARK: - Cleanup

        func cleanup() {
            idleController?.stop()
            idleController = nil
            idleAnimation = nil
            rootEntity = nil
        }

        // MARK: - Setup

        func setup(
            into arView: ARView,
            reduceMotion: Bool,
            onLoadResult: ((Bool) -> Void)?
        ) {
            reduceMotionEnabled = reduceMotion
            setupLighting(in: arView)
            setupCamera(in: arView)

            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.loadModel(into: arView, onLoadResult: onLoadResult)
            }
        }

        // MARK: - Scene composition

        private func setupCamera(in arView: ARView) {
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 30
            camera.position = [0, 0, Self.cameraDistance]

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(camera)
            arView.scene.addAnchor(anchor)
        }

        private func setupLighting(in arView: ARView) {
            let anchor = AnchorEntity(world: .zero)

            let keyLight = Entity()
            var directional = DirectionalLightComponent()
            directional.intensity = 2400
            keyLight.components.set(directional)
            keyLight.orientation = simd_quatf(angle: -.pi / 5, axis: [1, 0, 0])
            anchor.addChild(keyLight)

            let fillLight = Entity()
            var point = PointLightComponent()
            point.intensity = 1200
            point.attenuationRadius = 6.0
            fillLight.components.set(point)
            fillLight.position = [-0.6, 0.4, 1.2]
            anchor.addChild(fillLight)

            arView.scene.addAnchor(anchor)
        }

        // MARK: - Model loading

        private func loadModel(
            into arView: ARView,
            onLoadResult: ((Bool) -> Void)?
        ) async {
            guard let url = Bundle.main.url(
                forResource: "lyalya3d_v3",
                withExtension: "usdz",
                subdirectory: "ARAssets"
            ) ?? Bundle.main.url(
                forResource: "lyalya3d_v3",
                withExtension: "usdz"
            ) else {
                logger.warning("lyalya3d_v3.usdz не найден — остаётся 2D-fallback")
                onLoadResult?(false)
                return
            }

            do {
                let entity: Entity
                if #available(iOS 18.0, *) {
                    entity = try await Entity(contentsOf: url)
                } else {
                    entity = try Self.loadEntitySync(from: url)
                }

                frameEntity(entity)

                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(entity)
                arView.scene.addAnchor(anchor)

                rootEntity = entity
                idleAnimation = entity.availableAnimations.first
                startIdleAnimationIfNeeded()

                logger.info(
                    "lyalya3d_v3.usdz загружен. baked-анимаций: \(entity.availableAnimations.count)"
                )
                onLoadResult?(true)
            } catch {
                logger.error(
                    "Ошибка загрузки lyalya3d_v3.usdz: \(error.localizedDescription, privacy: .public)"
                )
                onLoadResult?(false)
            }
        }

        /// Synchronous wrapper для `Entity.load` — iOS 17 fallback.
        @available(iOS, introduced: 17.0, obsoleted: 18.0,
                   message: "Use Entity(contentsOf:) async init on iOS 18+.")
        private static func loadEntitySync(from url: URL) throws -> Entity {
            try Entity.load(contentsOf: url)
        }

        // MARK: - Framing

        /// Центрирует и масштабирует модель так, чтобы она занимала кадр,
        /// и компенсирует Z-up ориентацию исходного Blender-экспорта.
        private func frameEntity(_ entity: Entity) {
            entity.orientation = Self.uprightRotation

            let bounds = entity.visualBounds(relativeTo: nil)
            let extents = bounds.extents
            let maxExtent = max(extents.x, max(extents.y, extents.z))

            // Целевой видимый размер при выбранной камере/FOV.
            // < 1.0 — оставляет поля, чтобы антенны и ножки не упирались в край кадра.
            let targetSize: Float = 0.92
            if maxExtent > 0 {
                entity.scale = SIMD3<Float>(repeating: targetSize / maxExtent)
            }

            // Повторно вычисляем центр после масштаба и сдвигаем модель в (0,0,0).
            let scaledBounds = entity.visualBounds(relativeTo: nil)
            entity.position -= scaledBounds.center
        }

        // MARK: - Idle animation

        func applyReduceMotion(_ reduceMotion: Bool) {
            guard reduceMotion != reduceMotionEnabled else { return }
            reduceMotionEnabled = reduceMotion
            if reduceMotion {
                idleController?.stop()
                idleController = nil
            } else {
                startIdleAnimationIfNeeded()
            }
        }

        /// Запускает запечённую idle-анимацию в цикле.
        /// При Reduce Motion анимация не стартует — модель замирает статично.
        private func startIdleAnimationIfNeeded() {
            guard !reduceMotionEnabled,
                  idleController == nil,
                  let root = rootEntity,
                  let animation = idleAnimation else { return }

            idleController = root.playAnimation(
                animation.repeat(),
                transitionDuration: 0,
                startsPaused: false
            )
        }
    }
}

// MARK: - Preview

#Preview("LyalyaRealityKitView — 3D idle") {
    LyalyaRealityKitView()
        .frame(width: 220, height: 220)
        .background(ColorTokens.Brand.butter.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
        .padding(40)
}
