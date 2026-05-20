import Foundation

// MARK: - OralStoryCreatorModels
//
// v31 Wave E Ф.3 — «Сочини историю» (research G-06, Sago Mini School gap).
//
// Ребёнок выбирает 3 из 12 стимул-картинок → записывает ≤60 сек устного
// рассказа → WhisperKit транскрибирует → показывается транскрипт + TTR
// (type-token ratio = unique / total words) → сохранение в Realm
// `ChildOralStoryObject`.
//
// Корпус стимулов: pack_storycreator_stimuli.json — 40 изображений,
// сгруппированных по «герои» / «места» / «предметы».

enum OralStoryCreatorModels {

    // MARK: - Load Stimuli

    enum LoadStimuli {

        struct Response {
            let stimuli: [StimulusPicture]
        }

        struct ViewModel {
            let grouped: [String: [StimulusPicture]]   // category → pictures
            let categoriesInOrder: [String]
            let pickCountTarget: Int                   // 3
        }
    }

    // MARK: - Selection

    enum Select {

        struct Response {
            let selectedIds: [String]
        }

        struct ViewModel {
            let selectedIds: [String]
            let canStartRecording: Bool                // true if == 3 chosen
            let statusMessage: String
        }
    }

    // MARK: - Record Result (после остановки)

    enum RecordResult {

        struct Response {
            let transcript: String
            let durationSeconds: Double
            let stimuli: [StimulusPicture]
            let savedStoryId: String
        }

        struct ViewModel {
            let transcript: String
            let durationLabel: String
            let totalWords: Int
            let uniqueWords: Int
            let lexicalDiversity: Double       // 0…1 (TTR)
            let lexicalDiversityPercent: Int
            let stimuli: [StimulusPicture]
            let savedStoryId: String
            let accessibilityLabel: String
        }
    }
}

// MARK: - StimulusPicture

/// Картинка-стимул для рассказа.
/// Изображение бранится из существующих ассетов (scene_* / word_*),
/// если они есть в Asset Catalog. Иначе fallback на SF Symbol.
struct StimulusPicture: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    /// Категория: «герои» | «места» | «предметы» | «природа».
    let category: String
    /// SF Symbol — рендер-безопасный fallback (если scene_/word_ ассета нет).
    let symbol: String
}
