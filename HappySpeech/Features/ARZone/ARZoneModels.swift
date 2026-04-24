import Foundation
import SwiftUI

// MARK: - ARZone VIP Models

enum ARZoneModels {

    // MARK: - LoadGames
    enum LoadGames {
        struct Request {}
        struct Response {
            let games: [ARGame]
            let instructions: [InstructionCatalog.Seed]
        }
        struct ViewModel {
            let cards: [ARGameCard]
            let instructionSteps: [InstructionStep]
            let mascotState: LyalyaAnimation
            let phase: ARZonePhase
            let isARSupported: Bool
        }
    }

    // MARK: - SelectGame
    enum SelectGame {
        struct Request { let gameId: String }
        struct Response { let game: ARGame }
        struct ViewModel { let destination: ARGameDestination }
    }
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
            icon: "face.dashed",
            tintIndex: 0
        ),
        Seed(
            id: "step-2",
            number: 2,
            titleKey: "ar.zone.step2.title",
            bodyKey: "ar.zone.step2.body",
            icon: "speaker.wave.2.fill",
            tintIndex: 2
        ),
        Seed(
            id: "step-3",
            number: 3,
            titleKey: "ar.zone.step3.title",
            bodyKey: "ar.zone.step3.body",
            icon: "sparkles",
            tintIndex: 4
        )
    ]
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
