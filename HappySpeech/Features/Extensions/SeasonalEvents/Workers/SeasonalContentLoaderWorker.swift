import Foundation
import OSLog

// MARK: - SeasonalContentLoaderWorker
//
// Загружает seasonal content pack из Bundle по packId.
// Паки расположены в Content/Seed/seasonal/<packId>.json.

struct SeasonalPackDTO: Decodable {
    let id: String
    let soundTarget: String
    let group: String
    let version: Int
    let description: String
    let season: String
    let activeMonths: [Int]

    enum CodingKeys: String, CodingKey {
        case id, soundTarget, group, version, description, season
        case activeMonths = "active_months"
    }
}

final class SeasonalContentLoaderWorker {

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SeasonalLoader")

    // MARK: - Public API

    /// Загружает pack для активного сезонного события.
    /// Возвращает nil если нет активного события или файл не найден.
    func loadActivePack() async -> SeasonalPackDTO? {
        guard let event = await SeasonalEventsManager.shared.activeEvent else {
            Self.logger.debug("No active seasonal event — skip pack load")
            return nil
        }
        return await loadPack(packId: event.packId)
    }

    /// Загружает pack по конкретному packId.
    func loadPack(packId: String) async -> SeasonalPackDTO? {
        guard let url = Bundle.main.url(forResource: packId, withExtension: "json",
                                        subdirectory: "Seed/seasonal") else {
            Self.logger.error("Seasonal pack not found in bundle: \(packId, privacy: .public)")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let pack = try decoder.decode(SeasonalPackDTO.self, from: data)
            Self.logger.info("Loaded seasonal pack: \(pack.id, privacy: .public), units described in stages")
            return pack
        } catch {
            Self.logger.error("Failed to decode seasonal pack \(packId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
