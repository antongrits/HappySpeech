import Foundation
import OSLog

// MARK: - LogopedistChatPresentationLogic

@MainActor
protocol LogopedistChatPresentationLogic: AnyObject, Sendable {
    func presentLoad(response: LogopedistChatModels.Load.Response) async
    func presentSend(response: LogopedistChatModels.Send.Response) async
    func presentAttachAudio(response: LogopedistChatModels.AttachAudio.Response) async
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
    private let durationFormatter: DateComponentsFormatter

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

        let durFmt = DateComponentsFormatter()
        durFmt.unitsStyle = .abbreviated
        durFmt.allowedUnits = [.minute, .second]
        durFmt.zeroFormattingBehavior = .dropAll
        self.durationFormatter = durFmt
    }

    // MARK: - Load

    func presentLoad(response: LogopedistChatModels.Load.Response) async {
        let specialistName = response.specialist?.displayName
            ?? String(localized: "chat.specialist.notConnected")
        let credentialsKey = response.specialist?.credentialsKey ?? "chat.specialist.unknown.credentials"
        let credentials = String(localized: String.LocalizationValue(credentialsKey))

        let onlineLabel: String
        if response.specialist?.isOnline == true {
            onlineLabel = String(localized: "chat.specialist.online")
        } else if let lastSeen = response.specialist?.lastSeenAt {
            onlineLabel = String(
                format: String(localized: "chat.specialist.lastSeen"),
                dateFormatter.string(from: lastSeen)
            )
        } else {
            onlineLabel = String(localized: "chat.specialist.offline")
        }

        let connectionHint: String? = response.isConnected
            ? nil
            : String(localized: "chat.connection.offline.hint")

        let messageRows = response.messages.map { msg -> LogopedistChatModels.Load.MessageRow in
            mapMessage(msg)
        }

        let viewModel = LogopedistChatModels.Load.ViewModel(
            specialistName: specialistName,
            credentials: credentials,
            onlineStatusLabel: onlineLabel,
            isOnline: response.specialist?.isOnline ?? false,
            isConnected: response.isConnected,
            connectionHint: connectionHint,
            messages: messageRows,
            composerEnabled: response.specialist != nil
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
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
