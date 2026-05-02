import AVFoundation
import Combine
import OSLog
import RealityKit
import simd
import SwiftUI

// MARK: - LyalyaViseme

/// 6 логопедических визем для lip-sync 3D-маскота.
/// Используются совместно с `LyalyaRealityKitView` и `LyalyaLipSyncCoordinator`.
///
/// Маппинг на русские фонемы:
/// - `.a` → А, О, Э (открытый рот)
/// - `.i` → И, Е (широкая улыбка)
/// - `.u` → У, Ю (вытянутые вперёд губы)
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

/// UIViewRepresentable-обёртка над `ARView(cameraMode: .nonAR)` для 3D-маскота Ляли.
///
/// Реализует **compromise approach** (ADR-V13-LYALYA-3D-BLENDSHAPES-DEFERRED):
/// поскольку настоящие blendshapes требуют Blender / Reality Composer Pro (DCC-инструменты),
/// используются **named entity transform + material overrides** на основе `lyalya3d_v2.usdz`.
///
/// ### Named entities из lyalya3d_v2.usdz
/// - `Mouth` — целевой для scale-based lip-sync (scaleY: 0.2 closed → 1.6 open)
/// - `ArmLeft` — для `state_waving` (FromToByAnimation rotation X)
/// - `CheekLeft`, `CheekRight` — для `state_celebrating` (розовые щёки через material)
/// - `PupilLeft`, `PupilRight` — для blink (opacity 0 → 1)
///
/// ### Fallback стратегия (3 уровня)
/// 1. `lyalya3d_v2.usdz` загружен → RealityKit 3D рендер
/// 2. USDZ ошибка → `LyalyaRealityView` (legacy, через `onLoadFailed`)
/// 3. Оба недоступны → emoji fallback
///
/// ### Reduced Motion
/// При `accessibilityReduceMotion` = true: все idle-анимации не запускаются,
/// состояния применяются мгновенно без интерполяции.
///
/// ## Пример
/// ```swift
/// LyalyaRealityKitView(state: .celebrating, mood: 0.9)
/// LyalyaRealityKitView(state: .explaining, mouthOpen: lipSync.mouthOpen, viseme: lipSync.viseme)
/// ```
///
/// ## See Also
/// - ``LyalyaLipSyncCoordinator``
/// - ``LyalyaState``
/// - ``LyalyaViseme``
public struct LyalyaRealityKitView: UIViewRepresentable {

    // MARK: - Public API

    /// Текущее эмоциональное состояние маскота.
    public let state: LyalyaState
    /// Интенсивность эмоции 0.0–1.0.
    public let mood: Float
    /// Открытость рта 0.0–1.0 (из AVAudioPlayer amplitude или ARFaceAnchor).
    public let mouthOpen: Float
    /// Текущая визема для точной формы рта.
    public let viseme: LyalyaViseme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Опциональная подписка на кастомизацию Ляли (скин, цвет).
    /// Если LyalyaCustomizationStorage не внедрён в environment — используются defaults.
    @Environment(LyalyaCustomizationStorage.self) private var customization: LyalyaCustomizationStorage?
    /// Real-time lip-sync state из ARFaceAnchor blendshapes (Block L).
    /// Если ARSession активна (isTracking = true) — переопределяет параметры mouthOpen и viseme
    /// значениями из ARFaceAnchor для синхронизации рта маскота с ребёнком в реальном времени.
    /// Если ARSession неактивна — используются параметры переданные в init.
    @Environment(\.mascotLipSyncState) private var lipSyncState

    // MARK: - Init

    public init(
        state: LyalyaState = .idle,
        mood: Float = 0.5,
        mouthOpen: Float = 0,
        viseme: LyalyaViseme = .rest
    ) {
        self.state = state
        self.mood = mood
        self.mouthOpen = mouthOpen
        self.viseme = viseme
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
        arView.renderOptions = [
            .disableAREnvironmentLighting,
            .disableDepthOfField,
            .disableMotionBlur,
            .disablePersonOcclusion
        ]
        arView.isOpaque = false

        context.coordinator.loadScene(into: arView, reduceMotion: reduceMotion)
        return arView
    }

