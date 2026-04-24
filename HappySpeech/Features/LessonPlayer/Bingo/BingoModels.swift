import Foundation
import SwiftUI

// MARK: - Bingo VIP Models
//
// «Бинго со звуком»: 5×5 карточка слов. Логопед-маскот зачитывает слово
// (AVSpeechSynthesizer ru-RU), ребёнок ищет его в своей карточке и нажимает.
// Цель — собрать 5 в ряд (горизонталь / вертикаль / диагональ).
//
// Все модели согласованы с Clean Swift VIP: Request → Response → ViewModel.
// Ничего, что зависит от UIKit/SwiftUI кроме `@Observable` Display, не уходит
// в Interactor/Presenter — это держит бизнес-логику тестируемой.

enum BingoModels {

    // MARK: - LoadGame

    enum LoadGame {
        struct Request {
            let activity: SessionActivity
        }
        struct Response {
            let cells: [BingoCell]
            let totalWords: Int
            let firstWord: String?
        }
        struct ViewModel {
            let cells: [BingoCell]
            let totalWords: Int
            let calledWord: String
            let progressFraction: Double
        }
    }

    // MARK: - CallWord

    enum CallWord {
        struct Request {}
        struct Response {
            let word: String
            let index: Int          // 1-based номер слова в очереди
            let total: Int
        }
        struct ViewModel {
            let calledWord: String
            let calledWordIndex: Int
            let totalWords: Int
            let progressFraction: Double
            let isCalling: Bool
        }
    }

    // MARK: - MarkCell

    enum MarkCell {
        struct Request {
            let cellId: UUID
        }
        struct Response {
            let cells: [BingoCell]
            let bingoLines: [BingoLine]   // выигрышные линии (если набрались)
            let allMarked: Bool           // все 25 клеток marked
        }
        struct ViewModel {
            let cells: [BingoCell]
            let bingoLines: [BingoLine]
            let phase: BingoPhase
        }
    }

    // MARK: - CompleteGame

    enum CompleteGame {
        struct Request {}
        struct Response {
            let score: Float
            let bingoAchieved: Bool
            let markedCells: Int
            let totalCells: Int
        }
        struct ViewModel {
            let scoreLabel: String
            let starsEarned: Int
            let completionMessage: String
            let finalScore: Float
        }
    }
}

// MARK: - Domain types

/// Одна клетка 5×5 поля.
struct BingoCell: Identifiable, Sendable, Equatable, Hashable {
    let id: UUID
    let word: String
    let soundGroup: String      // для подсветки и accessibility
    var isMarked: Bool
    var isWinner: Bool          // входит в выигрышную линию
}

/// Индексы клеток в плоском массиве [0..24], составляющие линию бинго.
/// 5 строк + 5 столбцов + 2 диагонали = всего 12 линий.
typealias BingoLine = [Int]

/// Фаза игры — управляет переключением экранов в View.
enum BingoPhase: Sendable, Equatable {
    case loading        // первичная загрузка слов
    case playing        // основной геймплей
    case bingo          // промежуточная — анимация победы (overlay)
    case completed      // финальный экран со звёздами
}

// MARK: - View display state

/// `@Observable` хранилище состояния, которое читает SwiftUI-`BingoView`.
/// Реализует `BingoDisplayLogic` через extension в одноимённом файле.
@MainActor
@Observable
final class BingoViewDisplay {

    // Поле и его клетки
    var cells: [BingoCell] = []

    // Озвучивание
    var calledWord: String = ""
    var calledWordIndex: Int = 0       // 0 пока ничего не называли
    var totalWords: Int = 0
    var isCalling: Bool = false        // TTS сейчас говорит — для анимации иконки динамика

    // Состояние игры
    var phase: BingoPhase = .loading
    var bingoLines: [BingoLine] = []   // выигрышные линии (для подсветки)
    var progressFraction: Double = 0

    // Финальный экран
    var scoreLabel: String = ""
    var starsEarned: Int = 0
    var completionMessage: String = ""
    var lastScore: Float = 0
    var pendingFinalScore: Float?
}

// MARK: - Bingo line catalog

/// 12 линий бинго на сетке 5×5 (индексы 0–24, читаются слева-направо, сверху-вниз).
/// Используется и в Interactor (для `checkBingo`), и в тестах.
enum BingoLineCatalog {

    /// Размер сетки одна сторона.
    static let side: Int = 5

    /// Все 12 потенциальных линий.
    static let allLines: [BingoLine] = rows + columns + diagonals

    static var rows: [BingoLine] {
        (0..<side).map { row in
            (0..<side).map { col in row * side + col }
        }
    }

    static var columns: [BingoLine] {
        (0..<side).map { col in
            (0..<side).map { row in row * side + col }
        }
    }

    static var diagonals: [BingoLine] {
        let main = (0..<side).map { i in i * side + i }            // 0,6,12,18,24
        let anti = (0..<side).map { i in i * side + (side - 1 - i) } // 4,8,12,16,20
        return [main, anti]
    }
}
