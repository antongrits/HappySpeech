import Foundation

// MARK: - PhonemeFamilyMatcherModels

/// Модели игры «Разложи по семьям звуков». Слова берутся из реального словаря
/// (`PhonemeFamilyMatcherWorker` → `LessonContentMap`), не из статического seed.
enum PhonemeFamilyMatcherModels {

    enum Family: String, CaseIterable, Hashable, Identifiable {
        case whistling
        case hissing
        case sonorant
        case velar

        var id: String { rawValue }

        var title: String {
            switch self {
            case .whistling: return String(localized: "soundGroup.whistling")
            case .hissing:   return String(localized: "soundGroup.hissing")
            case .sonorant:  return String(localized: "soundGroup.sonorant")
            case .velar:     return String(localized: "soundGroup.velar")
            }
        }

        var color: String {
            switch self {
            case .whistling: return "SoundWhistlingBg"
            case .hissing:   return "SoundHissingBg"
            case .sonorant:  return "SoundSonorantBg"
            case .velar:     return "SoundVelarBg"
            }
        }

        /// Канонический звук-представитель группы (для записи прогресса).
        var representativeSound: String {
            switch self {
            case .whistling: return "С"
            case .hissing:   return "Ш"
            case .sonorant:  return "Р"
            case .velar:     return "К"
            }
        }
    }

    struct Word: Identifiable, Hashable {
        let id: String
        let text: String
        let family: Family
        var assignedFamily: Family?
    }

    struct ViewState: Equatable {
        var words: [Word]
        var isLoaded: Bool

        var matchedCount: Int {
            words.filter { $0.assignedFamily == $0.family }.count
        }

        var isEmpty: Bool {
            isLoaded && words.isEmpty
        }

        /// Все слова разложены (правильно или нет).
        var allAssigned: Bool {
            !words.isEmpty && words.allSatisfy { $0.assignedFamily != nil }
        }

        static let initial = ViewState(words: [], isLoaded: false)
    }
}
