import Foundation
import SwiftUI

// MARK: - ARFaceFilterModels (Clean Swift: Models)
//
// Block S.4 v16 — AR Face Filter Mode (fun mode).
//
// 5 масок (2D overlay через SF Symbols / emoji над ARSession). Никаких 3D
// USDZ. Speech trigger через polling-based ASR (1-сек чанки) — если
// произнесено целевое слово → mask color change + Lyalya celebrates.

// MARK: - FaceMaskKind

enum FaceMaskKind: String, Sendable, CaseIterable, Identifiable {

    case kitten   = "mask.kitten"
    case fox      = "mask.fox"
    case crown    = "mask.crown"
    case ushanka  = "mask.ushanka"
    case glasses  = "mask.glasses"

    var id: String { rawValue }

    /// Block G v18: эмодзи заменены на SF Symbols. Поле `emoji` сохранено
    /// для обратной совместимости — теперь возвращает то же, что `symbolName`.
    var emoji: String { symbolName }

    var symbolName: String {
        switch self {
        case .kitten:  return "cat.fill"
        case .fox:     return "pawprint.fill"
        case .crown:   return "crown.fill"
        case .ushanka: return "snowflake"
        case .glasses: return "eyeglasses"
        }
    }

    var localizedTitle: String {
        switch self {
        case .kitten:  return String(localized: "facefilter.mask.kitten")
        case .fox:     return String(localized: "facefilter.mask.fox")
        case .crown:   return String(localized: "facefilter.mask.crown")
        case .ushanka: return String(localized: "facefilter.mask.ushanka")
        case .glasses: return String(localized: "facefilter.mask.glasses")
        }
    }

    var triggerWord: String {
        switch self {
        case .kitten:  return "кот"
        case .fox:     return "лиса"
        case .crown:   return "корона"
        case .ushanka: return "шапка"
        case .glasses: return "очки"
        }
    }
}

// MARK: - FaceMaskState

enum FaceMaskState: String, Sendable {
    case idle
    case glowing      // trigger word произнесено
    case celebrating
}

// MARK: - ARFaceFilterModels namespace (VIP contracts)

enum ARFaceFilterModels {

    // MARK: SetMask

    enum SetMask {
        struct Request: Sendable {
            let mask: FaceMaskKind
        }

        struct ViewModel: Sendable {
            let mask: FaceMaskKind
            let promptText: String
            let triggerWord: String
        }
    }

    // MARK: Trigger

    enum Trigger {
        struct Request: Sendable {
            let recognizedText: String
        }

        struct Response: Sendable {
            let isMatched: Bool
            let matchedWord: String
        }

        struct ViewModel: Sendable {
            let isMatched: Bool
            let celebrationText: String
        }
    }
}
