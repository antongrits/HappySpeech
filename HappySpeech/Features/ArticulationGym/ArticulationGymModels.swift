import Foundation

// MARK: - ArticulationGymModels (Clean Swift: Models)
//
// F-302 v25 — «Зарядка для язычка».
//
// Сущности фичи:
//   • ArticulationSoundGroup — звуковая группа для подбора упражнений
//   • ArticulationItem — domain-модель одного упражнения
//   • ExerciseViewModel — данные для карточки упражнения
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: read-only — статичный каталог упражнений (без Realm, без сети, без ML).

// MARK: - ArticulationSoundGroup

/// Звуковая группа для подбора набора артикуляционных упражнений.
public enum ArticulationSoundGroup: String, CaseIterable, Sendable, Equatable {
    case sibilant  // свистящие (С, З, Ц)
    case hissing   // шипящие (Ш, Ж, Ч, Щ)
    case sonor     // соноры (Р, Л)

    /// Ключ локализации названия группы.
    public var titleKey: String {
        switch self {
        case .sibilant: return "articulationGym.group.sibilant"
        case .hissing:  return "articulationGym.group.hissing"
        case .sonor:    return "articulationGym.group.sonor"
        }
    }
}

// MARK: - ArticulationItem

/// Одно артикуляционное упражнение (domain-модель).
public struct ArticulationItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let titleKey: String         // ключ названия — «Блинчик»
    public let instructionKey: String   // ключ инструкции
    public let illustrationSymbol: String // SF Symbol — fallback-иллюстрация позы
    public let durationSeconds: Int     // 5–8 секунд

    public init(
        id: String,
        titleKey: String,
        instructionKey: String,
        illustrationSymbol: String,
        durationSeconds: Int
    ) {
        self.id = id
        self.titleKey = titleKey
        self.instructionKey = instructionKey
        self.illustrationSymbol = illustrationSymbol
        self.durationSeconds = durationSeconds
    }
}

// MARK: - ExerciseViewModel

/// Готовые данные для отображения карточки упражнения.
public struct ExerciseViewModel: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let instruction: String
    public let illustrationSymbol: String
    public let durationSeconds: Int

    public init(
        id: String,
        title: String,
        instruction: String,
        illustrationSymbol: String,
        durationSeconds: Int
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.illustrationSymbol = illustrationSymbol
        self.durationSeconds = durationSeconds
    }
}

// MARK: - ArticulationGymModels namespace

enum ArticulationGymModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let soundGroup: ArticulationSoundGroup
        }

        struct Response: Sendable {
            let soundGroup: ArticulationSoundGroup
            let exercises: [ArticulationItem]
        }

        struct ViewModel: Sendable, Equatable {
            let soundGroupLabel: String
            let exercises: [ExerciseViewModel]
            let totalCount: Int
        }
    }

    // MARK: TimerTick

    enum TimerTick {
        struct Request: Sendable {
            let exerciseIndex: Int
            let secondsRemaining: Int
        }

        struct Response: Sendable {
            let exerciseIndex: Int
            let secondsRemaining: Int
            let shouldAdvance: Bool
        }

        struct ViewModel: Sendable, Equatable {
            let timerText: String
            let timerAccessibilityLabel: String
            let ringProgress: Double
            let shouldAdvance: Bool
        }
    }

    // MARK: Next

    enum Next {
        struct Request: Sendable {
            let currentIndex: Int
        }

        struct Response: Sendable {
            let nextIndex: Int
            let isLast: Bool
        }

        struct ViewModel: Sendable, Equatable {
            let nextIndex: Int
            let showCompletion: Bool
            let progress: Double
        }
    }

    // MARK: Complete

    enum Complete {
        struct Request: Sendable {}

        struct Response: Sendable {
            let exerciseCount: Int
            let soundGroup: ArticulationSoundGroup
        }

        struct ViewModel: Sendable, Equatable {
            let celebrationText: String
        }
    }
}

// MARK: - ArticulationCatalog

/// Статичный каталог артикуляционных упражнений.
///
/// Используется как основной источник (контент-паки С-группы хранят те же
/// упражнения этапа 0). Универсальный набор работает для любой группы и
/// служит fallback-ом, как указано в ТЗ F-302.
enum ArticulationCatalog {