    public func updateUIView(_ uiView: ARView, context: Context) {
        // Block L: когда ARSession активна — lip-sync из ARFaceAnchor blendshapes
        // имеет приоритет над параметрами mouthOpen/viseme переданными в init.
        // Плавная lerp-интерполяция (α=0.2) выполняется внутри Coordinator.applyLipSyncSmoothed.
        // Reduced Motion: интерполяция отключается, mouth применяется мгновенно (snap).
        let effectiveMouthOpen: Float
        let effectiveViseme: LyalyaViseme
        if lipSyncState.isTracking {
            effectiveMouthOpen = lipSyncState.mouthOpen
            effectiveViseme = lipSyncState.viseme.lyalyaViseme
        } else {
            effectiveMouthOpen = mouthOpen
            effectiveViseme = viseme
        }
        context.coordinator.applyState(
            state,
            mood: mood,
            mouthOpen: effectiveMouthOpen,
            viseme: effectiveViseme,
            reduceMotion: reduceMotion,
            colorVariant: customization?.colorVariant
        )
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

// MARK: - Coordinator

extension LyalyaRealityKitView {

    /// Coordinator управляет загрузкой USDZ и применением состояний через
    /// named entity transform + material overrides (ADR-V13 compromise approach).
    @MainActor
    public final class Coordinator {

        // MARK: - Named entity references

        private var rootEntity: Entity?
        private var mouthEntity: Entity?
        private var armLeftEntity: Entity?
        private var cheekLeftEntity: Entity?
        private var cheekRightEntity: Entity?
        private var pupilLeftEntity: Entity?
        private var pupilRightEntity: Entity?

        // MARK: - Animation state

        private var animationControllers: [AnimationPlaybackController] = []
        private var blinkTimer: Timer?
        private var idleAnimTask: Task<Void, Never>?
        private var currentState: LyalyaState = .idle

        // MARK: - Lip-sync smoothing (Block L)

        /// Текущее сглаженное значение открытости рта (lerp α=0.2 на 60 fps).
        /// Хранится в Coordinator чтобы lerp работал между кадрами без jitter.
        private var smoothedMouthOpen: Float = 0.0
        /// Скорость интерполяции. Выбрана α=0.2 — баланс между отзывчивостью и плавностью.
        /// При Reduce Motion applyLipSyncSmoothed переключается в snap-режим (α=1.0).
        private static let lerpAlpha: Float = 0.2

        private let logger = Logger(subsystem: "ru.happyspeech", category: "LyalyaRealityKitView")

        // MARK: - Constants

        /// Базовый масштаб маскота (подобран под lyalya3d_v2.usdz геометрию).
        private static let baseScale: Float = 0.004
        /// Вертикальное смещение по Y для центровки в кадре.
        private static let basePositionY: Float = -0.1

        // MARK: - Scene setup

        func loadScene(into arView: ARView, reduceMotion: Bool) {
            // Освещение
            setupLighting(in: arView)

            // Загрузка USDZ
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.loadUSDZ(into: arView, reduceMotion: reduceMotion)
            }
        }

        private func setupLighting(in arView: ARView) {
            let anchor = AnchorEntity(world: .zero)

            let keyLight = Entity()
            var directional = DirectionalLightComponent()
            directional.intensity = 2000
            keyLight.components[DirectionalLightComponent.self] = directional
            keyLight.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])
            anchor.addChild(keyLight)

            let fillLight = Entity()
            var pointLight = PointLightComponent()
            pointLight.intensity = 800
            pointLight.attenuationRadius = 3.0
            fillLight.components[PointLightComponent.self] = pointLight
            fillLight.position = [-0.3, 0.2, 0.5]
            anchor.addChild(fillLight)

            arView.scene.addAnchor(anchor)
        }

