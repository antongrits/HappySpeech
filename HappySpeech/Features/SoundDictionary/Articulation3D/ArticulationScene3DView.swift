import SceneKit
import SwiftUI
import UIKit

// MARK: - ArticulationScene3DView
//
// Интерактивная 3D-модель сагиттального разреза головы (вращаемая жестом).
// Стиль — объёмный мед-рендер для детей 5–8 (полупрозрачная кожа-контур,
// тёплая палитра, мягкий свет), эталон — Tinybop «The Human Body».
//
// Геометрия строится процедурно в `ArticulationModelBuilder` из научных
// укладов A-06. Поза языка задаётся через `SCNMorpher` и плавно
// интерполируется при смене звука. Под Reduced Motion переходы мгновенные.
//
// Рендер: SceneKit `SCNView` (работает в симуляторе, в отличие от RealityKit).
// Прозрачный фон → ложится на родительскую карточку SwiftUI.

// Хелпер: UIColor из colorset-токена (SceneKit-материалы и SCNLight не принимают
// SwiftUI Color, только UIColor). Fallback некритичен — colorset всегда в бандле.
private func uiColor(_ name: String) -> UIColor {
    UIColor(named: name) ?? .systemPink
}

struct ArticulationScene3DView: UIViewRepresentable {

    /// Текущая поза (выбранный звук).
    let sound: ArticulationSound
    /// Учитывать Reduced Motion: при true — без анимации морфа и без авто-вращения.
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.scene = context.coordinator.makeScene()
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = false   // вращаем сам узел модели жестом
        scnView.isJitteringEnabled = true
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = false

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        scnView.addGestureRecognizer(pan)
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
        private var modelNode: SCNNode?
        private var tongueNode: SCNNode?
        private var glottisNode: SCNNode?
        private var airNodes: [ArticulationSound.Airstream: SCNNode] = [:]
        private var currentSound: ArticulationSound?

        // Базовый наклон модели (3/4-вид) + накопленный поворот жестом.
        private var baseYaw: Float = 0.42
        private var basePitch: Float = -0.06

        func makeScene() -> SCNScene {
            let scene = SCNScene()
            scene.background.contents = UIColor.clear

            let built = ArticulationModelBuilder.buildModelNode()
            modelNode = built.root
            tongueNode = built.tongue
            glottisNode = built.glottis
            airNodes = built.airNodes
            scene.rootNode.addChildNode(built.root)

            // Камера: фронт к профилю, модель заполняет кадр.
            let cameraNode = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 38
            camera.zNear = 1
            camera.zFar = 1000
            camera.wantsHDR = false
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 2, 150)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)

            addWarmLighting(to: scene)
            return scene
        }

        private func addWarmLighting(to scene: SCNScene) {
            // Ключевой тёплый directional (мягкие тени).
            let keyNode = SCNNode()
            let key = SCNLight()
            key.type = .directional
            key.color = uiColor("BrandButter")
            key.intensity = 700
            key.castsShadow = true
            key.shadowMode = .deferred
            key.shadowRadius = 6
            key.shadowColor = uiColor("KidInk").withAlphaComponent(0.18)
            keyNode.light = key
            keyNode.position = SCNVector3(-60, 80, 120)
            keyNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(keyNode)

            // Заполняющий мягкий omni (убирает резкие тени).
            let fillNode = SCNNode()
            let fill = SCNLight()
            fill.type = .omni
            fill.color = uiColor("BrandButter")
            fill.intensity = 350
            fillNode.light = fill
            fillNode.position = SCNVector3(90, 30, 90)
            scene.rootNode.addChildNode(fillNode)

            // Мягкий ambient (тёплая база).
            let ambientNode = SCNNode()
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.color = uiColor("KidSurface")
            ambient.intensity = 260
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)
        }

        // MARK: Pose application

        func apply(sound: ArticulationSound, animated: Bool, reduceMotion: Bool) {
            guard let tongue = tongueNode, let morpher = tongue.morpher else { return }
            let changed = currentSound != sound
            currentSound = sound
            scnView?.rendersContinuously = false

            // Морф языка: вес 1.0 на нужную цель, 0.0 на остальные.
            let targetIndex = sound == .neutral ? nil : sound.morphIndex

            let setWeights = {
                for i in 0..<morpher.targets.count {
                    morpher.setWeight(i == targetIndex ? 1.0 : 0.0, forTargetAt: i)
                }
            }

            if animated && changed {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = MotionTokens.Duration.moderate
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(name: .easeInEaseOut)
                setWeights()
                SCNTransaction.commit()
            } else {
                setWeights()
            }

            // Звонкость → волнистая глотта.
            updateVoicing(sound.isVoiced, animated: animated && changed)
            // Воздушная струя.
            updateAirstream(sound.airstream, animated: animated && changed)
            // Вибрация кончика для Р (только если не reduceMotion).
            updateTongueVibration(active: sound == .r && !reduceMotion)
        }

        private func updateVoicing(_ voiced: Bool, animated: Bool) {
            guard let glottis = glottisNode else { return }
            let target: CGFloat = voiced ? 1.0 : 0.0
            if animated {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = MotionTokens.Duration.quick
                glottis.opacity = target
                SCNTransaction.commit()
            } else {
                glottis.opacity = target
            }
        }

        private func updateAirstream(_ kind: ArticulationSound.Airstream, animated: Bool) {
            for (k, node) in airNodes {
                let target: CGFloat = (k == kind) ? 0.85 : 0.0
                if animated {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = MotionTokens.Duration.quick
                    node.opacity = target
                    SCNTransaction.commit()
                } else {
                    node.opacity = target
                }
            }
        }

        private func updateTongueVibration(active: Bool) {
            guard let tongue = tongueNode else { return }
            let key = "tipVibration"
            if active {
                guard tongue.action(forKey: key) == nil else { return }
                let up = SCNAction.moveBy(x: 0, y: 0.6, z: 0, duration: 0.06)
                let down = SCNAction.moveBy(x: 0, y: -0.6, z: 0, duration: 0.06)
                let seq = SCNAction.sequence([up, down])
                tongue.runAction(SCNAction.repeatForever(seq), forKey: key)
                scnView?.rendersContinuously = true
            } else {
                tongue.removeAction(forKey: key)
            }
        }

        // MARK: Rotation gesture

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let model = modelNode, let view = scnView else { return }
            let translation = gesture.translation(in: view)
            // Чувствительность: полный свайп по ширине ≈ 1.5 рад.
            let yaw = baseYaw + Float(translation.x) * 0.006
            let pitch = basePitch + Float(translation.y) * 0.004
            // Ограничиваем pitch, чтобы разрез не «лёг» плашмя.
            let clampedPitch = max(-0.5, min(0.5, pitch))
            model.eulerAngles = SCNVector3(clampedPitch, yaw, 0)

            if gesture.state == .ended || gesture.state == .cancelled {
                baseYaw = yaw
                basePitch = clampedPitch
            }
        }
    }
}
