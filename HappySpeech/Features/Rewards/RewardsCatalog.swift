import Foundation

// swiftlint:disable line_length
// Чисто-данные: записи каталога выровнены по колонкам для читаемости — длина строк
// допустима (нет логики, только литералы стикеров/достижений).

// MARK: - RewardsCatalog

/// Статический каталог стикеров и достижений альбома наград.
///
/// Каталог описывает **только структуру** (id, эмодзи, редкость, коллекция,
/// требуемый прогресс) — никакого зашитого состояния разблокировки и никаких
/// дат. Реальное состояние (что разблокировано, когда, какой прогресс)
/// вычисляется в `LiveRewardsRepository` из данных ребёнка.
enum RewardsCatalog {

    // MARK: - Achievement Definition

    struct AchievementDefinition {
        let key: String
        let emoji: String
        let medal: RewardsAchievement.Medal
        let required: Int
        /// Готовый русский заголовок — отображается ВСЕГДА, даже если xcstrings-ключ отсутствует.
        let title: String
        /// Готовая русская подсказка/описание.
        let hint: String

        init(
            _ key: String,
            _ emoji: String,
            _ medal: RewardsAchievement.Medal,
            _ required: Int,
            _ title: String,
            _ hint: String
        ) {
            self.key = key
            self.emoji = emoji
            self.medal = medal
            self.required = required
            self.title = title
            self.hint = hint
        }
    }

