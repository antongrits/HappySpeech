import Foundation
import SwiftUI

// MARK: - ColorAndSoundModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum ColorAndSoundModels {

    struct Pair: Identifiable, Hashable {
        let id: String
        let sound: String
        let colorName: String
        let colorHex: String
        let example: String
        var isMatched: Bool

        var color: Color {
            Color(hex: colorHex)
        }
    }

    struct ViewState: Equatable {
        var pairs: [Pair]
        var selectedId: String?

        static let initial = ViewState(pairs: [
            Pair(id: "r", sound: "Р", colorName: "Красный", colorHex: "#E74C3C", example: "Рак", isMatched: false),
            Pair(id: "s", sound: "С", colorName: "Синий", colorHex: "#3498DB", example: "Сова", isMatched: false),
            Pair(id: "z", sound: "З", colorName: "Зелёный", colorHex: "#27AE60", example: "Заяц", isMatched: false),
            Pair(id: "sh", sound: "Ш", colorName: "Серый", colorHex: "#7F8C8D", example: "Шум", isMatched: false),
            Pair(id: "l", sound: "Л", colorName: "Лимонный", colorHex: "#F1C40F", example: "Лиса", isMatched: false),
            Pair(id: "k", sound: "К", colorName: "Коричневый", colorHex: "#8B6F47", example: "Кот", isMatched: false)
        ], selectedId: nil)
    }
}
