import Foundation

// MARK: - WhisperGameModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum WhisperGameModels {

    enum Mode: String, CaseIterable, Hashable {
        case whisper
        case normal
        case loud

        var title: String {
            switch self {
            case .whisper: return "Шёпот"
            case .normal:  return "Обычно"
            case .loud:    return "Громко"
            }
        }

        var icon: String {
            switch self {
            case .whisper: return "speaker.wave.1"
            case .normal:  return "speaker.wave.2"
            case .loud:    return "speaker.wave.3.fill"
            }
        }

        var targetLevel: Double {
            switch self {
            case .whisper: return 0.20
            case .normal:  return 0.55
            case .loud:    return 0.88
            }
        }
    }

    struct ViewState: Equatable {
        var mode: Mode
        var currentLevel: Double
        var roundsCompleted: Int

        var matchAccuracy: Double {
            let delta = abs(currentLevel - mode.targetLevel)
            return max(0, 1 - delta * 2)
        }

        static let initial = ViewState(
            mode: .whisper,
            currentLevel: 0.18,
            roundsCompleted: 0
        )
    }
}
