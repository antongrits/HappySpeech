import Foundation

// MARK: - BedtimeModeModels (Clean Swift: Models)
//
// v31 Волна B, Функция Ф.3 «Bedtime mode (перед сном)».
//
// Спокойный вечерний поток: приглушённая тёплая палитра, дыхательное
// упражнение (3 цикла, 4-7-8), затем короткая колыбельная история через
// AVSpeechSynthesizer (ru-RU «Milena»). НЕ диагностический инструмент:
// project guide §11 — это педагогический ритуал, а не sleep tracker.
//
// Reduce Motion принудительно включён (фон без анимаций), AVAudioSession
// устанавливается в `.spokenAudio`, чтобы рассказчик переживал гудки в
// фоне и совмещался с детским полётным режимом.

// MARK: - BedtimeStage

public enum BedtimeStage: Int, Sendable, CaseIterable {
    /// Приветствие (Ляля говорит «давай готовиться ко сну»).
    case intro
    /// 3 цикла дыхания (вдох 4, задержка 4, выдох 6) — успокаивает.
    case breathing
    /// Чтение спокойной истории.
    case story
    /// Завершение: «спокойной ночи».
    case farewell
}

// MARK: - BedtimeStory

public struct BedtimeStory: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let text: String

    public init(id: String, title: String, text: String) {
        self.id = id
        self.title = title
        self.text = text
    }
}

// MARK: - BedtimeBreathingCycle

public struct BedtimeBreathingCycle: Sendable, Equatable {
    public let inhaleSeconds: Int
    public let holdSeconds: Int
    public let exhaleSeconds: Int
    public let totalCycles: Int

    public init(
        inhaleSeconds: Int = 4,
        holdSeconds: Int = 4,
        exhaleSeconds: Int = 6,
        totalCycles: Int = 3
    ) {
        self.inhaleSeconds = inhaleSeconds
        self.holdSeconds = holdSeconds
        self.exhaleSeconds = exhaleSeconds
        self.totalCycles = totalCycles
    }
}

// MARK: - BedtimeModeModels namespace

enum BedtimeModeModels {

    // MARK: Start

    enum Start {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let story: BedtimeStory
            let breathing: BedtimeBreathingCycle
            let storiesCountInLibrary: Int
        }

        struct ViewModel: Sendable {
            let title: String
            let introMessage: String
            let breathingTitle: String
            let breathingHint: String
            let storyTitle: String
            let storyText: String
            let farewell: String
            let breathing: BedtimeBreathingCycle
            let storiesCountLabel: String
        }
    }

    // MARK: AdvanceStage

    enum AdvanceStage {
        struct Request: Sendable {
            let currentStage: BedtimeStage
        }

        struct Response: Sendable {
            let nextStage: BedtimeStage
        }
    }

    // MARK: PickNewStory

    enum PickNewStory {
        struct Request: Sendable {
            let excludeId: String?
        }

        struct Response: Sendable {
            let story: BedtimeStory
        }
    }
}
