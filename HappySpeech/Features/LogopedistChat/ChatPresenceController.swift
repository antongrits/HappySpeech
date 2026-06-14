import Foundation
import OSLog

// MARK: - ChatPresenceController
//
// Эфемерное присутствие собеседника в треде «родитель ↔ логопед».
//
// Источник — `RealtimeDatabaseServiceProtocol` (presence-канал в Firebase
// Realtime Database). Контроллер живёт ровно столько, сколько экран чата
// открыт у текущего участника:
//
//   • start()  — объявляет МОЁ присутствие (online) и подписывается на
//                присутствие СОБЕСЕДНИКА (online + «печатает…»);
//   • setTyping(_:) — обновляет мой typing-флаг с дебаунсом авто-сброса;
//   • stop()   — снимает моё присутствие (online=false) и отписывается.
//
// RTDB выбрана для presence сознательно: узлы эфемерны, авто-очищаются через
// onDisconnect (статус «онлайн» не залипает при крэше/потере сети) и не
// тарифицируются как Firestore-документы.
//
// COPPA / Kids Category: в presence-узлы пишутся ТОЛЬКО технические флаги
// (online/typing/lastActive). Никакого имени/PII ребёнка или родителя.
// Участники — строго auth-связанные parent и specialist одного треда.

@MainActor
@Observable
final class ChatPresenceController {

    // MARK: - Public observable state

    /// Присутствие собеседника (другой стороны треда). До первого снапшота — `.absent`.
    private(set) var otherPresence: ChatPresence = .absent

    // MARK: - Dependencies

    private let service: any RealtimeDatabaseServiceProtocol
    private let chatId: String
    /// Мой auth UID — я объявляю присутствие под этим ключом.
    private let myUid: String
    /// UID собеседника — за его присутствием наблюдаю.
    private let otherUid: String

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "ChatPresence")

    // MARK: - Internal state

    private var observation: SharePlayObservation?
    /// Текущий мой typing-флаг (чтобы не слать дубликаты в RTDB).
    private var isTyping = false
    /// Дебаунс авто-сброса «печатает…»: если за N секунд нет нового ввода —
    /// снимаем typing, чтобы у собеседника индикатор не висел вечно.
    private var typingResetTask: Task<Void, Never>?
    private let typingIdleTimeout: Duration = .seconds(3)
    private var isStarted = false

    // MARK: - Init

    /// - Parameters:
    ///   - service: presence-канал (Realtime Database).
    ///   - chatId: детерминированный идентификатор треда (`ChatIdentity.chatId`).
    ///   - myUid: мой auth UID.
    ///   - otherUid: UID собеседника, чьё присутствие наблюдаю.
    init(
        service: any RealtimeDatabaseServiceProtocol,
        chatId: String,
        myUid: String,
        otherUid: String
    ) {
        self.service = service
        self.chatId = chatId
        self.myUid = myUid
        self.otherUid = otherUid
    }

    // MARK: - Lifecycle

    /// Объявляет онлайн-присутствие и подписывается на собеседника.
    /// Безопасно вызывать повторно (идемпотентно).
    func start() async {
        guard !isStarted, !chatId.isEmpty, !myUid.isEmpty, !otherUid.isEmpty else { return }
        isStarted = true

        // 1. Подписка на присутствие собеседника. Замыкание прыгает на main actor,
        //    чтобы безопасно обновить @Observable-состояние.
        do {
            observation = try await service.observeChatPresence(
                chatId: chatId,
                otherUid: otherUid
            ) { [weak self] presence in
                Task { @MainActor in
                    self?.otherPresence = presence
                }
            }
        } catch {
            Self.logger.notice("observeChatPresence failed: \(error.localizedDescription, privacy: .public)")
        }

        // 2. Объявляем себя онлайн (typing=false). onDisconnect внутри сервиса
        //    сам сбросит статус при потере связи.
        do {
            try await service.setChatPresence(chatId: chatId, uid: myUid, isTyping: false)
        } catch {
            Self.logger.notice("setChatPresence(online) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Обновляет мой typing-флаг. Вызывается из composer'а при изменении текста.
    /// Пустой ввод немедленно снимает typing; непустой — выставляет и перезапускает
    /// idle-таймер авто-сброса.
    func setTyping(_ typing: Bool) {
        guard isStarted else { return }
        typingResetTask?.cancel()

        if typing {
            // Идёт ввод: выставляем typing (если ещё не) и заводим idle-сброс.
            if !isTyping {
                isTyping = true
                pushTyping(true)
            }
            typingResetTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.typingIdleTimeout)
                if Task.isCancelled { return }
                self.isTyping = false
                self.pushTyping(false)
            }
        } else if isTyping {
            isTyping = false
            pushTyping(false)
        }
    }

    /// Снимает моё присутствие и отписывается от собеседника.
    func stop() async {
        guard isStarted else { return }
        isStarted = false
        typingResetTask?.cancel()
        typingResetTask = nil
        observation?.cancel()
        observation = nil
        isTyping = false
        await service.clearChatPresence(chatId: chatId, uid: myUid)
    }

    // MARK: - Private

    private func pushTyping(_ typing: Bool) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.setChatPresence(
                    chatId: self.chatId,
                    uid: self.myUid,
                    isTyping: typing
                )
            } catch {
                Self.logger.debug("pushTyping failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
