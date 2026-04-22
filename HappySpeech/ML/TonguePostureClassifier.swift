import Foundation
import OSLog

// MARK: - ArticulationPosture

/// Артикуляционная поза, определяемая по ARKit blendshapes.
/// В M4 будет заменена on-device Core ML-классификатором; пока — rule-based.
public enum ArticulationPosture: String, Sendable, CaseIterable, Hashable {
    case neutral       // нейтральное положение
    case cupShape      // «чашечка» — язык приподнят, края загнуты
    case shoveling     // «лопаточка» — широкий распластанный
    case mushroom      // «грибок» — присосан к нёбу
    case painter       // «маляр» — движение по нёбу
    case smile         // широкая улыбка
    case pucker        // «хоботок» / трубочка
    case tongueUp      // язык вверх
    case tongueDown    // язык вниз
    case tongueLeft    // влево
    case tongueRight   // вправо

    /// Локализованное название позы для UI.
    public var displayName: String {
        switch self {
        case .neutral:     return String(localized: "posture.neutral")
        case .cupShape:    return String(localized: "posture.cupShape")
        case .shoveling:   return String(localized: "posture.shoveling")
        case .mushroom:    return String(localized: "posture.mushroom")
        case .painter:     return String(localized: "posture.painter")
        case .smile:       return String(localized: "posture.smile")
        case .pucker:      return String(localized: "posture.pucker")
        case .tongueUp:    return String(localized: "posture.tongueUp")
        case .tongueDown:  return String(localized: "posture.tongueDown")
        case .tongueLeft:  return String(localized: "posture.tongueLeft")
        case .tongueRight: return String(localized: "posture.tongueRight")
        }
    }
}

// MARK: - TonguePostureClassifier

/// Rule-based классификатор поз на основе ARKit blendshapes.
/// Этот класс — контракт для будущей Core ML модели в M4.
public final class TonguePostureClassifier: @unchecked Sendable {

    public init() {}

    /// Возвращает наиболее вероятную позу для кадра blendshapes.
    public func classify(_ blendshapes: FaceBlendshapes) -> ArticulationPosture {
        // Приоритет: специфичные позы > общие.
        // Эти пороги эмпирические; будут уточнены датасетом в M4.

        if blendshapes.mouthPucker > 0.6 {
            return .pucker
        }
        if blendshapes.mouthFunnel > 0.6 {
            return .cupShape
        }
        if blendshapes.mouthRollLower > 0.5 && blendshapes.mouthRollUpper > 0.5 {
            return .mushroom
        }
        if blendshapes.isTongueOut {
            if blendshapes.jawOpen > 0.5 {
                return .tongueUp
            }
            return .shoveling
        }
        if blendshapes.mouthSmileLeft > 0.5 && blendshapes.mouthSmileRight > 0.5 {
            return .smile
        }
        if blendshapes.mouthLeft > 0.5 {
            return .tongueLeft
        }
        if blendshapes.mouthRight > 0.5 {
            return .tongueRight
        }
        if blendshapes.jawForward > 0.4 {
            return .painter
        }
        if blendshapes.jawOpen > 0.4 {
            return .tongueDown
        }
        return .neutral
    }

    /// 0…1 confidence, что поза `posture` поддерживается текущим кадром.
    /// Используется для прогресс-баров и "удержания позы" в играх.
    public func confidence(_ blendshapes: FaceBlendshapes, for posture: ArticulationPosture) -> Float {
        switch posture {
        case .neutral:
            // Чем спокойнее лицо — тем выше confidence нейтрального.
            let activity = blendshapes.jawOpen
                + blendshapes.mouthFunnel
                + blendshapes.mouthPucker
                + blendshapes.tongueOut
                + blendshapes.mouthSmileLeft
                + blendshapes.mouthSmileRight
            return max(0, 1 - min(1, activity / 2))

        case .smile:
            return clamp((blendshapes.mouthSmileLeft + blendshapes.mouthSmileRight) / 1.4)

        case .pucker:
            return clamp(blendshapes.mouthPucker / 0.8)

        case .cupShape:
            return clamp(blendshapes.mouthFunnel / 0.8)

        case .mushroom:
            let roll = (blendshapes.mouthRollLower + blendshapes.mouthRollUpper) / 2
            return clamp(roll / 0.7)

        case .shoveling:
            return clamp(blendshapes.tongueOut * (1 - blendshapes.jawOpen) / 0.6)

        case .tongueUp:
            return clamp((blendshapes.tongueOut * blendshapes.jawOpen) / 0.4)

        case .tongueDown:
            let inactive = 1 - blendshapes.tongueOut
            return clamp(blendshapes.jawOpen * inactive / 0.5)

        case .tongueLeft:
            return clamp(blendshapes.mouthLeft / 0.7)

        case .tongueRight:
            return clamp(blendshapes.mouthRight / 0.7)

        case .painter:
            return clamp(blendshapes.jawForward / 0.6)
        }
    }

    /// Вспомогательный: все confidence для всех поз.
    public func confidenceMap(_ blendshapes: FaceBlendshapes) -> [ArticulationPosture: Float] {
        ArticulationPosture.allCases.reduce(into: [:]) { map, posture in
            map[posture] = confidence(blendshapes, for: posture)
        }
    }

    // MARK: - Helpers

    private func clamp(_ value: Float) -> Float {
        min(1, max(0, value))
    }
}
