import Foundation
import SwiftUI

// MARK: - ARZone VIP Models

enum ARZoneModels {

    // MARK: - LoadGames
    enum LoadGames {
        struct Request {
            /// Идентификатор ребёнка — нужен AdaptivePlannerService для рекомендаций.
            let childId: String
            init(childId: String = "") { self.childId = childId }
        }
        struct Response {
            let games: [ARGame]
            let instructions: [InstructionCatalog.Seed]
            let tips: [InstructionCatalog.TipSeed]
            let plannerAdvice: ARPlannerAdvice?
        }
        struct ViewModel {
            let cards: [ARGameCard]
            let instructionSteps: [InstructionStep]
            let tips: [ARQuickTip]
            let recommendedCard: ARGameCard?
            let mascotState: LyalyaAnimation
            let phase: ARZonePhase
            let isARSupported: Bool
            /// Подсказка AdaptivePlanner — «сегодня Ляля советует», предупреждение об усталости.
            let plannerBanner: ARPlannerBanner?
        }
    }

    // MARK: - SelectGame (с pre-flight tutorial)
    enum SelectGame {
        struct Request {
            let gameId: String
            /// true — если пользователь уже видел инструкцию к этой игре (>= 1 раз)
            let skipTutorial: Bool
            init(gameId: String, skipTutorial: Bool = false) {
                self.gameId = gameId
                self.skipTutorial = skipTutorial
            }
        }
        struct Response {
            let game: ARGame
            let tutorial: ARTutorial
            let skipTutorial: Bool
        }
        struct ViewModel {
            let destination: ARGameDestination
            /// Если nil — нет инструкции, сразу запускаем игру.
            let tutorial: ARTutorial?
        }
    }

    // MARK: - SelectFallback
    /// Пользователь нажал «Открыть 2D-альтернативу» на устройстве без TrueDepth.
    enum SelectFallback {
        struct Request {}
        struct Response {}
        struct ViewModel {}
    }

    // MARK: - DismissTutorial
    /// Пользователь нажал «Начать» или «Пропустить» в tutorial sheet.
    enum DismissTutorial {
        enum Action: Sendable, Equatable {
            case start           // нажал «Начать»
            case skip            // нажал «Пропустить»
        }
        struct Request {
            let destination: ARGameDestination
            let action: Action
        }
        struct Response {
            let destination: ARGameDestination
        }
        struct ViewModel {
            let destination: ARGameDestination
        }
    }

    // MARK: - RefreshPlannerAdvice
    /// Периодическое обновление рекомендации планировщика (например, после завершения AR-сессии).
    enum RefreshPlannerAdvice {
        struct Request { let childId: String }
        struct Response { let advice: ARPlannerAdvice? }
        struct ViewModel { let banner: ARPlannerBanner? }
    }
}

// MARK: - ARTutorial (инструкция перед игрой)

/// Структура инструкции, показываемой в modal sheet перед стартом AR-игры.
/// Содержит шаги с SF Symbol иконками (fallback вместо Lottie) и короткий текст.
public struct ARTutorial: Sendable, Identifiable, Hashable {
    public let id: String                  // == gameId
    public let titleKey: String            // "ar.tutorial.<gameId>.title"
    public let bodyKey: String             // "ar.tutorial.<gameId>.body" (1-2 предложения)
    public let steps: [ARTutorialStep]
    public let animationSystemSymbol: String   // SF Symbol для анимации (symbolEffect)
    public let accentColorIndex: Int       // 0…5 для градиента
}

/// Один шаг в инструкции AR-игры.
public struct ARTutorialStep: Sendable, Identifiable, Hashable {
    public let id: String
    public let icon: String                // SF Symbol
    public let textKey: String
}

// MARK: - ARTutorialCatalog

/// Каталог инструкций для всех 8 AR-игр.
enum ARTutorialCatalog {