    /// 32 достижения. Прогресс (`currentProgress`) НЕ хранится здесь —
    /// он считается из реальных метрик ребёнка в `RewardsMetrics`.
    ///
    /// Поля `title` и `hint` содержат готовые русские строки — они НЕ строятся
    /// динамически из ключей локализации, поэтому карточки никогда не покажут
    /// сырой ключ вида `rewards.achievement.first_session.title`.
    static let achievementDefinitions: [AchievementDefinition] = [
        // Первые шаги (Bronze)
        .init("first_session",       "party.popper.fill", .bronze,  1,
              String(localized: "rewards.achievement.first_session.title",       defaultValue: "Первый урок"),
              String(localized: "rewards.achievement.first_session.hint",        defaultValue: "Проведи своё первое занятие")),
        .init("first_perfect",       "reward_gold_star",  .bronze,  1,
              String(localized: "rewards.achievement.first_perfect.title",       defaultValue: "Отличный результат"),
              String(localized: "rewards.achievement.first_perfect.hint",        defaultValue: "Получи 100% за урок")),
        .init("five_sessions",       "textformat.123",    .bronze,  5,
              String(localized: "rewards.achievement.five_sessions.title",       defaultValue: "Пять занятий"),
              String(localized: "rewards.achievement.five_sessions.hint",        defaultValue: "Проведи 5 занятий")),
        .init("ten_words",           "square.and.pencil", .bronze, 10,
              String(localized: "rewards.achievement.ten_words.title",           defaultValue: "Десять слов"),
              String(localized: "rewards.achievement.ten_words.hint",            defaultValue: "Выучи 10 новых слов")),
        .init("first_sticker",       "tag.fill",          .bronze,  1,
              String(localized: "rewards.achievement.first_sticker.title",       defaultValue: "Первый стикер"),
              String(localized: "rewards.achievement.first_sticker.hint",        defaultValue: "Разблокируй свой первый стикер")),
        // Звуки (Bronze / Silver)
        .init("sound_s_mastered",    "ant.fill",          .silver, 20,
              String(localized: "rewards.achievement.sound_s_mastered.title",    defaultValue: "Звук «С» освоен"),
              String(localized: "rewards.achievement.sound_s_mastered.hint",     defaultValue: "Потренируй звук С 20 раз")),
        .init("sound_r_mastered",    "music.note",        .silver, 20,
              String(localized: "rewards.achievement.sound_r_mastered.title",    defaultValue: "Звук «Р» освоен"),
              String(localized: "rewards.achievement.sound_r_mastered.hint",     defaultValue: "Потренируй звук Р 20 раз")),
        .init("sound_sh_mastered",   "water.waves",       .silver, 20,
              String(localized: "rewards.achievement.sound_sh_mastered.title",   defaultValue: "Звук «Ш» освоен"),
              String(localized: "rewards.achievement.sound_sh_mastered.hint",    defaultValue: "Потренируй звук Ш 20 раз")),
        .init("sound_l_mastered",    "leaf.fill",         .silver, 20,
              String(localized: "rewards.achievement.sound_l_mastered.title",    defaultValue: "Звук «Л» освоен"),
              String(localized: "rewards.achievement.sound_l_mastered.hint",     defaultValue: "Потренируй звук Л 20 раз")),
        .init("sound_k_mastered",    "word_frog",         .bronze, 20,
              String(localized: "rewards.achievement.sound_k_mastered.title",    defaultValue: "Звук «К» освоен"),
              String(localized: "rewards.achievement.sound_k_mastered.hint",     defaultValue: "Потренируй звук К 20 раз")),
        // Серии (Silver)
        .init("streak_3",            "flame.fill",        .bronze,  3,
              String(localized: "rewards.achievement.streak_3.title",            defaultValue: "Серия 3 дня"),
              String(localized: "rewards.achievement.streak_3.hint",             defaultValue: "Занимайся 3 дня подряд")),
        .init("streak_7",            "sparkles",          .silver,  7,
              String(localized: "rewards.achievement.streak_7.title",            defaultValue: "Серия неделя"),
              String(localized: "rewards.achievement.streak_7.hint",             defaultValue: "Занимайся 7 дней подряд")),
        .init("streak_14",           "sparkle",           .silver, 14,
              String(localized: "rewards.achievement.streak_14.title",           defaultValue: "Серия 2 недели"),
              String(localized: "rewards.achievement.streak_14.hint",            defaultValue: "Занимайся 14 дней подряд")),
        .init("streak_30",           "trophy.fill",       .gold,   30,
              String(localized: "rewards.achievement.streak_30.title",           defaultValue: "Серия месяц"),
              String(localized: "rewards.achievement.streak_30.hint",            defaultValue: "Занимайся 30 дней подряд")),
        // Сессии (Silver / Gold)
        .init("sessions_20",         "books.vertical.fill", .silver, 20,
              String(localized: "rewards.achievement.sessions_20.title",         defaultValue: "20 занятий"),
              String(localized: "rewards.achievement.sessions_20.hint",          defaultValue: "Проведи 20 занятий")),
        .init("sessions_50",         "graduationcap.fill",  .gold,   50,
              String(localized: "rewards.achievement.sessions_50.title",         defaultValue: "50 занятий"),
              String(localized: "rewards.achievement.sessions_50.hint",          defaultValue: "Проведи 50 занятий")),
        .init("sessions_100",        "crown.fill",        .gold,  100,
              String(localized: "rewards.achievement.sessions_100.title",        defaultValue: "100 занятий"),
              String(localized: "rewards.achievement.sessions_100.hint",         defaultValue: "Проведи 100 занятий")),
        .init("minutes_60",          "timer",             .silver, 60,
              String(localized: "rewards.achievement.minutes_60.title",          defaultValue: "Час практики"),
              String(localized: "rewards.achievement.minutes_60.hint",           defaultValue: "Набери 60 минут занятий")),
        .init("minutes_300",         "alarm.fill",        .gold,  300,
              String(localized: "rewards.achievement.minutes_300.title",         defaultValue: "5 часов практики"),
              String(localized: "rewards.achievement.minutes_300.hint",          defaultValue: "Набери 300 минут занятий")),
        // Коллекции (Silver / Gold)
        .init("collection_animals",  "pawprint.fill",     .silver, 12,
              String(localized: "rewards.achievement.collection_animals.title",  defaultValue: "Коллекция животные"),
              String(localized: "rewards.achievement.collection_animals.hint",   defaultValue: "Собери 12 стикеров животных")),
        .init("collection_space",    "reward_rocket",     .silver, 12,
              String(localized: "rewards.achievement.collection_space.title",    defaultValue: "Коллекция космос"),
              String(localized: "rewards.achievement.collection_space.hint",     defaultValue: "Собери 12 космических стикеров")),
        .init("collection_forest",   "word_forest",       .silver, 12,
              String(localized: "rewards.achievement.collection_forest.title",   defaultValue: "Коллекция лес"),
              String(localized: "rewards.achievement.collection_forest.hint",    defaultValue: "Собери 12 лесных стикеров")),
        .init("collection_ocean",    "water.waves",       .silver, 12,
              String(localized: "rewards.achievement.collection_ocean.title",    defaultValue: "Коллекция океан"),
              String(localized: "rewards.achievement.collection_ocean.hint",     defaultValue: "Собери 12 океанских стикеров")),
        .init("collection_halloween", "seasonal_halloween_full_moon", .gold, 12,
              String(localized: "rewards.achievement.collection_halloween.title", defaultValue: "Коллекция Хэллоуин"),
              String(localized: "rewards.achievement.collection_halloween.hint",  defaultValue: "Собери 12 хэллоуинских стикеров")),
        .init("collection_newyear",  "sparkles",          .gold,   12,
              String(localized: "rewards.achievement.collection_newyear.title",  defaultValue: "Коллекция Новый год"),
              String(localized: "rewards.achievement.collection_newyear.hint",   defaultValue: "Собери 12 новогодних стикеров")),
        // Качество (Gold)
        .init("perfect_10_row",      "reward_diamond",    .gold,   10,
              String(localized: "rewards.achievement.perfect_10_row.title",      defaultValue: "10 идеальных ответов"),
              String(localized: "rewards.achievement.perfect_10_row.hint",       defaultValue: "Дай 10 правильных ответов подряд")),
        .init("accuracy_90",         "target",            .gold,  100,
              String(localized: "rewards.achievement.accuracy_90.title",         defaultValue: "Точность 90%"),
              String(localized: "rewards.achievement.accuracy_90.hint",          defaultValue: "Достигни точности 90% за 100 упражнений")),
        .init("all_sounds",          "music.note",        .gold,    4,
              String(localized: "rewards.achievement.all_sounds.title",          defaultValue: "Все звуки"),
              String(localized: "rewards.achievement.all_sounds.hint",           defaultValue: "Освой 4 группы звуков")),
        // Редкие находки (Gold)
        .init("rare_sticker",        "sparkles",          .gold,    1,
              String(localized: "rewards.achievement.rare_sticker.title",        defaultValue: "Редкий стикер"),
              String(localized: "rewards.achievement.rare_sticker.hint",         defaultValue: "Разблокируй редкий стикер")),
        .init("epic_sticker",        "sparkles",          .gold,    1,
              String(localized: "rewards.achievement.epic_sticker.title",        defaultValue: "Эпический стикер"),
              String(localized: "rewards.achievement.epic_sticker.hint",         defaultValue: "Разблокируй эпический стикер")),
        .init("legendary_sticker",   "reward_rainbow",    .gold,    1,
              String(localized: "rewards.achievement.legendary_sticker.title",   defaultValue: "Легендарный стикер"),
              String(localized: "rewards.achievement.legendary_sticker.hint",    defaultValue: "Разблокируй легендарный стикер")),
        .init("all_collections",     "medal.fill",        .gold,    6,
              String(localized: "rewards.achievement.all_collections.title",     defaultValue: "Все коллекции"),
              String(localized: "rewards.achievement.all_collections.hint",      defaultValue: "Собери все 6 коллекций стикеров"))
    ]

