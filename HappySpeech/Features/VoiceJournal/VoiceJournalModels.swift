import Foundation

// MARK: - VoiceJournalModels
//
// «Дневник голоса» — список аудио-моментов с датой, длительностью и
// подписью. Запись и воспроизведение целиком на устройстве. Полностью
// offline / on-device (никакого Firestore, никакого облака).

enum VoiceJournalModels {

    // MARK: - LoadEntries

    enum LoadEntries {

        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let entries: [VoiceJournalEntry]
        }

        struct ViewModel: Sendable {
            let rows: [Row]
            let isEmpty: Bool
            let emptyTitle: String
            let emptyBody: String
            let emptyCtaTitle: String
        }

        struct Row: Sendable, Identifiable, Equatable {
            let id: String
            let title: String
            let dateText: String       // «23 мая»
            let durationText: String   // «0:42»
            let accessibilityLabel: String
            let entry: VoiceJournalEntry
        }
    }

    // MARK: - StartRecording

    enum StartRecording {

        struct Request: Sendable {}

        struct Response: Sendable {
            let granted: Bool
            let temporaryFileURL: URL?
            let errorMessage: String?
        }
    }

    // MARK: - StopRecording

    enum StopRecording {

        struct Request: Sendable {
            let childId: String
            let title: String
        }

        struct Response: Sendable {
            let entry: VoiceJournalEntry?
            let errorMessage: String?
        }
    }

    // MARK: - Play

    enum Play {

        struct Request: Sendable {
            let entry: VoiceJournalEntry
        }

        struct Response: Sendable {
            let success: Bool
        }
    }

    // MARK: - Delete

    enum Delete {

        struct Request: Sendable {
            let entry: VoiceJournalEntry
        }
    }
}
