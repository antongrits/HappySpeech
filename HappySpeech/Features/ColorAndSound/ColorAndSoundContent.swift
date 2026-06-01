import Foundation

// MARK: - ColorAndSoundContent

/// Генератор раундов игры «Цвет и звук» из реальных слов.
///
/// Для целевого звука берёт слова этого звука (`KidWordContentProvider`) и
/// «отвлекающие» слова других звуков, помечает принадлежность и присваивает
/// звуку устойчивый «цвет». Это фонематическая игра: ребёнок находит слова
/// «своего» звука среди других — тренировка звукового анализа.
enum ColorAndSoundContent {

    /// Один раунд: целевой звук, его цвет и карточки-слова.
    struct Round: Hashable {
        let sound: String
        let color: ColorAndSoundModels.SoundColor
        let cards: [ColorAndSoundModels.WordCard]
    }

    /// Цвет для группы звука (детерминированно).
    static func color(for sound: String) -> ColorAndSoundModels.SoundColor {
        let family = String(sound.prefix(1)).uppercased()
        switch family {
        case "С", "З", "Ц": return .sky
        case "Ш", "Ж", "Ч", "Щ": return .lilac
        case "Р": return .coral
        case "Л": return .mint
        case "К", "Г", "Х": return .butter
        default: return .rose
        }
    }

    /// Строит раунды под рабочие звуки ребёнка. Каждый раунд — один целевой
    /// звук, `matchPerRound` своих слов + `distractorsPerRound` чужих.
    static func rounds(
        forTargetSounds targets: [String],
        count: Int = 3,
        matchPerRound: Int = 3,
        distractorsPerRound: Int = 3
    ) -> [Round] {
        // Семейства для раундов: рабочие звуки ребёнка либо стартовая группа.
        let families = familiesForRounds(targets: targets, count: count)
        return families.map { family in
            let own = KidWordContentProvider.words(soundFamily: family)
                .shuffled()
                .prefix(matchPerRound)
                .map { card($0, belongs: true) }
            // Отвлекающие — из других семейств.
            let otherFamilies = KidWordContentProvider.allFamilies.filter { $0 != family }
            var distractorPool: [KidWordContentProvider.GameWord] = []
            for other in otherFamilies {
                distractorPool.append(contentsOf: KidWordContentProvider.words(soundFamily: other))
            }
            let distractors = distractorPool
                .shuffled()
                .prefix(distractorsPerRound)
                .map { card($0, belongs: false) }
            let combined = Array(own) + Array(distractors)
            let cards = combined.isEmpty ? fallbackCards(for: family) : combined
            return Round(sound: family, color: color(for: family), cards: cards)
        }
    }

    private static func card(
        _ word: KidWordContentProvider.GameWord,
        belongs: Bool
    ) -> ColorAndSoundModels.WordCard {
        ColorAndSoundModels.WordCard(
            id: "\(belongs ? "y" : "n")-\(word.id)",
            text: word.text,
            asset: word.asset,
            belongs: belongs,
            isSelected: false
        )
    }

    private static func familiesForRounds(targets: [String], count: Int) -> [String] {
        let mapped = targets
            .map { String($0.prefix(1)).uppercased() }
            .filter { KidWordContentProvider.allFamilies.contains($0) }
        var seen = Set<String>()
        let unique = mapped.filter { seen.insert($0).inserted }
        let base = unique.isEmpty ? ["С", "Ш", "Р"] : unique
        // Дополняем стартовыми семействами до нужного числа раундов.
        var result = base
        for family in KidWordContentProvider.allFamilies where result.count < count {
            if !result.contains(family) { result.append(family) }
        }
        return Array(result.prefix(max(1, count)))
    }

    /// Резервные карточки, если манифест недоступен (Preview/тесты).
    private static func fallbackCards(for family: String) -> [ColorAndSoundModels.WordCard] {
        [
            .init(id: "y-\(family)-1", text: "Слово", asset: nil, belongs: true, isSelected: false),
            .init(id: "y-\(family)-2", text: "Звук", asset: nil, belongs: true, isSelected: false),
            .init(id: "n-\(family)-1", text: "Кот", asset: "word_koshka", belongs: false, isSelected: false),
            .init(id: "n-\(family)-2", text: "Дом", asset: nil, belongs: false, isSelected: false)
        ]
    }
}
