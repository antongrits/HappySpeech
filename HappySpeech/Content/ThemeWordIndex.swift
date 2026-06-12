import Foundation
import OSLog

// MARK: - ThemeWordIndex

/// Индекс лексических тем: `theme → набор слов темы` + матрица валидных
/// `sound × theme` ячеек (из `theme_sound_matrix.json`, §4.1 спеки генератора).
///
/// Используется ``ContentVariationGenerator`` для тематической окраски
/// позиционных этапов: пул слов пака пересекается со словами темы, и активность
/// генерируется только если ячейка `(звук, тема)` валидна (≥ порога) и пул
/// после пересечения достаточен.
///
/// Источники (bundled, read once):
/// - `pack_lexical_themes.json` — 20 тем, ~1695 слов (поле `themes[].words[].text`);
/// - `theme_sound_matrix.json`  — измеренные счётчики `cells[theme][sound]`.
///
/// Все аксессоры read-only поверх immutable `let`-хранилища — safe из любого актора.
public enum ThemeWordIndex {

    // MARK: - Public Types

    /// Одна лексическая тема с её словами (нормализованными к нижнему регистру).
    public struct Theme: Sendable {
        public let id: String
        public let title: String
        /// Слова темы в нижнем регистре, без дубликатов, в порядке файла.
        public let words: [String]
    }

    // MARK: - Decoding

    private struct ThemesEnvelope: Decodable {
        let themes: [RawTheme]
    }

    private struct RawTheme: Decodable {
        let id: String
        let title: String
        let words: [RawThemeWord]
    }

    private struct RawThemeWord: Decodable {
        let text: String
    }

    private struct MatrixEnvelope: Decodable {
        let validCellThreshold: Int
        let cells: [String: [String: Int]]
    }

    // MARK: - Storage

    /// Темы в детерминированном порядке файла.
    public static let themes: [Theme] = loadThemes()

    /// `theme.id → Theme` для быстрого доступа.
    private static let themeByID: [String: Theme] = Dictionary(
        themes.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// Матрица §4.1: `cells[theme][sound] = число слов темы с целевым звуком`.
    private static let matrix: MatrixEnvelope = loadMatrix()

    /// Порог валидной ячейки (по умолчанию 8, читается из ресурса).
    public static var validCellThreshold: Int { matrix.validCellThreshold }

    // MARK: - Public API

    /// Все идентификаторы тем в детерминированном порядке.
    public static var themeIDs: [String] { themes.map(\.id) }

    /// Тема по идентификатору.
    public static func theme(id: String) -> Theme? { themeByID[id] }

    /// Валидна ли тематическая ячейка `(звук, тема)` — измеренный счётчик слов
    /// темы с целевым звуком ≥ порога (§4.1). `sound` — кириллический звук
    /// («С», «Ш»…). Мягкие (Сь/Зь и пр.) сводятся к базовому звуку.
    public static func isValidCell(sound: String, themeID: String) -> Bool {
        cellCount(sound: sound, themeID: themeID) >= matrix.validCellThreshold
    }

    /// Измеренное число слов темы с целевым звуком (0, если ячейка опущена/мала).
    public static func cellCount(sound: String, themeID: String) -> Int {
        guard let row = matrix.cells[themeID] else { return 0 }
        return row[normalizedSound(sound)] ?? 0
    }

    /// Все валидные темы для звука, в детерминированном порядке файла тем.
    public static func validThemes(for sound: String) -> [String] {
        themeIDs.filter { isValidCell(sound: sound, themeID: $0) }
    }

    /// Слова темы, СОДЕРЖАЩИЕ целевой звук, как `ContentItem` (детерминированный
    /// порядок файла тем). Картинка резолвится через `word_manifest`
    /// (`LessonContentMap`); слова без картинки остаются с `imageAsset == nil`
    /// (image-backed шаблоны отфильтруют их в генераторе).
    ///
    /// Это источник тематического пула (§4.1/§5.2 спеки): матрица §4.1 считает
    /// именно слова темы с целевым звуком — здесь они материализуются.
    /// `stage` проставляется вызывающим контекстом; здесь — нейтральный `.wordInit`.
    public static func soundWords(theme themeID: String, sound: String) -> [ContentItem] {
        guard let theme = theme(id: themeID) else { return [] }
        let needle = soundNeedle(sound)
        var seen = Set<String>()
        var items: [ContentItem] = []
        for word in theme.words {
            guard word.contains(needle) else { continue }
            guard seen.insert(word).inserted else { continue }
            let asset = LessonContentMap.asset(for: word)
            items.append(
                ContentItem(
                    id: "theme-\(themeID)-\(items.count)",
                    word: word,
                    imageAsset: asset,
                    audioAsset: nil,
                    hint: nil,
                    stage: .wordInit,
                    difficulty: 1
                )
            )
        }
        return items
    }

    /// Базовая буква-«игла» для проверки наличия звука в слове («Рь»→«р»).
    private static func soundNeedle(_ sound: String) -> String {
        let base = sound.lowercased().replacingOccurrences(of: "ь", with: "")
        return String(base.prefix(1))
    }

    // MARK: - Loaders

    private static func loadThemes() -> [Theme] {
        guard let url = Bundle.main.url(forResource: "pack_lexical_themes", withExtension: "json") else {
            HSLogger.content.error("ThemeWordIndex: pack_lexical_themes.json not in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder().decode(ThemesEnvelope.self, from: data)
            return envelope.themes.map { raw in
                var seen = Set<String>()
                let words = raw.words.compactMap { word -> String? in
                    let key = word.text.lowercased()
                    guard !key.isEmpty, seen.insert(key).inserted else { return nil }
                    return key
                }
                return Theme(id: raw.id, title: raw.title, words: words)
            }
        } catch {
            HSLogger.content.error("ThemeWordIndex: themes decode failed — \(error.localizedDescription)")
            return []
        }
    }

    private static func loadMatrix() -> MatrixEnvelope {
        guard let url = Bundle.main.url(forResource: "theme_sound_matrix", withExtension: "json") else {
            HSLogger.content.error("ThemeWordIndex: theme_sound_matrix.json not in bundle")
            return MatrixEnvelope(validCellThreshold: 8, cells: [:])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(MatrixEnvelope.self, from: data)
        } catch {
            HSLogger.content.error("ThemeWordIndex: matrix decode failed — \(error.localizedDescription)")
            return MatrixEnvelope(validCellThreshold: 8, cells: [:])
        }
    }

    /// Сводит мягкий/вариативный звук к базовому ключу матрицы («Рь»→«Р», «Сь»→«С»).
    private static func normalizedSound(_ sound: String) -> String {
        sound.uppercased().replacingOccurrences(of: "Ь", with: "")
    }
}
