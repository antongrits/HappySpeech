import Foundation
import SwiftUI

// MARK: - SpeechVisualizationModels (Clean Swift: Models)
//
// Block S.3 v16 — Speech Visualization Karaoke (real-time waveform + word).
//
// Использует существующий SpectrogramVisualizerView из DesignSystem +
// добавляет karaoke-overlay со слогами и синхронизацией.

// MARK: - KaraokeSyllable

struct KaraokeSyllable: Identifiable, Sendable, Hashable {
    let id: String
    let text: String
    let durationSeconds: Double  // длительность слога в эталоне
    let startOffset: Double      // начало в total word
}

// MARK: - KaraokeSyllableState

enum KaraokeSyllableState: String, Sendable {
    case idle
    case active     // подсветка во время воспроизведения / записи
    case correct    // accuracy >= 80%
    case warning    // accuracy 50-79%
    case incorrect  // accuracy < 50%

    var color: Color {
        switch self {
        case .idle:      return ColorTokens.Kid.inkSoft
        case .active:    return ColorTokens.Brand.primary
        case .correct:   return ColorTokens.Brand.mint
        case .warning:   return ColorTokens.Brand.butter
        case .incorrect: return ColorTokens.Brand.rose
        }
    }
}

// MARK: - VisualizationMode

enum VisualizationMode: String, Sendable {
    case listen      // воспроизведение эталона + анимация слогов
    case practice    // запись + сравнение

    var localizedTitle: String {
        switch self {
        case .listen:   return String(localized: "karaoke.mode.listen")
        case .practice: return String(localized: "karaoke.mode.practice")
        }
    }
}

// MARK: - SpeechVisualizationModels namespace (VIP contracts)

enum SpeechVisualizationModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let word: String
            let targetSound: String
        }

        struct Response: Sendable {
            let word: String
            let syllables: [KaraokeSyllable]
            let totalDuration: Double
        }

        struct ViewModel: Sendable {
            let title: String
            let wordDisplay: String
            let syllables: [SyllableViewModel]
            let totalDurationLabel: String
        }

        struct SyllableViewModel: Identifiable, Sendable {
            let id: String
            let text: String
            let state: KaraokeSyllableState
            let durationSeconds: Double
            let accessibilityLabel: String
        }
    }

    // MARK: SetMode

    enum SetMode {
        struct Request: Sendable {
            let mode: VisualizationMode
        }

        struct ViewModel: Sendable {
            let mode: VisualizationMode
            let instructionText: String
            let primaryButtonTitle: String
        }
    }

    // MARK: Score

    enum Score {
        struct Request: Sendable {
            let attemptDurationSeconds: Double
        }

        struct Response: Sendable {
            let perSyllableAccuracy: [Double]    // 0.0 — 1.0 на каждый слог
            let overallAccuracy: Double
        }

        struct ViewModel: Sendable {
            let summaryText: String
            let summaryColor: Color
            let updatedSyllables: [Load.SyllableViewModel]
            let confettiBurst: Bool
        }
    }
}
