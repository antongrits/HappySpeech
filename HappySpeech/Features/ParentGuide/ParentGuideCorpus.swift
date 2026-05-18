import Foundation

// MARK: - ParentGuideCorpus
//
// v29 Фаза 8, Функция 3 «Логопед для родителей».
//
// Статический корпус из 24 обучающих карточек-уроков, размеченных по
// тематике и (где применимо) по группам звуков. Содержание уроков —
// в Localizable.xcstrings; здесь — структура и метаданные.
//
// Методическая основа (см. [[speech-methodology]]): принцип «доступность
// родителю», ежедневная последовательная гимнастика (Фомичёва), щадящий
// речевой режим при заикании, важность похвалы за попытку.
//
// Полностью offline / on-device.

enum ParentGuideCorpus {

    /// Все уроки корпуса.
    static let lessons: [GuideLesson] = basics + articulation + sounds + phonemic + fluency + motivation

    // MARK: - Основы домашних занятий

    private static let basics: [GuideLesson] = [
        .init(id: "guide-basics-routine",
              topic: .basics,
              titleKey: "parentGuide.lesson.basics.routine.title",
              summaryKey: "parentGuide.lesson.basics.routine.summary",
              bodyKey: "parentGuide.lesson.basics.routine.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-basics-duration",
              topic: .basics,
              titleKey: "parentGuide.lesson.basics.duration.title",
              summaryKey: "parentGuide.lesson.basics.duration.summary",
              bodyKey: "parentGuide.lesson.basics.duration.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-basics-environment",
              topic: .basics,
              titleKey: "parentGuide.lesson.basics.environment.title",
              summaryKey: "parentGuide.lesson.basics.environment.summary",
              bodyKey: "parentGuide.lesson.basics.environment.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-basics-mistakes",
              topic: .basics,
              titleKey: "parentGuide.lesson.basics.mistakes.title",
              summaryKey: "parentGuide.lesson.basics.mistakes.summary",
              bodyKey: "parentGuide.lesson.basics.mistakes.body",
              relevantSoundGroups: [],
              readMinutes: 3)
    ]

    // MARK: - Артикуляционная гимнастика

    private static let articulation: [GuideLesson] = [
        .init(id: "guide-artic-mirror",
              topic: .articulation,
              titleKey: "parentGuide.lesson.artic.mirror.title",
              summaryKey: "parentGuide.lesson.artic.mirror.summary",
              bodyKey: "parentGuide.lesson.artic.mirror.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-artic-hold",
              topic: .articulation,
              titleKey: "parentGuide.lesson.artic.hold.title",
              summaryKey: "parentGuide.lesson.artic.hold.summary",
              bodyKey: "parentGuide.lesson.artic.hold.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-artic-sonants",
              topic: .articulation,
              titleKey: "parentGuide.lesson.artic.sonants.title",
              summaryKey: "parentGuide.lesson.artic.sonants.summary",
              bodyKey: "parentGuide.lesson.artic.sonants.body",
              relevantSoundGroups: ["sonants"],
              readMinutes: 3),
        .init(id: "guide-artic-whistling",
              topic: .articulation,
              titleKey: "parentGuide.lesson.artic.whistling.title",
              summaryKey: "parentGuide.lesson.artic.whistling.summary",
              bodyKey: "parentGuide.lesson.artic.whistling.body",
              relevantSoundGroups: ["whistling"],
              readMinutes: 3)
    ]

    // MARK: - Постановка и автоматизация звуков

    private static let sounds: [GuideLesson] = [
        .init(id: "guide-sounds-stages",
              topic: .sounds,
              titleKey: "parentGuide.lesson.sounds.stages.title",
              summaryKey: "parentGuide.lesson.sounds.stages.summary",
              bodyKey: "parentGuide.lesson.sounds.stages.body",
              relevantSoundGroups: [],
              readMinutes: 3),
        .init(id: "guide-sounds-automation",
              topic: .sounds,
              titleKey: "parentGuide.lesson.sounds.automation.title",
              summaryKey: "parentGuide.lesson.sounds.automation.summary",
              bodyKey: "parentGuide.lesson.sounds.automation.body",
              relevantSoundGroups: [],
              readMinutes: 3),
        .init(id: "guide-sounds-r",
              topic: .sounds,
              titleKey: "parentGuide.lesson.sounds.r.title",
              summaryKey: "parentGuide.lesson.sounds.r.summary",
              bodyKey: "parentGuide.lesson.sounds.r.body",
              relevantSoundGroups: ["sonants"],
              readMinutes: 3),
        .init(id: "guide-sounds-differentiation",
              topic: .sounds,
              titleKey: "parentGuide.lesson.sounds.differentiation.title",
              summaryKey: "parentGuide.lesson.sounds.differentiation.summary",
              bodyKey: "parentGuide.lesson.sounds.differentiation.body",
              relevantSoundGroups: ["whistling", "hissing"],
              readMinutes: 3)
    ]