        private func loadUSDZ(into arView: ARView, reduceMotion: Bool) async {
            guard let url = Bundle.main.url(
                forResource: "lyalya3d_v2",
                withExtension: "usdz",
                subdirectory: "ARAssets"
            ) else {
                logger.warning("lyalya3d_v2.usdz не найден в ARAssets — проверь Resources/ARAssets/")
                return
            }

            do {
                let entity = try await Entity.load(contentsOf: url)
                entity.scale = SIMD3<Float>(repeating: Self.baseScale)
                entity.position = [0, Self.basePositionY, 0]

                let cameraAnchor = AnchorEntity(world: .zero)
                let camera = PerspectiveCamera()
                camera.camera.fieldOfViewInDegrees = 40
                camera.position = [0, 0.0, 0.55]
                cameraAnchor.addChild(camera)
                arView.scene.addAnchor(cameraAnchor)

                let modelAnchor = AnchorEntity(world: .zero)
                modelAnchor.addChild(entity)
                arView.scene.addAnchor(modelAnchor)

                // Сохраняем ссылки на named entities
                self.rootEntity = entity
                self.mouthEntity = entity.findEntity(named: "Mouth")
                self.armLeftEntity = entity.findEntity(named: "ArmLeft")
                self.cheekLeftEntity = entity.findEntity(named: "CheekLeft")
                self.cheekRightEntity = entity.findEntity(named: "CheekRight")
                self.pupilLeftEntity = entity.findEntity(named: "PupilLeft")
                self.pupilRightEntity = entity.findEntity(named: "PupilRight")

                logger.info("lyalya3d_v2.usdz загружен. Mouth=\(self.mouthEntity != nil), ArmLeft=\(self.armLeftEntity != nil), Cheeks=\(self.cheekLeftEntity != nil)")

                if !reduceMotion {
                    startIdleAnimations(on: entity)
                }
            } catch {
                logger.error("Ошибка загрузки lyalya3d_v2.usdz: \(error.localizedDescription, privacy: .public)")
            }
        }

        // MARK: - State application

        /// Применяет состояние через transform + material overrides.
        func applyState(
            _ newState: LyalyaState,
            mood: Float,
            mouthOpen: Float,
            viseme: LyalyaViseme,
            reduceMotion: Bool,
            colorVariant: LyalyaColorVariant? = nil
        ) {
            guard rootEntity != nil else { return }

            if currentState != newState {
                currentState = newState
                applyEmotionState(newState, mood: mood, reduceMotion: reduceMotion)
            }

            applyLipSync(mouthOpen: mouthOpen, viseme: viseme, reduceMotion: reduceMotion)

            // Применяем цветовой вариант кастомизации к телу маскота
            if let variant = colorVariant {
                applyColorVariant(variant)
            }
        }

        // MARK: - Color variant (кастомизация скина)

        /// Применяет цвет тела из LyalyaCustomizationStorage.colorVariant.
        private func applyColorVariant(_ variant: LyalyaColorVariant) {
            guard let model = rootEntity?.findEntity(named: "Body") as? ModelEntity else { return }
            var material = SimpleMaterial()
            material.color = .init(tint: variant.uiColor)
            model.model?.materials = [material]
        }

        // MARK: - Lip-sync

        /// Применяет lip-sync через scale Mouth entity с lerp-сглаживанием.
        /// Mapping (ADR-V13 compromise):
        ///   scaleY: 0.2 (closed) → 1.6 (viseme_a открытый)
        ///
        /// Smooth lerp (α=0.2): smoothedMouthOpen += α * (target - smoothedMouthOpen).
        /// Reduced Motion: α=1.0 — мгновенный snap без анимации (WCAG 2.3.3 compliance).
        /// Вызывается из applyState → applyLipSync каждый кадр через updateUIView (60 fps).
        private func applyLipSync(mouthOpen: Float, viseme: LyalyaViseme, reduceMotion: Bool = false) {
            guard let mouth = mouthEntity else { return }

            // Lerp-интерполяция: плавное движение рта без jitter между ARFrame-обновлениями.
            // При Reduce Motion используем snap (α=1.0) — форма рта меняется мгновенно,
            // что всё равно даёт ребёнку визуальный feedback без анимации.
            let alpha = reduceMotion ? Float(1.0) : Self.lerpAlpha
            smoothedMouthOpen += alpha * (mouthOpen - smoothedMouthOpen)

            let (scaleX, scaleY) = visemeScale(viseme: viseme, mouthOpen: smoothedMouthOpen)
            mouth.transform.scale = SIMD3<Float>(scaleX, scaleY, 1.0)
        }

        private func visemeScale(viseme: LyalyaViseme, mouthOpen: Float) -> (scaleX: Float, scaleY: Float) {
            switch viseme {
            case .rest:
                // Закрытый рот: scaleY зависит от mouthOpen (0 → 0.2, 1 → 0.6)
                return (1.0, 0.2 + mouthOpen * 0.4)
            case .a:
                // А, О, Э — широко открытый
                return (0.8, 0.8 + mouthOpen * 0.8)
            case .i:
                // И, Е — широкая улыбка
                return (1.2 + mouthOpen * 0.2, 0.3 + mouthOpen * 0.3)
            case .uSound:
                // У, Ю — вытянутые вперёд
                return (0.5 + mouthOpen * 0.1, 0.5 + mouthOpen * 0.3)
            case .consonantClosed:
                // М, П, Б — плотно закрытые
                return (1.0, 0.1)
            case .consonantOpen:
                // С, Ш, Ж — чуть приоткрытый
                return (0.9 + mouthOpen * 0.2, 0.5 + mouthOpen * 0.4)
            }
        }

