import Foundation
import OSLog

// MARK: - ChatRepository
//
// Block R.2 v32 — реальный чат «родитель ↔ логопед».
//
// Этот протокол изолирует фичу LogopedistChat от слоёв Data/Sync/Firestore
// (project guide §2: Features импортируют только Services-протоколы). Он отвечает
// за весь жизненный цикл общения семьи и подключённого специалиста:
//
//   • connect/link — родитель подключает логопеда по коду-инвайту;
//   • история сообщений (offline-first: локальный кэш всегда доступен);
//   • real-time обновления (Firestore snapshot listener в live-реализации);
//   • отправка текста и аудио-вложений с offline-очередью (повторная отправка
//     при восстановлении сети, переиспользует SyncService-паттерн);
//   • пометка прочитанным и подсчёт непрочитанных.
//
// COPPA / Kids Category: участники чата — ТОЛЬКО parent и specialist. Ребёнок
// никогда не пишет и не читает. Доступ к репозиторию — только из родительского
// контура (см. `LogopedistChatView.environment(\.circuitContext, .parent)`).
//
// Безопасность данных: chatId детерминированно выводится из (childId|familyId,
// specialistId) — это гарантирует, что обе стороны открывают один и тот же тред
// без выдачи PII ребёнка в открытом виде (см. `ChatIdentity.chatId`).

// MARK: - ChatLinkState

/// Состояние связи семьи с конкретным специалистом.
public enum ChatLinkState: Sendable, Equatable {
    /// Логопед ещё не подключён к семье — показываем форму ввода кода.
    case notConnected
    /// Идёт подключение (валидация кода / запись связи).
    case connecting
    /// Логопед подключён — чат активен.
    case connected(SpecialistInfo)
    /// Ошибка подключения (например, неверный код).
    case failed(ChatRepositoryError)
}

// MARK: - ChatRepositoryError

public enum ChatRepositoryError: LocalizedError, Sendable, Equatable {
    case invalidCode
    case codeNotFound
    case codeExpired
    case alreadyConnected
    case notAuthenticated
    case sendFailedOffline
    case backendUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return String(localized: "chat.connect.error.invalidCode")
        case .codeNotFound:
            return String(localized: "chat.connect.error.notFound")
        case .codeExpired:
            return String(localized: "chat.connect.error.expired")
        case .alreadyConnected:
            return String(localized: "chat.connect.error.alreadyConnected")
        case .notAuthenticated:
            return String(localized: "chat.connect.error.notAuthenticated")
        case .sendFailedOffline:
            return String(localized: "chat.send.error.offline")
        case .backendUnavailable(let detail):
            return String(
                format: String(localized: "chat.connect.error.backend"),
                detail
            )
        }
    }
}

// MARK: - ChatIdentity

/// Детерминированный идентификатор треда. Обе стороны (семья и логопед)
/// получают один и тот же `chatId` без передачи имени/PII ребёнка.
public struct ChatIdentity: Sendable, Equatable, Hashable {
    /// Идентификатор семьи (parent uid) — владелец данных ребёнка.
    public let familyId: String
    /// Идентификатор подключённого специалиста.
    public let specialistId: String

    public init(familyId: String, specialistId: String) {
        self.familyId = familyId
        self.specialistId = specialistId
    }

    /// Детерминированный `chatId` — лексикографически отсортированная пара,
    /// чтобы порядок аргументов не влиял на результат. Документ Firestore:
    /// `chats/{chatId}`; сообщения — `chats/{chatId}/messages/{messageId}`.
    public var chatId: String {
        let lo = min(familyId, specialistId)
        let hi = max(familyId, specialistId)
        return "\(lo)__\(hi)"
    }
}

// MARK: - ChatRepository protocol

public protocol ChatRepository: Sendable {

    /// Текущее состояние связи семьи с указанным специалистом.
    /// Live: чтение из Firestore `chat_links/{chatId}`; offline — из локального кэша.
    func linkState(identity: ChatIdentity) async -> ChatLinkState

