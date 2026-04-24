import Combine
import OSLog
import RealityKit
import SwiftUI

// MARK: - LyalyaAnimation

/// Состояния анимации 3D-маскота Ляли.
/// Соответствуют смысловым состояниям Rive-маскота:
/// idle ↔ idle, waving ↔ listening, celebrating ↔ celebrating,
/// thinking ↔ thinking, pointing ↔ speaking, sad ↔ encouraging.
public enum LyalyaAnimation: String, CaseIterable, Sendable {
    case idle
    case waving
    case celebrating
    case thinking
    case pointing
    case sad

    /// Emoji-фоллбэк для 2D-режима когда USDZ не загрузился.
    var emoji: String {
        switch self {
        case .idle:        return "🦋"
        case .waving:      return "👋"
        case .celebrating: return "🎉"
        case .thinking:    return "🤔"
        case .pointing:    return "👆"
        case .sad:         return "🌈"
        }
    }

    /// Цвет градиента фоллбэка — из палитры бренда.
    var gradientColors: [Color] {
        switch self {
        case .idle:        return [Color("BrandLilac"), Color("BrandSky")]
        case .waving:      return [Color("BrandPrimary"), Color("BrandRose")]
        case .celebrating: return [Color("BrandButter"), Color("BrandGold")]
        case .thinking:    return [Color("BrandSky"), Color("BrandLilac")]
        case .pointing:    return [Color("BrandMint"), Color("BrandSky")]
        case .sad:         return [Color("BrandRose"), Color("BrandLilac")]
        }
    }
}

// MARK: - LyalyaAnimationHelper

/// Статический хелпер — применяет процедурную анимацию к Entity.
/// Используется обоими рендерерами (iOS17 + iOS18) чтобы не дублировать код.
enum LyalyaAnimationHelper {

