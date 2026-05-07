import ARKit
import OSLog
import SwiftUI

// MARK: - FaceMaskRenderer
//
// Block S.4 v16 — Worker: 2D-overlay рендер маски поверх лица в ARSession.
// Не рендерит 3D — только 2D overlay (emoji / SF Symbols) с pivot-to-face.
//
// MVP подход: ARFaceTrackingConfiguration активен, но мы НЕ рендерим
// SCNNode. Вместо этого показываем эмоджи на CGPoint, рассчитываемый
// из anchor.transform projected на screen. Это достаточно для fun-mode.

@MainActor
final class FaceMaskRenderer: NSObject {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "FaceMaskRenderer")

    // MARK: - Public state

    /// Текущая маска. Обновляется через VIP.
    var currentMask: FaceMaskKind = .kitten

    /// Состояние подсветки.
    var glowState: FaceMaskState = .idle

    // MARK: - Public API

    /// Доступность face tracking на устройстве (TrueDepth-камера).
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

    /// Предустановки overlay для каждой маски (yOffset относительно центра лица).
    func overlayOffset(for mask: FaceMaskKind) -> CGSize {
        switch mask {
        case .kitten:  return CGSize(width: 0,   height: -90)   // ушки сверху
        case .fox:     return CGSize(width: 0,   height: -90)   // мордочка сверху
        case .crown:   return CGSize(width: 0,   height: -110)  // корона выше
        case .ushanka: return CGSize(width: 0,   height: -100)  // шапка сверху
        case .glasses: return CGSize(width: 0,   height: -25)   // очки на уровне глаз
        }
    }

    /// Цвет glow для выбранной маски.
    func glowColor(for mask: FaceMaskKind) -> Color {
        switch mask {
        case .kitten:  return ColorTokens.Brand.butter
        case .fox:     return ColorTokens.Brand.rose
        case .crown:   return ColorTokens.Brand.gold
        case .ushanka: return ColorTokens.Brand.sky
        case .glasses: return ColorTokens.Brand.lilac
        }
    }
}

// NOTE deferred to Block Q (test coverage): integration test with ARSession mock.
