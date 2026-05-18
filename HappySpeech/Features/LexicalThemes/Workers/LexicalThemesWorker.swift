import Foundation
import OSLog

// MARK: - LexicalThemesWorkerProtocol

@MainActor
protocol LexicalThemesWorkerProtocol: AnyObject {
    /// Загружает список тем и отметки об освоении для ребёнка.
    func loadThemes(childId: String) async -> LexicalThemesModels.LoadThemes.Response
    /// Строит сессию мини-игр для конкретной темы.
    func buildThemeSession(themeId: String) -> LexicalThemesModels.StartTheme.Response?
    /// Отмечает тему освоенной (точность сессии ≥ 75%).
    func markThemeMastered(childId: String, themeId: String) async
}

// MARK: - LexicalThemesWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 7 «Мир слов».
//
// Загружает темы из локального корпуса, строит сессии мини-игр в
// методической прогрессии (называние → обобщение → классификация →
// действие). Освоение тем хранится локально через `progressSummary`
// профиля ребёнка (ключ с префиксом `lex.`). Offline / on-device.

@MainActor
final class LexicalThemesWorker: LexicalThemesWorkerProtocol {

    private let childRepository: any ChildRepository

    /// Префикс ключа в `progressSummary`, под которым хранится освоение тем.
    static let masteryKeyPrefix = "lex."

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LexicalThemes.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func loadThemes(childId: String) async -> LexicalThemesModels.LoadThemes.Response {
        var mastered: Set<String> = []
        do {
            let child = try await childRepository.fetch(id: childId)
            for (key, value) in child.progressSummary
            where key.hasPrefix(Self.masteryKeyPrefix) && value >= 0.75 {
                mastered.insert(String(key.dropFirst(Self.masteryKeyPrefix.count)))
            }
        } catch {
            Self.logger.error(
                "Failed to read mastery, none marked: \(error.localizedDescription, privacy: .public)"
            )
        }
        return .init(themes: LexicalThemesCorpus.themes, masteredThemeIds: mastered)
    }

    func buildThemeSession(
        themeId: String
    ) -> LexicalThemesModels.StartTheme.Response? {
        guard let theme = LexicalThemesCorpus.theme(id: themeId) else {
            Self.logger.error("Unknown theme: \(themeId, privacy: .public)")
            return nil
        }
        let rounds = Self.makeRounds(theme: theme)
        return .init(theme: theme, rounds: rounds)
    }

    func markThemeMastered(childId: String, themeId: String) async {
        do {
            try await childRepository.updateProgress(
                childId: childId,
                sound: Self.masteryKeyPrefix + themeId,
                rate: 1.0
            )
        } catch {
            Self.logger.error(
                "Failed to persist mastery: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Раунды идут по методической прогрессии типов игр.
    private static func makeRounds(theme: LexicalTheme) -> [LexicalRound] {
        let shuffled = theme.words.shuffled()
        var rounds: [LexicalRound] = []
        let kinds: [LexicalGameKind] = [
            .naming, .naming, .generalization, .generalization,
            .oddOneOut, .oddOneOut, .action, .action
        ]
        for (offset, kind) in kinds.enumerated()
        where offset < min(LexicalThemesCorpus.roundsPerSession, shuffled.count) {
            let word = shuffled[offset % shuffled.count]
            rounds.append(
                LexicalRound(
                    id: "\(kind.rawValue)-\(word.id)",
                    kind: kind,
                    word: word,
                    themeId: theme.id
                )
            )
        }
        return rounds
    }
}
