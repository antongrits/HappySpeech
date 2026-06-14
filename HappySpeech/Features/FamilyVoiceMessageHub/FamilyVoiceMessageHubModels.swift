import Foundation

// MARK: - FamilyVoiceMessageHubModels

/// Модели хаба семейных голосовых сообщений (thin VIP: Interactor `@Observable` +
/// View). Запись и доставка сообщений живут в фиче «Голос семьи» (FamilyVoice);
/// хаб отображает входящие и помечает прочитанными.
enum FamilyVoiceMessageHubModels {

    enum SenderRole: String, Hashable {
        case mom
        case dad
        case kid
        case grandma
        /// Нейтральная роль для записей из «Голоса семьи»: их делает родитель,
        /// но конкретный член семьи в хранилище (`FamilyRecordingObject`) не
        /// фиксируется — поэтому не выдумываем пол/родство, показываем «Семья».
        case family

        var title: String {
            switch self {
            case .mom:     return String(localized: "familyVoiceHub.role.mom")
            case .dad:     return String(localized: "familyVoiceHub.role.dad")
            case .kid:     return String(localized: "familyVoiceHub.role.kid")
            case .grandma: return String(localized: "familyVoiceHub.role.grandma")
            case .family:  return String(localized: "familyVoiceHub.role.family", defaultValue: "Семья")
            }
        }

        var emoji: String {
            switch self {
            case .mom:     return "👩"
            case .dad:     return "👨"
            case .kid:     return "🧒"
            case .grandma: return "👵"
            case .family:  return "👪"
            }
        }
    }

    struct Message: Identifiable, Hashable {
        let id: String
        let sender: SenderRole
        let durationSeconds: Int
        let timeLabel: String
        let preview: String
        var isUnread: Bool
    }

    struct ViewState: Equatable {
        var messages: [Message]

        var unreadCount: Int {
            messages.filter(\.isUnread).count
        }

        var isEmpty: Bool { messages.isEmpty }

        /// Стартовое состояние — пустое: реальных голосовых сообщений семьи нет,
        /// пока они не записаны через основную фичу «Голос семьи». Никаких
        /// выдуманных сообщений. Запись/доставка сообщений — в FamilyVoice.
        static let initial = ViewState(messages: [])
    }

    // MARK: - Mapping (RecordingDTO → Message)

    /// Строит сообщения хаба из реальных записей «Голоса семьи».
    /// Сортировка — новые сверху. `isUnread` берётся из персистентного набора
    /// прочитанных id (UserDefaults), а не выдумывается.
    static func messages(
        from recordings: [RecordingDTO],
        readIds: Set<String>,
        calendar: Calendar = .current
    ) -> [Message] {
        recordings
            .sorted { $0.recordedAt > $1.recordedAt }
            .map { dto in
                Message(
                    id: dto.id,
                    sender: .family,
                    durationSeconds: max(0, Int(dto.durationSeconds.rounded())),
                    timeLabel: timeLabel(for: dto.recordedAt, calendar: calendar),
                    preview: dto.word,
                    isUnread: !readIds.contains(dto.id)
                )
            }
    }

    /// Человекочитаемая метка времени записи («Сегодня, 14:05», «Вчера», дата).
    private static func timeLabel(
        for date: Date,
        calendar: Calendar
    ) -> String {
        if calendar.isDateInToday(date) {
            let time = date.formatted(date: .omitted, time: .shortened)
            return String(
                format: String(localized: "familyVoiceHub.time.today", defaultValue: "Сегодня, %@"),
                time
            )
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "familyVoiceHub.time.yesterday", defaultValue: "Вчера")
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - FamilyVoiceMessageReadStore

/// Лёгкое персистентное хранилище id прочитанных голосовых сообщений семьи.
///
/// `FamilyRecordingObject` не хранит флаг «прочитано», а добавлять поле в Realm-
/// модель — это миграция схемы. Состояние прочтения второстепенно и локально для
/// устройства, поэтому храним его в `UserDefaults` (как `ActiveChildStore`),
/// не трогая слой данных. Ключ скоупится по `parentId`.
final class FamilyVoiceMessageReadStore: @unchecked Sendable {

    nonisolated(unsafe) private let defaults: UserDefaults
    private let parentId: String

    init(parentId: String, defaults: UserDefaults = .standard) {
        self.parentId = parentId
        self.defaults = defaults
    }

    private var key: String { "hs.familyVoiceHub.read.\(parentId)" }

    func readIds() -> Set<String> {
        let stored = defaults.stringArray(forKey: key) ?? []
        return Set(stored)
    }

    func markRead(_ id: String) {
        var ids = readIds()
        guard ids.insert(id).inserted else { return }
        defaults.set(Array(ids), forKey: key)
    }

    func markRead(_ ids: [String]) {
        var current = readIds()
        let before = current.count
        current.formUnion(ids)
        guard current.count != before else { return }
        defaults.set(Array(current), forKey: key)
    }
}
