import Foundation
import SwiftUI

// MARK: - LetterPaintingFunModels

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
enum LetterPaintingFunModels {

    enum PaintColor: String, CaseIterable, Identifiable, Hashable {
        case coral
        case mint
        case sky
        case lilac
        case butter

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .coral:  return ColorTokens.Brand.primary
            case .mint:   return ColorTokens.Brand.mint
            case .sky:    return ColorTokens.Brand.sky
            case .lilac:  return ColorTokens.Brand.lilac
            case .butter: return ColorTokens.Brand.butter
            }
        }

        var label: String {
            switch self {
            case .coral:  return String(localized: "letterPainting.color.coral", defaultValue: "Коралловый")
            case .mint:   return String(localized: "letterPainting.color.mint", defaultValue: "Мятный")
            case .sky:    return String(localized: "letterPainting.color.sky", defaultValue: "Небесный")
            case .lilac:  return String(localized: "letterPainting.color.lilac", defaultValue: "Лиловый")
            case .butter: return String(localized: "letterPainting.color.butter", defaultValue: "Сливочный")
            }
        }
    }

    static let availableLetters: [String] = ["А", "Б", "В", "Р", "С", "Ш", "К", "Л"]

    struct Stroke: Identifiable, Hashable {
        let id: UUID
        let color: PaintColor
        let points: [CGPoint]
    }

    struct ViewState: Equatable {
        var currentLetter: String
        var strokes: [Stroke]
        var currentColor: PaintColor

        static let initial = ViewState(
            currentLetter: "Р",
            strokes: [],
            currentColor: .coral
        )
    }
}
