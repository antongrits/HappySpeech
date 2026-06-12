import AVFoundation
import Foundation
import OSLog

// MARK: - LogopedistChatBusinessLogic

@MainActor
protocol LogopedistChatBusinessLogic: AnyObject {
    func load(request: LogopedistChatModels.Load.Request) async
    func connect(request: LogopedistChatModels.Connect.Request) async
    func send(request: LogopedistChatModels.Send.Request) async
    func attachAudio(request: LogopedistChatModels.AttachAudio.Request) async
    func markAsRead(request: LogopedistChatModels.MarkAsRead.Request) async
    /// Подписаться на real-time обновления треда. Цикл работает до отмены
    /// задачи (View отменяет при исчезновении). Каждое изменение → новый load.
    func subscribe() async

    // MARK: Audio recording (голосовое сообщение логопеду)

    /// Запрашивает доступ к микрофону, настраивает `AVAudioSession` и стартует
    /// запись m4a во временный файл. Презентует состояние записи в View.
    func startAudioRecording() async
    /// Останавливает запись, измеряет реальную длительность и отправляет аудио
    /// логопеду (выгрузка в Storage внутри репозитория). Пустую/слишком
    /// короткую запись отбрасывает без отправки.
    func finishAudioRecording() async
    /// Прерывает запись без отправки (удаляет временный файл).
    func cancelAudioRecording() async

    // MARK: Audio playback (воспроизведение вложения)

    /// Проигрывает аудио-вложение сообщения. Для входящих — скачивает удалённый
    /// файл из Storage; для исходящих — проигрывает локальный путь. Повторный
    /// вызов на играющей дорожке останавливает воспроизведение.
    func playAttachment(messageId: String) async
    /// Останавливает текущее воспроизведение.
    func stopAudioPlayback() async
}

// MARK: - LogopedistChatDataStore

@MainActor
protocol LogopedistChatDataStore: AnyObject {
    var parentId: String { get set }
    var specialistId: String { get set }
}

// MARK: - LogopedistChatInteractor (Clean Swift: Interactor)
//
// Block R.2 v32 — реальный чат «родитель ↔ логопед».
//
// Источник данных — `ChatRepository` (Services-протокол), который изолирует
// фичу от Firestore/Sync (project guide §2). Логика:
//
//   1. `load`     — состояние связи + история (offline-first) + unread/outbox
//   2. `connect`  — подключить логопеда по коду-инвайту, затем перезагрузить
//   3. `send`     — отправить текст (online → .sent, offline → очередь .sending)
//   4. `attachAudio` — сообщение с аудио-вложением (запись занятия)
//   5. `markAsRead`  — пометить входящие прочитанными
//   6. `subscribe`   — real-time: каждое изменение треда → пере-`load`
//
// COPPA / Kids Category: участники — только parent и specialist. Ребёнок не
// пишет и не читает. Вызывается строго из родительского контура.
//
// Этика (project guide §11): пока реальный логопед не подключён, экран честно
// показывает форму подключения, а не выдуманного собеседника. Никаких
// авто-ответов «специалиста» — входящие приходят только через реальный
// real-time поток репозитория.

@MainActor
final class LogopedistChatInteractor: LogopedistChatBusinessLogic, LogopedistChatDataStore {

    // MARK: - DataStore

    var parentId: String
    var specialistId: String

    // MARK: - VIP

    var presenter: (any LogopedistChatPresentationLogic)?

    // MARK: - Dependencies

