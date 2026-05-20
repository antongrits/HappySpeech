import Foundation

// MARK: - CustomWordListModels (Clean Swift: Models)
//
// v31 Волна C, Функция Ф.4 «Списки слов специалиста».
//
// Логопед составляет плоский список слов с целевым звуком, а ContentEngine
// собирает из него готовые упражнения трёх шаблонов: repeat-after-model,
// bingo, memory. Списки хранятся локально (CustomWordListObject), без
// внешней синхронизации, без диагностических меток (project guide §11).

// MARK: - GeneratedExerciseKind

public enum GeneratedExerciseKind: String, Sendable, Codable, Equatable, CaseIterable {
    case repeatAfterModel = "repeat-after-model"
    case bingo
    case memory

    public var titleKey: String {
        switch self {
        case .repeatAfterModel: return "customWordList.template.repeat"
        case .bingo:            return "customWordList.template.bingo"
        case .memory:           return "customWordList.template.memory"
        }
    }
}

// MARK: - GeneratedExercise

public struct GeneratedExercise: Sendable, Identifiable, Equatable {
    public let id: String
    public let kind: GeneratedExerciseKind
    public let words: [String]
    public let targetSound: String

    public init(id: String, kind: GeneratedExerciseKind, words: [String], targetSound: String) {
        self.id = id
        self.kind = kind
        self.words = words
        self.targetSound = targetSound
    }
}

// MARK: - WordListDraft (editor state)

public struct WordListDraft: Sendable, Equatable {
    public var id: String
    public var name: String
    public var targetSound: String
    public var words: [String]

    public init(
        id: String = UUID().uuidString,
        name: String = "",
        targetSound: String = "Р",
        words: [String] = []
    ) {
        self.id = id
        self.name = name
        self.targetSound = targetSound
        self.words = words
    }

    func toData(specialistId: String, createdAt: Date, now: Date = Date()) -> CustomWordListData {
        CustomWordListData(
            id: id,
            specialistId: specialistId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            targetSound: targetSound,
            words: words
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            createdAt: createdAt,
            updatedAt: now
        )
    }

    static func from(_ data: CustomWordListData) -> WordListDraft {
        WordListDraft(
            id: data.id,
            name: data.name,
            targetSound: data.targetSound,
            words: data.words
        )
    }
}

// MARK: - CustomWordListModels namespace

enum CustomWordListModels {

    // MARK: Available target sounds (логопедически осмысленный набор)

    static let availableSounds: [String] = [
        "С", "З", "Ц", "Ш", "Ж", "Ч", "Щ", "Р", "Рь", "Л", "Ль", "К", "Г", "Х", "Й"
    ]

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let specialistId: String
        }

        struct Response: Sendable {
            let lists: [CustomWordListData]
        }

        struct ViewModel: Sendable {
            let lists: [RowViewModel]
            let isEmpty: Bool
        }

        struct RowViewModel: Sendable, Identifiable, Equatable {
            let id: String
            let name: String
            let targetSoundText: String
            let wordsCountText: String
            let accessibilityLabel: String
        }
    }

    // MARK: Save

    enum Save {
        struct Request: Sendable {
            let specialistId: String
            let draft: WordListDraft
        }

        struct Response: Sendable {
            let savedId: String
        }

        struct FailureResponse: Sendable {
            let reason: ValidationError
        }

        struct ViewModel: Sendable {
            let dismiss: Bool
        }

        struct FailureViewModel: Sendable {
            let message: String
        }
    }

    // MARK: Delete

    enum Delete {
        struct Request: Sendable {
            let id: String
        }

        struct Response: Sendable {
            let removedId: String
        }
    }

    // MARK: Preview (in-editor generated exercises list)

    enum Preview {
        struct Request: Sendable {
            let draft: WordListDraft
        }

        struct Response: Sendable {
            let exercises: [GeneratedExercise]
        }

        struct ViewModel: Sendable {
            let text: String
            let exercisesCount: Int
        }
    }
}

// MARK: - ValidationError

public enum ValidationError: Error, Equatable, Sendable {
    case emptyName
    case emptyWords
}
