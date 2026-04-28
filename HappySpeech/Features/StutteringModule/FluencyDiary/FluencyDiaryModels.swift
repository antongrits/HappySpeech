import Foundation

// MARK: - Stub texts (MVP, 5 hardcoded)

enum FluencyDiaryTexts {
    static let texts: [String] = [
        "Кошка спит на диване. Она мягкая и тёплая. Мама гладит кошку.",
        "Машина едет по дороге. Гудит гудок: би-би! Дорога длинная.",
        "Котёнок пьёт молоко. Молоко вкусное. Котёнок доволен.",
        "Мальчик рисует домик. У домика красная крыша. Рядом растёт дерево.",
        "Птичка сидит на ветке. Она поёт песенку. Солнышко светит ярко."
    ]

    static func text(at index: Int) -> String {
        texts[index % texts.count]
    }
}