    static func tutorial(for gameId: String) -> ARTutorial {
        switch gameId {
        case "ar-mirror":
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.arMirror.title",
                bodyKey: "ar.tutorial.arMirror.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.arMirror.step1"),
                    ARTutorialStep(id: "s2", icon: "face.smiling.inverse", textKey: "ar.tutorial.arMirror.step2"),
                    ARTutorialStep(id: "s3", icon: "star.fill", textKey: "ar.tutorial.arMirror.step3")
                ],
                animationSystemSymbol: "camera.metering.center.weighted",
                accentColorIndex: 0
            )
        case "butterfly-catch":
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.butterflyCatch.title",
                bodyKey: "ar.tutorial.butterflyCatch.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.butterflyCatch.step1"),
                    ARTutorialStep(id: "s2", icon: "mouth.fill", textKey: "ar.tutorial.butterflyCatch.step2"),
                    ARTutorialStep(id: "s3", icon: "sparkles", textKey: "ar.tutorial.butterflyCatch.step3")
                ],
                animationSystemSymbol: "sparkles",
                accentColorIndex: 1
            )
        case "hold-the-pose":
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.holdThePose.title",
                bodyKey: "ar.tutorial.holdThePose.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.holdThePose.step1"),
                    ARTutorialStep(id: "s2", icon: "face.smiling", textKey: "ar.tutorial.holdThePose.step2"),
                    ARTutorialStep(id: "s3", icon: "timer", textKey: "ar.tutorial.holdThePose.step3")
                ],
                animationSystemSymbol: "stopwatch",
                accentColorIndex: 2
            )
        case "mimic-lyalya":
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.mimicLyalya.title",
                bodyKey: "ar.tutorial.mimicLyalya.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.mimicLyalya.step1"),
                    ARTutorialStep(id: "s2", icon: "person.fill.viewfinder", textKey: "ar.tutorial.mimicLyalya.step2"),
                    ARTutorialStep(id: "s3", icon: "checkmark.circle.fill", textKey: "ar.tutorial.mimicLyalya.step3")
                ],
                animationSystemSymbol: "person.fill.viewfinder",
                accentColorIndex: 3
            )
        case "breathing-ar":
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.breathingAR.title",
                bodyKey: "ar.tutorial.breathingAR.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.breathingAR.step1"),
                    ARTutorialStep(id: "s2", icon: "wind", textKey: "ar.tutorial.breathingAR.step2"),
                    ARTutorialStep(id: "s3", icon: "lungs.fill", textKey: "ar.tutorial.breathingAR.step3")
                ],
                animationSystemSymbol: "wind",
                accentColorIndex: 2
            )
        case "sound-and-face":
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.soundAndFace.title",
                bodyKey: "ar.tutorial.soundAndFace.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.soundAndFace.step1"),
                    ARTutorialStep(id: "s2", icon: "mic.fill", textKey: "ar.tutorial.soundAndFace.step2"),
                    ARTutorialStep(id: "s3", icon: "waveform.and.mic", textKey: "ar.tutorial.soundAndFace.step3")
                ],
                animationSystemSymbol: "waveform.and.mic",
                accentColorIndex: 5
            )
        case "pose-sequence":
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.poseSequence.title",
                bodyKey: "ar.tutorial.poseSequence.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.poseSequence.step1"),
                    ARTutorialStep(id: "s2", icon: "list.number", textKey: "ar.tutorial.poseSequence.step2"),
                    ARTutorialStep(id: "s3", icon: "checkmark.seal.fill", textKey: "ar.tutorial.poseSequence.step3")
                ],
                animationSystemSymbol: "list.number",
                accentColorIndex: 4
            )
        case "ar-story-quest":
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.arStoryQuest.title",
                bodyKey: "ar.tutorial.arStoryQuest.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.arStoryQuest.step1"),
                    ARTutorialStep(id: "s2", icon: "book.pages", textKey: "ar.tutorial.arStoryQuest.step2"),
                    ARTutorialStep(id: "s3", icon: "star.bubble.fill", textKey: "ar.tutorial.arStoryQuest.step3")
                ],
                animationSystemSymbol: "book.pages",
                accentColorIndex: 3
            )
        default:
            return ARTutorial(
                id: gameId,
                titleKey: "ar.tutorial.default.title",
                bodyKey: "ar.tutorial.default.body",
                steps: [
                    ARTutorialStep(id: "s1", icon: "camera.fill", textKey: "ar.tutorial.default.step1")
                ],
                animationSystemSymbol: "arkit",
                accentColorIndex: 0
            )
        }
    }
}

// MARK: - ARPlannerAdvice (domain — из AdaptivePlannerService)

/// Рекомендация AdaptivePlannerService для AR-зоны.
public struct ARPlannerAdvice: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// Планировщик рекомендует именно AR сегодня — показать highlighted game
        case arRecommended(gameId: String)
        /// Ребёнок устал — мягкое предупреждение
        case fatigueWarning(level: FatigueLevel)
        /// Всё хорошо — нет специального сообщения
        case none
    }
    public let kind: Kind
    public let recommendedGameId: String?

    public init(kind: Kind, recommendedGameId: String? = nil) {
        self.kind = kind
        self.recommendedGameId = recommendedGameId
    }
}

// MARK: - ARPlannerBanner (view-ready)

/// View-модель баннера Планировщика в ARZone.
public struct ARPlannerBanner: Sendable, Identifiable, Equatable {
    public enum Variant: Sendable, Equatable {
        case recommended        // «Сегодня Ляля советует:»
        case fatigueWarning     // «Сделай паузу перед AR»
        case fatigueLight       // «Устал(а)? Можно немного отдохнуть»
    }
    public let id: String
    public let variant: Variant
    public let titleKey: String
    public let bodyKey: String
    public let icon: String
    public let highlightedGameId: String?  // если .recommended — какую игру выделить
}

