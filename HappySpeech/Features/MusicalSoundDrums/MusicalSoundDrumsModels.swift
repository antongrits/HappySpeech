import Foundation

// MARK: - MusicalSoundDrumsModels

/// Модели логоритмической игры «Звуковые барабаны».
///
/// Ляля показывает ритмический рисунок из слогов рабочего звука ребёнка
/// (например «СА-са-СО»), ребёнок повторяет его, нажимая барабаны в нужной
/// последовательности (громкий слог → большой барабан). Точность повтора идёт
/// в outcome планировщика.
enum MusicalSoundDrumsModels {

    /// Барабан = громкость слога в рисунке.
    enum DrumId: String, CaseIterable, Hashable {
        case low      // тихий / безударный
        case mid      // средний
        case high     // громкий / ударный

        var icon: String {
            switch self {
            case .low:  return "circle.fill"
            case .mid:  return "circle.circle.fill"
            case .high: return "smallcircle.filled.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .low:  return String(localized: "musicalDrums.drum.low")
            case .mid:  return String(localized: "musicalDrums.drum.mid")
            case .high: return String(localized: "musicalDrums.drum.high")
            }
        }
    }

    /// Один слог рисунка: текст + ожидаемый барабан (громкость).
    struct Syllable: Hashable {
        let text: String
        let drum: DrumId
    }

    struct ViewState: Equatable {
        /// Рабочий звук текущего рисунка («С», «Р» …).
        var sound: String
        /// Слоги целевого рисунка по порядку.
        var pattern: [Syllable]
        /// Сколько слогов рисунка ребёнок уже верно повторил.
        var progressIndex: Int
        /// Последний нажатый барабан (для подсветки).
        var lastDrumId: DrumId?
        /// Завершённые раунды и удачные раунды (для звёзд/точности).
        var roundsPlayed: Int
        var roundsCorrect: Int
        var totalTaps: Int
        var correctTaps: Int
        var bestStars: Int
        var isLoaded: Bool
        /// Показывать ли «рисунок повторён» (раунд успешно завершён).
        var roundComplete: Bool

        /// Текстовый рисунок для показа («СА-са-СО»).
        var patternText: String {
            pattern.map(\.text).joined(separator: "-")
        }

        var accuracy: Double {
            totalTaps > 0 ? Double(correctTaps) / Double(totalTaps) : 0
        }

        var stars: Int {
            guard totalTaps > 0 else { return 0 }
            switch accuracy {
            case 0.9...: return 3
            case 0.7..<0.9: return 2
            default: return 1
            }
        }

        static let initial = ViewState(
            sound: "С",
            pattern: MusicalSoundDrumsContent.pattern(for: "С", length: 3),
            progressIndex: 0,
            lastDrumId: nil,
            roundsPlayed: 0,
            roundsCorrect: 0,
            totalTaps: 0,
            correctTaps: 0,
            bestStars: 0,
            isLoaded: true,
            roundComplete: false
        )
    }
}