        // MARK: - Emotion states

        private func applyEmotionState(
            _ state: LyalyaState,
            mood: Float,
            reduceMotion: Bool
        ) {
            guard let root = rootEntity else { return }

            idleAnimTask?.cancel()
            animationControllers.forEach { $0.stop() }
            animationControllers.removeAll()

            if reduceMotion {
                applyStaticTransform(state, mood: mood, to: root)
                return
            }

            switch state {
            case .idle:
                applyIdleState(to: root)

            case .celebrating:
                // Радость: подпрыгивание + розовые щёки
                applyCheerfulCheeks(active: true, mood: mood)

                var upTransform = root.transform
                upTransform.translation.y += 0.04 * mood
                upTransform.rotation = simd_quatf(angle: .pi * 0.15 * mood, axis: [0, 1, 0])
                let jumpAnim = FromToByAnimation<Transform>(
                    name: "celebrating-jump",
                    from: root.transform,
                    to: upTransform,
                    duration: MotionTokens.Duration.quick,
                    timing: .easeOut,
                    bindTarget: .transform,
                    repeatMode: .autoReverse
                )
                if let res = try? AnimationResource.generate(with: jumpAnim) {
                    animationControllers.append(root.playAnimation(res))
                }

            case .thinking:
                // Наклон + медленные глаза вверх-вправо
                applyCheerfulCheeks(active: false, mood: 0)
                let thinkAngle: Float = 0.14 // ~8 градусов
                let thinkAnim = FromToByAnimation<Transform>(
                    name: "thinking-tilt",
                    from: root.transform,
                    to: Transform(rotation: simd_quatf(angle: thinkAngle, axis: [0, 0, 1])),
                    duration: MotionTokens.Duration.slow,
                    timing: .easeInOut,
                    bindTarget: .transform,
                    repeatMode: .autoReverse
                )
                if let res = try? AnimationResource.generate(with: thinkAnim) {
                    animationControllers.append(root.playAnimation(res))
                }

            case .sad:
                // Грусть: немного вниз
                applyCheerfulCheeks(active: false, mood: 0)
                var sadTransform = root.transform
                sadTransform.translation.y -= 0.03
                let sadAnim = FromToByAnimation<Transform>(
                    name: "sad-droop",
                    from: root.transform,
                    to: sadTransform,
                    duration: MotionTokens.Duration.slow,
                    timing: .easeInOut,
                    bindTarget: .transform,
                    repeatMode: .autoReverse
                )
                if let res = try? AnimationResource.generate(with: sadAnim) {
                    animationControllers.append(root.playAnimation(res))
                }
                // Рот вниз — выставляем сразу через scale
                mouthEntity?.transform.scale = SIMD3<Float>(1.1, 0.3, 1.0)
                // Уголки вниз через rotation Z (если есть отдельный entity)
                if let mouth = mouthEntity {
                    let sadMouthAngle: Float = -.pi * 0.08
                    mouth.orientation = simd_quatf(angle: sadMouthAngle, axis: [0, 0, 1])
                }

            case .waving:
                // Взмах левой руки через FromToByAnimation
                if let arm = armLeftEntity {
                    let waveAnim = FromToByAnimation<Transform>(
                        name: "arm-wave",
                        from: Transform(rotation: simd_quatf(angle: 0, axis: [1, 0, 0])),
                        to: Transform(rotation: simd_quatf(angle: -.pi * 0.4, axis: [1, 0, 0])),
                        duration: MotionTokens.Duration.moderate,
                        timing: .easeInOut,
                        bindTarget: .transform,
                        repeatMode: .autoReverse
                    )
                    if let res = try? AnimationResource.generate(with: waveAnim) {
                        animationControllers.append(arm.playAnimation(res))
                    }
                }

            case .pointing:
                // Пульсирующее увеличение — «смотри!»
                var bigTransform = root.transform
                bigTransform.scale = SIMD3<Float>(repeating: Self.baseScale * 1.08)
                let pulseAnim = FromToByAnimation<Transform>(
                    name: "pointing-pulse",
                    from: root.transform,
                    to: bigTransform,
                    duration: MotionTokens.Duration.standard,
                    timing: .easeInOut,
                    bindTarget: .transform,
                    repeatMode: .autoReverse
                )
                if let res = try? AnimationResource.generate(with: pulseAnim) {
                    animationControllers.append(root.playAnimation(res))
                }

            case .explaining, .singing:
                // Лёгкое покачивание головы — оживлённое объяснение / пение
                let explainAnim = FromToByAnimation<Transform>(
                    name: "explaining-bob",
                    from: Transform(rotation: simd_quatf(angle: .pi * 0.03, axis: [0, 0, 1])),
                    to: Transform(rotation: simd_quatf(angle: -.pi * 0.03, axis: [0, 0, 1])),
                    duration: MotionTokens.Duration.moderate,
                    timing: .easeInOut,
                    bindTarget: .transform,
                    repeatMode: .autoReverse
                )
                if let res = try? AnimationResource.generate(with: explainAnim) {
                    animationControllers.append(root.playAnimation(res))
                }

            case .happy, .encouraging:
                // Радость/поддержка: слабый вариант celebrating
                applyCheerfulCheeks(active: true, mood: mood * 0.5)
                var happyTransform = root.transform
                happyTransform.translation.y += 0.02 * mood
                let happyAnim = FromToByAnimation<Transform>(
                    name: "happy-bounce",
                    from: root.transform,
                    to: happyTransform,
                    duration: MotionTokens.Duration.quick,
                    timing: .easeOut,
                    bindTarget: .transform,
                    repeatMode: .autoReverse
                )
                if let res = try? AnimationResource.generate(with: happyAnim) {
                    animationControllers.append(root.playAnimation(res))
                }
            }
        }

