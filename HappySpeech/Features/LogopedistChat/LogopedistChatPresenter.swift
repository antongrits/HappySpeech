import Foundation
import OSLog

// MARK: - LogopedistChatPresentationLogic

@MainActor
protocol LogopedistChatPresentationLogic: AnyObject, Sendable {
    func presentLoad(response: LogopedistChatModels.Load.Response) async
    func presentSend(response: LogopedistChatModels.Send.Response) async
    func presentAttachAudio(response: LogopedistChatModels.AttachAudio.Response) async
    func presentConnect(response: LogopedistChatModels.Connect.Response) async
}

// Default no-op so existing presenter doubles (test spies) keep conforming.
extension LogopedistChatPresentationLogic {
    func presentConnect(response: LogopedistChatModels.Connect.Response) async {}
}

// MARK: - LogopedistChatPresenter (Clean Swift: Presenter)
//
// Block R.2 v18 — мапит Response → ViewModel.
//
// • Все строки через `String(localized:)` — ключи появятся в xcstrings
//   автоматически при сборке.
// • Время сообщений: «14:30», «вчера 10:15», «25 апр».
// • Status icons (для родительских sent-сообщений): waiting / checkmark.

@MainActor
final class LogopedistChatPresenter: LogopedistChatPresentationLogic {

    weak var displayLogic: (any LogopedistChatDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LogopedistChat.Presenter"
    )

    private let timeFormatter: DateFormatter
    private let dateFormatter: DateFormatter
    private let sectionFormatter: DateFormatter
    private let durationFormatter: DateComponentsFormatter
    private let calendar: Calendar