    /// Универсальный набор — подходит для любого звука (5 упражнений).
    static let universal: [ArticulationItem] = [
        .init(id: "art-smile", titleKey: "articulationGym.exercise.smile.title",
              instructionKey: "articulationGym.exercise.smile.instruction",
              illustrationSymbol: "face.smiling", durationSeconds: 5),
        .init(id: "art-tube", titleKey: "articulationGym.exercise.tube.title",
              instructionKey: "articulationGym.exercise.tube.instruction",
              illustrationSymbol: "mouth", durationSeconds: 5),
        .init(id: "art-pancake", titleKey: "articulationGym.exercise.pancake.title",
              instructionKey: "articulationGym.exercise.pancake.instruction",
              illustrationSymbol: "rectangle.compress.vertical", durationSeconds: 8),
        .init(id: "art-swing", titleKey: "articulationGym.exercise.swing.title",
              instructionKey: "articulationGym.exercise.swing.instruction",
              illustrationSymbol: "arrow.up.arrow.down", durationSeconds: 8),
        .init(id: "art-cup", titleKey: "articulationGym.exercise.cup.title",
              instructionKey: "articulationGym.exercise.cup.instruction",
              illustrationSymbol: "cup.and.saucer", durationSeconds: 8)
    ]

    /// Свистящие (С, З, Ц) — 5 специфичных упражнений.
    static let sibilant: [ArticulationItem] = [
        .init(id: "art-slide", titleKey: "articulationGym.exercise.slide.title",
              instructionKey: "articulationGym.exercise.slide.instruction",
              illustrationSymbol: "triangle", durationSeconds: 6),
        .init(id: "art-bridge", titleKey: "articulationGym.exercise.bridge.title",
              instructionKey: "articulationGym.exercise.bridge.instruction",
              illustrationSymbol: "arc.fill", durationSeconds: 6),
        .init(id: "art-fence", titleKey: "articulationGym.exercise.fence.title",
              instructionKey: "articulationGym.exercise.fence.instruction",
              illustrationSymbol: "lineweight", durationSeconds: 5),
        .init(id: "art-pump", titleKey: "articulationGym.exercise.pump.title",
              instructionKey: "articulationGym.exercise.pump.instruction",
              illustrationSymbol: "wind", durationSeconds: 6),
        .init(id: "art-thread", titleKey: "articulationGym.exercise.thread.title",
              instructionKey: "articulationGym.exercise.thread.instruction",
              illustrationSymbol: "minus", durationSeconds: 6)
    ]

    /// Шипящие (Ш, Ж, Ч, Щ) — 5 специфичных упражнений.
    static let hissing: [ArticulationItem] = [
        .init(id: "art-spatula", titleKey: "articulationGym.exercise.spatula.title",
              instructionKey: "articulationGym.exercise.spatula.instruction",
              illustrationSymbol: "rectangle", durationSeconds: 6),
        .init(id: "art-deepcup", titleKey: "articulationGym.exercise.deepcup.title",
              instructionKey: "articulationGym.exercise.deepcup.instruction",
              illustrationSymbol: "cup.and.saucer.fill", durationSeconds: 8),
        .init(id: "art-focus", titleKey: "articulationGym.exercise.focus.title",
              instructionKey: "articulationGym.exercise.focus.instruction",
              illustrationSymbol: "wind.snow", durationSeconds: 6),
        .init(id: "art-mushroom", titleKey: "articulationGym.exercise.mushroom.title",
              instructionKey: "articulationGym.exercise.mushroom.instruction",
              illustrationSymbol: "umbrella", durationSeconds: 8),
        .init(id: "art-sail", titleKey: "articulationGym.exercise.sail.title",
              instructionKey: "articulationGym.exercise.sail.instruction",
              illustrationSymbol: "triangle.fill", durationSeconds: 6)
    ]

    /// Соноры (Р, Л) — 5 специфичных упражнений.
    static let sonor: [ArticulationItem] = [
        .init(id: "art-painter", titleKey: "articulationGym.exercise.painter.title",
              instructionKey: "articulationGym.exercise.painter.instruction",
              illustrationSymbol: "paintbrush", durationSeconds: 8),
        .init(id: "art-horse", titleKey: "articulationGym.exercise.horse.title",
              instructionKey: "articulationGym.exercise.horse.instruction",
              illustrationSymbol: "hare", durationSeconds: 6),
        .init(id: "art-drum", titleKey: "articulationGym.exercise.drum.title",
              instructionKey: "articulationGym.exercise.drum.instruction",
              illustrationSymbol: "metronome", durationSeconds: 6),
        .init(id: "art-turkey", titleKey: "articulationGym.exercise.turkey.title",
              instructionKey: "articulationGym.exercise.turkey.instruction",
              illustrationSymbol: "bird", durationSeconds: 6),
        .init(id: "art-woodpecker", titleKey: "articulationGym.exercise.woodpecker.title",
              instructionKey: "articulationGym.exercise.woodpecker.instruction",
              illustrationSymbol: "hammer", durationSeconds: 8)
    ]

    /// Возвращает набор упражнений для группы (специфичный + 2 универсальных разминочных).
    static func exercises(for group: ArticulationSoundGroup) -> [ArticulationItem] {
        let warmUp = Array(universal.prefix(2))
        let specific: [ArticulationItem]
        switch group {
        case .sibilant: specific = sibilant
        case .hissing:  specific = hissing
        case .sonor:    specific = sonor
        }
        return warmUp + specific
    }
}