    /// Применяет процедурную RealityKit-анимацию к Entity.
    /// Если USDZ содержит именованную анимацию — использует её.
    /// Иначе — генерирует через `FromToByAnimation` / `OrbitAnimation`.
    @MainActor
    static func apply(_ anim: LyalyaAnimation, to entity: Entity) {
        // Приоритет: именованные анимации внутри USDZ
        if let namedAnim = entity.availableAnimations.first(where: {
            $0.name?.lowercased() == anim.rawValue
        }) {
            entity.playAnimation(namedAnim.repeat())
            return
        }

        // Процедурные анимации через RealityKit API
        switch anim {

        case .idle:
            // Медленное вращение вокруг Y — «дышащий» idle
            let spin = OrbitAnimation(
                name: "idle-spin",
                duration: 8.0,
                axis: [0, 1, 0],
                startTransform: entity.transform,
                spinClockwise: false,
                orientToPath: false,
                rotationCount: 1.0,
                repeatMode: .repeat
            )
            if let res = try? AnimationResource.generate(with: spin) {
                entity.playAnimation(res)
            }

        case .waving:
            // Покачивание вправо-влево — имитация взмаха
            let waveAnim = FromToByAnimation<Transform>(
                name: "waving",
                from: Transform(rotation: simd_quatf(angle: .pi * 0.12, axis: [0, 0, 1])),
                to: Transform(rotation: simd_quatf(angle: -.pi * 0.12, axis: [0, 0, 1])),
                duration: MotionTokens.Duration.moderate,
                timing: .easeInOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let res = try? AnimationResource.generate(with: waveAnim) {
                entity.playAnimation(res)
            }

        case .celebrating:
            // Лёгкий подскок с поворотом — радость
            var upTransform = entity.transform
            upTransform.translation.y += 0.07
            upTransform.rotation = simd_quatf(angle: .pi * 0.25, axis: [0, 1, 0])
            let jumpAnim = FromToByAnimation<Transform>(
                name: "celebrating",
                from: entity.transform,
                to: upTransform,
                duration: MotionTokens.Duration.quick,
                timing: .easeOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let res = try? AnimationResource.generate(with: jumpAnim) {
                entity.playAnimation(res)
            }

        case .thinking:
            // Наклон головы — задумчивость
            let tiltAnim = FromToByAnimation<Transform>(
                name: "thinking",
                from: entity.transform,
                to: Transform(rotation: simd_quatf(angle: .pi * 0.08, axis: [0, 0, 1])),
                duration: MotionTokens.Duration.slow,
                timing: .easeInOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let res = try? AnimationResource.generate(with: tiltAnim) {
                entity.playAnimation(res)
            }

        case .pointing:
            // Пульсирующее увеличение — «смотри!»
            var bigTransform = entity.transform
            bigTransform.scale = SIMD3<Float>(repeating: 0.0048)
            let pulseAnim = FromToByAnimation<Transform>(
                name: "pointing",
                from: entity.transform,
                to: bigTransform,
                duration: MotionTokens.Duration.standard,
                timing: .easeInOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let res = try? AnimationResource.generate(with: pulseAnim) {
                entity.playAnimation(res)
            }

        case .sad:
            // Мягкое покачивание — грусть, но не пугающее
            let swayAnim = FromToByAnimation<Transform>(
                name: "sad",
                from: Transform(rotation: simd_quatf(angle: .pi * 0.05, axis: [0, 0, 1])),
                to: Transform(rotation: simd_quatf(angle: -.pi * 0.05, axis: [0, 0, 1])),
                duration: MotionTokens.Duration.slow,
                timing: .easeInOut,
                bindTarget: .transform,
                repeatMode: .autoReverse
            )
            if let res = try? AnimationResource.generate(with: swayAnim) {
                entity.playAnimation(res)
            }
        }
    }
}

// MARK: - LyalyaRealityView

/// SwiftUI-обёртка для 3D-маскота Ляли из `lyalya3d.usdz`.
///
/// Используется на экранах **Onboarding**, **Demo**, **SessionComplete**, **Rewards**.
///
/// Стратегия деградации:
/// - iOS 17+: `ARView(cameraMode: .nonAR)` через `UIViewRepresentable` (чистый 3D, без AR)
/// - iOS 18+: нативный `RealityView` (SwiftUI)
/// - Любая ошибка загрузки USDZ → 2D-фоллбэк (градиент + emoji)
///
/// Все длительности — через `MotionTokens`. Reduced Motion учтён.
///
/// ### Использование
/// ```swift
/// LyalyaRealityView(animation: .celebrating, size: 240)
/// LyalyaRealityView.large(animation: .waving)
/// ```
public struct LyalyaRealityView: View {

    // MARK: - Properties

    public let animation: LyalyaAnimation
    public let size: CGFloat

    @State private var loadFailed: Bool = false
    @State private var isVisible: Bool = false
    @State private var idleBobOffset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init

    public init(animation: LyalyaAnimation = .idle, size: CGFloat = 200) {
        self.animation = animation
        self.size = size
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if loadFailed {
                fallbackView
            } else {
                mascotContent
            }
        }
        .frame(width: size, height: size)
        .offset(y: idleBobOffset)
        .scaleEffect(isVisible ? 1 : 0.85)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .none : MotionTokens.bounce) {
                isVisible = true
            }
            if !reduceMotion && animation == .idle {
                withAnimation(MotionTokens.idlePulse) {
                    idleBobOffset = -5
                }
            }
        }
        .onChange(of: animation) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(MotionTokens.outQuick) { idleBobOffset = -8 }
            withAnimation(MotionTokens.outQuick.delay(MotionTokens.Duration.quick)) {
                idleBobOffset = animation == .idle ? -5 : 0
            }
        }
    }

    // MARK: - 3D Content

    @ViewBuilder
    private var mascotContent: some View {
        if #available(iOS 18, *) {
            Lyalya18View(
                animation: animation,
                size: size,
                onLoadFailed: { loadFailed = true }
            )
        } else {
            Lyalya17View(
                animation: animation,
                size: size,
                onLoadFailed: { loadFailed = true }
            )
        }
    }

    // MARK: - 2D Fallback

    /// Круглый градиентный фоллбэк с emoji.
    /// Активируется когда USDZ недоступен (симулятор без 3D-поддержки, ошибка загрузки).
    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: animation.gradientColors,
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .shadow(
                    color: (animation.gradientColors.first ?? .clear).opacity(0.35),
                    radius: 14, x: 0, y: 6
                )

            Text(animation.emoji)
                .font(.system(size: size * 0.45))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Lyalya17View (iOS 17+, ARView nonAR)

/// RealityKit через `ARView(cameraMode: .nonAR)` — 3D-рендерер без AR-камеры.
/// Доступен с iOS 13, является основным для таргета iOS 17+.
private struct Lyalya17View: UIViewRepresentable {

