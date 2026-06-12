import Foundation
import OSLog

// MARK: - CulturalContentPackLoader
//
// Разбирает бандл-ресурс `pack_cultural.json` один раз и отдаёт элементы
// `CulturalItem`. Этот пак — фольклор и чистоговорки от методиста-логопеда
// (потешки/прибаутки — public domain; чистоговорки и часть скороговорок —
// оригинальные тексты HappySpeech) для автоматизации/дифференциации звуков,
// речевого ритма и дыхания (gap #7).
//
// Контентные паки одноязычны (ru-primary), поэтому `titleKey` здесь хранит
// готовый русский заголовок: `String(localized:)` в презентере вернёт сам
// текст ключа, если его нет в String Catalog. Строки `lines` уже литеральные
// (как и в статическом `CulturalContentData`).
//
// Полностью offline / on-device. При отказе бандла возвращает пустой набор —
// статический каталог `CulturalContentData` остаётся рабочим.

struct CulturalContentPackLoader {

    static let shared = CulturalContentPackLoader()

    let items: [CulturalItem]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CulturalContent.PackLoader"
    )

    // MARK: - JSON DTOs

    private struct Pack: Decodable {
        let items: [ItemDTO]
    }

    private struct ItemDTO: Decodable {
        let id: String
        let category: String
        let titleKey: String
        let authorKey: String?
        let durationSeconds: Double
        let targetSounds: [String]
        let lines: [LineDTO]
        let symbolName: String
    }

    private struct LineDTO: Decodable {
        let id: Int
        let startSeconds: Double
        let endSeconds: Double
        let text: String
    }

    // MARK: - Init

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_cultural", withExtension: "json"
        ) else {
            Self.logger.error("pack_cultural.json not found in bundle — using empty set")
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            items = pack.items.compactMap { dto in
                guard let category = CulturalCategory(rawValue: dto.category) else {
                    Self.logger.error("Unknown cultural category: \(dto.category, privacy: .public)")
                    return nil
                }
                let lines = dto.lines.map {
                    CulturalLine(
                        id: $0.id,
                        startSeconds: $0.startSeconds,
                        endSeconds: $0.endSeconds,
                        text: $0.text
                    )
                }
                return CulturalItem(
                    id: dto.id,
                    category: category,
                    titleKey: dto.titleKey,
                    authorKey: dto.authorKey,
                    durationSeconds: dto.durationSeconds,
                    targetSounds: dto.targetSounds,
                    lines: lines,
                    symbolName: dto.symbolName
                )
            }
            let loadedCount = items.count
            Self.logger.info("CulturalContent pack loaded: \(loadedCount, privacy: .public) items")
        } catch {
            Self.logger.error(
                "pack_cultural.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            items = []
        }
    }
}
