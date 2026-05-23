import Foundation

// MARK: - MusicalSoundDrumsModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum MusicalSoundDrumsModels {

    enum DrumId: String, CaseIterable, Hashable {
        case low
        case mid
        case high

        var icon: String {
            switch self {
            case .low:  return "circle.fill"
            case .mid:  return "circle.circle.fill"
            case .high: return "smallcircle.filled.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .low:  return "Низкий"
            case .mid:  return "Средний"
            case .high: return "Высокий"
            }
        }
    }

    struct ViewState: Equatable {
        var targetPhoneme: String
        var beatsCount: Int
        var lastDrumId: DrumId?
        var rhythmPattern: [DrumId]

        static let initial = ViewState(
            targetPhoneme: "Та-Та-Та",
            beatsCount: 0,
            lastDrumId: nil,
            rhythmPattern: [.low, .mid, .high]
        )
    }
}
