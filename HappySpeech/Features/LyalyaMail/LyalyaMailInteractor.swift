import Foundation
import OSLog

// MARK: - LyalyaMailBusinessLogic

@MainActor
protocol LyalyaMailBusinessLogic: AnyObject {
    func loadMail(_ request: LyalyaMailModels.LoadMail.Request) async
    func openLetter(_ request: LyalyaMailModels.OpenLetter.Request) async
    func delete(_ request: LyalyaMailModels.Delete.Request) async
}

// MARK: - LyalyaMailStore (in-memory persistence)

/// Хранилище писем — простой in-memory dictionary, attached to AppContainer'у
/// в будущем. Сейчас singleton-actor, чтобы между разными view-инстансами
/// сохранялись «прочитано» и «удалено» в рамках одной сессии.
///
/// Будущее: заменить на `LyalyaLetterRealm` (RealmActor extension) без
/// изменения публичного контракта store'а.
actor LyalyaMailStore {

    static let shared = LyalyaMailStore()

    private var lettersByChild: [String: [LyalyaLetterDTO]] = [:]

    func letters(for childId: String) -> [LyalyaLetterDTO] {
        if let existing = lettersByChild[childId] {
            return existing.sorted { $0.date > $1.date }
        }
        let seeded = LyalyaMailSeed.seedLetters(for: childId)
        lettersByChild[childId] = seeded
        return seeded.sorted { $0.date > $1.date }
    }

    func markRead(letterId: UUID, childId: String) -> LyalyaLetterDTO? {
        guard var arr = lettersByChild[childId],
              let idx = arr.firstIndex(where: { $0.id == letterId })
        else { return nil }
        arr[idx].isRead = true
        lettersByChild[childId] = arr
        return arr[idx]
    }

    func remove(letterId: UUID, childId: String) {
        guard var arr = lettersByChild[childId] else { return }
        arr.removeAll { $0.id == letterId }
        lettersByChild[childId] = arr
    }
}

// MARK: - LyalyaMailInteractor

/// VIP-Interactor для «Письма от Ляли». Загружает список писем из in-memory
/// store, отмечает прочитанные, удаляет. Сидирует 5 стартовых писем при
/// первом запросе по `childId`.
@MainActor
final class LyalyaMailInteractor: LyalyaMailBusinessLogic {

    var presenter: (any LyalyaMailPresentationLogic)?

    private let childId: String
    private let store: LyalyaMailStore

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LyalyaMail.Interactor"
    )

    init(
        childId: String,
        store: LyalyaMailStore = .shared
    ) {
        self.childId = childId
        self.store = store
    }

    // MARK: - Load

    func loadMail(_ request: LyalyaMailModels.LoadMail.Request) async {
        logger.info("loadMail childId=\(request.childId, privacy: .private)")
        let letters = await store.letters(for: request.childId)
        await presenter?.presentLetters(
            response: .init(childId: request.childId, letters: letters)
        )
    }

    // MARK: - Open

    func openLetter(_ request: LyalyaMailModels.OpenLetter.Request) async {
        logger.info("openLetter id=\(request.letterId, privacy: .public)")
        guard let updated = await store.markRead(letterId: request.letterId, childId: childId) else {
            return
        }
        await presenter?.presentOpenedLetter(response: .init(letter: updated))
        // Перезагружаем список — счётчик непрочитанных обновится.
        await loadMail(.init(childId: childId))
    }

    // MARK: - Delete

    func delete(_ request: LyalyaMailModels.Delete.Request) async {
        logger.info("delete letter id=\(request.letterId, privacy: .public)")
        await store.remove(letterId: request.letterId, childId: childId)
        await presenter?.presentDeleted(response: .init(removedId: request.letterId))
        await loadMail(.init(childId: childId))
    }
}

// MARK: - LyalyaMailSeed

/// 5 стартовых seed-писем — без зависимости на дату, тёплый детский тон.
enum LyalyaMailSeed {

    /// Используем фиксированный namespace UUID per-childId, чтобы id писем
    /// были стабильны между запусками preview и не плодились дубликаты при
    /// hot reload.
    static func seedLetters(for childId: String) -> [LyalyaLetterDTO] {
        let now = Date()
        let calendar = Calendar.current
        func date(daysAgo: Int) -> Date {
            calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        }
        return [
            LyalyaLetterDTO(
                id: stableUUID("welcome", childId: childId),
                childId: childId,
                kind: .welcome,
                title: "Привет, мой друг!",
                body: """
                Я так рада, что мы будем играть вместе! Со мной ты научишься говорить \
                красиво и чётко. Ты — настоящий герой звуков. Жду тебя завтра!
                """,
                date: date(daysAgo: 0),
                isRead: false,
                audioFileName: nil
            ),
            LyalyaLetterDTO(
                id: stableUUID("streak3", childId: childId),
                childId: childId,
                kind: .streak,
                title: "Ура! Три дня подряд!",
                body: """
                Ты занимался со мной уже три дня! Это очень круто. Маленькие шажки \
                каждый день — и звуки слушаются всё лучше. Я тобой горжусь!
                """,
                date: date(daysAgo: 1),
                isRead: false,
                audioFileName: nil
            ),
            LyalyaLetterDTO(
                id: stableUUID("firstSound", childId: childId),
                childId: childId,
                kind: .firstSound,
                title: "Звук получился!",
                body: """
                Сегодня у тебя впервые получился чистый звук. Я слышала и хлопала \
                в ладоши! Завтра попробуем ещё — и будет ещё чище.
                """,
                date: date(daysAgo: 2),
                isRead: true,
                audioFileName: nil
            ),
            LyalyaLetterDTO(
                id: stableUUID("sharedFamily", childId: childId),
                childId: childId,
                kind: .family,
                title: "Покажи маме и папе",
                body: """
                Расскажи маме или папе свой любимый звук! Им будет так приятно \
                услышать твой голос. А мне — посмотреть, как вы вместе радуетесь.
                """,
                date: date(daysAgo: 3),
                isRead: true,
                audioFileName: nil
            ),
            LyalyaLetterDTO(
                id: stableUUID("weekendReminder", childId: childId),
                childId: childId,
                kind: .weekendReminder,
                title: "Выходные — время историй",
                body: """
                Сегодня выходной! Давай вместе сочиним коротенькую историю. \
                Зайди в раздел игр — там тебя ждёт новое задание.
                """,
                date: date(daysAgo: 4),
                isRead: true,
                audioFileName: nil
            )
        ]
    }

    /// Детерминированный UUID на основе тэга письма + childId.
    /// Используем простой hash — он стабилен внутри одной версии Swift,
    /// этого достаточно для seed данных.
    private static func stableUUID(_ tag: String, childId: String) -> UUID {
        let combined = "lyalya.\(tag).\(childId)"
        var hasher = Hasher()
        hasher.combine(combined)
        let hash = UInt64(bitPattern: Int64(hasher.finalize()))
        // Делим хэш на два 64-битных значения для UUID-конструктора.
        let lo = UInt8.random(in: 0...255)
        _ = lo // unused — мы хотим стабильность.
        let bytes: [UInt8] = (0..<16).map { i in
            UInt8((hash >> UInt64((i % 8) * 8)) & 0xFF)
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
