import Foundation

// MARK: - ParentHomeModels (Clean Swift namespace)

enum ParentHomeModels {

    // MARK: Fetch

    enum Fetch {
        struct Request: Sendable {
            let preferredChildId: String?
        }

        struct Response: Sendable {
            let childId: String
            let childName: String
            let childAge: Int
            let targetSounds: [String]
            let currentStreak: Int
            let totalSessionMinutes: Int
            let overallRate: Double
            let recentSessions: [SessionData]
            let progressSummary: [String: Double]
            let homeTask: String?
        }

        struct ViewModel: Sendable {
            let childId: String
            let childName: String
            let childAge: Int
            let targetSoundsText: String
            let greeting: String
            let currentStreak: Int
            let totalSessionMinutes: Int
            let overallRate: Double
            let lastSession: SessionSummary?
            let recentSessions: [SessionSummary]
            let soundProgress: [SoundProgress]
            let homeTask: String?
            let recommendations: [String]
        }
    }

    // MARK: Domain data

    struct SessionData: Sendable {
        let id: String
        let date: Date
        let templateType: String
        let targetSound: String
        let durationSeconds: Int
        let totalAttempts: Int
        let correctAttempts: Int
    }

    // MARK: Display models

    struct SessionSummary: Identifiable, Sendable, Hashable {
        let id: String
        let targetSound: String
        let templateName: String
        let dateText: String
        let durationText: String
        let totalAttempts: Int
        let correctAttempts: Int
        let successRate: Double

        var resultText: String { "\(correctAttempts)/\(totalAttempts)" }
    }

    struct SoundProgress: Identifiable, Sendable, Hashable {
        var id: String { sound }
        let sound: String
        let familyName: String
        let currentStage: String
        let overallRate: Double
    }
}
