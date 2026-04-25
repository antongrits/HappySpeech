import Foundation

// MARK: - Demo VIP Models
//
// 15-шаговый walkthrough приложения. Spotlight-overlay подсвечивает целевой
// блок, маскот Ляля даёт текстовую подсказку, прогресс «Шаг N из 15».

// MARK: - DemoStep (DTO)

public struct DemoStep: Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let description: String
    public let mascotText: String
    public let screenEmoji: String
    public let highlightColor: String   // hex или semantic name (resolved во View)

    public init(
        id: Int,
        title: String,
        description: String,
        mascotText: String,
        screenEmoji: String,
        highlightColor: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.mascotText = mascotText
        self.screenEmoji = screenEmoji
        self.highlightColor = highlightColor
    }
}

// MARK: - VIP scenes

enum DemoModels {

    // MARK: - LoadDemo

    enum LoadDemo {
        struct Request: Sendable {}
        struct Response: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
        }
        struct ViewModel: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
            let totalSteps: Int
            let progress: Double
            let progressLabel: String
            let isFirst: Bool
            let isLast: Bool
            let backTitle: String
            let nextTitle: String
            let stepTitle: String
            let stepDescription: String
            let mascotText: String
            let screenEmoji: String
        }
    }

    // MARK: - AdvanceStep

    enum AdvanceStep {
        struct Request: Sendable {}
        struct Response: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
            let isCompleted: Bool
        }
        struct ViewModel: Sendable {
            let currentIndex: Int
            let totalSteps: Int
            let progress: Double
            let progressLabel: String
            let isFirst: Bool
            let isLast: Bool
            let backTitle: String
            let nextTitle: String
            let stepTitle: String
            let stepDescription: String
            let mascotText: String
            let screenEmoji: String
            let isCompleted: Bool
        }
    }

    // MARK: - GoBack

    enum GoBack {
        struct Request: Sendable {}
        struct Response: Sendable {
            let steps: [DemoStep]
            let currentIndex: Int
        }
        struct ViewModel: Sendable {
            let currentIndex: Int
            let progress: Double
            let progressLabel: String
            let isFirst: Bool
            let isLast: Bool
            let backTitle: String
            let nextTitle: String
            let stepTitle: String
            let stepDescription: String
            let mascotText: String
            let screenEmoji: String
        }
    }

    // MARK: - Skip

    enum SkipDemo {
        struct Request: Sendable {}
        struct Response: Sendable {}
        struct ViewModel: Sendable {}
    }

    // MARK: - Complete

    enum CompleteDemo {
        struct Request: Sendable {}
        struct Response: Sendable {}
        struct ViewModel: Sendable {}
    }
}
