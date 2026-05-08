import Foundation

// MARK: - VoiceCloning Namespace
//
// Модели VIP для VoiceCloningScreen (T.1 v17 / Block T).
// Голосовой архив ребёнка для self-comparison: запись 5-секундных
// сэмплов и прослушивание прогресса со временем.

enum VoiceCloning {

    // MARK: - Requests (View → Interactor)

    struct LoadRequest: Equatable {
        let childId: String
    }

    struct StartRecordingRequest: Equatable {
        let childId: String
        let word: String
        let targetSound: String
    }

    struct StopRecordingRequest: Equatable {
        let childId: String
    }

    struct PlaySampleRequest: Equatable {
        let sampleId: String
    }

    struct DeleteSampleRequest: Equatable {
        let sampleId: String
    }

    // MARK: - Responses (Interactor → Presenter)

    struct LoadResponse {
        let samples: [VoiceSampleData]
        let suggestedWord: String
        let targetSound: String
    }

    struct RecordingStateResponse: Equatable {
        let isRecording: Bool
        let elapsedSeconds: Double
        let amplitude: Float
    }

    struct RecordingResultResponse {
        let success: Bool
        let savedSampleId: String?
        let errorMessage: String?
    }

    struct PlaybackResponse: Equatable {
        let isPlaying: Bool
        let currentSampleId: String?
    }

    struct DeleteResponse: Equatable {
        let success: Bool
        let deletedSampleId: String
    }

    // MARK: - ViewModel rows (Presenter → View)

    /// Готовая для отрисовки строка архива.
    struct ArchiveRow: Identifiable, Equatable {
        let id: String
        let title: String              // слово
        let targetSound: String
        let dateText: String           // "8 мая, 14:30"
        let durationText: String       // "0:04"
        let audioFilePath: String
    }

    /// Группировка строк по неделям ("На этой неделе", "Неделя назад", "Май 2026").
    struct ArchiveSection: Identifiable, Equatable {
        var id: String { title }
        let title: String
        let rows: [ArchiveRow]
    }

    /// Состояние экрана.
    enum ScreenState: Equatable {
        case loading
        case empty
        case ready
        case error(String)
    }

    // MARK: - Suggested words (для записи)

    /// Слова-подсказки по группам звуков для записи 5-сек сэмпла.
    /// Минимальный набор для T.1 — расширяется в content engine.
    enum SuggestedWordCatalog {

        static func words(forSound sound: String) -> [String] {
            switch sound.uppercased() {
            case "С":
                return ["сом", "сани", "сапоги", "сон", "санки"]
            case "З":
                return ["зонт", "зима", "заяц", "звезда", "замок"]
            case "Ц":
                return ["цапля", "цыплёнок", "цветок", "цирк"]
            case "Ш":
                return ["шапка", "шуба", "шарф", "шишка", "шкаф"]
            case "Ж":
                return ["жук", "жираф", "жаба", "журнал"]
            case "Ч":
                return ["часы", "чайник", "черепаха", "чашка"]
            case "Щ":
                return ["щётка", "щенок", "щука", "ящик"]
            case "Р":
                return ["рыба", "рак", "ракета", "роза", "радуга"]
            case "Л":
                return ["лук", "лиса", "лимон", "ложка", "луна"]
            case "К":
                return ["кот", "кит", "куртка", "кубик"]
            case "Г":
                return ["гусь", "груша", "гриб", "горох"]
            case "Х":
                return ["хлеб", "хобот", "халат", "хомяк"]
            default:
                return ["мама", "папа", "дом", "солнце"]
            }
        }

        static func defaultWord(forSound sound: String) -> String {
            words(forSound: sound).first ?? "мама"
        }
    }
}
