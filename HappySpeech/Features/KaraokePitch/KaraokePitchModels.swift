import Foundation
import SwiftUI

// MARK: - KaraokePitchModels
//
// v31 Wave E Ф.1 — «Караоке с контуром мелодики» (research F-02).
// Расширяет v29 Prosody/SpeechTempo: ребёнок видит две линии Pitch-контура —
// эталонную (модель) и собственную (в реальном времени), пытается совпасть.
//
// Контент: 20 фраз из существующего pack_prosody.json (выборка из 150
// просодических фраз). Корпус не дублируется — берётся через
// `KaraokePitchCorpus` (тонкая обёртка над ProsodyCorpus).
//
// Clean Swift VIP: View → Interactor → Presenter → Models → Workers.

enum KaraokePitchModels {

    // MARK: - Start (загрузка фразы и эталона)

    enum Start {

        struct Request {
            let phraseIndex: Int
        }

        struct Response {
            let phrase: KaraokePhrase
            let modelContour: [PitchPoint]
            let totalPhrases: Int
        }

        struct ViewModel {
            let phraseText: String
            let intonationSymbol: String
            let modelContour: [PitchPoint]
            let totalPhrases: Int
            let currentIndex: Int
            let accessibilityLabel: String
        }
    }

    // MARK: - LiveSample (поток pitch ребёнка)

    enum LiveSample {

        struct Response {
            let liveContour: [PitchPoint]
            let amplitude: Float
        }

        struct ViewModel {
            let liveContour: [PitchPoint]
            let amplitudeNormalised: CGFloat
        }
    }

    // MARK: - Score (после остановки записи)

    enum Score {

        struct Request {
            let liveContour: [PitchPoint]
        }

        struct Response {
            let phrase: KaraokePhrase
            let modelContour: [PitchPoint]
            let liveContour: [PitchPoint]
            let similarity: Double      // 0…1
            let starsEarned: Int        // 0…3
        }

        struct ViewModel {
            let phraseText: String
            let similarityPercent: Int       // 0…100
            let starsEarned: Int             // 0…3
            let feedbackMessage: String
            let modelContour: [PitchPoint]
            let liveContour: [PitchPoint]
            let accessibilityLabel: String
        }
    }
}

// MARK: - KaraokePhrase

/// Фраза для караоке-сессии: текст + эталон pitch-контура из бандла.
struct KaraokePhrase: Sendable, Identifiable, Equatable {
    let id: String
    let text: String
    /// `statement` | `question` | `exclamation` — для построения эталона.
    let intonation: String
    /// SF Symbol для подсказки типа интонации.
    let intonationSymbol: String
}

// MARK: - PitchPoint

/// Одна точка pitch-контура.
/// - `time`: нормализованное время [0…1] (фраза = единичная длительность).
/// - `frequencyHz`: основная частота. `nil` — пауза/шум/отсутствие голоса.
struct PitchPoint: Sendable, Equatable {
    let time: Double
    let frequencyHz: Double?
}

// MARK: - PitchTrackerConfig

/// Конфигурация YIN-tracker'а для детских голосов 100…500 Hz.
struct PitchTrackerConfig: Sendable, Equatable {
    let sampleRate: Double
    let minFrequencyHz: Double
    let maxFrequencyHz: Double
    /// YIN threshold τ (typical 0.10…0.15).
    let yinThreshold: Double

    static let kidVoice = PitchTrackerConfig(
        sampleRate: 16_000,
        minFrequencyHz: 100,
        maxFrequencyHz: 500,
        yinThreshold: 0.15
    )
}