    // MARK: - Фонематический слух

    private static let phonemic: [GuideLesson] = [
        .init(id: "guide-phon-why",
              topic: .phonemic,
              titleKey: "parentGuide.lesson.phon.why.title",
              summaryKey: "parentGuide.lesson.phon.why.summary",
              bodyKey: "parentGuide.lesson.phon.why.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-phon-games",
              topic: .phonemic,
              titleKey: "parentGuide.lesson.phon.games.title",
              summaryKey: "parentGuide.lesson.phon.games.summary",
              bodyKey: "parentGuide.lesson.phon.games.body",
              relevantSoundGroups: [],
              readMinutes: 3),
        .init(id: "guide-phon-school",
              topic: .phonemic,
              titleKey: "parentGuide.lesson.phon.school.title",
              summaryKey: "parentGuide.lesson.phon.school.summary",
              bodyKey: "parentGuide.lesson.phon.school.body",
              relevantSoundGroups: [],
              readMinutes: 2)
    ]

    // MARK: - Плавность речи / заикание

    private static let fluency: [GuideLesson] = [
        .init(id: "guide-fluency-dos",
              topic: .fluency,
              titleKey: "parentGuide.lesson.fluency.dos.title",
              summaryKey: "parentGuide.lesson.fluency.dos.summary",
              bodyKey: "parentGuide.lesson.fluency.dos.body",
              relevantSoundGroups: [],
              readMinutes: 3),
        .init(id: "guide-fluency-donts",
              topic: .fluency,
              titleKey: "parentGuide.lesson.fluency.donts.title",
              summaryKey: "parentGuide.lesson.fluency.donts.summary",
              bodyKey: "parentGuide.lesson.fluency.donts.body",
              relevantSoundGroups: [],
              readMinutes: 3),
        .init(id: "guide-fluency-tempo",
              topic: .fluency,
              titleKey: "parentGuide.lesson.fluency.tempo.title",
              summaryKey: "parentGuide.lesson.fluency.tempo.summary",
              bodyKey: "parentGuide.lesson.fluency.tempo.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-fluency-calm",
              topic: .fluency,
              titleKey: "parentGuide.lesson.fluency.calm.title",
              summaryKey: "parentGuide.lesson.fluency.calm.summary",
              bodyKey: "parentGuide.lesson.fluency.calm.body",
              relevantSoundGroups: [],
              readMinutes: 2)
    ]

    // MARK: - Мотивация и похвала

    private static let motivation: [GuideLesson] = [
        .init(id: "guide-motiv-praise",
              topic: .motivation,
              titleKey: "parentGuide.lesson.motiv.praise.title",
              summaryKey: "parentGuide.lesson.motiv.praise.summary",
              bodyKey: "parentGuide.lesson.motiv.praise.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-motiv-effort",
              topic: .motivation,
              titleKey: "parentGuide.lesson.motiv.effort.title",
              summaryKey: "parentGuide.lesson.motiv.effort.summary",
              bodyKey: "parentGuide.lesson.motiv.effort.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-motiv-play",
              topic: .motivation,
              titleKey: "parentGuide.lesson.motiv.play.title",
              summaryKey: "parentGuide.lesson.motiv.play.summary",
              bodyKey: "parentGuide.lesson.motiv.play.body",
              relevantSoundGroups: [],
              readMinutes: 2),
        .init(id: "guide-motiv-patience",
              topic: .motivation,
              titleKey: "parentGuide.lesson.motiv.patience.title",
              summaryKey: "parentGuide.lesson.motiv.patience.summary",
              bodyKey: "parentGuide.lesson.motiv.patience.body",
              relevantSoundGroups: [],
              readMinutes: 2)
    ]

    /// Возвращает урок по идентификатору.
    static func lesson(forId id: String) -> GuideLesson? {
        lessons.first { $0.id == id }
    }

    /// Маппинг звука (С, Ш, Р…) в группу.
    static func soundGroup(for sound: String) -> String? {
        let whistling: Set<String> = ["С", "Сь", "З", "Зь", "Ц"]
        let hissing: Set<String> = ["Ш", "Ж", "Ч", "Щ"]
        let sonants: Set<String> = ["Р", "Рь", "Л", "Ль"]
        let velar: Set<String> = ["К", "Г", "Х"]
        if whistling.contains(sound) { return "whistling" }
        if hissing.contains(sound) { return "hissing" }
        if sonants.contains(sound) { return "sonants" }
        if velar.contains(sound) { return "velar" }
        return nil
    }
}
