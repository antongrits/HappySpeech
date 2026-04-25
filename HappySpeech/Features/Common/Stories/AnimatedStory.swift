import SwiftUI

// MARK: - AnimatedStory

/// Модель анимированной истории для логопедических занятий с детьми 5–8 лет.
/// Каждая история содержит 3 сцены с целевым звуком и emoji-персонажем.
public struct AnimatedStory: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    /// Целевой звук для отработки: "Ш", "Р", "Л" и т.д.
    public let targetSound: String
    public let scenes: [AnimatedStoryScene]
    /// Уровень сложности: 1 — простой, 2 — средний, 3 — сложный.
    public let difficulty: Int
    public let ageMin: Int
    public let ageMax: Int
    /// Два hex-цвета для LinearGradient фона.
    public let backgroundGradient: [String]
}

// MARK: - AnimatedStoryScene

/// Одна сцена истории с текстом, персонажем и типом анимации.
public struct AnimatedStoryScene: Identifiable, Codable, Sendable {
    public let id: String
    /// Эмодзи-фон сцены (несколько символов).
    public let backgroundEmoji: String
    /// Эмодзи главного персонажа сцены.
    public let characterEmoji: String
    /// Нарративный текст от лица рассказчика (русский).
    public let narrativeText: String
    /// Целевое слово с нужным звуком — выделяется жирным в UI.
    public let targetWord: String
    public let animationType: StoryAnimationType
    public let characterPosition: AnimatedCharacterPosition
}

// MARK: - StoryAnimationType

public enum StoryAnimationType: String, Codable, Sendable {
    case bounce
    case slide
    case float
    case spin
    case grow
    case shake
    case fadeIn
    case flip
}

// MARK: - AnimatedCharacterPosition

public enum AnimatedCharacterPosition: String, Codable, Sendable {
    case left
    case center
    case right
    case top
    case bottom
}
