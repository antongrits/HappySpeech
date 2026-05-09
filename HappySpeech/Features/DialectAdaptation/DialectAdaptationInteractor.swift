import Foundation
import OSLog

// MARK: - DialectAdaptationBusinessLogic

@MainActor
protocol DialectAdaptationBusinessLogic: AnyObject {
    func load(request: DialectAdaptationModels.Load.Request) async
    func select(request: DialectAdaptationModels.Select.Request) async
    func reset(request: DialectAdaptationModels.Reset.Request) async
}

// MARK: - DialectAdaptationDataStore

@MainActor
protocol DialectAdaptationDataStore: AnyObject {
    var childId: String { get set }
}

// MARK: - DialectAdaptationInteractor (Clean Swift: Interactor)
//
// Block R.1 v18 — выбор регионального диалекта для адаптации модели
// произношения. Per-region phonetic profile подаётся в PronunciationScorer
// через `DialectProfileStore` (UserDefaults singleton).
//
// Логика:
//   1. `load` — прочитать сохранённый dialectId, собрать список 5 вариантов
//   2. `select` — записать выбор + дату, послать haptic success
//   3. `reset` — вернуть default (central / литературная норма)
//
// Persistence: UserDefaults (proven pattern, без Realm миграций).
// Haptic: при `select` — `.notification(.success)`.
// COPPA: вся логика on-device, никаких сетевых запросов.

@MainActor
final class DialectAdaptationInteractor: DialectAdaptationBusinessLogic, DialectAdaptationDataStore {

    // MARK: - DataStore

    var childId: String

    // MARK: - VIP

    var presenter: (any DialectAdaptationPresentationLogic)?

    // MARK: - Dependencies

    private let userDefaults: UserDefaults
    private let hapticService: any HapticService
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "DialectAdaptation")

    // MARK: - UserDefaults keys (per-child)

    private enum Keys {
        static let prefix = "happyspeech.dialect."
        static func selectedId(_ childId: String) -> String { "\(prefix)\(childId).id" }
        static func appliedISO(_ childId: String) -> String { "\(prefix)\(childId).appliedAt" }
    }

    // MARK: - Init

    init(
        childId: String,
        hapticService: any HapticService,
        userDefaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.hapticService = hapticService
        self.userDefaults = userDefaults
    }

    // MARK: - Load

    func load(request: DialectAdaptationModels.Load.Request) async {
        let snapshot = readSnapshot(for: request.childId)

        let response = DialectAdaptationModels.Load.Response(
            currentDialect: snapshot.dialect,
            availableDialects: RegionalDialect.all,
            appliedAt: snapshot.appliedAt
        )

        await presenter?.presentLoad(response: response)
    }

    // MARK: - Select

    func select(request: DialectAdaptationModels.Select.Request) async {
        guard let dialect = RegionalDialect.find(id: request.dialectId) else {
            Self.logger.error("Unknown dialectId: \(request.dialectId, privacy: .public)")
            return
        }

        writeSnapshot(
            dialectId: dialect.id,
            appliedAt: request.now,
            for: request.childId
        )

        hapticService.notification(.success)
        Self.logger.info("Dialect applied: \(dialect.id, privacy: .public)")

        let response = DialectAdaptationModels.Select.Response(
            success: true,
            appliedDialect: dialect,
            appliedAt: request.now
        )

        await presenter?.presentSelect(response: response)
    }

    // MARK: - Reset

    func reset(request: DialectAdaptationModels.Reset.Request) async {
        let defaultDialect = RegionalDialect.default

        writeSnapshot(
            dialectId: defaultDialect.id,
            appliedAt: Date(),
            for: request.childId
        )

        Self.logger.info("Dialect reset to default")

        let response = DialectAdaptationModels.Reset.Response(
            restored: defaultDialect
        )

        await presenter?.presentReset(response: response)
    }

    // MARK: - Snapshot persistence

    private struct DialectSnapshot {
        let dialect: RegionalDialect
        let appliedAt: Date?
    }

    private func readSnapshot(for childId: String) -> DialectSnapshot {
        let storedId = userDefaults.string(forKey: Keys.selectedId(childId))
        let dialect = storedId.flatMap { RegionalDialect.find(id: $0) }
            ?? RegionalDialect.default

        let storedISO = userDefaults.string(forKey: Keys.appliedISO(childId))
        let isoFormatter = ISO8601DateFormatter()

        return DialectSnapshot(
            dialect: dialect,
            appliedAt: storedISO.flatMap { isoFormatter.date(from: $0) }
        )
    }

    private func writeSnapshot(
        dialectId: String,
        appliedAt: Date,
        for childId: String
    ) {
        let isoFormatter = ISO8601DateFormatter()
        userDefaults.set(dialectId, forKey: Keys.selectedId(childId))
        userDefaults.set(
            isoFormatter.string(from: appliedAt),
            forKey: Keys.appliedISO(childId)
        )
    }
}
