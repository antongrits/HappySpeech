import Foundation
import OSLog

// MARK: - ParentGuideCorpus
//
// v29 Фаза 8, Функция 3 «Логопед для родителей».
//
// Корпус обучающих карточек-уроков для родителя как со-терапевта,
// размеченных по тематике и (где применимо) по группам звуков.
//
// Контент загружается из бандл-ресурса `pack_parent_guide.json` (~60 уроков).
// Методическая основа (см. [[speech-methodology]]): принцип «доступность
// родителю», ежедневная последовательная гимнастика (Фомичёва), щадящий
// речевой режим при заикании, важность похвалы за попытку.
//
// Полностью offline / on-device.

enum ParentGuideCorpus {

    /// Все уроки корпуса (из `pack_parent_guide.json`).
    static let lessons: [GuideLesson] = ParentGuidePackLoader.shared.lessons

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

// MARK: - ParentGuidePackLoader
//
// Разбирает `pack_parent_guide.json` один раз. При отказе бандла возвращает
// безопасный минимальный набор, чтобы модуль оставался рабочим.

struct ParentGuidePackLoader {

    static let shared = ParentGuidePackLoader()

    let lessons: [GuideLesson]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ParentGuide.PackLoader"
    )

    private struct Pack: Decodable {
        let lessons: [LessonDTO]
    }

    private struct LessonDTO: Decodable {
        let id: String
        let topic: String
        let title: String
        let summary: String
        let body: String
        let relevantSoundGroups: [String]
        let readMinutes: Int
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_parent_guide", withExtension: "json"
        ) else {
            Self.logger.error("pack_parent_guide.json not found in bundle — using fallback")
            lessons = ParentGuidePackLoader.fallbackLessons
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            lessons = pack.lessons.compactMap { dto in
                guard let topic = GuideTopic(rawValue: dto.topic) else {
                    Self.logger.error("Unknown topic: \(dto.topic, privacy: .public)")
                    return nil
                }
                return GuideLesson(
                    id: dto.id,
                    topic: topic,
                    title: dto.title,
                    summary: dto.summary,
                    body: dto.body,
                    relevantSoundGroups: dto.relevantSoundGroups,
                    readMinutes: dto.readMinutes
                )
            }
        } catch {
            Self.logger.error(
                "pack_parent_guide.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            lessons = ParentGuidePackLoader.fallbackLessons
        }
    }

    /// Минимальный безопасный набор на случай отказа бандла.
    private static let fallbackLessons: [GuideLesson] = [
        GuideLesson(
            id: "guide-basics-routine", topic: .basics,
            title: "Когда лучше заниматься",
            summary: "Регулярность важнее длительности.",
            body: """
            Лучше всего заниматься каждый день в одно и то же время — так занятие \
            становится привычкой. Короткое ежедневное занятие даёт больше, \
            чем долгое раз в неделю.
            """,
            relevantSoundGroups: [], readMinutes: 2
        ),
        GuideLesson(
            id: "guide-artic-mirror", topic: .articulation,
            title: "Гимнастика перед зеркалом",
            summary: "Зеркало помогает ребёнку контролировать движения.",
            body: """
            Артикуляционную гимнастику делайте перед зеркалом — ребёнок видит свой \
            язык и губы и сравнивает с образцом. Зрительный контроль ускоряет \
            освоение правильных укладов.
            """,
            relevantSoundGroups: [], readMinutes: 2
        ),
        GuideLesson(
            id: "guide-fluency-dos", topic: .fluency,
            title: "Как говорить с ребёнком, который заикается",
            summary: "Говорите спокойно, медленно, не торопите.",
            body: """
            Сами говорите неторопливо и спокойно — ребёнок подстраивается под ваш \
            темп. Не перебивайте, дайте договорить. Спокойная речь взрослого — \
            лучший образец плавности.
            """,
            relevantSoundGroups: [], readMinutes: 3
        ),
        GuideLesson(
            id: "guide-motiv-praise", topic: .motivation,
            title: "Как правильно хвалить",
            summary: "Хвалите конкретно и за дело.",
            body: """
            Вместо общего «молодец» скажите, что именно получилось: «Ты так чётко \
            сказал звук С!». Конкретная похвала показывает ребёнку, что ценится, \
            и он повторяет успех.
            """,
            relevantSoundGroups: [], readMinutes: 2
        ),
        GuideLesson(
            id: "guide-phon-why", topic: .phonemic,
            title: "Зачем нужен фонематический слух",
            summary: "Это умение различать звуки речи на слух.",
            body: """
            Фонематический слух — способность слышать и различать звуки родного \
            языка. Это основа правильного произношения и грамотного письма.
            """,
            relevantSoundGroups: [], readMinutes: 2
        ),
        GuideLesson(
            id: "guide-sounds-stages", topic: .sounds,
            title: "Этапы работы над звуком",
            summary: "Звук проходит путь от изолированного до речи.",
            body: """
            Работа над звуком идёт по ступеням: подготовка артикуляции, постановка, \
            автоматизация в слогах, словах, фразах и связной речи. Перескакивать \
            ступени нельзя.
            """,
            relevantSoundGroups: [], readMinutes: 3
        )
    ]
}
