import Foundation

// MARK: - SessionShell VIP Models

enum SessionShellModels {

    // MARK: StartSession
    enum StartSession {
        struct Request {
            let childId: String
            let targetSoundId: String
            let sessionType: SessionType
        }
        struct Response {
            let activities: [SessionActivity]
            let totalSteps: Int
            let estimatedMinutes: Int
        }
        struct ViewModel {
            let activities: [SessionActivity]
            let totalSteps: Int
            let progressTitle: String
        }
    }

    // MARK: CompleteActivity
    enum CompleteActivity {
        struct Request {
            let activityId: String
            let score: Float
            let durationSeconds: Int
            let errorCount: Int
        }
        struct Response {
            let nextActivity: SessionActivity?
            let isSessionComplete: Bool
            let earnedReward: SessionReward?
            let fatigueDetected: Bool
        }
        struct ViewModel {
            let shouldAdvance: Bool
            let shouldShowFatigueAlert: Bool
            let shouldShowReward: Bool
            let reward: RewardViewModel?
        }
    }

    // MARK: PauseSession
    enum PauseSession {
        struct Request {}
        struct Response { let currentProgress: Float }
        struct ViewModel {
            let progressPercentage: Float
            let timeSpentFormatted: String
        }
    }
}

// MARK: - Domain

struct SessionActivity: Identifiable, Sendable, Equatable {
    let id: String
    let gameType: GameType
    let lessonId: String
    let soundTarget: String
    let difficulty: Int
    var isCompleted: Bool
    var score: Float?
}

enum GameType: String, Sendable, CaseIterable {
    case listenAndChoose        = "ListenAndChoose"
    case repeatAfterModel       = "RepeatAfterModel"
    case minimalPairs           = "MinimalPairs"
    case dragAndMatch           = "DragAndMatch"
    case memory                 = "Memory"
    case bingo                  = "Bingo"
    case breathing              = "Breathing"
    case rhythm                 = "Rhythm"
    case sorting                = "Sorting"
    case puzzleReveal           = "PuzzleReveal"
    case soundHunter            = "SoundHunter"
    case narrativeQuest         = "NarrativeQuest"
    case visualAcoustic         = "VisualAcoustic"
    case storyCompletion        = "StoryCompletion"
    case articulationImitation  = "ArticulationImitation"
    case arActivity             = "ARActivity"
}

enum SessionType: String, Sendable {
    case adaptive
    case quickPractice
    case screening
    case homeworkTask
}

struct SessionReward: Sendable, Equatable {
    let kind: Kind
    enum Kind: String, Sendable { case star, badge, sticker }
    static let star = SessionReward(kind: .star)
}

struct RewardViewModel: Sendable, Equatable {
    let emoji: String
    let title: String
    let subtitle: String
}
