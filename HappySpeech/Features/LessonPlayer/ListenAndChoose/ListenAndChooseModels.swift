import Foundation

// MARK: - ListenAndChoose VIP Models

enum ListenAndChooseModels {

    // MARK: LoadRound
    enum LoadRound {
        struct Request {
            let soundTarget: String
            let difficulty: Int
        }
        struct Response {
            let targetWord: String
            let options: [OptionItem]
            let correctIndex: Int
            let audioAsset: String?
        }
        struct ViewModel {
            let targetWord: String
            let options: [OptionViewModel]
            let correctIndex: Int
            let instructionText: String
        }

        struct OptionItem: Sendable {
            let id: String
            let word: String
            let imageAsset: String?
        }
        struct OptionViewModel: Identifiable, Equatable {
            let id: String
            let word: String
            let imageSystemName: String
        }
    }

    // MARK: SubmitAttempt
    enum SubmitAttempt {
        struct Request {
            let selectedIndex: Int
            let correctIndex: Int
            let attemptsUsed: Int
        }
        struct Response {
            let isCorrect: Bool
            let isFinalAttempt: Bool
            let score: Float
            let shouldRevealAnswer: Bool
            let correctIndex: Int
        }
        struct ViewModel {
            let isCorrect: Bool
            let feedbackText: String
            let shouldRevealAnswer: Bool
            let correctIndex: Int
            let finalScore: Float?
        }
    }
}