    /// Каталог достижений с нулевым прогрессом и заблокированным состоянием —
    /// используется для пустого альбома (нет ребёнка / нет данных).
    ///
    /// Используем `def.title` / `def.hint` напрямую — они уже содержат
    /// готовые русские строки с Russian fallback и НИКОГДА не покажут сырой ключ.
    static func lockedAchievements() -> [RewardsAchievement] {
        achievementDefinitions.map { def in
            RewardsAchievement(
                id: def.key,
                key: def.key,
                emoji: def.emoji,
                title: def.title,
                hint: def.hint,
                medal: def.medal,
                requiredProgress: def.required,
                currentProgress: 0,
                isUnlocked: false,
                unlockedAt: nil
            )
        }
    }

    // MARK: - Sticker Template

    private struct StickerTemplate {
        let id: String
        let emoji: String
        let nameKey: String
        let collection: StickerCollection
        let rarity: StickerRarity
        let conditionKey: String
    }

    /// Каталог стикеров (72 шт., 6 коллекций × 12) — БЕЗ состояния разблокировки.
    /// Реальное `isUnlocked` / `unlockedAt` подставляется в `stickers(...)`.
    private static let templates: [StickerTemplate] = animals + space + forest + ocean + halloween + newYear

    /// Полностью заблокированный каталог (пустой альбом).
    static func lockedStickers() -> [Sticker] {
        templates.map { tpl in
            Sticker(
                id: tpl.id,
                emoji: tpl.emoji,
                name: String(localized: String.LocalizationValue(tpl.nameKey)),
                collection: tpl.collection,
                rarity: tpl.rarity,
                isUnlocked: false,
                isNew: false,
                unlockCondition: String(localized: String.LocalizationValue(tpl.conditionKey)),
                unlockedAt: nil
            )
        }
    }

