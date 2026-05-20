import Foundation

// MARK: - ComprehensionDetectiveModels (Clean Swift: Models)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив».
//
// Методика: импрессивная речь по Р.Е. Левиной — понимание устной инструкции.
// 4 грамматических уровня сложности:
//   1. Простое поручение («возьми мяч»).
//   2. Двойное поручение с союзом и («возьми мяч и положи в корзину»).
//   3. С предлогом («положи под стол»).
//   4. С причинно-следственной/относительной конструкцией («дай то, чем рисуют»).
//
// UI: ребёнок слышит инструкцию (TTS Siri или Ляля, если есть запись), видит
// 4 SF-картинки в сетке 2×2 и тапает правильную.

// MARK: - GrammarTier

/// Уровень грамматической сложности инструкции (по Левиной).
public enum GrammarTier: Int, CaseIterable, Sendable, Codable {
    case simple = 1
    case doubleInstruction = 2
    case withPreposition = 3
    case causalRelative = 4

    public var titleKey: String {
        switch self {
        case .simple:              return "detective.tier.1.title"
        case .doubleInstruction:   return "detective.tier.2.title"
        case .withPreposition:     return "detective.tier.3.title"
        case .causalRelative:      return "detective.tier.4.title"
        }
    }

    public var hintKey: String {
        switch self {
        case .simple:              return "detective.tier.1.hint"
        case .doubleInstruction:   return "detective.tier.2.hint"
        case .withPreposition:     return "detective.tier.3.hint"
        case .causalRelative:      return "detective.tier.4.hint"
        }
    }
}

// MARK: - DetectiveItem

/// Один пункт корпуса: инструкция + 4 картинки (одна правильная).
public struct DetectiveItem: Sendable, Equatable, Identifiable, Codable {

    public let id: String
    public let tier: GrammarTier
    /// Текст инструкции — озвучивается голосом Ляли или Siri TTS.
    public let instruction: String
    /// Все 4 варианта-картинки. Первая в исходном порядке — правильная.
    /// При показе порядок перемешивается, а правильный id хранится отдельно.
    public let pictures: [DetectivePicture]
    /// ID правильной картинки из массива `pictures`.
    public let correctPictureId: String

    public init(
        id: String,
        tier: GrammarTier,
        instruction: String,
        pictures: [DetectivePicture],
        correctPictureId: String
    ) {
        self.id = id
        self.tier = tier
        self.instruction = instruction
        self.pictures = pictures
        self.correctPictureId = correctPictureId
    }
}

// MARK: - DetectivePicture

public struct DetectivePicture: Sendable, Equatable, Identifiable, Codable, Hashable {
    public let id: String
    /// SF Symbol (бесплатный фолбэк, всегда доступен).
    public let symbolName: String
    /// Подпись для VoiceOver.
    public let label: String

    public init(id: String, symbolName: String, label: String) {
        self.id = id
        self.symbolName = symbolName
        self.label = label
    }
}

// MARK: - ComprehensionDetectiveModels namespace

enum ComprehensionDetectiveModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
            let preferredTier: GrammarTier?
        }

        struct Response: Sendable {
            let tier: GrammarTier
            let item: DetectiveItem
            let shuffledPictures: [DetectivePicture]
            let availableTiers: [GrammarTier]
            let totalItemsInTier: Int
            let itemIndex: Int
        }

        struct ViewModel: Sendable {
            let title: String
            let tierLabel: String
            let tierHint: String
            let instruction: String
            let pictures: [PictureViewModel]
            let availableTiers: [TierChip]
            let progressLabel: String
            let accessibilityLabel: String
        }

        struct PictureViewModel: Identifiable, Sendable, Equatable, Hashable {
            let id: String
            let symbolName: String
            let accessibilityLabel: String
        }

        struct TierChip: Identifiable, Sendable, Equatable, Hashable {
            let id: Int
            let title: String
            let isSelected: Bool
        }
    }

    // MARK: Pick

    enum Pick {
        struct Request: Sendable {
            let pictureId: String
        }

        struct Response: Sendable {
            let isCorrect: Bool
            let pickedPictureId: String
            let correctPictureId: String
            let instruction: String
        }

        struct ViewModel: Sendable {
            let isCorrect: Bool
            let toastTitle: String
            let toastDetail: String
            let correctPictureId: String
        }
    }

    // MARK: NextItem

    enum NextItem {
        struct Request: Sendable {
            let nextTier: GrammarTier?
        }
    }
}
