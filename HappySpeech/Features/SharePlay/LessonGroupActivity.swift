import Foundation
import GroupActivities
import OSLog

// MARK: - LessonGroupActivity
//
// GroupActivity тип для совместного логопедического урока через FaceTime.
// activityIdentifier уникален для HappySpeech: "com.happyspeech.lesson-shareplay".
//
// COPPA: metadata содержит только название звука — без PII ребёнка.
// Активируется ТОЛЬКО из родительского контура после BiometricGate.

struct LessonGroupActivity: GroupActivity {

    // MARK: - Required GroupActivity

    static let activityIdentifier = "com.happyspeech.lesson-shareplay"

    // MARK: - Properties

    /// ID урока (Realm UUID) — для загрузки контента на принимающей стороне.
    var lessonId: String

    /// Код звука (напр. "с", "ш", "р") — для subtitle и PronunciationScorer.
    var soundId: String

    /// Вид шаблона игры: "listenAndChoose", "repeatAfterModel" и т.д.
    var templateKind: String

    // MARK: - Metadata

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = String(localized: "shareplay.activity.title")
        // subtitle зависит от soundId
        meta.subtitle = subtitleForSound(soundId)
        meta.type = .generic
        return meta
    }

    // MARK: - Private

    private func subtitleForSound(_ sound: String) -> String {
        let key = "shareplay.activity.subtitle.\(sound)"
        let localized = String(localized: String.LocalizationValue(key))
        // Если перевода нет — генерим generic
        if localized == key {
            return String(
                format: String(localized: "shareplay.activity.subtitle.generic"),
                sound.uppercased()
            )
        }
        return localized
    }
}

// MARK: - Logger extension

private extension Logger {
    static let groupActivity = Logger(subsystem: "ru.happyspeech", category: "GroupActivity")
}