    /// Каталог стикеров с реальным состоянием разблокировки: разблокированы
    /// только стикеры, реально находящиеся в инвентаре ребёнка (купленные в
    /// RewardShop). Дата разблокировки — реальная `purchasedAt`.
    static func stickers(
        ownedIds: Set<String>,
        purchasedAt: [String: Date]
    ) -> [Sticker] {
        templates.map { tpl in
            let owned = ownedIds.contains(tpl.id)
            return Sticker(
                id: tpl.id,
                emoji: tpl.emoji,
                name: String(localized: String.LocalizationValue(tpl.nameKey)),
                collection: tpl.collection,
                rarity: tpl.rarity,
                isUnlocked: owned,
                isNew: false,
                unlockCondition: String(localized: String.LocalizationValue(tpl.conditionKey)),
                unlockedAt: owned ? purchasedAt[tpl.id] : nil
            )
        }
    }

    // MARK: - Collections (templates only — no fabricated unlock state)

    private static let animals: [StickerTemplate] = [
        .init(id: "animals.cat",    emoji: "word_cat",  nameKey: "rewards.sticker.cat",    collection: .animals, rarity: .common,    conditionKey: "rewards.cond.cat"),
        .init(id: "animals.dog",    emoji: "word_dog",  nameKey: "rewards.sticker.dog",    collection: .animals, rarity: .common,    conditionKey: "rewards.cond.dog"),
        .init(id: "animals.fox",    emoji: "word_fox",  nameKey: "rewards.sticker.fox",    collection: .animals, rarity: .rare,      conditionKey: "rewards.cond.fox"),
        .init(id: "animals.bear",   emoji: "word_bear", nameKey: "rewards.sticker.bear",   collection: .animals, rarity: .common,    conditionKey: "rewards.cond.bear"),
        .init(id: "animals.panda",  emoji: "word_bear", nameKey: "rewards.sticker.panda",  collection: .animals, rarity: .rare,      conditionKey: "rewards.cond.panda"),
        .init(id: "animals.lion",   emoji: "reward_champion", nameKey: "rewards.sticker.lion", collection: .animals, rarity: .epic,   conditionKey: "rewards.cond.lion"),
        .init(id: "animals.tiger",  emoji: "reward_brave_heart", nameKey: "rewards.sticker.tiger", collection: .animals, rarity: .epic, conditionKey: "rewards.cond.tiger"),
        .init(id: "animals.frog",   emoji: "word_frog", nameKey: "rewards.sticker.frog",   collection: .animals, rarity: .common,    conditionKey: "rewards.cond.frog"),
        .init(id: "animals.bunny",  emoji: "word_hare", nameKey: "rewards.sticker.bunny",  collection: .animals, rarity: .common,    conditionKey: "rewards.cond.bunny"),
        .init(id: "animals.horse",  emoji: "word_cow",  nameKey: "rewards.sticker.horse",  collection: .animals, rarity: .rare,      conditionKey: "rewards.cond.horse"),
        .init(id: "animals.owl",    emoji: "word_bird", nameKey: "rewards.sticker.owl",    collection: .animals, rarity: .rare,      conditionKey: "rewards.cond.owl"),
        .init(id: "animals.dragon", emoji: "reward_brave_heart", nameKey: "rewards.sticker.dragon", collection: .animals, rarity: .legendary, conditionKey: "rewards.cond.dragon")
    ]

