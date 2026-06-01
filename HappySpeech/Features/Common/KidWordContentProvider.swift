import Foundation

// MARK: - KidWordContentProvider

/// Общий поставщик слов для детских word-игр.
///
/// Извлекает реальные слова из bundled-манифеста (`LessonContentMap`,
/// 1351 слово с привязкой к группе звуков и имейджсету) и приводит их к
/// удобному для игр виду. Заменяет статические seed-списки во множестве
/// мелких игровых фич: контент берётся из единого источника правды,
/// фильтруется по группе звуков ребёнка и стадии коррекции.
///
/// Все методы — чистые (без I/O, без актора): манифест уже закэширован в
/// `LessonContentMap`. Безопасно вызывать из любого Worker/Interactor.
enum KidWordContentProvider {

    // MARK: - Word

    /// Одно игровое слово с разрешённым ассетом-иллюстрацией.
    struct GameWord: Sendable, Identifiable, Hashable {
        let id: String
        let text: String
        /// Имя имейджсета (`word_*`) для `HSContentSymbol`, либо nil.
        let asset: String?
        /// Группа звуков, к которой относится слово («С», «Ш», «Р» …).
        let soundFamily: String?
    }

    // MARK: - Sound families

    /// Канонические группы звуков русской логопедии.
    static let whistling = ["С", "Сь", "З", "Зь", "Ц"]
    static let hissing   = ["Ш", "Ж", "Ч", "Щ"]
    static let sonorant  = ["Р", "Рь", "Л", "Ль"]
    static let velar     = ["К", "Г", "Х"]

    /// Все канонические группы звуков в порядке прохождения программы.
    static let allFamilies: [String] = whistling + hissing + sonorant + velar

    // MARK: - Lookup

    /// Слова по конкретной группе звуков (одна буква манифеста, например «С»).
    /// Отсортированы детерминированно (по слову), затем при необходимости
    /// перемешиваются вызывающей стороной с собственным генератором.
    static func words(soundFamily: String, limit: Int = .max) -> [GameWord] {
        let entries = LessonContentMap.words(soundFamily: soundFamily)
        return entries
            .sorted { $0.word < $1.word }
            .prefix(limit)
            .map {
                GameWord(
                    id: "\(soundFamily)-\($0.word)",
                    text: $0.word.capitalizedFirst,
                    asset: $0.asset,
                    soundFamily: $0.soundFamily
                )
            }
    }

    /// Слова по широкой группе (свистящие / шипящие / соноры / заднеязычные).
    static func words(in group: SoundGroup, limit: Int = .max) -> [GameWord] {
        let families: [String]
        switch group {
        case .whistling: families = whistling
        case .hissing:   families = hissing
        case .sonorant:  families = sonorant
        case .velar:     families = velar
        }
        var result: [GameWord] = []
        for family in families {
            result.append(contentsOf: words(soundFamily: family))
        }
        // Уникализируем по тексту, сохраняя порядок.
        var seen = Set<String>()
        let unique = result.filter { seen.insert($0.text.lowercased()).inserted }
        return Array(unique.prefix(limit))
    }

    /// Группа, к которой относится буква-семейство.
    static func group(for soundFamily: String) -> SoundGroup? {
        if whistling.contains(soundFamily) { return .whistling }
        if hissing.contains(soundFamily) { return .hissing }
        if sonorant.contains(soundFamily) { return .sonorant }
        if velar.contains(soundFamily) { return .velar }
        return nil
    }

    /// Группы звуков, актуальные для ребёнка по его `targetSounds`.
    /// Если у ребёнка нет целевых звуков — берём свистящие (стартовая группа
    /// программы).
    static func groups(forTargetSounds targets: [String]) -> [SoundGroup] {
        let mapped = targets.compactMap { group(for: $0) }
        if mapped.isEmpty { return [.whistling] }
        // Уникализируем, сохраняя порядок.
        var seen = Set<SoundGroup>()
        return mapped.filter { seen.insert($0).inserted }
    }

    // MARK: - SoundGroup

    enum SoundGroup: String, Sendable, CaseIterable, Hashable {
        case whistling
        case hissing
        case sonorant
        case velar

        var title: String {
            switch self {
            case .whistling: return String(localized: "soundGroup.whistling")
            case .hissing:   return String(localized: "soundGroup.hissing")
            case .sonorant:  return String(localized: "soundGroup.sonorant")
            case .velar:     return String(localized: "soundGroup.velar")
            }
        }
    }
}

// MARK: - String helper

private extension String {
    /// Возвращает строку с заглавной первой буквой (без изменения остального),
    /// корректно для кириллицы.
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