    private let repository: any ChatRepository
    private let hapticService: any HapticService
    /// Запись голосового сообщения логопеду (m4a, 16 kHz mono). Сам `AVAudioSession`
    /// и разрешение микрофона настраиваются здесь, в Interactor (рекордер их не трогает).
    private let audioRecorder: any AudioFileRecording
    /// Воспроизведение аудио-вложений. `activatesPlaybackSession` переводит сессию
    /// в `.playback` перед стартом.
    private let audioPlayer: any AudioFilePlaying
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "LogopedistChat")

    // MARK: - State

    /// Текущая связь (обновляется в `load` / `connect`).
    private var linkState: ChatLinkState = .notConnected

    // MARK: - Audio state

    /// URL текущей/последней записи в песочнице (`nil`, когда запись не идёт).
    private var recordingURL: URL?
    /// Момент старта записи — для измерения реальной длительности.
    private var recordingStartedAt: Date?
    /// Тикающий таймер, обновляющий длительность записи в UI каждые 0.2 с.
    private var recordingTickTask: Task<Void, Never>?
    private var isRecordingAudio: Bool = false
    /// Минимальная длительность записи, чтобы её отправлять (короче — шум/случайный тап).
    private let minRecordingSeconds: TimeInterval = 0.7
    /// Максимальная длительность голосового сообщения (защита от «забытой» записи).
    private let maxRecordingSeconds: TimeInterval = 120

    /// Идентификатор сообщения, чьё аудио сейчас проигрывается (`nil` — тишина).
    private var playingMessageId: String?
    /// Сторож автоостановки: завершает проигрывание по окончании файла.
    private var playbackWatchTask: Task<Void, Never>?

    private var identity: ChatIdentity {
        ChatIdentity(familyId: parentId, specialistId: specialistId)
    }

    private var isConnected: Bool {
        if case .connected = linkState { return true }
        return false
    }

    private var connectedSpecialist: SpecialistInfo? {
        if case .connected(let specialist) = linkState { return specialist }
        return nil
    }

    // MARK: - Init

    /// Кэш последних загруженных сообщений — нужен для resolve'а аудио-источника
    /// по `messageId` при воспроизведении (без повторного обращения к репозиторию).
    private var cachedMessages: [ChatMessage] = []

    /// Designated init с инъекцией `ChatRepository`.
    init(
        parentId: String,
        specialistId: String,
        repository: any ChatRepository,
        hapticService: any HapticService,
        audioRecorder: any AudioFileRecording = LiveAudioFileRecorder(),
        audioPlayer: any AudioFilePlaying = LiveAudioFilePlayer(activatesPlaybackSession: true)
    ) {
        self.parentId = parentId
        self.specialistId = specialistId
        self.repository = repository
        self.hapticService = hapticService
        self.audioRecorder = audioRecorder
        self.audioPlayer = audioPlayer
    }

    /// Совместимый init без репозитория — для существующих тестов и кода,
    /// которые ещё не передают `ChatRepository`. По умолчанию используется
    /// «пустой» репозиторий без подключённого специалиста: экран честно
    /// показывает форму подключения, `send` игнорируется (нет адресата).
    /// `userDefaults` принимается для бинарной совместимости вызовов (no-op).
    convenience init(
        parentId: String,
        specialistId: String,
        hapticService: any HapticService,
        userDefaults: UserDefaults = .standard
    ) {
        _ = userDefaults
        self.init(
            parentId: parentId,
            specialistId: specialistId,
            repository: EmptyChatRepository(),
            hapticService: hapticService
        )
    }

    // MARK: - Load

    func load(request: LogopedistChatModels.Load.Request) async {
        linkState = await repository.linkState(identity: identity)

        let specialist = connectedSpecialist
        let messages = isConnected ? await repository.loadHistory(identity: identity) : []
        let unread = isConnected ? await repository.unreadCount(identity: identity) : 0
        let pending = isConnected ? await repository.pendingOutboxCount(identity: identity) : 0
        // Кэшируем тред для resolve'а аудио-источника при воспроизведении.
        cachedMessages = messages

        let response = LogopedistChatModels.Load.Response(
            specialist: specialist,
            messages: messages,
            isConnected: isConnected,
            unreadCount: unread,
            pendingOutboxCount: pending,
            linkState: linkState
        )
        await presenter?.presentLoad(response: response)
    }

    // MARK: - Connect

    func connect(request: LogopedistChatModels.Connect.Request) async {
        let trimmed = request.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await presenter?.presentConnect(response: .init(resultState: .failed(.invalidCode)))
            return
        }

        let result = await repository.connectSpecialist(familyId: request.familyId, code: trimmed)
        linkState = result

        switch result {
        case .connected:
            hapticService.notification(.success)
            Self.logger.info("Specialist connected via code")
        case .failed:
            hapticService.notification(.error)
        case .connecting, .notConnected:
            break
        }

        await presenter?.presentConnect(response: .init(resultState: result))
        // После успешного подключения сразу перезагружаем тред.
        if case .connected = result {
            await load(request: .init(parentId: parentId, specialistId: specialistId))
        }
    }

    // MARK: - Send

    func send(request: LogopedistChatModels.Send.Request) async {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        // Сообщение можно отправить только реально подключённому специалисту.
        guard isConnected else { return }

        let created = await repository.sendText(
            identity: identity,
            text: request.text,
            now: request.now
        )
        hapticService.selection()
        Self.logger.info("Parent message sent (status=\(created.status.rawValue))")

        let response = LogopedistChatModels.Send.Response(
            createdMessage: created,
            appendedMessages: [created]
        )
        await presenter?.presentSend(response: response)
        await load(request: .init(parentId: parentId, specialistId: specialistId))
    }

    // MARK: - AttachAudio

    func attachAudio(request: LogopedistChatModels.AttachAudio.Request) async {
        guard isConnected else { return }

        let created = await repository.sendAudio(
            identity: identity,
            localAudioPath: request.localAudioPath,
            durationSeconds: request.durationSeconds,
            titleKey: "chat.attachment.audio.title",
            now: request.now
        )
        // Длительность и путь не логируем как PII; статус — безопасный rawValue.
        Self.logger.info("Audio attachment sent (status=\(created.status.rawValue, privacy: .public))")

        let response = LogopedistChatModels.AttachAudio.Response(createdMessage: created)
        await presenter?.presentAttachAudio(response: response)
        await load(request: .init(parentId: parentId, specialistId: specialistId))
    }

    // MARK: - Audio recording

    func startAudioRecording() async {
        guard isConnected, !isRecordingAudio else { return }

        // 1. Разрешение микрофона (iOS 17+ API).
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            Self.logger.info("Mic permission denied for chat voice message")
            await presenter?.presentRecording(viewModel: .init(
                isRecording: false,
                durationLabel: "0:00",
                errorMessage: String(localized: "chat.audio.error.micDenied")
            ))
            return
        }

        // 2. Настраиваем AVAudioSession под запись (как в LiveAudioService).
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true, options: [])
        } catch {
            Self.logger.error("Chat recording session setup failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentRecording(viewModel: .init(
                isRecording: false,
                durationLabel: "0:00",
                errorMessage: String(localized: "chat.audio.error.recordFailed")
            ))
            return
        }

        // 3. Старт записи во временный m4a.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat_voice_\(UUID().uuidString).m4a")
        guard audioRecorder.startRecording(to: url) else {
            Self.logger.error("Chat AVAudioRecorder failed to start")
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            await presenter?.presentRecording(viewModel: .init(
                isRecording: false,
                durationLabel: "0:00",
                errorMessage: String(localized: "chat.audio.error.recordFailed")
            ))
            return
        }

        recordingURL = url
        recordingStartedAt = Date()
        isRecordingAudio = true
        hapticService.impact(.medium)
        await presentRecordingTick()
        startRecordingTimer()
    }

    func finishAudioRecording() async {
        guard isRecordingAudio else { return }
        stopRecordingTimer()
        audioRecorder.stopRecording()
        isRecordingAudio = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let url = recordingURL
        recordingURL = nil
        recordingStartedAt = nil

        // Сбрасываем индикатор записи в UI.
        await presenter?.presentRecording(viewModel: .init(
            isRecording: false, durationLabel: "0:00", errorMessage: nil
        ))

        // Слишком короткая запись — отбрасываем без отправки (защита от случайного тапа).
        guard let url, duration >= minRecordingSeconds,
              FileManager.default.fileExists(atPath: url.path) else {
            if let url { try? FileManager.default.removeItem(at: url) }
            Self.logger.info("Chat voice message discarded (too short)")
            return
        }

        await attachAudio(request: .init(
            parentId: parentId,
            specialistId: specialistId,
            attachmentTitle: String(localized: "chat.attachment.audio.title"),
            durationSeconds: min(duration, maxRecordingSeconds),
            localAudioPath: url.path,
            now: Date()
        ))
    }

    func cancelAudioRecording() async {
        guard isRecordingAudio else { return }
        stopRecordingTimer()
        audioRecorder.stopRecording()
        isRecordingAudio = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        recordingStartedAt = nil
        await presenter?.presentRecording(viewModel: .init(
            isRecording: false, durationLabel: "0:00", errorMessage: nil
        ))
    }

    private func startRecordingTimer() {
        recordingTickTask?.cancel()
        recordingTickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { break }
                guard let self else { break }
                await self.tickRecording()
            }
        }
    }

    private func tickRecording() async {
        guard isRecordingAudio, let start = recordingStartedAt else { return }
        let elapsed = Date().timeIntervalSince(start)
        // Авто-стоп по достижению лимита.
        if elapsed >= maxRecordingSeconds {
            await finishAudioRecording()
            return
        }
        await presentRecordingTick()
    }

    private func presentRecordingTick() async {
        let elapsed = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        await presenter?.presentRecording(viewModel: .init(
            isRecording: true,
            durationLabel: Self.durationLabel(elapsed),
            errorMessage: nil
        ))
    }

    private func stopRecordingTimer() {
        recordingTickTask?.cancel()
        recordingTickTask = nil
    }

    /// Форматирует длительность записи в «м:сс» для таймера composer'а.
    private static func durationLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Audio playback

    func playAttachment(messageId: String) async {
        // Повторный тап по играющей дорожке — стоп.
        if playingMessageId == messageId {
            await stopAudioPlayback()
            return
        }
        // Переключение на другую дорожку — сначала остановим текущую.
        if playingMessageId != nil {
            await stopAudioPlayback()
        }

        guard let message = cachedMessages.first(where: { $0.id == messageId }) else { return }

        // Источник: локальный путь (исходящее) приоритетнее; иначе — скачиваем
        // удалённый файл из Storage (входящее).
        var localURL: URL?
        if let path = message.localAudioPath, !path.isEmpty,
           FileManager.default.fileExists(atPath: path) {
            localURL = URL(fileURLWithPath: path)
        } else if let remoteURL = message.attachment?.remoteURL {
            // Показываем «подготовку» (скачивание) в UI.
            await presenter?.presentPlayback(viewModel: .init(
                playingMessageId: nil, preparingMessageId: messageId, errorMessage: nil
            ))
            localURL = await repository.downloadAudio(remoteURL: remoteURL)
        }

        guard let url = localURL else {
            await presenter?.presentPlayback(viewModel: .init(
                playingMessageId: nil,
                preparingMessageId: nil,
                errorMessage: String(localized: "chat.audio.error.playFailed")
            ))
            return
        }

        do {
            try audioPlayer.play(contentsOf: url)
            playingMessageId = messageId
            hapticService.selection()
            await presenter?.presentPlayback(viewModel: .init(
                playingMessageId: messageId, preparingMessageId: nil, errorMessage: nil
            ))
            startPlaybackWatch(messageId: messageId)
        } catch {
            Self.logger.error("Chat audio playback failed: \(error.localizedDescription, privacy: .public)")
            playingMessageId = nil
            await presenter?.presentPlayback(viewModel: .init(
                playingMessageId: nil,
                preparingMessageId: nil,
                errorMessage: String(localized: "chat.audio.error.playFailed")
            ))
        }
    }

    func stopAudioPlayback() async {
        playbackWatchTask?.cancel()
        playbackWatchTask = nil
        audioPlayer.stop()
        playingMessageId = nil
        await presenter?.presentPlayback(viewModel: .init(
            playingMessageId: nil, preparingMessageId: nil, errorMessage: nil
        ))
    }

    /// Следит за окончанием воспроизведения (плеер сам не уведомляет Interactor):
    /// как только `isPlaying` сбрасывается — снимаем подсветку дорожки.
    private func startPlaybackWatch(messageId: String) {
        playbackWatchTask?.cancel()
        playbackWatchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { break }
                guard let self else { break }
                let finished = self.isPlaybackFinished(for: messageId)
                if finished {
                    await self.handlePlaybackFinished(messageId: messageId)
                    break
                }
            }
        }
    }

    private func isPlaybackFinished(for messageId: String) -> Bool {
        playingMessageId == messageId && !audioPlayer.isPlaying
    }

    private func handlePlaybackFinished(messageId: String) async {
        guard playingMessageId == messageId else { return }
        audioPlayer.stop()
        playingMessageId = nil
        await presenter?.presentPlayback(viewModel: .init(
            playingMessageId: nil, preparingMessageId: nil, errorMessage: nil
        ))
    }

    // MARK: - MarkAsRead

    func markAsRead(request: LogopedistChatModels.MarkAsRead.Request) async {
        guard isConnected, !request.messageIds.isEmpty else { return }
        let updated = await repository.markAsRead(identity: identity, messageIds: request.messageIds)
        if !updated.isEmpty {
            Self.logger.debug("MarkAsRead: \(updated.count) messages")
            await load(request: .init(parentId: parentId, specialistId: specialistId))
        }
    }

    // MARK: - Subscribe (real-time)

    func subscribe() async {
        // Подписка имеет смысл только при подключённом специалисте.
        if !isConnected {
            linkState = await repository.linkState(identity: identity)
        }
        guard isConnected else { return }

        let stream = repository.messageStream(identity: identity)
        for await _ in stream {
            // Любое изменение треда → перезагрузка (пере-маппинг секций/unread).
            // Cancellation выходит из цикла естественно.
            if Task.isCancelled { break }
            await load(request: .init(parentId: parentId, specialistId: specialistId))
        }
    }
}

