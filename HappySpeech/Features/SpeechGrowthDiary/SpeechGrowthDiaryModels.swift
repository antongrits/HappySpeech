import Foundation

// MARK: - SpeechGrowthDiaryModels
//
// v31 Wave E Ф.4 — «Дневник речевого роста».
//
// Родитель записывает ≤30-секундные клипы практики речи ребёнка. Клип
// и thumbnail (first frame) шифруются CryptoKit AES-GCM-256 (ключ — в
// Keychain). Никакого облака. Per-clip share-token (локальный) — для
// специалиста: родитель явно даёт доступ.
//
// Этическое требование (CLAUDE.md §11):
//   • opt-in (parent gate),
//   • COPPA-safe,
//   • no cloud egress,
//   • никаких ключей в логах.

enum SpeechGrowthDiaryModels {

    // MARK: - List

    enum List {

        struct Response {
            let clips: [EncryptedVideoClipData]
        }

        struct ViewModel {
            let clips: [ClipRow]
            let isEmpty: Bool
        }

        struct ClipRow: Sendable, Identifiable, Equatable {
            let id: String
            let recordedAtLabel: String
            let durationLabel: String
            let topicTag: String
            let targetSound: String
            let note: String
            let isShared: Bool
            let isShareExpired: Bool
        }
    }

    // MARK: - Save Clip

    enum SaveClip {

        struct Request {
            let sourceFileURL: URL
            let thumbnailFileURL: URL?
            let durationSeconds: Double
            let topicTag: String
            let targetSound: String
            let note: String
        }

        struct Response {
            let saved: EncryptedVideoClipData
        }
    }

    // MARK: - Share

    enum Share {

        struct Request {
            let clipId: String
            /// Срок жизни share-token в часах (1…168).
            let durationHours: Int
        }

        struct Response {
            let clipId: String
            let token: String
            let expiresAt: Date
        }

        struct ViewModel {
            let token: String
            let expiresAtLabel: String
            let copyMessage: String
        }
    }
}
