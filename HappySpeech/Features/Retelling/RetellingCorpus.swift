import Foundation

// MARK: - RetellingCorpus
//
// v29 Фаза 8, Функция 2 «Расскажи по-настоящему».
//
// Стартовый корпус коротких историй с серией кадров-предложений и
// разметкой смысловых звеньев (герой / место / проблема / решение).
// Тексты возрастные (6–8 лет), частотная лексика, простой синтаксис
// (Ткаченко, Нищева). Представительный набор — может быть расширен
// командой speech-content-curator. Полностью offline / on-device.

enum RetellingCorpus {

    /// Полный корпус историй.
    static let stories: [RetellingStory] = [
        catAndBird, lostMitten, helpfulRain, snowmanFriend,
        braveHedgehog, gardenHarvest
    ]

    // MARK: - История: Кот и птичка

    static let catAndBird = RetellingStory(
        id: "cat-and-bird", title: "Кот и птичка",
        frames: [
            .init(id: "cb-1", sentence: "Жил во дворе пушистый кот Мурзик.",
                  link: .hero, symbolName: "cat.fill"),
            .init(id: "cb-2", sentence: "Он гулял по зелёному саду.",
                  link: .place, symbolName: "tree.fill"),
            .init(id: "cb-3", sentence: "Вдруг кот увидел птенчика, который выпал из гнезда.",
                  link: .problem, symbolName: "exclamationmark.bubble.fill"),
            .init(id: "cb-4", sentence: "Мурзик осторожно отнёс птенчика обратно в гнездо.",
                  link: .solution, symbolName: "checkmark.seal.fill")
        ]
    )

    // MARK: - История: Потерянная варежка

    static let lostMitten = RetellingStory(
        id: "lost-mitten", title: "Потерянная варежка",
        frames: [
            .init(id: "lm-1", sentence: "Маленькая девочка Катя пошла гулять зимой.",
                  link: .hero, symbolName: "person.fill"),
            .init(id: "lm-2", sentence: "Она каталась с горки в снежном парке.",
                  link: .place, symbolName: "snowflake"),
            .init(id: "lm-3", sentence: "Дома Катя заметила, что потеряла одну варежку.",
                  link: .problem, symbolName: "exclamationmark.bubble.fill"),
            .init(id: "lm-4", sentence: "Мама помогла связать новую тёплую варежку.",
                  link: .solution, symbolName: "checkmark.seal.fill")
        ]
    )

    // MARK: - История: Добрый дождик

    static let helpfulRain = RetellingStory(
        id: "helpful-rain", title: "Добрый дождик",
        frames: [
            .init(id: "hr-1", sentence: "На грядке рос маленький подсолнух.",
                  link: .hero, symbolName: "sun.max.fill"),
            .init(id: "hr-2", sentence: "Он жил в саду у бабушки.",
                  link: .place, symbolName: "house.fill"),
            .init(id: "hr-3", sentence: "Стояла жара, и подсолнух очень хотел пить.",
                  link: .problem, symbolName: "exclamationmark.bubble.fill"),
            .init(id: "hr-4", sentence: "Пришла туча, и тёплый дождик напоил подсолнух.",
                  link: .solution, symbolName: "cloud.rain.fill")
        ]
    )

    // MARK: - История: Снеговик-друг

    static let snowmanFriend = RetellingStory(
        id: "snowman-friend", title: "Снеговик-друг",
        frames: [
            .init(id: "sf-1", sentence: "Брат и сестра слепили во дворе снеговика.",
                  link: .hero, symbolName: "person.2.fill"),
            .init(id: "sf-2", sentence: "Снеговик стоял возле большого дома.",
                  link: .place, symbolName: "house.fill"),
            .init(id: "sf-3", sentence: "Выглянуло солнце, и снеговик начал таять.",
                  link: .problem, symbolName: "exclamationmark.bubble.fill"),
            .init(id: "sf-4", sentence: "Дети перенесли снеговика в тень под деревом.",
                  link: .solution, symbolName: "checkmark.seal.fill")
        ]
    )

    // MARK: - История: Смелый ёжик

    static let braveHedgehog = RetellingStory(
        id: "brave-hedgehog", title: "Смелый ёжик",
        frames: [
            .init(id: "bh-1", sentence: "В лесу жил колючий ёжик Пых.",
                  link: .hero, symbolName: "hare.fill"),
            .init(id: "bh-2", sentence: "Его норка была под старым пеньком.",
                  link: .place, symbolName: "tree.fill"),
            .init(id: "bh-3", sentence: "Однажды ёжик не смог найти дорогу домой.",
                  link: .problem, symbolName: "exclamationmark.bubble.fill"),
            .init(id: "bh-4", sentence: "Добрая белочка показала ёжику тропинку к норке.",
                  link: .solution, symbolName: "checkmark.seal.fill")
        ]
    )

    // MARK: - История: Урожай в огороде

    static let gardenHarvest = RetellingStory(
        id: "garden-harvest", title: "Урожай в огороде",
        frames: [
            .init(id: "gh-1", sentence: "Дедушка посадил весной много овощей.",
                  link: .hero, symbolName: "person.fill"),
            .init(id: "gh-2", sentence: "Грядки были в большом огороде за домом.",
                  link: .place, symbolName: "leaf.fill"),
            .init(id: "gh-3", sentence: "Овощей выросло так много, что дедушка не успевал собрать.",
                  link: .problem, symbolName: "exclamationmark.bubble.fill"),
            .init(id: "gh-4", sentence: "Вся семья вместе собрала богатый урожай.",
                  link: .solution, symbolName: "checkmark.seal.fill")
        ]
    )

    // MARK: - Queries

    /// История по идентификатору.
    static func story(id: String) -> RetellingStory? {
        stories.first { $0.id == id }
    }

    /// Случайная история для сессии.
    static func randomStory() -> RetellingStory {
        stories.randomElement() ?? catAndBird
    }
}