    init(displayLogic: (any LogopedistChatDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        timeFmt.locale = Locale(identifier: "ru_RU")
        self.timeFormatter = timeFmt

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "d MMM, HH:mm"
        dateFmt.locale = Locale(identifier: "ru_RU")
        self.dateFormatter = dateFmt

        let sectionFmt = DateFormatter()
        sectionFmt.dateFormat = "d MMMM yyyy"
        sectionFmt.locale = Locale(identifier: "ru_RU")
        self.sectionFormatter = sectionFmt

        let durFmt = DateComponentsFormatter()
        durFmt.unitsStyle = .abbreviated
        durFmt.allowedUnits = [.minute, .second]
        durFmt.zeroFormattingBehavior = .dropAll
        self.durationFormatter = durFmt

        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        self.calendar = cal
    }

    // MARK: - Load

    func presentLoad(response: LogopedistChatModels.Load.Response) async {
        let isConnected = response.specialist != nil

        let specialistName = response.specialist?.displayName
            ?? String(localized: "chat.specialist.notConnected")
        let credentialsKey = response.specialist?.credentialsKey ?? "chat.specialist.unknown.credentials"
        let credentials = String(localized: String.LocalizationValue(credentialsKey))

        // Presence-подпись показывается ТОЛЬКО для реально подключённого
        // специалиста. Если специалиста нет — никакого индикатора присутствия
        // (не имитируем доступность живого логопеда, project guide §11).
        let onlineLabel: String?
        if let specialist = response.specialist {
            if specialist.isOnline {
                onlineLabel = String(localized: "chat.specialist.online")
            } else if let lastSeen = specialist.lastSeenAt {
                onlineLabel = String(
                    format: String(localized: "chat.specialist.lastSeen"),
                    dateFormatter.string(from: lastSeen)
                )
            } else {
                onlineLabel = nil
            }
        } else {
            onlineLabel = nil
        }

        // Подсказка про офлайн-доставку имеет смысл только когда специалист
        // подключён, но связи сейчас нет.
        let connectionHint: String? = nil

        // Честное пустое состояние, когда специалист не подключён к семье.
        let emptyStateHint: String? = isConnected
            ? nil
            : String(localized: "chat.empty.notConnected.hint")

        let messageRows = response.messages.map { msg -> LogopedistChatModels.Load.MessageRow in
            mapMessage(msg)
        }
        let sections = groupByDay(response.messages)

        // Форму ввода кода показываем, только когда логопед реально не подключён.
        let showConnectForm: Bool
        switch response.linkState {
        case .connected:
            showConnectForm = false
        default:
            showConnectForm = !isConnected
        }

        let outboxLabel: String? = response.pendingOutboxCount > 0
            ? String(
                format: String(localized: "chat.outbox.pending"),
                response.pendingOutboxCount
            )
            : nil

        let unreadBadge: String? = response.unreadCount > 0
            ? "\(response.unreadCount)"
            : nil

        let viewModel = LogopedistChatModels.Load.ViewModel(
            specialistName: specialistName,
            credentials: credentials,
            onlineStatusLabel: onlineLabel,
            isOnline: response.specialist?.isOnline ?? false,
            isConnected: isConnected,
            connectionHint: connectionHint,
            emptyStateHint: emptyStateHint,
            messages: messageRows,
            composerEnabled: isConnected,
            sections: sections,
            showConnectForm: showConnectForm,
            outboxLabel: outboxLabel,
            unreadBadge: unreadBadge
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - Connect

    func presentConnect(response: LogopedistChatModels.Connect.Response) async {
        let viewModel: LogopedistChatModels.Connect.ViewModel
        switch response.resultState {
        case .connected:
            viewModel = LogopedistChatModels.Connect.ViewModel(
                isConnected: true,
                errorMessage: nil,
                successMessage: String(localized: "chat.connect.success")
            )
        case .failed(let error):
            viewModel = LogopedistChatModels.Connect.ViewModel(
                isConnected: false,
                errorMessage: error.errorDescription ?? String(localized: "chat.connect.error.generic"),
                successMessage: nil
            )
        case .connecting, .notConnected:
            viewModel = LogopedistChatModels.Connect.ViewModel(
                isConnected: false,
                errorMessage: nil,
                successMessage: nil
            )
        }
        await displayLogic?.displayConnect(viewModel: viewModel)
    }

    // MARK: - Date grouping

    /// Группирует сообщения по календарному дню. Заголовки: «Сегодня», «Вчера»,
    /// иначе — «25 апреля 2026». Сообщения предполагаются отсортированными по
    /// возрастанию `createdAt`; порядок секций сохраняется.
    private func groupByDay(_ messages: [ChatMessage]) -> [LogopedistChatModels.Load.DaySection] {
        guard !messages.isEmpty else { return [] }
        var sections: [LogopedistChatModels.Load.DaySection] = []
        var currentKey: Date?
        var bucket: [ChatMessage] = []

        func flush() {
            guard let key = currentKey, !bucket.isEmpty else { return }
            let rows = bucket.map { mapMessage($0) }
            sections.append(
                LogopedistChatModels.Load.DaySection(
                    id: ISO8601DateFormatter().string(from: key),
                    dateLabel: sectionLabel(for: key),
                    messages: rows
                )
            )
            bucket = []
        }

        for message in messages.sorted(by: { $0.createdAt < $1.createdAt }) {
            let dayStart = calendar.startOfDay(for: message.createdAt)
            if currentKey == nil { currentKey = dayStart }
            if dayStart != currentKey {
                flush()
                currentKey = dayStart
            }
            bucket.append(message)
        }
        flush()
        return sections
    }

    private func sectionLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "chat.section.today")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "chat.section.yesterday")
        }
        return sectionFormatter.string(from: date)
    }

    // MARK: - Send

    func presentSend(response: LogopedistChatModels.Send.Response) async {
        let viewModel = LogopedistChatModels.Send.ViewModel(
            confirmationMessage: String(localized: "chat.send.confirmation"),
            success: true
        )
        await displayLogic?.displaySend(viewModel: viewModel)
    }

    // MARK: - AttachAudio

    func presentAttachAudio(response: LogopedistChatModels.AttachAudio.Response) async {
        let viewModel = LogopedistChatModels.AttachAudio.ViewModel(
            confirmationMessage: String(localized: "chat.attach.confirmation")
        )
        await displayLogic?.displayAttachAudio(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func mapMessage(_ msg: ChatMessage) -> LogopedistChatModels.Load.MessageRow {
        let isFromParent = msg.sender == .parent
        let timeLabel = formatTime(msg.createdAt)
        let statusLabel = formatStatus(msg.status, isFromParent: isFromParent)
        let statusSymbol = symbolForStatus(msg.status, isFromParent: isFromParent)
        let isRead = msg.status == .read

        let attachment: LogopedistChatModels.Load.AttachmentRow?
        if let att = msg.attachment {
            let attTitle = String(localized: String.LocalizationValue(att.titleKey))
            let durationLabel = att.durationSeconds.flatMap {
                durationFormatter.string(from: $0)
            }
            attachment = LogopedistChatModels.Load.AttachmentRow(
                id: att.id,
                title: attTitle,
                symbolName: att.symbolName,
                durationLabel: durationLabel
            )
        } else {
            attachment = nil
        }

        let senderLabel = isFromParent
            ? String(localized: "chat.sender.parent")
            : String(localized: "chat.sender.specialist")

        let a11y: String
        if let att = attachment {
            a11y = String(
                format: String(localized: "chat.message.a11y.withAttachment"),
                senderLabel,
                msg.text,
                att.title,
                timeLabel
            )
        } else {
            a11y = String(
                format: String(localized: "chat.message.a11y"),
                senderLabel,
                msg.text,
                timeLabel
            )
        }

        return LogopedistChatModels.Load.MessageRow(
            id: msg.id,
            isFromParent: isFromParent,
            text: msg.text,
            timeLabel: timeLabel,
            statusLabel: statusLabel,
            statusSymbol: statusSymbol,
            isRead: isRead,
            attachment: attachment,
            accessibilityLabel: a11y
        )
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return timeFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return String(
                format: String(localized: "chat.time.yesterday"),
                timeFormatter.string(from: date)
            )
        }
        return dateFormatter.string(from: date)
    }

    private func formatStatus(_ status: MessageStatus, isFromParent: Bool) -> String {
        guard isFromParent else { return "" }
        switch status {
        case .sending:   return String(localized: "chat.status.sending")
        case .sent:      return String(localized: "chat.status.sent")
        case .delivered: return String(localized: "chat.status.delivered")
        case .read:      return String(localized: "chat.status.read")
        case .failed:    return String(localized: "chat.status.failed")
        }
    }

    private func symbolForStatus(_ status: MessageStatus, isFromParent: Bool) -> String? {
        guard isFromParent else { return nil }
        switch status {
        case .sending:   return "clock"
        case .sent:      return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read:      return "checkmark.circle.fill"
        case .failed:    return "exclamationmark.triangle.fill"
        }
    }
}