        /// Применяет статичный transform без анимации (для Reduce Motion).
        private func applyStaticTransform(
            _ state: LyalyaState,
            mood: Float,
            to root: Entity
        ) {
            switch state {
            case .idle:
                root.transform = Transform(scale: SIMD3<Float>(repeating: Self.baseScale))
            case .celebrating:
                applyCheerfulCheeks(active: true, mood: mood)
                root.transform = Transform(scale: SIMD3<Float>(repeating: Self.baseScale * (1 + 0.05 * mood)))
            case .sad:
                mouthEntity?.transform.scale = SIMD3<Float>(1.1, 0.3, 1.0)
                applyCheerfulCheeks(active: false, mood: 0)
            default:
                root.transform = Transform(scale: SIMD3<Float>(repeating: Self.baseScale))
                applyCheerfulCheeks(active: false, mood: 0)
            }
        }

        // MARK: - Cheeks (celebrating state)

        /// Изменяет цвет щёк через SimpleMaterial — розоватые для celebrating.
        private func applyCheerfulCheeks(active: Bool, mood: Float) {
            let cheekColor: UIColor = active
                ? UIColor(red: 1.0, green: 0.65, blue: 0.65, alpha: min(1.0, 0.5 + Double(mood) * 0.5))
                : UIColor(red: 0.95, green: 0.82, blue: 0.82, alpha: 0.3)

            [cheekLeftEntity, cheekRightEntity].forEach { cheekEntity in
                guard let model = cheekEntity as? ModelEntity else { return }
                var material = SimpleMaterial()
                material.color = .init(tint: cheekColor)
                model.model?.materials = [material]
            }

            if active && mood > 0.5 {
                let cheekScale: Float = 1.0 + (mood - 0.5) * 0.3
                cheekLeftEntity?.transform.scale = SIMD3<Float>(repeating: cheekScale)
                cheekRightEntity?.transform.scale = SIMD3<Float>(repeating: cheekScale)
            }
        }

        // MARK: - Idle animations (blink + breathing + head sway)

        private func startIdleAnimations(on entity: Entity) {
            // Breathing: root scale 1.0 → 1.02 → 1.0 (4-секундный цикл)
            startBreathing(on: entity)

            // Head sway: rotation Y ±2° медленный синус
            startHeadSway(on: entity)

            // Blink: каждые 3–5 сек
            scheduleBlink()
        }