    /// Подключает логопеда к семье по коду-инвайту (6 символов).
    ///
    /// Live: query `chat_links` по `shortCode`, валидация TTL/consumed, запись
    /// связи `chat_links/{chatId}` и `specialists/{sid}.linkedChildIds`.
    /// Возвращает обновлённое состояние (`.connected` или `.failed`).
    func connectSpecialist(
        familyId: String,
        code: String
    ) async -> ChatLinkState

    /// Возвращает закэшированную историю сообщений (offline-first).
    /// Live: сначала локальный кэш, затем серверная синхронизация.
    func loadHistory(identity: ChatIdentity) async -> [ChatMessage]

    /// Подписка на real-time обновления треда. Каждое изменение порождает
    /// полный снапшот сообщений (отсортированный по `createdAt`).
    ///
    /// Live: Firestore `addSnapshotListener`. Offline/Mock: единичный yield
    /// текущего кэша, поток остаётся открытым до отмены.
    func messageStream(identity: ChatIdentity) -> AsyncStream<[ChatMessage]>

    /// Отправляет текстовое сообщение в тред.
    ///
    /// - Parameter sender: автор сообщения (`.parent` по умолчанию — родительский
    ///   контур; специалист передаёт `.specialist`, отправляя сообщение родителю).
    ///
    /// Offline-first: сообщение сразу пишется в локальный кэш со статусом
    /// `.sending`; при наличии сети — выгружается в Firestore (`.sent`), иначе
    /// ставится в offline-очередь и доставляется при восстановлении связи.
    /// Возвращает созданное сообщение (с актуальным статусом).
    @discardableResult
    func sendText(
        identity: ChatIdentity,
        text: String,
        now: Date,
        sender: MessageSender
    ) async -> ChatMessage

    /// Отправляет сообщение с аудио-вложением (запись занятия).
    ///
    /// Локальный m4a выгружается в Firebase Storage (parental-gated путь), а в
    /// возвращённом сообщении сохраняется `localAudioPath` — отправитель может
    /// проиграть запись локально сразу, не дожидаясь download-URL.
    @discardableResult
    func sendAudio(
        identity: ChatIdentity,
        localAudioPath: String,
        durationSeconds: Double,
        titleKey: String,
        now: Date
    ) async -> ChatMessage

    /// Скачивает удалённое аудио-вложение (Firebase Storage download-URL) в
    /// локальный кэш-файл для воспроизведения. `AVAudioPlayer` не умеет
    /// стримить HTTP напрямую, поэтому входящее аудио сначала материализуется
    /// на диск. Возвращает локальный URL готового файла или `nil` при сбое.
    ///
    /// Реализация кэширует по имени файла: повторное воспроизведение того же
    /// вложения не качает его заново.
    func downloadAudio(remoteURL: URL) async -> URL?

    /// Помечает входящие (от специалиста) сообщения прочитанными.
    /// Возвращает идентификаторы реально обновлённых сообщений.
    @discardableResult
    func markAsRead(identity: ChatIdentity, messageIds: [String]) async -> [String]

    /// Кол-во непрочитанных входящих сообщений в треде (для бейджа в ParentHome).
    func unreadCount(identity: ChatIdentity) async -> Int

    /// Кол-во сообщений, ожидающих отправки в offline-очереди (для индикатора).
    func pendingOutboxCount(identity: ChatIdentity) async -> Int
}

// MARK: - ChatRepository defaults

public extension ChatRepository {

    /// Совместимость с родительским контуром: отправка от имени `.parent`
    /// (исторический вызов `sendText(identity:text:now:)`).
    @discardableResult
    func sendText(
        identity: ChatIdentity,
        text: String,
        now: Date
    ) async -> ChatMessage {
        await sendText(identity: identity, text: text, now: now, sender: .parent)
    }

    /// Дефолт: воспроизведение по file:// (исходящее, проигрывается локально)
    /// без обращения к сети. Удалённые HTTP-URL должны переопределяться в
    /// продакшн-реализации (`FirestoreChatRepository`). Сохраняет совместимость
    /// тестовых дублей, не реализующих скачивание.
    func downloadAudio(remoteURL: URL) async -> URL? {
        guard remoteURL.isFileURL else { return nil }
        return FileManager.default.fileExists(atPath: remoteURL.path) ? remoteURL : nil
    }
}