    let animation: LyalyaAnimation
    let size: CGFloat
    let onLoadFailed: () -> Void

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Lyalya17View")

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)
        arView.renderOptions = [.disableAREnvironmentLighting, .disableMotionBlur]

        setupCamera(in: arView)
        setupLighting(in: arView)

        context.coordinator.load(
            into: arView,
            animation: animation,
            logger: logger,
            onFailed: onLoadFailed
        )
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.update(animation: animation, logger: logger)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: Scene setup

    private func setupCamera(in arView: ARView) {
        let anchor = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 40
        camera.position = [0, 0, 0.5]
        anchor.addChild(camera)
        arView.scene.addAnchor(anchor)
    }

    private func setupLighting(in arView: ARView) {
        let anchor = AnchorEntity(world: .zero)
        let lightEntity = Entity()
        var directional = DirectionalLightComponent()
        directional.intensity = 1800
        lightEntity.components[DirectionalLightComponent.self] = directional
        lightEntity.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])
        anchor.addChild(lightEntity)
        arView.scene.addAnchor(anchor)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {

        private var mascotEntity: Entity?
        private var currentAnimation: LyalyaAnimation?
        private var cancellables = Set<AnyCancellable>()

        func load(
            into arView: ARView,
            animation: LyalyaAnimation,
            logger: Logger,
            onFailed: @escaping () -> Void
        ) {
            guard let url = Bundle.main.url(
                forResource: "lyalya3d",
                withExtension: "usdz",
                subdirectory: "ARAssets"
            ) else {
                logger.warning("lyalya3d.usdz не найден — 2D фоллбэк")
                onFailed()
                return
            }

            Entity.loadAsync(contentsOf: url)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        logger.error("Загрузка USDZ: \(error.localizedDescription, privacy: .public)")
                        onFailed()
                        self?.cancellables.removeAll()
                    }
                } receiveValue: { [weak self] entity in
                    guard let self else { return }
                    entity.scale = SIMD3<Float>(repeating: 0.004)
                    entity.position = [0, -0.1, 0]

                    let anchor = AnchorEntity(world: .zero)
                    anchor.addChild(entity)
                    arView.scene.addAnchor(anchor)

                    self.mascotEntity = entity
                    self.currentAnimation = animation
                    LyalyaAnimationHelper.apply(animation, to: entity)
                    self.cancellables.removeAll()
                }
                .store(in: &cancellables)
        }

        func update(animation: LyalyaAnimation, logger: Logger) {
            guard let entity = mascotEntity,
                  currentAnimation != animation else { return }
            currentAnimation = animation
            LyalyaAnimationHelper.apply(animation, to: entity)
        }
    }
}

// MARK: - Lyalya18View (iOS 18+, RealityView SwiftUI native)

@available(iOS 18, *)
private struct Lyalya18View: View {

    let animation: LyalyaAnimation
    let size: CGFloat
    let onLoadFailed: () -> Void

    @State private var mascotEntity: Entity?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Lyalya18View")

    var body: some View {
        RealityView { content in
            guard let url = Bundle.main.url(
                forResource: "lyalya3d",
                withExtension: "usdz",
                subdirectory: "ARAssets"
            ) else {
                logger.warning("lyalya3d.usdz не найден — 2D фоллбэк")
                onLoadFailed()
                return
            }

            do {
                let entity = try await ModelEntity(contentsOf: url)
                entity.scale = SIMD3<Float>(repeating: 0.004)
                entity.position = [0, -0.1, 0]

                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(entity)
                content.add(anchor)

                mascotEntity = entity
                LyalyaAnimationHelper.apply(animation, to: entity)
            } catch {
                logger.error("RealityView iOS18 ошибка: \(error.localizedDescription, privacy: .public)")
                onLoadFailed()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onChange(of: animation) { _, newAnim in
            guard let entity = mascotEntity else { return }
            LyalyaAnimationHelper.apply(newAnim, to: entity)
        }
    }
}

// MARK: - Convenience Factory

public extension LyalyaRealityView {

    /// Маленький — для inline карточек и списков.
    static func small(animation: LyalyaAnimation = .idle) -> LyalyaRealityView {
        LyalyaRealityView(animation: animation, size: 96)
    }

    /// Стандартный — для экранов сессии и HUD.
    static func medium(animation: LyalyaAnimation = .idle) -> LyalyaRealityView {
        LyalyaRealityView(animation: animation, size: 200)
    }

    /// Крупный — для Onboarding, Rewards, SessionComplete.
    static func large(animation: LyalyaAnimation = .idle) -> LyalyaRealityView {
        LyalyaRealityView(animation: animation, size: 280)
    }
}

// MARK: - Previews

#Preview("Idle medium") {
    LyalyaRealityView.medium(animation: .idle)
        .padding(SpacingTokens.sp8)
}

#Preview("Celebrating large") {
    LyalyaRealityView.large(animation: .celebrating)
        .padding(SpacingTokens.sp8)
}

#Preview("All states") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: SpacingTokens.sp4) {
            ForEach(LyalyaAnimation.allCases, id: \.self) { anim in
                VStack(spacing: SpacingTokens.sp2) {
                    LyalyaRealityView.small(animation: anim)
                    Text(anim.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(SpacingTokens.sp4)
    }
}