    private static let space: [StickerTemplate] = [
        .init(id: "space.rocket",   emoji: "reward_rocket", nameKey: "rewards.sticker.rocket", collection: .space, rarity: .common,    conditionKey: "rewards.cond.rocket"),
        .init(id: "space.star",     emoji: "reward_gold_star", nameKey: "rewards.sticker.star", collection: .space, rarity: .common,   conditionKey: "rewards.cond.star"),
        .init(id: "space.planet",   emoji: "globe.europe.africa.fill", nameKey: "rewards.sticker.planet", collection: .space, rarity: .rare, conditionKey: "rewards.cond.planet"),
        .init(id: "space.moon",     emoji: "moon.fill", nameKey: "rewards.sticker.moon",   collection: .space, rarity: .common,    conditionKey: "rewards.cond.moon"),
        .init(id: "space.comet",    emoji: "sparkles",  nameKey: "rewards.sticker.comet",  collection: .space, rarity: .rare,      conditionKey: "rewards.cond.comet"),
        .init(id: "space.alien",    emoji: "person.fill.questionmark", nameKey: "rewards.sticker.alien", collection: .space, rarity: .epic, conditionKey: "rewards.cond.alien"),
        .init(id: "space.ufo",      emoji: "globe",     nameKey: "rewards.sticker.ufo",    collection: .space, rarity: .epic,      conditionKey: "rewards.cond.ufo"),
        .init(id: "space.sun",      emoji: "sun.max.fill", nameKey: "rewards.sticker.sun", collection: .space, rarity: .common,    conditionKey: "rewards.cond.sun"),
        .init(id: "space.galaxy",   emoji: "moon.stars.fill", nameKey: "rewards.sticker.galaxy", collection: .space, rarity: .legendary, conditionKey: "rewards.cond.galaxy"),
        .init(id: "space.satellite", emoji: "antenna.radiowaves.left.and.right", nameKey: "rewards.sticker.satellite", collection: .space, rarity: .rare, conditionKey: "rewards.cond.satellite"),
        .init(id: "space.astronaut", emoji: "mascot_lyalya_wave", nameKey: "rewards.sticker.astronaut", collection: .space, rarity: .rare, conditionKey: "rewards.cond.astronaut"),
        .init(id: "space.blackhole", emoji: "circle.fill", nameKey: "rewards.sticker.blackhole", collection: .space, rarity: .legendary, conditionKey: "rewards.cond.blackhole")
    ]

    private static let forest: [StickerTemplate] = [
        .init(id: "forest.mushroom", emoji: "word_flower", nameKey: "rewards.sticker.mushroom", collection: .forest, rarity: .common, conditionKey: "rewards.cond.mushroom"),
        .init(id: "forest.tree",    emoji: "word_forest", nameKey: "rewards.sticker.tree",   collection: .forest, rarity: .common,    conditionKey: "rewards.cond.tree"),
        .init(id: "forest.leaf",    emoji: "leaf.fill",  nameKey: "rewards.sticker.leaf",   collection: .forest, rarity: .common,    conditionKey: "rewards.cond.leaf"),
        .init(id: "forest.snail",   emoji: "word_butterfly_insect", nameKey: "rewards.sticker.snail", collection: .forest, rarity: .rare, conditionKey: "rewards.cond.snail"),
        .init(id: "forest.hedgehog", emoji: "word_hare", nameKey: "rewards.sticker.hedgehog", collection: .forest, rarity: .rare,    conditionKey: "rewards.cond.hedgehog"),
        .init(id: "forest.butterfly", emoji: "word_butterfly_insect", nameKey: "rewards.sticker.butterfly", collection: .forest, rarity: .epic, conditionKey: "rewards.cond.butterfly"),
        .init(id: "forest.deer",    emoji: "word_bear",  nameKey: "rewards.sticker.deer",   collection: .forest, rarity: .epic,      conditionKey: "rewards.cond.deer"),
        .init(id: "forest.acorn",   emoji: "word_apple", nameKey: "rewards.sticker.acorn",  collection: .forest, rarity: .common,    conditionKey: "rewards.cond.acorn"),
        .init(id: "forest.fern",    emoji: "leaf.fill",  nameKey: "rewards.sticker.fern",   collection: .forest, rarity: .common,    conditionKey: "rewards.cond.fern"),
        .init(id: "forest.squirrel", emoji: "word_hare", nameKey: "rewards.sticker.squirrel", collection: .forest, rarity: .rare,    conditionKey: "rewards.cond.squirrel"),
        .init(id: "forest.wolf",    emoji: "word_fox",   nameKey: "rewards.sticker.wolf",   collection: .forest, rarity: .rare,      conditionKey: "rewards.cond.wolf"),
        .init(id: "forest.phoenix", emoji: "word_bird",  nameKey: "rewards.sticker.phoenix", collection: .forest, rarity: .legendary, conditionKey: "rewards.cond.phoenix")
    ]

