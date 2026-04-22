import Foundation

// MARK: - ARActivity VIP Models
// Backlog: see backlog.md for implementation tickets

enum ARActivityModels {

    // MARK: - LoadSession
    enum LoadSession {
        struct Request { var sessionId: String = "" }
        struct Response { var items: [String] = [] }
        struct ViewModel { var displayItems: [String] = [] }
    }

    // MARK: - SubmitAttempt
    enum SubmitAttempt {
        struct Request { var selectedWord: String = ""; var audioURL: URL? = nil }
        struct Response { var isCorrect: Bool = false; var score: Double = 0 }
        struct ViewModel { var feedbackText: String = ""; var isCorrect: Bool = false }
    }
}
