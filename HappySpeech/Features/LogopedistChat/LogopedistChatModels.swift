import Foundation

// MARK: - LogopedistChatModels (Clean Swift: Models)
//
// Block R.2 v18 — LogopedistChat Screen.
//
// Сущности фичи:
//   • ChatMessage — одно сообщение в треде parent ↔ specialist
//   • MessageAttachment — приложенный аудио-файл (highlight сессии)
//   • MessageSender — parent | specialist (НЕ child — COPPA-safe)
//   • Request/Response/ViewModel — VIP контракты
//
// Persistence: Firestore-backed репозиторий за Worker-границей с offline-очередью.
// Real-time доставка — через `subscribe()` (см. LogopedistChatInteractor), который
// слушает поток обновлений треда и пере-`load`-ит ViewModel при каждом изменении.
//
// COPPA: ребёнок никогда не пишет и не читает chat. Чат строго parent →
// specialist. Доступ только из parent контура.

// MARK: - MessageSender

public enum MessageSender: String, Sendable, Equatable {
    case parent
    case specialist
}

// MARK: - MessageStatus

/// Статус доставки сообщения.
public enum MessageStatus: String, Sendable, Equatable {
    case sending     // сейчас отправляется
    case sent        // ушло на сервер
    case delivered   // доставлено получателю
    case read        // прочитано
    case failed      // ошибка отправки (offline)
}

// MARK: - MessageAttachment

/// Приложение к сообщению — пока только аудио (session highlight).
public struct MessageAttachment: Identifiable, Sendable, Hashable {
    public let id: String
    public let kind: Kind
    public let titleKey: String
    public let durationSeconds: Double?
    /// Удалённый URL аудио в Firebase Storage (download-URL). Получатель
    /// проигрывает именно его — НЕ локальный путь песочницы отправителя.
    /// `nil`, когда вложение ещё не выгружено или для нон-аудио видов.
    public let remoteURL: URL?

    public enum Kind: String, Sendable {
        case audioRecording
        case sessionHighlight
        case progressReport
    }

    public init(
        id: String,
        kind: Kind,
        titleKey: String,
        durationSeconds: Double?,
        remoteURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.titleKey = titleKey
        self.durationSeconds = durationSeconds
        self.remoteURL = remoteURL
    }