// MARK: - ARGameBadge (бейдж состояния карточки)

/// Бейдж для карточки AR-игры — показывает статус от планировщика/прогресса.
public enum ARGameBadge: Sendable, Equatable, Hashable {
    case recommendedByLyalya   // «Ляля советует» — AdaptivePlanner выбрал эту игру
    case newGame               // первый раз
    case completed             // ребёнок уже прошёл сегодня
    case none
}

// MARK: - ARZonePhase

/// Фаза отображения ARZone-экрана.
/// `.loading` — 3D Ляля ещё грузится (первые ~300 мс),
/// `.ready` — всё отрисовано, карточки готовы,
/// `.unsupported` — устройство не поддерживает ARFaceTracking.
public enum ARZonePhase: Sendable, Hashable {
    case loading
    case ready
    case unsupported
}

// MARK: - InstructionStep

/// Шаг инструкции для входа в AR-зону.
/// Показывается на экране входа в AR-зону (3 шага: поднеси лицо → включи звук → следуй за Лялей).
public struct InstructionStep: Sendable, Identifiable, Hashable {
    public let id: String
    public let number: Int
    public let title: String
    public let body: String
    public let icon: String           // SF Symbol
    public let tintIndex: Int         // 0…5 → ARCardPalette
}

// MARK: - InstructionCatalog

/// Источник правды по статичным шагам инструкции.
/// Тексты подтягиваются через `String(localized:)` в Presenter.
enum InstructionCatalog {

    struct Seed: Sendable, Hashable {
        let id: String
        let number: Int
        let titleKey: String
        let bodyKey: String
        let icon: String
        let tintIndex: Int
    }

    static let seeds: [Seed] = [
        Seed(
            id: "step-1",
            number: 1,
            titleKey: "ar.zone.step1.title",
            bodyKey: "ar.zone.step1.body",
            icon: "face.smiling",
            tintIndex: 0
        ),
        Seed(
            id: "step-2",
            number: 2,
            titleKey: "ar.zone.step2.title",
            bodyKey: "ar.zone.step2.body",
            icon: "light.max",
            tintIndex: 2
        ),
        Seed(
            id: "step-3",
            number: 3,
            titleKey: "ar.zone.step3.title",
            bodyKey: "ar.zone.step3.body",
            icon: "mic.fill",
            tintIndex: 4
        )
    ]

    // MARK: - Quick tips

    /// Лёгкие подсказки-карусель под hero-баннером (ротация 4 сек).
    /// Никакой бизнес-логики — это «совет дня» для повышения качества AR-сессии.
    struct TipSeed: Sendable, Hashable {
        let id: String
        let textKey: String
        let icon: String
    }

    static let tipSeeds: [TipSeed] = [
        TipSeed(id: "tip-1", textKey: "ar.zone.tip1", icon: "headphones"),
        TipSeed(id: "tip-2", textKey: "ar.zone.tip2", icon: "leaf.fill"),
        TipSeed(id: "tip-3", textKey: "ar.zone.tip3", icon: "hand.thumbsup.fill")
    ]
}

// MARK: - ARQuickTip (view-ready)

/// Готовая к рендеру подсказка для карусели.
public struct ARQuickTip: Sendable, Identifiable, Hashable {
    public let id: String
    public let text: String
    public let icon: String
}

// MARK: - ARDifficultyFilter

/// Фильтр карточек по сложности.
public enum ARDifficultyFilter: Hashable, CaseIterable, Sendable {
    case all
    case easy       // difficulty == 1
    case medium     // difficulty == 2
    case hard       // difficulty == 3

    /// Локализованный заголовок чипа.
    public var titleKey: String {
        switch self {
        case .all:    return "ar.zone.filter.all"
        case .easy:   return "ar.zone.filter.easy"
        case .medium: return "ar.zone.filter.medium"
        case .hard:   return "ar.zone.filter.hard"
        }
    }

    /// Подходит ли карточка под фильтр.
    public func matches(_ card: ARGameCard) -> Bool {
        switch self {
        case .all:    return true
        case .easy:   return card.difficulty == 1
        case .medium: return card.difficulty == 2
        case .hard:   return card.difficulty == 3
        }
    }
}

// MARK: - ARGame (domain model)

public struct ARGame: Sendable, Identifiable, Hashable {
    public let id: String
    public let nameKey: String                  // ключ для String(localized:)
    public let descriptionKey: String
    public let iconName: String                 // SF Symbol
    public let difficulty: Int                  // 1…3
    public let estimatedMinutes: Int
    public let targetSounds: [String]           // пустой = все звуки
    public let requiresFaceTracking: Bool
    public let destination: ARGameDestination
}

