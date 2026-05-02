import Observation
import SwiftUI

// MARK: - MascotLipSyncState

/// Real-time состояние lip-sync маскота Ляли, обновляемое из ARMirror через
/// ARFaceAnchor blendshapes. Распространяется через Environment в LyalyaMascotView.
///
/// Поток данных:
///   ARFaceAnchor → ARMirrorView.startFrameStream → MascotLipSyncState → MouthBubbleOverlay
///
/// Thread safety: весь доступ через @MainActor. Sendable обеспечивается тем,
/// что все свойства — value-types и изменяются только на MainActor.
@MainActor
@Observable
public final class MascotLipSyncState {

    // MARK: - Mouth

    /// Открытость рта 0...1 (0 = закрыт, 1 = широко открыт).
    /// Источник: ARFaceAnchor.blendShapes[.jawOpen].
    public var mouthOpen: Float = 0.0

    // MARK: - Viseme

    /// Текущая визема — для phoneme-based mouth shape overlay.
    /// Маппинг из UnifiedFacePoseWorker.currentViseme(_:).
    public var viseme: LipSyncViseme = .neutral

    // MARK: - Confidence

    /// Уверенность трекинга 0...1. Используется как opacity MouthBubbleOverlay.
    public var confidence: Float = 0.0

    // MARK: - Tracking flag

    /// true = ARSession активна и данные обновляются (TrueDepth camera работает).
    /// false = фолбэк: нет TrueDepth, сессия paused или устройство в background.
    public var isTracking: Bool = false

    // MARK: - Init

    public init() {}
}

// MARK: - LipSyncViseme

/// 5 логопедических визем для real-time lip-sync маскота.
/// Соответствует Viseme (UnifiedFacePoseWorker), но является отдельным типом
/// для слоя DesignSystem чтобы не создавать зависимость DesignSystem → ML.
public enum LipSyncViseme: String, Sendable, CaseIterable {
    /// Нейтральная поза — рот закрыт или почти закрыт.
    case neutral
    /// Открытый рот — А, Я (jawOpen > 0.6).
    case open
    /// Широкая улыбка — И, Е (lipsSmile > 0.4).
    case wide
    /// Округлённые губы — О, У (lipsPucker / lipsFunnel > 0.5).
    case rounded
    /// Улыбка-полуоткрыт — Ы, дефолтное состояние (mouthOpen 0.2..0.6).
    case smile
}

// MARK: - Viseme → LipSyncViseme conversion

public extension LipSyncViseme {

    /// Конвертация из Viseme (UnifiedFacePoseWorker) в LipSyncViseme (DesignSystem).
    /// Изолирует DesignSystem от прямой зависимости на ML-типы.
    init(from viseme: Viseme) {
        switch viseme {
        case .closed: self = .neutral
        case .a:      self = .open
        case .e:      self = .wide
        case .i:      self = .smile
        case .o:      self = .rounded
        case .u:      self = .rounded
        }
    }

    /// Конвертация в LyalyaViseme для использования в LyalyaRealityKitView (3D-маскот).
    /// LyalyaViseme — тип DesignSystem/RealityKit слоя, отдельный от LipSyncViseme.
    var lyalyaViseme: LyalyaViseme {
        switch self {
        case .neutral: return .rest
        case .open:    return .a
        case .wide:    return .i
        case .rounded: return .uSound
        case .smile:   return .consonantOpen
        }
    }
}