    private static let ocean: [StickerTemplate] = [
        .init(id: "ocean.wave",     emoji: "water.waves", nameKey: "rewards.sticker.wave",  collection: .ocean, rarity: .common,     conditionKey: "rewards.cond.wave"),
        .init(id: "ocean.fish",     emoji: "word_fish",  nameKey: "rewards.sticker.fish",   collection: .ocean, rarity: .common,     conditionKey: "rewards.cond.fish"),
        .init(id: "ocean.crab",     emoji: "word_fish",  nameKey: "rewards.sticker.crab",   collection: .ocean, rarity: .common,     conditionKey: "rewards.cond.crab"),
        .init(id: "ocean.dolphin",  emoji: "word_fish",  nameKey: "rewards.sticker.dolphin", collection: .ocean, rarity: .rare,      conditionKey: "rewards.cond.dolphin"),
        .init(id: "ocean.turtle",   emoji: "word_frog",  nameKey: "rewards.sticker.turtle", collection: .ocean, rarity: .rare,       conditionKey: "rewards.cond.turtle"),
        .init(id: "ocean.shark",    emoji: "word_fish",  nameKey: "rewards.sticker.shark",  collection: .ocean, rarity: .epic,       conditionKey: "rewards.cond.shark"),
        .init(id: "ocean.octopus",  emoji: "word_fish",  nameKey: "rewards.sticker.octopus", collection: .ocean, rarity: .epic,      conditionKey: "rewards.cond.octopus"),
        .init(id: "ocean.seahorse", emoji: "reward_rainbow", nameKey: "rewards.sticker.seahorse", collection: .ocean, rarity: .rare, conditionKey: "rewards.cond.seahorse"),
        .init(id: "ocean.jellyfish", emoji: "word_butterfly_insect", nameKey: "rewards.sticker.jellyfish", collection: .ocean, rarity: .rare, conditionKey: "rewards.cond.jellyfish"),
        .init(id: "ocean.whale",    emoji: "word_fish",  nameKey: "rewards.sticker.whale",  collection: .ocean, rarity: .legendary,  conditionKey: "rewards.cond.whale"),
        .init(id: "ocean.lobster",  emoji: "word_fish",  nameKey: "rewards.sticker.lobster", collection: .ocean, rarity: .common,    conditionKey: "rewards.cond.lobster"),
        .init(id: "ocean.mermaid",  emoji: "word_fish",  nameKey: "rewards.sticker.mermaid", collection: .ocean, rarity: .legendary, conditionKey: "rewards.cond.mermaid")
    ]

