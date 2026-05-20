import CoreGraphics
import Foundation

// MARK: - LetterTraceModels (Clean Swift: Models)
//
// v31 Волна C, Функция Ф.2 «Пиши пальчиком/пером».
//
// Кид-фича: PencilKit canvas + reference stroke skeleton из bundled JSON.
// Stroke similarity оценивается простой Hausdorff-подобной метрикой (Frechet-like
// без полного DP — для on-device latency). Apple Pencil поддерживается на
// iPad; на iPhone — палец (PencilKit allowsFingerDrawing).
//
// project guide §11: педагогическая поддержка, не диагностика моторики.

// MARK: - TraceItemKind

public enum TraceItemKind: String, Sendable, Codable, Equatable {
    case letter
    case syllable

    public var sectionTitleKey: String {
        switch self {
        case .letter:   return "letterTrace.category.alphabet"
        case .syllable: return "letterTrace.category.syllables"
        }
    }
}

// MARK: - TraceItem

public struct TraceItem: Sendable, Identifiable, Equatable, Codable {
    public let id: String
    public let kind: TraceItemKind
    public let symbol: String
    /// Список stroke'ов (ломаных в нормализованных координатах 0…1).
    public let strokes: [[TracePoint]]

    public init(id: String, kind: TraceItemKind, symbol: String, strokes: [[TracePoint]]) {
        self.id = id
        self.kind = kind
        self.symbol = symbol
        self.strokes = strokes
    }
}

// MARK: - TracePoint (Sendable normalized point)

public struct TracePoint: Sendable, Codable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - TraceScore

/// Результат сравнения пользовательского контура с эталоном.
public struct TraceScore: Sendable, Equatable {
    /// 0...1 — насколько точка-в-точку совпали контуры.
    public let similarity: Double
    /// Удобный целочисленный процент 0…100.
    public var percent: Int { max(0, min(100, Int((similarity * 100).rounded()))) }
    /// Категория: отлично/хорошо/попробуй ещё.
    public var band: ScoreBand {
        switch percent {
        case 75...:    return .excellent
        case 50..<75:  return .good
        default:       return .tryAgain
        }
    }

    public enum ScoreBand: Sendable, Equatable {
        case excellent
        case good
        case tryAgain
    }

    public init(similarity: Double) {
        self.similarity = max(0, min(1, similarity))
    }
}

// MARK: - LetterTraceModels namespace

enum LetterTraceModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let items: [TraceItem]
        }

        struct ViewModel: Sendable {
            let totalCount: Int
            let firstItem: ItemViewModel?
        }

        struct ItemViewModel: Sendable, Identifiable, Equatable {
            let id: String
            let symbol: String
            let kind: TraceItemKind
            let promptText: String
            let referenceStrokes: [[TracePoint]]
            let progressText: String
        }
    }

    // MARK: Advance

    enum Advance {
        struct Request: Sendable {
            let currentItemId: String?
        }

        struct Response: Sendable {
            let nextItem: TraceItem?
            let position: Int
            let totalCount: Int
        }

        struct ViewModel: Sendable {
            let item: Load.ItemViewModel?
        }
    }

    // MARK: Score

    enum Score {
        struct Request: Sendable {
            let itemId: String
            /// Пользовательские stroke'ы в нормализованных координатах 0…1.
            let userStrokes: [[TracePoint]]
        }

        struct Response: Sendable {
            let itemId: String
            let score: TraceScore
        }

        struct ViewModel: Sendable {
            let feedbackText: String
            let bandSymbol: String
            let isSuccess: Bool
            let percent: Int
        }
    }
}
