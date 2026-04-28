import Foundation

// MARK: - SoftOnset word lists (stub MVP)

enum SoftOnsetWords {
    static let easyWords: [String] = [
        "арбуз", "облако", "утка", "иголка", "эхо",
        "ослик", "аист", "улитка", "осень", "утро",
        "лампа", "луна", "лиса", "лимон", "лодка",
        "мяч", "мама", "море", "молоко", "медведь",
        "небо", "нос", "нитка", "нога", "ножик"
    ]

    static func words(for difficulty: StutteringDifficulty) -> [String] {
        switch difficulty {
        case .easy:   return easyWords
        case .medium: return easyWords
        case .hard:   return easyWords
        }
    }
}