    private static let halloween: [StickerTemplate] = [
        .init(id: "halloween.pumpkin", emoji: "seasonal_halloween_full_moon", nameKey: "rewards.sticker.pumpkin", collection: .halloween, rarity: .common, conditionKey: "rewards.cond.pumpkin"),
        .init(id: "halloween.ghost",   emoji: "exclamationmark.triangle.fill", nameKey: "rewards.sticker.ghost", collection: .halloween, rarity: .common, conditionKey: "rewards.cond.ghost"),
        .init(id: "halloween.bat",     emoji: "moon.fill", nameKey: "rewards.sticker.bat",     collection: .halloween, rarity: .common, conditionKey: "rewards.cond.bat"),
        .init(id: "halloween.spider",  emoji: "ant.fill",  nameKey: "rewards.sticker.spider",  collection: .halloween, rarity: .rare,   conditionKey: "rewards.cond.spider"),
        .init(id: "halloween.witch",   emoji: "person.fill", nameKey: "rewards.sticker.witch", collection: .halloween, rarity: .rare,   conditionKey: "rewards.cond.witch"),
        .init(id: "halloween.skeleton", emoji: "exclamationmark.triangle.fill", nameKey: "rewards.sticker.skeleton", collection: .halloween, rarity: .rare, conditionKey: "rewards.cond.skeleton"),
        .init(id: "halloween.vampire", emoji: "person.fill", nameKey: "rewards.sticker.vampire", collection: .halloween, rarity: .epic, conditionKey: "rewards.cond.vampire"),
        .init(id: "halloween.zombie",  emoji: "person.fill", nameKey: "rewards.sticker.zombie", collection: .halloween, rarity: .epic,  conditionKey: "rewards.cond.zombie"),
        .init(id: "halloween.cauldron", emoji: "wand.and.sparkles", nameKey: "rewards.sticker.cauldron", collection: .halloween, rarity: .common, conditionKey: "rewards.cond.cauldron"),
        .init(id: "halloween.moon",    emoji: "moon.fill", nameKey: "rewards.sticker.fullmoon", collection: .halloween, rarity: .rare, conditionKey: "rewards.cond.fullmoon"),
        .init(id: "halloween.potion",  emoji: "flask.fill", nameKey: "rewards.sticker.potion", collection: .halloween, rarity: .rare,  conditionKey: "rewards.cond.potion"),
        .init(id: "halloween.demon",   emoji: "exclamationmark.triangle.fill", nameKey: "rewards.sticker.demon", collection: .halloween, rarity: .legendary, conditionKey: "rewards.cond.demon")
    ]

    private static let newYear: [StickerTemplate] = [
        .init(id: "newyear.fireworks", emoji: "sparkles", nameKey: "rewards.sticker.fireworks", collection: .newYear, rarity: .common, conditionKey: "rewards.cond.fireworks"),
        .init(id: "newyear.gift",     emoji: "gift.fill", nameKey: "rewards.sticker.gift",   collection: .newYear, rarity: .common,    conditionKey: "rewards.cond.gift"),
        .init(id: "newyear.tree",     emoji: "seasonal_newyear_christmas_tree", nameKey: "rewards.sticker.xmastree", collection: .newYear, rarity: .common, conditionKey: "rewards.cond.xmastree"),
        .init(id: "newyear.bell",     emoji: "bell.fill", nameKey: "rewards.sticker.bell",   collection: .newYear, rarity: .common,    conditionKey: "rewards.cond.bell"),
        .init(id: "newyear.candy",    emoji: "word_cake", nameKey: "rewards.sticker.candy",  collection: .newYear, rarity: .common,    conditionKey: "rewards.cond.candy"),
        .init(id: "newyear.snowflake", emoji: "snowflake", nameKey: "rewards.sticker.snowflake", collection: .newYear, rarity: .rare,  conditionKey: "rewards.cond.snowflake"),
        .init(id: "newyear.snowman",  emoji: "snowflake", nameKey: "rewards.sticker.snowman", collection: .newYear, rarity: .rare,     conditionKey: "rewards.cond.snowman"),
        .init(id: "newyear.champagne", emoji: "wineglass.fill", nameKey: "rewards.sticker.champagne", collection: .newYear, rarity: .rare, conditionKey: "rewards.cond.champagne"),
        .init(id: "newyear.santahat", emoji: "person.fill", nameKey: "rewards.sticker.santa", collection: .newYear, rarity: .epic,    conditionKey: "rewards.cond.santa"),
        .init(id: "newyear.reindeer", emoji: "word_bear", nameKey: "rewards.sticker.reindeer", collection: .newYear, rarity: .epic,   conditionKey: "rewards.cond.reindeer"),
        .init(id: "newyear.elf",      emoji: "person.fill", nameKey: "rewards.sticker.elf",  collection: .newYear, rarity: .rare,      conditionKey: "rewards.cond.elf"),
        .init(id: "newyear.unicorn",  emoji: "reward_rainbow", nameKey: "rewards.sticker.unicorn", collection: .newYear, rarity: .legendary, conditionKey: "rewards.cond.unicorn")
    ]
}
// swiftlint:enable line_length
