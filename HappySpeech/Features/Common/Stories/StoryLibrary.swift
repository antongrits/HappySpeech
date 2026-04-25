import Foundation

// MARK: - StoryLibrary

/// Библиотека из 20 анимированных историй для логопедических занятий.
/// Покрывает шипящие (Ш, Ж, Щ, Ч), свистящие (С, З, Ц), соноры (Р, Л),
/// заднеязычные (К, Г, Х) и смешанные звуки (П, Е, Б, Д, Т).
public final class StoryLibrary: Sendable {

    // MARK: - Singleton

    public static let shared = StoryLibrary()

    private init() {}

    // MARK: - All Stories

    public let allStories: [AnimatedStory] = [

        // ─── Шипящие ────────────────────────────────────────────────────────

        AnimatedStory(
            id: "shustray-shishka",
            title: "Шустрая шишка",
            targetSound: "Ш",
            scenes: [
                AnimatedStoryScene(
                    id: "shustray-shishka-1",
                    backgroundEmoji: "🌲🌲🌲",
                    characterEmoji: "🌰",
                    narrativeText: "В шумном лесу на высокой ели жила маленькая шустрая шишка.",
                    targetWord: "шишка",
                    animationType: .bounce,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "shustray-shishka-2",
                    backgroundEmoji: "🌬️🌲",
                    characterEmoji: "🌰💨",
                    narrativeText: "Шалый ветер налетел и схватил шишку, понося её вниз с шумом.",
                    targetWord: "шишку",
                    animationType: .slide,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "shustray-shishka-3",
                    backgroundEmoji: "🐿️🏠",
                    characterEmoji: "🌰🐿️",
                    narrativeText: "Рыжая белочка поймала шишку и унесла её в своё тёплое гнёздышко.",
                    targetWord: "шишку",
                    animationType: .grow,
                    characterPosition: .left
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#FFA07A", "#FF6347"]
        ),

        AnimatedStory(
            id: "zhukov-v-luzhe",
            title: "Жучок в луже",
            targetSound: "Ж",
            scenes: [
                AnimatedStoryScene(
                    id: "zhukov-v-luzhe-1",
                    backgroundEmoji: "🌧️🌿",
                    characterEmoji: "🐞",
                    narrativeText: "Маленький жучок жил под листочком и очень любил дождик.",
                    targetWord: "жучок",
                    animationType: .bounce,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "zhukov-v-luzhe-2",
                    backgroundEmoji: "🌊💦",
                    characterEmoji: "🐞🌊",
                    narrativeText: "После дождя жучок прыгнул в большую лужу и начал плескаться.",
                    targetWord: "жучок",
                    animationType: .float,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "zhukov-v-luzhe-3",
                    backgroundEmoji: "🌺🌤️",
                    characterEmoji: "🐞🌺",
                    narrativeText: "Жучок выбрался на цветок и сушил крылышки под тёплым солнышком.",
                    targetWord: "жучок",
                    animationType: .spin,
                    characterPosition: .right
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#87CEEB", "#4169E1"]
        ),

        AnimatedStory(
            id: "shchenok-i-shchetka",
            title: "Щенок и щётка",
            targetSound: "Щ",
            scenes: [
                AnimatedStoryScene(
                    id: "shchenok-i-shchetka-1",
                    backgroundEmoji: "🏠🌿",
                    characterEmoji: "🐶",
                    narrativeText: "Маленький щенок нашёл на полу большую пушистую щётку.",
                    targetWord: "щенок",
                    animationType: .grow,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "shchenok-i-shchetka-2",
                    backgroundEmoji: "✨💫",
                    characterEmoji: "🐶🪥",
                    narrativeText: "Щенок начал играть с щёткой и катал её по всей комнате.",
                    targetWord: "щёткой",
                    animationType: .bounce,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "shchenok-i-shchetka-3",
                    backgroundEmoji: "✨🌟",
                    characterEmoji: "🐶✨",
                    narrativeText: "Щенок почистил щёткой свою шёрстку и стал блестеть как звёздочка.",
                    targetWord: "щёткой",
                    animationType: .spin,
                    characterPosition: .center
                )
            ],
            difficulty: 2,
            ageMin: 5,
            ageMax: 8,
            backgroundGradient: ["#FFD700", "#FFA500"]
        ),

        AnimatedStory(
            id: "chaynik-chudak",
            title: "Чайник-чудак",
            targetSound: "Ч",
            scenes: [
                AnimatedStoryScene(
                    id: "chaynik-chudak-1",
                    backgroundEmoji: "☕🍵",
                    characterEmoji: "🫖",
                    narrativeText: "Жил-был чудной чайник, который умел петь песенки.",
                    targetWord: "чайник",
                    animationType: .bounce,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "chaynik-chudak-2",
                    backgroundEmoji: "🎩💨",
                    characterEmoji: "🫖🎩",
                    narrativeText: "Чайник надел волшебную шляпу и начал чудить — превращал воду в чай.",
                    targetWord: "чайник",
                    animationType: .spin,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "chaynik-chudak-3",
                    backgroundEmoji: "☕🌸",
                    characterEmoji: "🫖☕",
                    narrativeText: "Чайник налил всем горячего чаю и очень гордился своим чудесным даром.",
                    targetWord: "чаю",
                    animationType: .float,
                    characterPosition: .center
                )
            ],
            difficulty: 2,
            ageMin: 5,
            ageMax: 8,
            backgroundGradient: ["#FF8C69", "#CD5C5C"]
        ),

        // ─── Свистящие ───────────────────────────────────────────────────────

        AnimatedStory(
            id: "sinyaya-sobaka",
            title: "Синяя собака",
            targetSound: "С",
            scenes: [
                AnimatedStoryScene(
                    id: "sinyaya-sobaka-1",
                    backgroundEmoji: "🌤️🌈",
                    characterEmoji: "🐕",
                    narrativeText: "В синем саду жила самая добрая собака по имени Соня.",
                    targetWord: "собака",
                    animationType: .fadeIn,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "sinyaya-sobaka-2",
                    backgroundEmoji: "🦴🌿",
                    characterEmoji: "🐕💙",
                    narrativeText: "Соня нашла большую косточку и сразу же спрятала её в саду.",
                    targetWord: "Соня",
                    animationType: .slide,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "sinyaya-sobaka-3",
                    backgroundEmoji: "🏠💙",
                    characterEmoji: "🐕🦴",
                    narrativeText: "Собака Соня очень любила свой синий домик и свою любимую кость.",
                    targetWord: "собака",
                    animationType: .bounce,
                    characterPosition: .right
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#87CEEB", "#1E90FF"]
        ),

        AnimatedStory(
            id: "zaychik-na-zaryadke",
            title: "Зайчик на зарядке",
            targetSound: "З",
            scenes: [
                AnimatedStoryScene(
                    id: "zaychik-na-zaryadke-1",
                    backgroundEmoji: "🌄🌿",
                    characterEmoji: "🐰",
                    narrativeText: "Рано утром на зелёной полянке зайчик делал зарядку.",
                    targetWord: "зайчик",
                    animationType: .bounce,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "zaychik-na-zaryadke-2",
                    backgroundEmoji: "🏋️🌿",
                    characterEmoji: "🐰🏋️",
                    narrativeText: "Зайчик поднимал морковки как гантельки и громко считал до десяти.",
                    targetWord: "зайчик",
                    animationType: .shake,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "zaychik-na-zaryadke-3",
                    backgroundEmoji: "🌞🌈",
                    characterEmoji: "🐰🌟",
                    narrativeText: "После зарядки зайчик был здоровым и весёлым на весь день.",
                    targetWord: "зайчик",
                    animationType: .float,
                    characterPosition: .center
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#90EE90", "#228B22"]
        ),

        AnimatedStory(
            id: "tsyplyonok-tsezar",
            title: "Цыплёнок Цезарь",
            targetSound: "Ц",
            scenes: [
                AnimatedStoryScene(
                    id: "tsyplyonok-tsezar-1",
                    backgroundEmoji: "🌻🌾",
                    characterEmoji: "🐣",
                    narrativeText: "Маленький цыплёнок по имени Цезарь только что вылупился из яйца.",
                    targetWord: "цыплёнок",
                    animationType: .grow,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "tsyplyonok-tsezar-2",
                    backgroundEmoji: "👑🌟",
                    characterEmoji: "🐣👑",
                    narrativeText: "Цезарь нашёл золотую корону и объявил себя царём всего птичьего двора.",
                    targetWord: "цыплёнок",
                    animationType: .spin,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "tsyplyonok-tsezar-3",
                    backgroundEmoji: "🌻🐣",
                    characterEmoji: "🐣🌻",
                    narrativeText: "Цыплёнок Цезарь собрал всех цыплят и угостил их семечками из цветка.",
                    targetWord: "цыплят",
                    animationType: .bounce,
                    characterPosition: .center
                )
            ],
            difficulty: 2,
            ageMin: 5,
            ageMax: 8,
            backgroundGradient: ["#FFD700", "#FF8C00"]
        ),

        // ─── Соноры Р ───────────────────────────────────────────────────────

        AnimatedStory(
            id: "rybka-rita",
            title: "Рыбка Рита",
            targetSound: "Р",
            scenes: [
                AnimatedStoryScene(
                    id: "rybka-rita-1",
                    backgroundEmoji: "🌊🪸",
                    characterEmoji: "🐠",
                    narrativeText: "В розовом море жила маленькая рыбка Рита с радужными плавниками.",
                    targetWord: "рыбка",
                    animationType: .float,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "rybka-rita-2",
                    backgroundEmoji: "🌊💎",
                    characterEmoji: "🐠🐚",
                    narrativeText: "Рита нашла красивую ракушку и решила подарить её другу-крабику.",
                    targetWord: "Рита",
                    animationType: .slide,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "rybka-rita-3",
                    backgroundEmoji: "🐚🌊",
                    characterEmoji: "🐠🦀",
                    narrativeText: "Рыбка Рита и крабик радостно играли с ракушкой весь день напролёт.",
                    targetWord: "рыбка",
                    animationType: .bounce,
                    characterPosition: .left
                )
            ],
            difficulty: 2,
            ageMin: 6,
            ageMax: 8,
            backgroundGradient: ["#00CED1", "#20B2AA"]
        ),

        AnimatedStory(
            id: "raketa-ryzhik",
            title: "Ракета Рыжик",
            targetSound: "Р",
            scenes: [
                AnimatedStoryScene(
                    id: "raketa-ryzhik-1",
                    backgroundEmoji: "🌌⭐",
                    characterEmoji: "🚀",
                    narrativeText: "Рыжая ракета Рыжик мечтала долететь до самой далёкой звезды.",
                    targetWord: "ракета",
                    animationType: .grow,
                    characterPosition: .bottom
                ),
                AnimatedStoryScene(
                    id: "raketa-ryzhik-2",
                    backgroundEmoji: "⭐🌙",
                    characterEmoji: "🚀⭐",
                    narrativeText: "Рыжик разогнался и рванул вверх, оставляя рыжий след в небе.",
                    targetWord: "рванул",
                    animationType: .slide,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "raketa-ryzhik-3",
                    backgroundEmoji: "🌙🌟",
                    characterEmoji: "🚀🌟",
                    narrativeText: "Ракета Рыжик добралась до луны и радостно прокричала: «Ура!»",
                    targetWord: "ракета",
                    animationType: .bounce,
                    characterPosition: .top
                )
            ],
            difficulty: 2,
            ageMin: 6,
            ageMax: 8,
            backgroundGradient: ["#191970", "#4B0082"]
        ),

        // ─── Соноры Л ───────────────────────────────────────────────────────

        AnimatedStory(
            id: "lisa-i-lyagushka",
            title: "Лиса и лягушка",
            targetSound: "Л",
            scenes: [
                AnimatedStoryScene(
                    id: "lisa-i-lyagushka-1",
                    backgroundEmoji: "🌿🍃",
                    characterEmoji: "🦊",
                    narrativeText: "Ловкая лиса гуляла по лесу и нашла большое лесное озеро.",
                    targetWord: "лиса",
                    animationType: .slide,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "lisa-i-lyagushka-2",
                    backgroundEmoji: "🐸💧",
                    characterEmoji: "🦊🐸",
                    narrativeText: "На листочке сидела маленькая лягушка и квакала на всю поляну.",
                    targetWord: "лягушка",
                    animationType: .bounce,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "lisa-i-lyagushka-3",
                    backgroundEmoji: "🌿🌸",
                    characterEmoji: "🦊🐸",
                    narrativeText: "Лиса и лягушка подружились и каждый день ловили луч солнца вместе.",
                    targetWord: "лягушка",
                    animationType: .float,
                    characterPosition: .center
                )
            ],
            difficulty: 2,
            ageMin: 6,
            ageMax: 8,
            backgroundGradient: ["#7CFC00", "#228B22"]
        ),

        AnimatedStory(
            id: "luna-i-lena",
            title: "Луна Лена",
            targetSound: "Л",
            scenes: [
                AnimatedStoryScene(
                    id: "luna-i-lena-1",
                    backgroundEmoji: "🌙✨",
                    characterEmoji: "🌙",
                    narrativeText: "Луна по имени Лена каждую ночь светила над лесом и над лугом.",
                    targetWord: "луна",
                    animationType: .fadeIn,
                    characterPosition: .top
                ),
                AnimatedStoryScene(
                    id: "luna-i-lena-2",
                    backgroundEmoji: "⭐💫",
                    characterEmoji: "🌙⭐",
                    narrativeText: "Лена собирала вокруг себя звёздочки и строила из них ласковый букет.",
                    targetWord: "Лена",
                    animationType: .float,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "luna-i-lena-3",
                    backgroundEmoji: "🌙🌲",
                    characterEmoji: "🌙🌟",
                    narrativeText: "Луна Лена лила лёгкий серебряный свет на всех спящих лесных зверей.",
                    targetWord: "луна",
                    animationType: .spin,
                    characterPosition: .top
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#2C3E50", "#8E44AD"]
        ),

        // ─── Заднеязычные ────────────────────────────────────────────────────

        AnimatedStory(
            id: "kot-kuzma",
            title: "Кот Кузьма",
            targetSound: "К",
            scenes: [
                AnimatedStoryScene(
                    id: "kot-kuzma-1",
                    backgroundEmoji: "🏠🌳",
                    characterEmoji: "🐱",
                    narrativeText: "Кот Кузьма жил в красивом домике и каждый день ловил клубки.",
                    targetWord: "кот",
                    animationType: .bounce,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "kot-kuzma-2",
                    backgroundEmoji: "🎩🌟",
                    characterEmoji: "🐱🎩",
                    narrativeText: "Кузьма надел клетчатую кепку и отправился на кулинарный конкурс.",
                    targetWord: "Кузьма",
                    animationType: .slide,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "kot-kuzma-3",
                    backgroundEmoji: "🏆🎉",
                    characterEmoji: "🐱🏆",
                    narrativeText: "Кот Кузьма выиграл кубок и принёс домой целую корзину конфет.",
                    targetWord: "кот",
                    animationType: .grow,
                    characterPosition: .center
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#FF9966", "#FF5E62"]
        ),

        AnimatedStory(
            id: "gus-grisha",
            title: "Гусь Гриша",
            targetSound: "Г",
            scenes: [
                AnimatedStoryScene(
                    id: "gus-grisha-1",
                    backgroundEmoji: "🌾🏞️",
                    characterEmoji: "🦆",
                    narrativeText: "Гордый гусь Гриша жил на большом зелёном лугу у голубого пруда.",
                    targetWord: "гусь",
                    animationType: .fadeIn,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "gus-grisha-2",
                    backgroundEmoji: "🌾🌊",
                    characterEmoji: "🦆🌊",
                    narrativeText: "Гриша гордо плыл по воде и громко гоготал от радости.",
                    targetWord: "гоготал",
                    animationType: .float,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "gus-grisha-3",
                    backgroundEmoji: "🌅🌾",
                    characterEmoji: "🦆🌟",
                    narrativeText: "Гусь Гриша угостил всех гостей гречкой и говорил им добрые слова.",
                    targetWord: "гусь",
                    animationType: .bounce,
                    characterPosition: .right
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#56AB2F", "#A8E063"]
        ),

        AnimatedStory(
            id: "khomyak-khrabry",
            title: "Хомяк Храбрый",
            targetSound: "Х",
            scenes: [
                AnimatedStoryScene(
                    id: "khomyak-khrabry-1",
                    backgroundEmoji: "🌲🌾",
                    characterEmoji: "🐹",
                    narrativeText: "Маленький хомяк решил стать самым храбрым хомяком в лесу.",
                    targetWord: "хомяк",
                    animationType: .grow,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "khomyak-khrabry-2",
                    backgroundEmoji: "🛡️⚔️",
                    characterEmoji: "🐹🛡️",
                    narrativeText: "Хомяк сделал щит из орехового листа и меч из тонкой веточки.",
                    targetWord: "хомяк",
                    animationType: .shake,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "khomyak-khrabry-3",
                    backgroundEmoji: "🏆🌟",
                    characterEmoji: "🐹🌟",
                    narrativeText: "Все в лесу хвалили храброго хомяка и угощали его вкусными хлебными крошками.",
                    targetWord: "хомяка",
                    animationType: .bounce,
                    characterPosition: .center
                )
            ],
            difficulty: 2,
            ageMin: 5,
            ageMax: 8,
            backgroundGradient: ["#D4A056", "#A0522D"]
        ),

        // ─── Бонусные (смешанные/грамматика) ────────────────────────────────

        AnimatedStory(
            id: "mishka-i-mishutka",
            title: "Мишка и мишутка",
            targetSound: "Ш",
            scenes: [
                AnimatedStoryScene(
                    id: "mishka-i-mishutka-1",
                    backgroundEmoji: "🌲🌲",
                    characterEmoji: "🐻",
                    narrativeText: "Большой мишка и маленький мишутка жили в шалаше посреди леса.",
                    targetWord: "мишка",
                    animationType: .bounce,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "mishka-i-mishutka-2",
                    backgroundEmoji: "🍯🌿",
                    characterEmoji: "🐻🍯",
                    narrativeText: "Мишка нашёл в лесу большой шар мёда и позвал мишутку делиться.",
                    targetWord: "мишутку",
                    animationType: .slide,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "mishka-i-mishutka-3",
                    backgroundEmoji: "🌲🏠",
                    characterEmoji: "🐻🐻",
                    narrativeText: "Мишка и мишутка съели весь мёд и пошли спать в свой уютный шалаш.",
                    targetWord: "шалаш",
                    animationType: .float,
                    characterPosition: .right
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#8B4513", "#D2691E"]
        ),

        AnimatedStory(
            id: "pingvin-pyotr",
            title: "Пингвин Пётр",
            targetSound: "П",
            scenes: [
                AnimatedStoryScene(
                    id: "pingvin-pyotr-1",
                    backgroundEmoji: "🧊❄️",
                    characterEmoji: "🐧",
                    narrativeText: "Пингвин Пётр жил на плоской льдине посреди холодного океана.",
                    targetWord: "пингвин",
                    animationType: .slide,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "pingvin-pyotr-2",
                    backgroundEmoji: "🐟🧊",
                    characterEmoji: "🐧🐟",
                    narrativeText: "Пётр поймал пять больших рыбок и принёс их в подарок пингвинятам.",
                    targetWord: "Пётр",
                    animationType: .bounce,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "pingvin-pyotr-3",
                    backgroundEmoji: "❄️🌟",
                    characterEmoji: "🐧⭐",
                    narrativeText: "Пингвин Пётр стал лучшим папой и получил почётную полярную звезду.",
                    targetWord: "пингвин",
                    animationType: .grow,
                    characterPosition: .center
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#00BFFF", "#87CEFA"]
        ),

        AnimatedStory(
            id: "yozhik-egor",
            title: "Ёжик Егор",
            targetSound: "Е",
            scenes: [
                AnimatedStoryScene(
                    id: "yozhik-egor-1",
                    backgroundEmoji: "🍄🌲",
                    characterEmoji: "🦔",
                    narrativeText: "Ёжик Егор ел ежевику у ели и ёжился от утреннего холода.",
                    targetWord: "ёжик",
                    animationType: .shake,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "yozhik-egor-2",
                    backgroundEmoji: "🍂🍄",
                    characterEmoji: "🦔🍄",
                    narrativeText: "Егор нашёл ёлку с вкусными грибами и наколол их на иголки.",
                    targetWord: "Егор",
                    animationType: .bounce,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "yozhik-egor-3",
                    backgroundEmoji: "🌲🏠",
                    characterEmoji: "🦔🌟",
                    narrativeText: "Ёжик Егор принёс грибы домой и сварил ароматный ежевичный суп.",
                    targetWord: "ёжик",
                    animationType: .float,
                    characterPosition: .right
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#556B2F", "#8FBC8F"]
        ),

        AnimatedStory(
            id: "babochka-bella",
            title: "Бабочка Белла",
            targetSound: "Б",
            scenes: [
                AnimatedStoryScene(
                    id: "babochka-bella-1",
                    backgroundEmoji: "🌺🌸",
                    characterEmoji: "🦋",
                    narrativeText: "Бабочка Белла жила в большом саду среди белых и розовых цветов.",
                    targetWord: "бабочка",
                    animationType: .float,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "babochka-bella-2",
                    backgroundEmoji: "🌈🌺",
                    characterEmoji: "🦋🌈",
                    narrativeText: "Белла летела сквозь радугу и собирала блестящие капли росы.",
                    targetWord: "Белла",
                    animationType: .spin,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "babochka-bella-3",
                    backgroundEmoji: "🌸✨",
                    characterEmoji: "🦋🌸",
                    narrativeText: "Бабочка Белла нарисовала крыльями большую букву «Б» на небе.",
                    targetWord: "бабочка",
                    animationType: .bounce,
                    characterPosition: .center
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#FF69B4", "#DA70D6"]
        ),

        AnimatedStory(
            id: "drakon-dima",
            title: "Дракон Дима",
            targetSound: "Д",
            scenes: [
                AnimatedStoryScene(
                    id: "drakon-dima-1",
                    backgroundEmoji: "🔥🏔️",
                    characterEmoji: "🐲",
                    narrativeText: "Дракон Дима добрый и дружелюбный жил в далёкой долине.",
                    targetWord: "дракон",
                    animationType: .grow,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "drakon-dima-2",
                    backgroundEmoji: "🔥👑",
                    characterEmoji: "🐲🔥",
                    narrativeText: "Дима дул огнём на большую лужу и делал из неё дым-облако.",
                    targetWord: "Дима",
                    animationType: .bounce,
                    characterPosition: .right
                ),
                AnimatedStoryScene(
                    id: "drakon-dima-3",
                    backgroundEmoji: "👑🌟",
                    characterEmoji: "🐲👑",
                    narrativeText: "Дракон Дима стал добрым другом для всех жителей долины.",
                    targetWord: "дракон",
                    animationType: .float,
                    characterPosition: .center
                )
            ],
            difficulty: 2,
            ageMin: 6,
            ageMax: 8,
            backgroundGradient: ["#B22222", "#FF4500"]
        ),

        AnimatedStory(
            id: "tigr-timur",
            title: "Тигр Тимур",
            targetSound: "Т",
            scenes: [
                AnimatedStoryScene(
                    id: "tigr-timur-1",
                    backgroundEmoji: "🌿🏕️",
                    characterEmoji: "🐯",
                    narrativeText: "Тигр Тимур тихо ходил по тропинке в тропическом лесу.",
                    targetWord: "тигр",
                    animationType: .slide,
                    characterPosition: .left
                ),
                AnimatedStoryScene(
                    id: "tigr-timur-2",
                    backgroundEmoji: "🌿🌟",
                    characterEmoji: "🐯🌿",
                    narrativeText: "Тимур танцевал среди деревьев и тихонько пел тигриные песни.",
                    targetWord: "Тимур",
                    animationType: .bounce,
                    characterPosition: .center
                ),
                AnimatedStoryScene(
                    id: "tigr-timur-3",
                    backgroundEmoji: "🏕️🔥",
                    characterEmoji: "🐯🌟",
                    narrativeText: "Тигр Тимур сидел у тёплого костра и рассказывал тигрятам сказки.",
                    targetWord: "тигр",
                    animationType: .float,
                    characterPosition: .right
                )
            ],
            difficulty: 1,
            ageMin: 5,
            ageMax: 7,
            backgroundGradient: ["#FF8C00", "#FF4500"]
        )
    ]

    // MARK: - Queries

    /// Истории для конкретного целевого звука.
    public func stories(for sound: String) -> [AnimatedStory] {
        allStories.filter { $0.targetSound == sound }
    }

    /// Истории по возрасту ребёнка.
    public func stories(forAge age: Int) -> [AnimatedStory] {
        allStories.filter { $0.ageMin <= age && age <= $0.ageMax }
    }

    /// История по идентификатору.
    public func story(id: String) -> AnimatedStory? {
        allStories.first { $0.id == id }
    }
}

