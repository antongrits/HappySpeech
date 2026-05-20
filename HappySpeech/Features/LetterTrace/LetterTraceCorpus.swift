import Foundation
import OSLog

// MARK: - LetterTraceCorpus
//
// v31 Волна C, Функция Ф.2 «Пиши пальчиком/пером».
//
// Загружает буквы и слоги из bundled JSON
// `Content/Seed/pack_letter_trace.json` (33 буквы + 10 проблемных слогов).
// Полностью offline / on-device.

public enum LetterTraceCorpus {

    public static var allItems: [TraceItem] { loadOnce() }

    public static func item(byId id: String) -> TraceItem? {
        allItems.first { $0.id == id }
    }

    // MARK: - Private

    private nonisolated(unsafe) static var cached: [TraceItem] = []
    private nonisolated(unsafe) static var didLoad = false
    private static let cacheLock = NSLock()

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LetterTrace.Corpus"
    )

    private static func loadOnce() -> [TraceItem] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if didLoad { return cached }
        didLoad = true
        cached = decodeBundledPack()
        logger.info("LetterTraceCorpus loaded: \(cached.count, privacy: .public) items")
        return cached
    }

    private static func decodeBundledPack() -> [TraceItem] {
        guard let url = Bundle.main.url(forResource: "pack_letter_trace", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            logger.warning("pack_letter_trace.json не найден — корпус пуст")
            return []
        }
        do {
            let pack = try JSONDecoder().decode(TracePackDTO.self, from: data)
            return pack.items.map { dto in
                TraceItem(
                    id: dto.id,
                    kind: TraceItemKind(rawValue: dto.kind) ?? .letter,
                    symbol: dto.symbol,
                    strokes: dto.strokes.map { stroke in
                        stroke.map { TracePoint(x: $0.x, y: $0.y) }
                    }
                )
            }
        } catch {
            logger.error("pack_letter_trace.json decode error: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

// MARK: - JSON DTO

private struct TracePackDTO: Decodable {
    let version: String
    let items: [TraceItemDTO]

    struct TraceItemDTO: Decodable {
        let id: String
        let kind: String
        let symbol: String
        let strokes: [[PointDTO]]
    }

    struct PointDTO: Decodable {
        let x: Double
        let y: Double
    }
}