        private func startBreathing(on entity: Entity) {
            idleAnimTask = Task { @MainActor [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    let baseScaleVec = SIMD3<Float>(repeating: Self.baseScale)
                    let breathScaleVec = SIMD3<Float>(repeating: Self.baseScale * 1.02)
                    let breathIn = FromToByAnimation<Transform>(
                        name: "breath-in",
                        from: Transform(scale: baseScaleVec),
                        to: Transform(scale: breathScaleVec),
                        duration: 2.0,
                        timing: .easeInOut,
                        bindTarget: .transform,
                        repeatMode: .none
                    )
                    let breathOut = FromToByAnimation<Transform>(
                        name: "breath-out",
                        from: Transform(scale: breathScaleVec),
                        to: Transform(scale: baseScaleVec),
                        duration: 2.0,
                        timing: .easeInOut,
                        bindTarget: .transform,
                        repeatMode: .none
                    )
                    if let resIn = try? AnimationResource.generate(with: breathIn) {
                        let ctrl = entity.playAnimation(resIn)
                        self.animationControllers.append(ctrl)
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if Task.isCancelled { break }
                    if let resOut = try? AnimationResource.generate(with: breathOut) {
                        let ctrl = entity.playAnimation(resOut)
                        self.animationControllers.append(ctrl)
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        private func startHeadSway(on entity: Entity) {
            let swayRight = FromToByAnimation<Transform>(
                name: "sway-right",
                from: Transform(rotation: simd_quatf(angle: .pi * 0.035, axis: [0, 1, 0])),
                to: Transform(rotation: simd_quatf(angle: -.pi * 0.035, axis: [0, 1, 0])),
                duration: 3.5,
                timing: .easeInOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let res = try? AnimationResource.generate(with: swayRight) {
                animationControllers.append(entity.playAnimation(res))
            }
        }

        private func scheduleBlink() {
            blinkTimer?.invalidate()
            // Случайный интервал 3–5 секунд
            let interval = TimeInterval.random(in: 3.0...5.0)
            blinkTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.performBlink()
                }
            }
        }

        private func performBlink() {
            [pupilLeftEntity, pupilRightEntity].forEach { pupil in
                guard let model = pupil as? ModelEntity else { return }
                var closedMat = SimpleMaterial()
                closedMat.color = .init(tint: .black)
                model.model?.materials = [closedMat]
            }

            // Через 0.1 секунды — открыть
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self else { return }
                [self.pupilLeftEntity, self.pupilRightEntity].forEach { pupil in
                    guard let model = pupil as? ModelEntity else { return }
                    var openMat = SimpleMaterial()
                    openMat.color = .init(tint: .darkGray)
                    model.model?.materials = [openMat]
                }
                self.scheduleBlink()
            }
        }

        private func applyIdleState(to root: Entity) {
            // Idle: лёгкое медленное вращение вокруг Y
            let idleSpin = OrbitAnimation(
                name: "idle-slow-spin",
                duration: 12.0,
                axis: [0, 1, 0],
                startTransform: root.transform,
                spinClockwise: false,
                orientToPath: false,
                rotationCount: 1.0,
                repeatMode: .repeat
            )
            if let res = try? AnimationResource.generate(with: idleSpin) {
                animationControllers.append(root.playAnimation(res))
            }
        }
    }
}

// MARK: - Previews

#Preview("LyalyaRealityKitView — idle") {
    LyalyaRealityKitView(state: .idle, mood: 0.5)
        .frame(width: 200, height: 200)
        .background(Color(.systemBackground))
        .clipShape(Circle())
}

#Preview("LyalyaRealityKitView — celebrating") {
    LyalyaRealityKitView(state: .celebrating, mood: 1.0)
        .frame(width: 240, height: 240)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 24))
}

#Preview("LyalyaRealityKitView — lip-sync visemes") {
    @Previewable @State var currentViseme: LyalyaViseme = .rest
    @Previewable @State var openVal: Float = 0.5

    VStack(spacing: 16) {
        LyalyaRealityKitView(state: .explaining, mouthOpen: openVal, viseme: currentViseme)
            .frame(width: 200, height: 200)

        Picker(String(localized: "lyalya.viseme.picker.label"), selection: $currentViseme) {
            ForEach(LyalyaViseme.allCases, id: \.rawValue) { v in
                Text(v.rawValue).tag(v)
            }
        }
        .pickerStyle(.segmented)

        Slider(value: $openVal, in: 0...1)
            .padding(.horizontal)
    }
    .padding()
}