// MARK: - ARGameDestination

public enum ARGameDestination: String, Sendable, Hashable, CaseIterable {
    case arMirror
    case butterflyCatch
    case holdThePose
    case mimicLyalya
    case breathingGame
    case soundAndFace
    case poseSequence
    case arStoryQuest
}

// MARK: - ARGameCard (view-ready)

public struct ARGameCard: Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let difficulty: Int
    public let estimatedMinutes: Int
    public let accentColorIndex: Int            // 0…5 для gradient выбора
    public let destination: ARGameDestination
    /// Бейдж состояния от AdaptivePlannerService.
    public let badge: ARGameBadge
    /// true, если ребёнок уже запускал эту игру — tutorial можно пропустить.
    public let hasBeenPlayedBefore: Bool
}

// MARK: - Catalog (источник правды по играм)

enum ARGameCatalog {

    static let all: [ARGame] = [
        ARGame(
            id: "ar-mirror",
            nameKey: "ar.game.arMirror.name",
            descriptionKey: "ar.game.arMirror.desc",
            iconName: "face.smiling",
            difficulty: 1,
            estimatedMinutes: 3,
            targetSounds: [],
            requiresFaceTracking: true,
            destination: .arMirror
        ),
        ARGame(
            id: "butterfly-catch",
            nameKey: "ar.game.butterflyCatch.name",
            descriptionKey: "ar.game.butterflyCatch.desc",
            iconName: "sparkles",
            difficulty: 2,
            estimatedMinutes: 4,
            targetSounds: [],
            requiresFaceTracking: true,
            destination: .butterflyCatch
        ),
        ARGame(
            id: "hold-the-pose",
            nameKey: "ar.game.holdThePose.name",
            descriptionKey: "ar.game.holdThePose.desc",
            iconName: "stopwatch",
            difficulty: 2,
            estimatedMinutes: 3,
            targetSounds: [],
            requiresFaceTracking: true,
            destination: .holdThePose
        ),
        ARGame(
            id: "mimic-lyalya",
            nameKey: "ar.game.mimicLyalya.name",
            descriptionKey: "ar.game.mimicLyalya.desc",
            iconName: "person.fill.viewfinder",
            difficulty: 1,
            estimatedMinutes: 4,
            targetSounds: [],
            requiresFaceTracking: true,
            destination: .mimicLyalya
        ),
        ARGame(
            id: "breathing-ar",
            nameKey: "ar.game.breathingAR.name",
            descriptionKey: "ar.game.breathingAR.desc",
            iconName: "wind",
            difficulty: 1,
            estimatedMinutes: 3,
            targetSounds: [],
            requiresFaceTracking: true,
            destination: .breathingGame
        ),
        ARGame(
            id: "sound-and-face",
            nameKey: "ar.game.soundAndFace.name",
            descriptionKey: "ar.game.soundAndFace.desc",
            iconName: "waveform.and.mic",
            difficulty: 3,
            estimatedMinutes: 5,
            targetSounds: ["С", "З", "Ш", "Ж", "Р", "Л"],
            requiresFaceTracking: true,
            destination: .soundAndFace
        ),
        ARGame(
            id: "pose-sequence",
            nameKey: "ar.game.poseSequence.name",
            descriptionKey: "ar.game.poseSequence.desc",
            iconName: "list.number",
            difficulty: 3,
            estimatedMinutes: 5,
            targetSounds: [],
            requiresFaceTracking: true,
            destination: .poseSequence
        ),
        ARGame(
            id: "ar-story-quest",
            nameKey: "ar.game.arStoryQuest.name",
            descriptionKey: "ar.game.arStoryQuest.desc",
            iconName: "book.pages",
            difficulty: 3,
            estimatedMinutes: 6,
            targetSounds: [],
            requiresFaceTracking: true,
            destination: .arStoryQuest
        )
    ]

    static func game(id: String) -> ARGame? {
        all.first { $0.id == id }
    }
}

// MARK: - AR Card Palette

/// Палитра градиентов для карточек AR-игр (индекс 0…5 циклически).
enum ARCardPalette {
    static let gradients: [[Color]] = [
        [ColorTokens.Brand.primary, ColorTokens.Brand.rose],
        [ColorTokens.Brand.sky, ColorTokens.Brand.lilac],
        [ColorTokens.Brand.mint, ColorTokens.Brand.sky],
        [ColorTokens.Brand.butter, ColorTokens.Brand.primary],
        [ColorTokens.Brand.lilac, ColorTokens.Brand.primary],
        [ColorTokens.Brand.rose, ColorTokens.Brand.butter]
    ]

    static func gradient(for index: Int) -> [Color] {
        gradients[index % gradients.count]
    }
}