    public var symbolName: String {
        switch kind {
        case .audioRecording:    return "waveform"
        case .sessionHighlight:  return "play.rectangle.fill"
        case .progressReport:    return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - ChatMessage

public struct ChatMessage: Identifiable, Sendable, Equatable {

    public let id: String
    public let sender: MessageSender
    public let text: String
    public let createdAt: Date
    public let status: MessageStatus
    public let attachment: MessageAttachment?
    public let isOptional: Bool   // для seed/preview сообщений
    /// Локальный путь к m4a в песочнице отправителя. Заполнен только для
    /// исходящих аудио-сообщений и пока выгрузка в Storage идёт — позволяет
    /// проиграть запись локально, не дожидаясь download-URL. Для входящих
    /// сообщений и текста — `nil` (источник воспроизведения — `attachment.remoteURL`).
    public let localAudioPath: String?

    public init(
        id: String,
        sender: MessageSender,
        text: String,
        createdAt: Date,
        status: MessageStatus = .sent,
        attachment: MessageAttachment? = nil,
        isOptional: Bool = false,
        localAudioPath: String? = nil
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.attachment = attachment
        self.isOptional = isOptional
        self.localAudioPath = localAudioPath
    }
}

// MARK: - SpecialistInfo

/// Информация о подключённом специалисте.
public struct SpecialistInfo: Sendable, Equatable {
    public let displayName: String
    public let credentialsKey: String  // «Логопед-дефектолог», «Нейропсихолог»
    public let isOnline: Bool
    public let lastSeenAt: Date?

    public init(
        displayName: String,
        credentialsKey: String,
        isOnline: Bool,
        lastSeenAt: Date?
    ) {
        self.displayName = displayName
        self.credentialsKey = credentialsKey
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
    }
}

// MARK: - LogopedistChatModels namespace

enum LogopedistChatModels {

    // MARK: Load

    enum Load {

        struct Request: Sendable {
            let parentId: String
            let specialistId: String
        }

        struct Response: Sendable {
            let specialist: SpecialistInfo?
            let messages: [ChatMessage]
            let isConnected: Bool
            /// Кол-во непрочитанных входящих сообщений (для бейджа).
            let unreadCount: Int
            /// Кол-во сообщений, ожидающих отправки (offline-очередь).
            let pendingOutboxCount: Int
            /// Состояние связи с логопедом (форма кода / подключён / ошибка).
            let linkState: ChatLinkState

            init(
                specialist: SpecialistInfo?,
                messages: [ChatMessage],
                isConnected: Bool,
                unreadCount: Int = 0,
                pendingOutboxCount: Int = 0,
                linkState: ChatLinkState? = nil
            ) {
                self.specialist = specialist
                self.messages = messages
                self.isConnected = isConnected
                self.unreadCount = unreadCount
                self.pendingOutboxCount = pendingOutboxCount
                // Если linkState не передан — выводим из specialist/isConnected
                // (сохраняет совместимость с тестами, конструирующими Response
                // только через specialist/messages/isConnected).
                if let linkState {
                    self.linkState = linkState
                } else if let specialist {
                    self.linkState = .connected(specialist)
                } else {
                    self.linkState = .notConnected
                }
            }
        }

        struct ViewModel: Sendable {
            let specialistName: String
            let credentials: String
            /// Подпись о присутствии специалиста. `nil`, когда специалист
            /// не подключён — тогда presence-индикатор не показывается вовсе
            /// (никакой фейковой доступности).
            let onlineStatusLabel: String?
            let isOnline: Bool
            let isConnected: Bool
            let connectionHint: String?
            /// Текст честного пустого состояния, когда специалист не подключён.
            let emptyStateHint: String?
            /// Плоский список сообщений (совместимость + a11y rotor).
            let messages: [MessageRow]
            /// Сообщения, сгруппированные по дате (UI рисует date-разделители).
            let sections: [DaySection]
            let composerEnabled: Bool
            /// Показывать ли форму ввода кода логопеда (когда не подключён).
            let showConnectForm: Bool
            /// Подпись индикатора offline-очереди (`nil` — нечего показывать).
            let outboxLabel: String?
            /// Подпись непрочитанных (`nil` — нет непрочитанных).
            let unreadBadge: String?

            init(
                specialistName: String,
                credentials: String,
                onlineStatusLabel: String?,
                isOnline: Bool,
                isConnected: Bool,
                connectionHint: String?,
                emptyStateHint: String?,
                messages: [MessageRow],
                composerEnabled: Bool,
                sections: [DaySection] = [],
                showConnectForm: Bool = false,
                outboxLabel: String? = nil,
                unreadBadge: String? = nil
            ) {
                self.specialistName = specialistName
                self.credentials = credentials
                self.onlineStatusLabel = onlineStatusLabel
                self.isOnline = isOnline
                self.isConnected = isConnected
                self.connectionHint = connectionHint
                self.emptyStateHint = emptyStateHint
                self.messages = messages
                self.sections = sections
                self.composerEnabled = composerEnabled
                self.showConnectForm = showConnectForm
                self.outboxLabel = outboxLabel
                self.unreadBadge = unreadBadge
            }
        }

        /// Группа сообщений за один день с человекочитаемым заголовком
        /// («Сегодня», «Вчера», «25 апреля»).
        struct DaySection: Identifiable, Sendable {
            let id: String
            let dateLabel: String
            let messages: [MessageRow]
        }

        struct MessageRow: Identifiable, Sendable {
            let id: String
            let isFromParent: Bool
            let text: String
            let timeLabel: String
            let statusLabel: String
            let statusSymbol: String?
            let isRead: Bool
            let attachment: AttachmentRow?
            let accessibilityLabel: String
        }

        struct AttachmentRow: Identifiable, Sendable {
            let id: String
            let title: String
            let symbolName: String
            let durationLabel: String?
            /// Идентификатор сообщения-владельца вложения. Используется View, чтобы
            /// запросить воспроизведение у Interactor (`playAttachment(messageId:)`)
            /// и сопоставить активную проигрываемую дорожку.
            let messageId: String
            /// Можно ли вообще проиграть вложение (есть локальный файл или
            /// удалённый URL). Для `failed`-аудио без источника — `false`.
            let isPlayable: Bool
        }
    }

    // MARK: Playback (воспроизведение аудио-вложения)

    enum Playback {

        /// Состояние плеера, поднимаемое в View для подсветки активной дорожки
        /// и переключения иконки play↔stop.
        struct ViewModel: Sendable {
            /// Идентификатор сообщения, чьё аудио сейчас играет. `nil` — ничего
            /// не воспроизводится.
            let playingMessageId: String?
            /// Идёт ли подготовка (скачивание входящего аудио из Storage).
            let preparingMessageId: String?
            /// Сообщение об ошибке воспроизведения (`nil` — нет ошибки).
            let errorMessage: String?
        }
    }

    // MARK: Connect (подключение логопеда по коду)

    enum Connect {

        struct Request: Sendable {
            let familyId: String
            let code: String
        }

        struct Response: Sendable {
            let resultState: ChatLinkState
        }

        struct ViewModel: Sendable {
            let isConnected: Bool
            /// Сообщение об ошибке (`nil` — успех).
            let errorMessage: String?
            /// Сообщение об успехе (`nil` — ошибка).
            let successMessage: String?
        }
    }

    // MARK: Subscribe (real-time обновление треда)

    enum Subscribe {

        struct Response: Sendable {
            let messages: [ChatMessage]
            let unreadCount: Int
            let pendingOutboxCount: Int
        }
    }

    // MARK: Send

    enum Send {

        struct Request: Sendable {
            let parentId: String
            let specialistId: String
            let text: String
            let now: Date
        }

        struct Response: Sendable {
            let createdMessage: ChatMessage
            let appendedMessages: [ChatMessage]
        }

        struct ViewModel: Sendable {
            let confirmationMessage: String
            let success: Bool
        }
    }

    // MARK: AttachAudio

    enum AttachAudio {

        struct Request: Sendable {
            let parentId: String
            let specialistId: String
            let attachmentTitle: String
            /// Реальная длительность записанного m4a (секунды), измеренная при
            /// остановке записи. Больше не хардкод.
            let durationSeconds: Double
            /// Путь к локальному m4a в песочнице. Репозиторий выгрузит его в
            /// Storage и пришлёт download-URL. Пусто → честный `.failed`.
            let localAudioPath: String
            let now: Date
        }

        struct Response: Sendable {
            let createdMessage: ChatMessage
        }

        struct ViewModel: Sendable {
            let confirmationMessage: String
        }
    }

    // MARK: Recording (запись голосового сообщения)

    enum Recording {

        /// Состояние записи в composer'е (мигающий индикатор + таймер).
        struct ViewModel: Sendable {
            let isRecording: Bool
            /// Текущая длительность записи, отформатированная («0:07»).
            let durationLabel: String
            /// Сообщение об ошибке записи (`nil` — нет ошибки; например, отказ
            /// в доступе к микрофону).
            let errorMessage: String?
        }
    }

    // MARK: MarkAsRead

    enum MarkAsRead {

        struct Request: Sendable {
            let parentId: String
            let messageIds: [String]
        }

        struct Response: Sendable {
            let updatedIds: [String]
        }
    }
}