// MARK: - EmptyChatRepository

/// Репозиторий-заглушка: никакого подключённого логопеда, пустой тред.
/// Используется как дефолт для совместимого init без `ChatRepository`
/// (честное пустое состояние, project guide §11).
private struct EmptyChatRepository: ChatRepository {
    func linkState(identity: ChatIdentity) async -> ChatLinkState { .notConnected }
    func connectSpecialist(familyId: String, code: String) async -> ChatLinkState { .failed(.codeNotFound) }
    func loadHistory(identity: ChatIdentity) async -> [ChatMessage] { [] }
    func messageStream(identity: ChatIdentity) -> AsyncStream<[ChatMessage]> {
        AsyncStream { $0.finish() }
    }
    @discardableResult
    func sendText(identity: ChatIdentity, text: String, now: Date) async -> ChatMessage {
        ChatMessage(id: UUID().uuidString, sender: .parent, text: text, createdAt: now, status: .failed)
    }
    @discardableResult
    func sendAudio(
        identity: ChatIdentity,
        localAudioPath: String,
        durationSeconds: Double,
        titleKey: String,
        now: Date
    ) async -> ChatMessage {
        ChatMessage(id: UUID().uuidString, sender: .parent, text: "", createdAt: now, status: .failed)
    }
    @discardableResult
    func markAsRead(identity: ChatIdentity, messageIds: [String]) async -> [String] { [] }
    func unreadCount(identity: ChatIdentity) async -> Int { 0 }
    func pendingOutboxCount(identity: ChatIdentity) async -> Int { 0 }
}
