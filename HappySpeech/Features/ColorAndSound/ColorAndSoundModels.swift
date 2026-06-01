import Foundation
import SwiftUI

// MARK: - ColorAndSoundModels

/// Модели игры «Цвет и звук» (фонематическое восприятие).
///
/// Каждому рабочему звуку сопоставлен «цвет звука» (из палитры бренда — без
/// hex). В раунде показывается целевой звук, а на карточках — реальные слова
/// (`KidWordContentProvider`): часть начинается на целевой звук, часть — нет.
/// Ребёнок отмечает слова «своего цвета». Верные отметки идут в outcome.
enum ColorAndSoundModels {

    /// Палитра «цветов звука» — токены бренда (не hex).
    enum SoundColor: String, Hashable, CaseIterable {
        case coral, sky, mint, butter, lilac, rose

        var color: Color {
            switch self {
            case .coral:  return ColorTokens.Brand.primary
            case .sky:    return ColorTokens.Brand.sky
            case .mint:   return ColorTokens.Brand.mint
            case .butter: return ColorTokens.Brand.butter
            case .lilac:  return ColorTokens.Brand.lilac
            case .rose:   return ColorTokens.Brand.rose
            }
        }

        var name: String {
            switch self {
            case .coral:  return String(localized: "colorAndSound.color.coral")
            case .sky:    return String(localized: "colorAndSound.color.sky")
            case .mint:   return String(localized: "colorAndSound.color.mint")
            case .butter: return String(localized: "colorAndSound.color.butter")
            case .lilac:  return String(localized: "colorAndSound.color.lilac")
            case .rose:   return String(localized: "colorAndSound.color.rose")
            }
        }
    }

    /// Карточка-слово в раунде.
    struct WordCard: Identifiable, Hashable {
        let id: String
        let text: String
        let asset: String?
        /// Принадлежит ли слово целевому звуку раунда.
        let belongs: Bool
        var isSelected: Bool
    }

    struct ViewState: Equatable {
        /// Целевой звук текущего раунда.
        var sound: String
        var soundColor: SoundColor
        var cards: [WordCard]
        var roundIndex: Int = 0
        var totalRounds: Int = 1
        var correctPicks: Int = 0
        var wrongPicks: Int = 0
        var bestStars: Int = 0
        var isLoaded: Bool = false
        var roundComplete: Bool = false

        /// Сколько правильных слов нужно найти в раунде.
        var targetCount: Int { cards.filter(\.belongs).count }
        /// Сколько верных уже выбрано в текущем раунде.
        var foundCount: Int { cards.filter { $0.belongs && $0.isSelected }.count }

        var isGameComplete: Bool { roundIndex >= totalRounds }

        var accuracy: Double {
            let attempts = correctPicks + wrongPicks
            return attempts > 0 ? Double(correctPicks) / Double(attempts) : 0
        }

        var stars: Int {
            guard correctPicks + wrongPicks > 0 else { return 0 }
            switch accuracy {
            case 0.9...: return 3
            case 0.7..<0.9: return 2
            default: return 1
            }
        }

        static let empty = ViewState(
            sound: "С",
            soundColor: .sky,
            cards: []
        )

        static let initial: ViewState = {
            let rounds = ColorAndSoundContent.rounds(forTargetSounds: [], count: 3)
            var state = ViewState(sound: "С", soundColor: .sky, cards: [])
            state.totalRounds = rounds.count
            state.isLoaded = true
            if let first = rounds.first { state.apply(round: first) }
            return state
        }()

        /// Загружает в состояние конкретный раунд.
        mutating func apply(round: ColorAndSoundContent.Round) {
            sound = round.sound
            soundColor = round.color
            cards = round.cards.shuffled()
            roundComplete = false
        }
    }
}
