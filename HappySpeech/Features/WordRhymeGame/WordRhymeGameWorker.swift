import Foundation
import OSLog

// MARK: - WordRhymeGameWorkerProtocol

@MainActor
protocol WordRhymeGameWorkerProtocol: AnyObject {
    /// Собирает раунды игры на рифмы из реального словаря, отфильтрованного
    /// под группы звуков ребёнка. Каждый раунд — слово-цель и 3 варианта,
    /// один из которых рифмуется.
    func buildRounds(childId: String) async -> [WordRhymeGameModels.Round]
}

// MARK: - WordRhymeGameWorker (Clean Swift: Worker)
//
// Формирует игру на рифмы из bundled-манифеста (`LessonContentMap`):
//   • берёт реальные слова рабочих групп звуков ребёнка;
//   • группирует по рифмующемуся «хвосту» (совпадение ударно-финальной части);
//   • для каждого слова-цели подбирает рифму и 2 дистрактора из других хвостов.
// Offline / on-device — словарь локальный.

@MainActor
final class WordRhymeGameWorker: WordRhymeGameWorkerProtocol {

    static let roundsPerSession = 6

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordRhymeGame.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildRounds(childId: String) async -> [WordRhymeGameModels.Round] {
        var targetSounds: [String] = []
        if !childId.isEmpty {
            do {
                targetSounds = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let groups = KidWordContentProvider.groups(forTargetSounds: targetSounds)
        var pool: [KidWordContentProvider.GameWord] = []
        for group in groups {
            pool.append(contentsOf: KidWordContentProvider.words(in: group))
        }
        // Подмешиваем заднеязычные/соноры для разнообразия дистракторов,
        // если рабочая группа узкая.
        if pool.count < 24 {
            pool.append(contentsOf: KidWordContentProvider.words(in: .velar))
            pool.append(contentsOf: KidWordContentProvider.words(in: .sonorant))
        }
        // Уникализируем по тексту.
        var seen = Set<String>()
        pool = pool.filter { seen.insert($0.text.lowercased()).inserted }

        let rounds = Self.makeRounds(from: pool)
        Self.logger.debug("built \(rounds.count) rhyme rounds")
        return rounds
    }

    // MARK: - Pure round building

    /// Группирует слова по рифмующемуся хвосту и собирает раунды.
    static func makeRounds(from pool: [KidWordContentProvider.GameWord]) -> [WordRhymeGameModels.Round] {
        // tail → слова
        var byTail: [String: [KidWordContentProvider.GameWord]] = [:]
        for word in pool {
            let tail = rhymeTail(of: word.text)
            guard !tail.isEmpty else { continue }
            byTail[tail, default: []].append(word)
        }

        // Хвосты, у которых есть пара (для рифмы) — кандидаты на слово-цель.
        let rhymingTails = byTail.filter { $0.value.count >= 2 }.keys.sorted()

        var rounds: [WordRhymeGameModels.Round] = []
        var usedTargets = Set<String>()

        for tail in rhymingTails {
            guard rounds.count < roundsPerSession else { break }
            let group = byTail[tail] ?? []
            guard group.count >= 2 else { continue }
            let target = group[0]
            let rhyme = group[1]
            guard !usedTargets.contains(target.text.lowercased()) else { continue }
            usedTargets.insert(target.text.lowercased())

            // 2 дистрактора из НЕрифмующихся слов.
            let distractors = pool
                .filter { rhymeTail(of: $0.text) != tail }
                .filter { $0.text.lowercased() != target.text.lowercased() }
                .prefix(40)
                .shuffled()
                .prefix(2)

            guard distractors.count == 2 else { continue }

            let correctOption = WordRhymeGameModels.RhymeOption(
                id: "opt-rhyme",
                word: rhyme.text,
                asset: rhyme.asset
            )
            var options = [correctOption] + distractors.enumerated().map { idx, word in
                WordRhymeGameModels.RhymeOption(
                    id: "opt-d\(idx)",
                    word: word.text,
                    asset: word.asset
                )
            }
            options.shuffle()

            rounds.append(
                WordRhymeGameModels.Round(
                    id: "round-\(target.id)",
                    targetWord: target.text,
                    targetAsset: target.asset,
                    options: options,
                    correctOptionId: correctOption.id
                )
            )
        }
        return rounds
    }

    /// Рифмующийся «хвост» слова — последние 2 буквы (упрощённая фонетическая
    /// рифма для русских слов). Слова рифмуются, если совпадает хвост и при
    /// этом слова различаются.
    static func rhymeTail(of word: String) -> String {
        let lower = word.lowercased().trimmingCharacters(in: .whitespaces)
        let letters = lower.filter { $0.isLetter }
        guard letters.count >= 3 else { return "" }
        return String(letters.suffix(2))
    }
}
