import Foundation

// MARK: - ParentVoiceNoteModels (Clean Swift: Models)
//
// v31 Волна B, Функция Ф.4 «Parent voice notes».
//
// Родитель записывает короткое подбадривание (до 30 сек) для конкретного
// шаблона урока. В hero-зоне LessonPlayer у ребёнка появляется кнопка
// «Мамин голос». Per-child opt-in (Settings). Полностью локально
// (Documents/ParentVoiceNotes/), не уходит в Firestore — COPPA-safe.

// MARK: - LessonTemplateOption

/// Лёгкий идентификатор шаблона урока (subset GameType-карта).
/// Используется чтобы родитель мог выбрать, к какому шаблону привязать запись.
public struct LessonTemplateOption: Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let symbolName: String

    public init(id: String, title: String, symbolName: String) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
    }

    /// Канонический набор шаблонов (16 шаблонов уроков HappySpeech).
    /// Локализуется в Presenter — здесь только ключи и системные иконки.
    public static let canonical: [LessonTemplateOption] = [
        .init(id: "repeat-after-model",   title: "voice.tpl.repeat",        symbolName: "speaker.wave.2.fill"),
        .init(id: "listen-and-choose",    title: "voice.tpl.listen",        symbolName: "ear.fill"),
        .init(id: "drag-and-match",       title: "voice.tpl.dragMatch",     symbolName: "rectangle.and.hand.point.up.left.fill"),
        .init(id: "story-completion",     title: "voice.tpl.story",         symbolName: "book.fill"),
        .init(id: "puzzle-reveal",        title: "voice.tpl.puzzle",        symbolName: "puzzlepiece.fill"),
        .init(id: "sorting",              title: "voice.tpl.sorting",       symbolName: "square.grid.2x2.fill"),
        .init(id: "memory",               title: "voice.tpl.memory",        symbolName: "rectangle.on.rectangle.fill"),
        .init(id: "bingo",                title: "voice.tpl.bingo",         symbolName: "checkerboard.rectangle"),
        .init(id: "sound-hunter",         title: "voice.tpl.hunter",        symbolName: "magnifyingglass"),
        .init(id: "articulation-imitation", title: "voice.tpl.articulate",  symbolName: "mouth.fill"),
        .init(id: "ar-activity",          title: "voice.tpl.ar",            symbolName: "viewfinder"),
        .init(id: "visual-acoustic",      title: "voice.tpl.visualAcoust",  symbolName: "waveform"),
        .init(id: "breathing",            title: "voice.tpl.breathing",     symbolName: "wind"),
        .init(id: "rhythm",               title: "voice.tpl.rhythm",        symbolName: "metronome.fill"),
        .init(id: "narrative-quest",      title: "voice.tpl.narrative",     symbolName: "books.vertical.fill"),
        .init(id: "minimal-pairs",        title: "voice.tpl.minimalPairs",  symbolName: "rectangle.split.2x1.fill")
    ]
}

// MARK: - RecorderState

public enum RecorderState: Sendable, Equatable {
    case idle
    case recording(elapsedSeconds: Double)
    case stopped(durationSeconds: Double, fileURL: URL)
    case playingPreview
    case failed(message: String)
}

// MARK: - ParentVoiceNoteModels namespace

enum ParentVoiceNoteModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let childId: String
        }

        struct Response: Sendable {
            let childId: String
            let templates: [LessonTemplateOption]
            let existingClips: [ParentVoiceClipData]
            let isEnabledGlobally: Bool
        }

        struct ViewModel: Sendable {
            let title: String
            let introMessage: String
            let templates: [TemplateViewModel]
            let isEnabledGlobally: Bool
            let optInLabel: String
            let optInSubtitle: String
        }

        struct TemplateViewModel: Identifiable, Sendable, Equatable, Hashable {
            let id: String
            let title: String
            let symbolName: String
            let hasClip: Bool
            let durationLabel: String?
            let recordedAtLabel: String?
        }
    }

    // MARK: SaveClip

    enum SaveClip {
        struct Request: Sendable {
            let childId: String
            let lessonTemplate: String
            let fileURL: URL
            let durationSec: Double
        }

        struct Response: Sendable {
            let savedClip: ParentVoiceClipData
        }
    }

    // MARK: DeleteClip

    enum DeleteClip {
        struct Request: Sendable {
            let clipId: String
        }

        struct Response: Sendable {
            let wasDeleted: Bool
            let clipId: String
        }
    }

    // MARK: ToggleEnabled

    enum ToggleEnabled {
        struct Request: Sendable {
            let childId: String
            let isEnabled: Bool
        }

        struct Response: Sendable {
            let isEnabled: Bool
        }
    }
}
