import Foundation
import OSLog

// MARK: - SoundDetectiveCorpus
//
// F2-009 «Звуковой детектив» (Wave 2).
//
// Корпус слов-улик с позиционной разметкой целевого звука. Загружается из
// `pack_sound_detective.json` (своя схема, как `pack_phonemic_analysis.json`).
// Разметка `sounds` отражает звуковой, а не буквенный состав (оглушение
// согласных в конце, без мягкого знака как отдельного звука). Все
// `imageAsset` проверены по `word_manifest.json`. Полностью offline /
// on-device.

enum SoundDetectiveCorpus {

    /// Сколько раундов в одной сессии (9–12, антифатиговое правило).
    static var roundsPerSession: Int { SoundDetectivePackLoader.shared.roundsPerSession }

    /// Все слова-улики корпуса.
    static var allItems: [SoundDetectiveItem] { SoundDetectivePackLoader.shared.items }

    /// Слова, допустимые на данном уровне (minLevel ≤ level).
    /// Для уровня без `absent` элементы с position == .absent отбрасываются.
    static func items(for level: SoundDetectiveLevel) -> [SoundDetectiveItem] {
        let allowed = allowedMinLevels(upTo: level)
        let zones = Set(level.zones)
        return allItems.filter { item in
            allowed.contains(item.minLevel) && zones.contains(item.position)
        }
    }

    /// Уровни сложности, чьи слова можно показывать на `level` (свой + проще).
    private static func allowedMinLevels(upTo level: SoundDetectiveLevel) -> Set<SoundDetectiveLevel> {
        switch level {
        case .binary:     return [.binary]
        case .ternary:    return [.binary, .ternary]
        case .withAbsent: return [.binary, .ternary, .withAbsent]
        }
    }

    /// Слова на уровне, с приоритетом целевых звуков ребёнка.
    /// Если целевых слов мало — добивает остальными словами уровня.
    static func items(
        for level: SoundDetectiveLevel,
        targetSounds: [String]
    ) -> [SoundDetectiveItem] {
        let pool = items(for: level)
        guard !targetSounds.isEmpty else { return pool }
        let normalized = Set(targetSounds.map { $0.uppercased() })
        let preferred = pool.filter { normalized.contains($0.targetSound.uppercased()) }
        let rest = pool.filter { !normalized.contains($0.targetSound.uppercased()) }
        // Достаточно целевых для полной сессии? — отдаём их первыми.
        if preferred.count >= roundsPerSession {
            return preferred + rest
        }
        return preferred + rest
    }
}

// MARK: - SoundDetectivePackLoader
//
// Разбирает `pack_sound_detective.json` один раз. При отказе бандла
// возвращает безопасный минимальный набор, чтобы модуль оставался рабочим.

struct SoundDetectivePackLoader {

    static let shared = SoundDetectivePackLoader()

    let roundsPerSession: Int
    let items: [SoundDetectiveItem]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDetective.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let items: [ItemDTO]
    }

    private struct ItemDTO: Decodable {
        let id: String
        let word: String
        let imageAsset: String
        let targetSound: String
        let soundFamily: String
        let position: String
        let sounds: [String]
        let difficulty: Int
        let minLevel: String
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_sound_detective", withExtension: "json"
        ) else {
            Self.logger.error("pack_sound_detective.json not found in bundle — using fallback")
            roundsPerSession = 10
            items = SoundDetectivePackLoader.fallbackItems
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = max(6, pack.roundsPerSession)
            let decoded = pack.items.compactMap(Self.makeItem)
            items = decoded.isEmpty ? SoundDetectivePackLoader.fallbackItems : decoded
        } catch {
            Self.logger.error(
                "pack_sound_detective.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 10
            items = SoundDetectivePackLoader.fallbackItems
        }
    }

    private static func makeItem(_ dto: ItemDTO) -> SoundDetectiveItem? {
        guard let position = SoundZone(rawValue: dto.position) else {
            logger.error("Unknown position: \(dto.position, privacy: .public)")
            return nil
        }
        guard let minLevel = SoundDetectiveLevel(rawValue: dto.minLevel) else {
            logger.error("Unknown minLevel: \(dto.minLevel, privacy: .public)")
            return nil
        }
        return SoundDetectiveItem(
            id: dto.id,
            word: dto.word,
            imageAsset: dto.imageAsset,
            targetSound: dto.targetSound,
            soundFamily: dto.soundFamily,
            position: position,
            sounds: dto.sounds,
            difficulty: dto.difficulty,
            minLevel: minLevel
        )
    }

    // MARK: Fallback (минимальный рабочий набор)

    private static let fallbackItems: [SoundDetectiveItem] = [
        .init(id: "det-fb-sok", word: "сок", imageAsset: "word_sok",
              targetSound: "С", soundFamily: "свистящие", position: .start,
              sounds: ["с", "о", "к"], difficulty: 1, minLevel: .binary),
        .init(id: "det-fb-nos", word: "нос", imageAsset: "word_nos",
              targetSound: "С", soundFamily: "свистящие", position: .end,
              sounds: ["н", "о", "с"], difficulty: 1, minLevel: .binary),
        .init(id: "det-fb-kosa", word: "коса", imageAsset: "word_kosa",
              targetSound: "С", soundFamily: "свистящие", position: .middle,
              sounds: ["к", "о", "с", "а"], difficulty: 2, minLevel: .ternary),
        .init(id: "det-fb-shapka", word: "шапка", imageAsset: "word_hat",
              targetSound: "Ш", soundFamily: "шипящие", position: .start,
              sounds: ["ш", "а", "п", "к", "а"], difficulty: 1, minLevel: .binary),
        .init(id: "det-fb-mysh", word: "мышь", imageAsset: "word_mysh",
              targetSound: "Ш", soundFamily: "шипящие", position: .end,
              sounds: ["м", "ы", "ш"], difficulty: 1, minLevel: .binary),
        .init(id: "det-fb-mashina", word: "машина", imageAsset: "word_car",
              targetSound: "Ш", soundFamily: "шипящие", position: .middle,
              sounds: ["м", "а", "ш", "ы", "н", "а"], difficulty: 2, minLevel: .ternary),
        .init(id: "det-fb-rak", word: "рак", imageAsset: "word_rak",
              targetSound: "Р", soundFamily: "соноры", position: .start,
              sounds: ["р", "а", "к"], difficulty: 1, minLevel: .binary),
        .init(id: "det-fb-syr", word: "сыр", imageAsset: "word_syr",
              targetSound: "Р", soundFamily: "соноры", position: .end,
              sounds: ["с", "ы", "р"], difficulty: 1, minLevel: .binary),
        .init(id: "det-fb-luk", word: "лук", imageAsset: "word_onion",
              targetSound: "Л", soundFamily: "соноры", position: .start,
              sounds: ["л", "у", "к"], difficulty: 1, minLevel: .binary),
        .init(id: "det-fb-stol", word: "стол", imageAsset: "word_stol",
              targetSound: "Л", soundFamily: "соноры", position: .end,
              sounds: ["с", "т", "о", "л"], difficulty: 2, minLevel: .ternary),
        .init(id: "det-abs-fb-myach", word: "мяч", imageAsset: "word_ball",
              targetSound: "С", soundFamily: "свистящие", position: .absent,
              sounds: ["м", "а", "ч"], difficulty: 3, minLevel: .withAbsent)
    ]
}
