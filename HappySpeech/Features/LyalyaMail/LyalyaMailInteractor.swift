import Foundation
import OSLog

// MARK: - LyalyaMailBusinessLogic

@MainActor
protocol LyalyaMailBusinessLogic: AnyObject {
    func loadMail(_ request: LyalyaMailModels.LoadMail.Request) async
    func openLetter(_ request: LyalyaMailModels.OpenLetter.Request) async
    func delete(_ request: LyalyaMailModels.Delete.Request) async
}

// MARK: - LyalyaMailInteractor

/// VIP-Interactor для «Письма от Ляли».
///
/// Письма персистятся в Realm (`LyalyaLetterObject`) — «прочитано»/«удалено»
/// больше не теряются при перезапуске. Письма генерируются по РЕАЛЬНЫМ событиям
/// ребёнка (приветствие при старте, серия N дней, первый чистый звук), а не из
/// статичного фейк-seed. Генерация идемпотентна (стабильные id по триггеру).
@MainActor
final class LyalyaMailInteractor: LyalyaMailBusinessLogic {

    var presenter: (any LyalyaMailPresentationLogic)?

    private let childId: String
    private let realmActor: RealmActor?
    private let childRepository: (any ChildRepository)?
    private let sessionRepository: (any SessionRepository)?

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LyalyaMail.Interactor"
    )

    init(
        childId: String,
        realmActor: RealmActor? = nil,
        childRepository: (any ChildRepository)? = nil,
        sessionRepository: (any SessionRepository)? = nil
    ) {
        self.childId = childId
        self.realmActor = realmActor
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
    }

    // MARK: - Load

    func loadMail(_ request: LyalyaMailModels.LoadMail.Request) async {
        logger.info("loadMail childId=\(request.childId, privacy: .private)")

        // 1. По реальным событиям ребёнка генерируем и идемпотентно сохраняем
        //    новые письма (приветствие / серия / первый чистый звук).
        await generateEventLetters(childId: request.childId)

        // 2. Читаем письма из Realm. Если репозитория нет (preview) — пусто.
        let letters = await fetchLetters(childId: request.childId)
        await presenter?.presentLetters(
            response: .init(childId: request.childId, letters: letters)
        )
    }

    // MARK: - Open

    func openLetter(_ request: LyalyaMailModels.OpenLetter.Request) async {
        logger.info("openLetter id=\(request.letterId, privacy: .public)")
        guard let realmActor else { return }
        guard let updated = await realmActor.markLyalyaLetterRead(letterId: request.letterId.uuidString) else {
            return
        }
        await presenter?.presentOpenedLetter(response: .init(letter: updated.asDTO))
        // Перезагружаем список — счётчик непрочитанных обновится.
        await loadMail(.init(childId: childId))
    }

    // MARK: - Delete

    func delete(_ request: LyalyaMailModels.Delete.Request) async {
        logger.info("delete letter id=\(request.letterId, privacy: .public)")
        if let realmActor {
            _ = await realmActor.deleteLyalyaLetter(letterId: request.letterId.uuidString)
        }
        await presenter?.presentDeleted(response: .init(removedId: request.letterId))
        await loadMail(.init(childId: childId))
    }

    // MARK: - Private

    private func fetchLetters(childId: String) async -> [LyalyaLetterDTO] {
        guard let realmActor else { return [] }
        let data = await realmActor.fetchLyalyaLetters(childId: childId)
        return data.map { $0.asDTO }.sorted { $0.date > $1.date }
    }

    /// Генерирует письма по реальным событиям и идемпотентно сохраняет их.
    /// Каждое письмо имеет стабильный id (триггер + childId) — повторная
    /// генерация не плодит дубликаты и не сбрасывает «прочитано».
    private func generateEventLetters(childId: String) async {
        guard let realmActor else { return }

        // Приветственное письмо — всегда (первый вход в почту).
        await realmActor.insertLyalyaLetterIfAbsent(
            LyalyaMailLetters.welcome(childId: childId)
        )

        // Письма по реальным данным ребёнка.
        let profile = try? await childRepository?.fetch(id: childId)
        let sessions = (try? await sessionRepository?.fetchAll(childId: childId)) ?? []

        // Серия N дней подряд — письмо на достигнутых рубежах.
        let streak = profile?.currentStreak ?? 0
        for milestone in [3, 7, 14, 30] where streak >= milestone {
            await realmActor.insertLyalyaLetterIfAbsent(
                LyalyaMailLetters.streak(childId: childId, days: milestone)
            )
        }

        // Первый «чистый» звук — успешная сессия (successRate ≥ 0.85).
        if sessions.contains(where: { $0.totalAttempts > 0 && $0.successRate >= 0.85 }) {
            await realmActor.insertLyalyaLetterIfAbsent(
                LyalyaMailLetters.firstSound(childId: childId)
            )
        }
    }
}

// MARK: - LyalyaLetterData → DTO

private extension LyalyaLetterData {
    var asDTO: LyalyaLetterDTO {
        LyalyaLetterDTO(
            id: UUID(uuidString: id) ?? UUID(),
            childId: childId,
            kind: LetterKind(rawValue: kind) ?? .welcome,
            title: title,
            body: body,
            date: date,
            isRead: isRead,
            audioFileName: audioFileName
        )
    }
}

// MARK: - LyalyaMailLetters (event-driven content)

/// Фабрика писем по реальным событиям. Тёплый детский тон, без сложных оборотов.
/// id стабильны (детерминированы по триггеру + childId) — идемпотентность.
enum LyalyaMailLetters {

    static func welcome(childId: String) -> LyalyaLetterData {
        LyalyaLetterData(
            id: stableId("welcome", childId: childId),
            childId: childId,
            kind: LetterKind.welcome.rawValue,
            title: String(localized: "lyalyaMail.welcome.title"),
            body: String(localized: "lyalyaMail.welcome.body"),
            date: Date(),
            isRead: false,
            audioFileName: nil
        )
    }

    static func streak(childId: String, days: Int) -> LyalyaLetterData {
        LyalyaLetterData(
            id: stableId("streak\(days)", childId: childId),
            childId: childId,
            kind: LetterKind.streak.rawValue,
            title: String(format: String(localized: "lyalyaMail.streak.title %lld"), days),
            body: String(format: String(localized: "lyalyaMail.streak.body %lld"), days),
            date: Date(),
            isRead: false,
            audioFileName: nil
        )
    }

    static func firstSound(childId: String) -> LyalyaLetterData {
        LyalyaLetterData(
            id: stableId("firstSound", childId: childId),
            childId: childId,
            kind: LetterKind.firstSound.rawValue,
            title: String(localized: "lyalyaMail.firstSound.title"),
            body: String(localized: "lyalyaMail.firstSound.body"),
            date: Date(),
            isRead: false,
            audioFileName: nil
        )
    }

    /// Детерминированный строковый id (UUID-форма) по триггеру + childId.
    private static func stableId(_ tag: String, childId: String) -> String {
        let combined = "lyalya.letter.\(tag).\(childId)"
        var hasher = Hasher()
        hasher.combine(combined)
        let hash = UInt64(bitPattern: Int64(hasher.finalize()))
        let bytes: [UInt8] = (0..<16).map { i in
            UInt8((hash >> UInt64((i % 8) * 8)) & 0xFF)
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )).uuidString
    }
}
