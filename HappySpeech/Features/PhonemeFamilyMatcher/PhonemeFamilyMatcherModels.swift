import Foundation

// MARK: - PhonemeFamilyMatcherModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum PhonemeFamilyMatcherModels {

    enum Family: String, CaseIterable, Hashable, Identifiable {
        case whistling
        case hissing
        case sonorant
        case velar

        var id: String { rawValue }

        var title: String {
            switch self {
            case .whistling: return "Свистящие"
            case .hissing:   return "Шипящие"
            case .sonorant:  return "Соноры"
            case .velar:     return "Заднеязычные"
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
    }

    struct Word: Identifiable, Hashable {
        let id: String
        let text: String
        let family: Family
        var assignedFamily: Family?
    }

    struct ViewState: Equatable {
        var words: [Word]

        var matchedCount: Int {
            words.filter { $0.assignedFamily == $0.family }.count
        }

        static let initial = ViewState(words: [
            Word(id: "w1", text: "Сова", family: .whistling, assignedFamily: nil),
            Word(id: "w2", text: "Зебра", family: .whistling, assignedFamily: nil),
            Word(id: "w3", text: "Цапля", family: .whistling, assignedFamily: nil),
            Word(id: "w4", text: "Шапка", family: .hissing, assignedFamily: nil),
            Word(id: "w5", text: "Жираф", family: .hissing, assignedFamily: nil),
            Word(id: "w6", text: "Щётка", family: .hissing, assignedFamily: nil),
            Word(id: "w7", text: "Рыба", family: .sonorant, assignedFamily: nil),
            Word(id: "w8", text: "Луна", family: .sonorant, assignedFamily: nil),
            Word(id: "w9", text: "Рак", family: .sonorant, assignedFamily: nil),
            Word(id: "w10", text: "Кот", family: .velar, assignedFamily: nil),
            Word(id: "w11", text: "Гуси", family: .velar, assignedFamily: nil),
            Word(id: "w12", text: "Хлеб", family: .velar, assignedFamily: nil)
        ])
    }
}
