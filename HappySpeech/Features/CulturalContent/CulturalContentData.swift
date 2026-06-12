import Foundation

// MARK: - CulturalItem bundled catalog
//
// Статический каталог контента: сказки, песни, стихи/потешки/считалки/загадки,
// скороговорки и чистоговорки. Все тексты народные / public domain.
// Вынесен из CulturalContentModels.swift в отдельный файл, чтобы тело
// CulturalItem не превышало лимит SwiftLint type_body_length.

extension CulturalItem {

    // MARK: — Сказки (fairyTale)

    static let fairyTales: [CulturalItem] = [
        .init(
            id: "tale.repka",
            category: .fairyTale,
            titleKey: "cultural.tale.repka.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 180,
            targetSounds: ["Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "Посадил дед репку."),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 12,
                             text: "Выросла репка большая-пребольшая."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Стал дед репку из земли тащить."),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Тянет-потянет, вытянуть не может.")
            ],
            symbolName: "leaf.fill"
        ),
        .init(
            id: "tale.kolobok",
            category: .fairyTale,
            titleKey: "cultural.tale.kolobok.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 240,
            targetSounds: ["К", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Жили-были старик со старухой."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Испекла старуха колобок."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Покатился колобок по дорожке."),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Я колобок, колобок, я от бабушки ушёл!")
            ],
            symbolName: "circle.fill"
        ),
        .init(
            id: "tale.kurochka",
            category: .fairyTale,
            titleKey: "cultural.tale.kurochka.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 120,
            targetSounds: ["К", "Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "Жила-была курочка Ряба."),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 12,
                             text: "Снесла курочка яичко — не простое, а золотое."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 20,
                             text: "Дед бил-бил — не разбил. Баба била-била — не разбила."),
                CulturalLine(id: 3, startSeconds: 20, endSeconds: 28,
                             text: "Мышка бежала, хвостиком махнула — яичко упало и разбилось.")
            ],
            symbolName: "bird.fill"
        ),
        .init(
            id: "tale.teremok",
            category: .fairyTale,
            titleKey: "cultural.tale.teremok.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 200,
            targetSounds: ["Т", "Р", "М"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Стоит в поле теремок, теремок."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 14,
                             text: "Прибежала мышка-норушка. — Кто-кто в теремочке живёт?"),
                CulturalLine(id: 2, startSeconds: 14, endSeconds: 22,
                             text: "Прискакала лягушка-квакушка. — Я, мышка-норушка!"),
                CulturalLine(id: 3, startSeconds: 22, endSeconds: 30,
                             text: "Стали они жить-поживать да добра наживать.")
            ],
            symbolName: "house.fill"
        ),
        .init(
            id: "tale.zayushkina",
            category: .fairyTale,
            titleKey: "cultural.tale.zayushkina.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 160,
            targetSounds: ["З", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 7,
                             text: "Жили-были лиса да заяц."),
                CulturalLine(id: 1, startSeconds: 7,  endSeconds: 15,
                             text: "У лисы была избушка ледяная, а у зайца — лубяная."),
                CulturalLine(id: 2, startSeconds: 15, endSeconds: 22,
                             text: "Пришла весна — у лисы избушка растаяла."),
                CulturalLine(id: 3, startSeconds: 22, endSeconds: 30,
                             text: "Выгнала лиса зайчика из его избушки.")
            ],
            symbolName: "snowflake"
        ),
        .init(
            id: "tale.masha",
            category: .fairyTale,
            titleKey: "cultural.tale.masha.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 180,
            targetSounds: ["М", "Ш"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Машенька пошла в лес за грибами."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 14,
                             text: "Заблудилась и нашла избушку."),
                CulturalLine(id: 2, startSeconds: 14, endSeconds: 22,
                             text: "В избушке жили три медведя: Михайло Иванович, Настасья Петровна и Мишутка."),
                CulturalLine(id: 3, startSeconds: 22, endSeconds: 30,
                             text: "Машенька попробовала кашу и легла спать в маленькую кроватку.")
            ],
            symbolName: "pawprint.fill"
        ),
        .init(
            id: "tale.turnip.song",
            category: .fairyTale,
            titleKey: "cultural.tale.turnip.song.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 90,
            targetSounds: ["Р", "Д", "Б"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 8,
                             text: "Дёрни, дёрни, дедка репку — никак."),
                CulturalLine(id: 1, startSeconds: 8,  endSeconds: 16,
                             text: "Позвал дедка бабку — бабка за дедку, дедка за репку."),
                CulturalLine(id: 2, startSeconds: 16, endSeconds: 24,
                             text: "Тянут-потянут — вытянули репку!"),
                CulturalLine(id: 3, startSeconds: 24, endSeconds: 30,
                             text: "Вот и сказочке конец, а кто слушал — молодец!")
            ],
            symbolName: "star.fill"
        ),
        .init(
            id: "tale.snegurochka",
            category: .fairyTale,
            titleKey: "cultural.tale.snegurochka.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 150,
            targetSounds: ["С", "Н", "Г"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 7,
                             text: "Слепили дед и баба Снегурочку из снега."),
                CulturalLine(id: 1, startSeconds: 7,  endSeconds: 15,
                             text: "Стала Снегурочка живой — улыбается, говорит."),
                CulturalLine(id: 2, startSeconds: 15, endSeconds: 22,
                             text: "Играла Снегурочка с подружками, прыгала через костёр."),
                CulturalLine(id: 3, startSeconds: 22, endSeconds: 30,
                             text: "Прыгнула — и растаяла облачком.")
            ],
            symbolName: "snowflake"
        )
    ]

    // MARK: — Песенки и колыбельные (song)

    static let songs: [CulturalItem] = [
        .init(
            id: "song.elka",
            category: .song,
            titleKey: "cultural.song.elka.title",
            authorKey: "cultural.song.elka.author",
            durationSeconds: 90,
            targetSounds: ["Л", "С"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "В лесу родилась ёлочка,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "В лесу она росла."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Зимой и летом стройная,"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Зелёная была.")
            ],
            symbolName: "tree.fill"
        ),
        .init(
            id: "song.lullaby.bayu",
            category: .song,
            titleKey: "cultural.song.lullaby.bayu.title",
            authorKey: "cultural.song.folk.author",
            durationSeconds: 60,
            targetSounds: ["Б", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 7,
                             text: "Баю-баю-баю-бай,"),
                CulturalLine(id: 1, startSeconds: 7,  endSeconds: 14,
                             text: "Ты, собачка, не лай."),
                CulturalLine(id: 2, startSeconds: 14, endSeconds: 21,
                             text: "Белолапая, не лай,"),
                CulturalLine(id: 3, startSeconds: 21, endSeconds: 28,
                             text: "Мою детку не пугай.")
            ],
            symbolName: "moon.fill"
        ),
        .init(
            id: "song.lullaby.spi",
            category: .song,
            titleKey: "cultural.song.lullaby.spi.title",
            authorKey: "cultural.song.folk.author",
            durationSeconds: 70,
            targetSounds: ["С", "П"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 7,
                             text: "Спи, малютка, почивай,"),
                CulturalLine(id: 1, startSeconds: 7,  endSeconds: 14,
                             text: "Тихий сон не прерывай."),
                CulturalLine(id: 2, startSeconds: 14, endSeconds: 21,
                             text: "Завтра встанешь поутру,"),
                CulturalLine(id: 3, startSeconds: 21, endSeconds: 28,
                             text: "Выйдешь ты опять в игру.")
            ],
            symbolName: "moon.stars.fill"
        ),
        .init(
            id: "song.lullaby.kotik",
            category: .song,
            titleKey: "cultural.song.lullaby.kotik.title",
            authorKey: "cultural.song.folk.author",
            durationSeconds: 65,
            targetSounds: ["К", "Т"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 7,
                             text: "Котик серенький присел"),
                CulturalLine(id: 1, startSeconds: 7,  endSeconds: 14,
                             text: "На краёчку и запел."),
                CulturalLine(id: 2, startSeconds: 14, endSeconds: 21,
                             text: "Баю-баю, баю-бай,"),
                CulturalLine(id: 3, startSeconds: 21, endSeconds: 28,
                             text: "Поскорее засыпай.")
            ],
            symbolName: "moon.fill"
        ),
        .init(
            id: "song.ladushki",
            category: .song,
            titleKey: "cultural.song.ladushki.title",
            authorKey: "cultural.song.folk.author",
            durationSeconds: 50,
            targetSounds: ["Л", "Д"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Ладушки, ладушки!"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Где были? — У бабушки."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Что ели? — Кашку."),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Что пили? — Бражку.")
            ],
            symbolName: "hands.clap.fill"
        ),
        .init(
            id: "song.kalinkas",
            category: .song,
            titleKey: "cultural.song.kalinka.title",
            authorKey: "cultural.song.folk.author",
            durationSeconds: 75,
            targetSounds: ["К", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 7,
                             text: "Калинка, калинка, калинка моя!"),
                CulturalLine(id: 1, startSeconds: 7,  endSeconds: 14,
                             text: "В саду ягода-малинка, малинка моя!"),
                CulturalLine(id: 2, startSeconds: 14, endSeconds: 21,
                             text: "Ах! Под сосною, под зелёною"),
                CulturalLine(id: 3, startSeconds: 21, endSeconds: 28,
                             text: "Спать положите вы меня.")
            ],
            symbolName: "leaf.fill"
        )
    ]

    // MARK: — Стихи, потешки, считалки, загадки (poem)

    static let poems: [CulturalItem] = [
        // Стихи классиков
        .init(
            id: "poem.barto.bear",
            category: .poem,
            titleKey: "cultural.poem.barto.bear.title",
            authorKey: "cultural.poem.barto.author",
            durationSeconds: 30,
            targetSounds: ["Ш", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 4,
                             text: "Уронили мишку на пол,"),
                CulturalLine(id: 1, startSeconds: 4,  endSeconds: 8,
                             text: "Оторвали мишке лапу."),
                CulturalLine(id: 2, startSeconds: 8,  endSeconds: 12,
                             text: "Всё равно его не брошу,"),
                CulturalLine(id: 3, startSeconds: 12, endSeconds: 16,
                             text: "Потому что он хороший.")
            ],
            symbolName: "quote.opening"
        ),
        .init(
            id: "poem.barto.bull",
            category: .poem,
            titleKey: "cultural.poem.barto.bull.title",
            authorKey: "cultural.poem.barto.author",
            durationSeconds: 28,
            targetSounds: ["Б", "Ш"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "Идёт бычок, качается,"),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 10,
                             text: "Вздыхает на ходу:"),
                CulturalLine(id: 2, startSeconds: 10, endSeconds: 15,
                             text: "Ох, доска кончается,"),
                CulturalLine(id: 3, startSeconds: 15, endSeconds: 20,
                             text: "Сейчас я упаду!")
            ],
            symbolName: "quote.opening"
        ),
        .init(
            id: "poem.barto.bunny",
            category: .poem,
            titleKey: "cultural.poem.barto.bunny.title",
            authorKey: "cultural.poem.barto.author",
            durationSeconds: 28,
            targetSounds: ["З", "Й"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "Зайку бросила хозяйка —"),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 10,
                             text: "Под дождём остался зайка."),
                CulturalLine(id: 2, startSeconds: 10, endSeconds: 15,
                             text: "Со скамейки слезть не смог,"),
                CulturalLine(id: 3, startSeconds: 15, endSeconds: 20,
                             text: "Весь до ниточки промок.")
            ],
            symbolName: "quote.opening"
        ),
        .init(
            id: "poem.chuk.muha",
            category: .poem,
            titleKey: "cultural.poem.chuk.muha.title",
            authorKey: "cultural.poem.chuk.author",
            durationSeconds: 60,
            targetSounds: ["Х", "Ц"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 4,
                             text: "Муха, муха, цокотуха,"),
                CulturalLine(id: 1, startSeconds: 4,  endSeconds: 8,
                             text: "Позолоченное брюхо."),
                CulturalLine(id: 2, startSeconds: 8,  endSeconds: 12,
                             text: "Муха по полю пошла,"),
                CulturalLine(id: 3, startSeconds: 12, endSeconds: 16,
                             text: "Муха денежку нашла.")
            ],
            symbolName: "ant.fill"
        ),
        .init(
            id: "poem.marsh.washtub",
            category: .poem,
            titleKey: "cultural.poem.marsh.washtub.title",
            authorKey: "cultural.poem.marsh.author",
            durationSeconds: 45,
            targetSounds: ["Р", "М"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "Мойдодыр!"),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 12,
                             text: "Ты не мытый! — закричал он."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 19,
                             text: "Умывайся поскорей,"),
                CulturalLine(id: 3, startSeconds: 19, endSeconds: 26,
                             text: "Воду лей, не жалей!")
            ],
            symbolName: "drop.fill"
        ),
        // Потешки
        .init(
            id: "poem.potesh.petushok",
            category: .poem,
            titleKey: "cultural.poem.potesh.petushok.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 35,
            targetSounds: ["П", "К"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Петушок, петушок,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Золотой гребешок,"),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Масляна головушка,"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Шёлкова бородушка,"),
                CulturalLine(id: 4, startSeconds: 24, endSeconds: 30,
                             text: "Что ты рано встаёшь, голосисто поёшь?")
            ],
            symbolName: "bird.fill"
        ),
        .init(
            id: "poem.potesh.soroka",
            category: .poem,
            titleKey: "cultural.poem.potesh.soroka.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 40,
            targetSounds: ["С", "Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Сорока-ворона кашку варила,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Деток кормила."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Этому дала, этому дала,"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Этому дала, этому дала,"),
                CulturalLine(id: 4, startSeconds: 24, endSeconds: 30,
                             text: "А этому — не дала!")
            ],
            symbolName: "bird.2.fill"
        ),
        .init(
            id: "poem.potesh.vodichka",
            category: .poem,
            titleKey: "cultural.poem.potesh.vodichka.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 30,
            targetSounds: ["В", "Д"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Водичка, водичка,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Умой моё личико,"),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Чтобы глазоньки блестели,"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Чтобы щёчки краснели.")
            ],
            symbolName: "drop.fill"
        ),
        .init(
            id: "poem.potesh.solnyshko",
            category: .poem,
            titleKey: "cultural.poem.potesh.solnyshko.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 28,
            targetSounds: ["С", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Солнышко-вёдрышко,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Выгляни в окошечко!"),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Твои детки плачут,"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "По камушкам скачут.")
            ],
            symbolName: "sun.max.fill"
        ),
        .init(
            id: "poem.potesh.kotausya",
            category: .poem,
            titleKey: "cultural.poem.potesh.kotausya.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 32,
            targetSounds: ["К", "Т"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Кот-кот-котик, котик мой,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Серый маленький, больной."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Заболела у кота"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Маленькая лапота.")
            ],
            symbolName: "pawprint.fill"
        ),
        .init(
            id: "poem.potesh.dojdik",
            category: .poem,
            titleKey: "cultural.poem.potesh.dojdik.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 28,
            targetSounds: ["Д", "Ж"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Дождик, дождик, пуще,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Дам тебе я гущи."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Дождик, дождик, посильней,"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Огород наш полирей!")
            ],
            symbolName: "cloud.rain.fill"
        ),
        // Считалки
        .init(
            id: "poem.schit.raztri",
            category: .poem,
            titleKey: "cultural.poem.schit.raztri.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 20,
            targetSounds: ["Р", "С"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "Раз, два, три, четыре, пять,"),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 10,
                             text: "Вышел зайчик погулять."),
                CulturalLine(id: 2, startSeconds: 10, endSeconds: 15,
                             text: "Вдруг охотник выбегает,"),
                CulturalLine(id: 3, startSeconds: 15, endSeconds: 20,
                             text: "Прямо в зайчика стреляет!")
            ],
            symbolName: "number.circle.fill"
        ),
        .init(
            id: "poem.schit.ene",
            category: .poem,
            titleKey: "cultural.poem.schit.ene.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 18,
            targetSounds: ["Н", "Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "Эни-бени, рики-факи,"),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 10,
                             text: "Турба-урба, синтибряки,"),
                CulturalLine(id: 2, startSeconds: 10, endSeconds: 15,
                             text: "Эус, деус, красатеус,"),
                CulturalLine(id: 3, startSeconds: 15, endSeconds: 18,
                             text: "Бац!")
            ],
            symbolName: "number.circle.fill"
        ),
        .init(
            id: "poem.schit.zazhumurki",
            category: .poem,
            titleKey: "cultural.poem.schit.zazhumurki.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 20,
            targetSounds: ["З", "Ж"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "Горшок, горшочек, золотой бочок,"),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 10,
                             text: "Выйди погулять на часок."),
                CulturalLine(id: 2, startSeconds: 10, endSeconds: 15,
                             text: "Раз, два, три — беги!"),
                CulturalLine(id: 3, startSeconds: 15, endSeconds: 20,
                             text: "Не зевай, убегай!")
            ],
            symbolName: "number.circle.fill"
        ),
        .init(
            id: "poem.schit.kto",
            category: .poem,
            titleKey: "cultural.poem.schit.kto.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 20,
            targetSounds: ["К", "Т"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 5,
                             text: "На золотом крыльце сидели"),
                CulturalLine(id: 1, startSeconds: 5,  endSeconds: 10,
                             text: "Царь, царевич, король, королевич,"),
                CulturalLine(id: 2, startSeconds: 10, endSeconds: 15,
                             text: "Сапожник, портной."),
                CulturalLine(id: 3, startSeconds: 15, endSeconds: 20,
                             text: "Кто ты будешь такой?")
            ],
            symbolName: "crown.fill"
        ),
        // Загадки
        .init(
            id: "poem.riddle.koshka",
            category: .poem,
            titleKey: "cultural.poem.riddle.koshka.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 25,
            targetSounds: ["К", "Ш"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Мягкие лапки,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "А в лапках царапки."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Днём спит,"),
                CulturalLine(id: 3, startSeconds: 18, endSeconds: 24,
                             text: "Ночью гуляет. (Кошка)")
            ],
            symbolName: "questionmark.circle.fill"
        ),
        .init(
            id: "poem.riddle.yolka",
            category: .poem,
            titleKey: "cultural.poem.riddle.yolka.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 25,
            targetSounds: ["З", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Зимой и летом"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Одним цветом."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Что это? (Ёлка)")
            ],
            symbolName: "questionmark.circle.fill"
        ),
        .init(
            id: "poem.riddle.sneg",
            category: .poem,
            titleKey: "cultural.poem.riddle.sneg.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 25,
            targetSounds: ["С", "Н"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Белый, белый, белый снег —"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Всё закрыл за один миг."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Пришла весна — и нет его. (Снег)")
            ],
            symbolName: "questionmark.circle.fill"
        ),
        .init(
            id: "poem.riddle.med",
            category: .poem,
            titleKey: "cultural.poem.riddle.med.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 22,
            targetSounds: ["М", "Д"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "В лесу живёт косолапый,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Мёд любит, лапу сосёт."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Кто это? (Медведь)")
            ],
            symbolName: "questionmark.circle.fill"
        ),
        .init(
            id: "poem.riddle.solnce",
            category: .poem,
            titleKey: "cultural.poem.riddle.solnce.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 24,
            targetSounds: ["С", "Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Утром встаю, всех согреваю,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Ввечеру за горку прячусь."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Что это? (Солнце)")
            ],
            symbolName: "questionmark.circle.fill"
        ),
        .init(
            id: "poem.riddle.ryba",
            category: .poem,
            titleKey: "cultural.poem.riddle.ryba.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 24,
            targetSounds: ["Р", "Б"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Не говорит, не поёт,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "А рот открывает."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Живёт в воде и плавает. (Рыба)")
            ],
            symbolName: "questionmark.circle.fill"
        ),
        .init(
            id: "poem.riddle.yabloko",
            category: .poem,
            titleKey: "cultural.poem.riddle.yabloko.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 22,
            targetSounds: ["Б", "К"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Круглое, румяное,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "С дерева упало,"),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "На земле лежало. (Яблоко)")
            ],
            symbolName: "questionmark.circle.fill"
        ),
        .init(
            id: "poem.riddle.grib",
            category: .poem,
            titleKey: "cultural.poem.riddle.grib.title",
            authorKey: "cultural.tale.folk.author",
            durationSeconds: 22,
            targetSounds: ["Г", "Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "В лесу вырос, шапку надел,"),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "В корзинку просится."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Что это? (Гриб)")
            ],
            symbolName: "questionmark.circle.fill"
        )
    ]

    // MARK: — Скороговорки и чистоговорки (tongueTwister)

    static let tongueTwisters: [CulturalItem] = [
        // Скороговорки
        .init(
            id: "twist.shasha",
            category: .tongueTwister,
            titleKey: "cultural.twist.shasha.title",
            authorKey: nil,
            durationSeconds: 12,
            targetSounds: ["Ш", "С"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 12,
                             text: "Шла Саша по шоссе и сосала сушку.")
            ],
            symbolName: "tongue"
        ),
        .init(
            id: "twist.bobry",
            category: .tongueTwister,
            titleKey: "cultural.twist.bobry.title",
            authorKey: nil,
            durationSeconds: 10,
            targetSounds: ["Б", "Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 10,
                             text: "Бобры идут в боры, бобры добры.")
            ],
            symbolName: "leaf.fill"
        ),
        .init(
            id: "twist.greka",
            category: .tongueTwister,
            titleKey: "cultural.twist.greka.title",
            authorKey: nil,
            durationSeconds: 14,
            targetSounds: ["Р", "К"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 7,
                             text: "Ехал Грека через реку,"),
                CulturalLine(id: 1, startSeconds: 7, endSeconds: 14,
                             text: "Видит Грека — в реке рак.")
            ],
            symbolName: "water.waves"
        ),
        .init(
            id: "twist.korol",
            category: .tongueTwister,
            titleKey: "cultural.twist.korol.title",
            authorKey: nil,
            durationSeconds: 14,
            targetSounds: ["Р", "К"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 7,
                             text: "Карл у Клары украл кораллы,"),
                CulturalLine(id: 1, startSeconds: 7, endSeconds: 14,
                             text: "Клара у Карла украла кларнет.")
            ],
            symbolName: "music.note"
        ),
        .init(
            id: "twist.prokofy",
            category: .tongueTwister,
            titleKey: "cultural.twist.prokofy.title",
            authorKey: nil,
            durationSeconds: 16,
            targetSounds: ["П", "Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 8,
                             text: "Проворонила ворона воронёнка."),
                CulturalLine(id: 1, startSeconds: 8, endSeconds: 16,
                             text: "Воронёнок — вороньего племени.")
            ],
            symbolName: "bird.fill"
        ),
        .init(
            id: "twist.sasha",
            category: .tongueTwister,
            titleKey: "cultural.twist.sasha2.title",
            authorKey: nil,
            durationSeconds: 12,
            targetSounds: ["С"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 12,
                             text: "У Сени и Сани в сетях сом с усами.")
            ],
            symbolName: "water.waves"
        ),
        .init(
            id: "twist.zhuzha",
            category: .tongueTwister,
            titleKey: "cultural.twist.zhuzha.title",
            authorKey: nil,
            durationSeconds: 12,
            targetSounds: ["Ж"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 12,
                             text: "Жук жужжит, жужжит, жужжит.")
            ],
            symbolName: "ant.fill"
        ),
        .init(
            id: "twist.chashka",
            category: .tongueTwister,
            titleKey: "cultural.twist.chashka.title",
            authorKey: nil,
            durationSeconds: 12,
            targetSounds: ["Ч", "Щ"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 12,
                             text: "Четыре чёрненьких чумазеньких чертёнка чертили чёрными чернилами чертёж.")
            ],
            symbolName: "pencil"
        ),
        .init(
            id: "twist.shorstka",
            category: .tongueTwister,
            titleKey: "cultural.twist.shorstka.title",
            authorKey: nil,
            durationSeconds: 12,
            targetSounds: ["Ш"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 12,
                             text: "Шёрстка у кошки, шишки у кошки.")
            ],
            symbolName: "pawprint.fill"
        ),
        .init(
            id: "twist.lakomka",
            category: .tongueTwister,
            titleKey: "cultural.twist.lakomka.title",
            authorKey: nil,
            durationSeconds: 14,
            targetSounds: ["Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0, endSeconds: 7,
                             text: "Лара у Вали играла на рояле."),
                CulturalLine(id: 1, startSeconds: 7, endSeconds: 14,
                             text: "Валя лежала, лира лежала.")
            ],
            symbolName: "music.note"
        ),
        // Чистоговорки
        .init(
            id: "clean.sa",
            category: .tongueTwister,
            titleKey: "cultural.clean.sa.title",
            authorKey: "cultural.clean.author",
            durationSeconds: 18,
            targetSounds: ["С"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Са-са-са — вот летит оса."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Со-со-со — катится колесо."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Су-су-су — ягоды в лесу.")
            ],
            symbolName: "waveform"
        ),
        .init(
            id: "clean.sha",
            category: .tongueTwister,
            titleKey: "cultural.clean.sha.title",
            authorKey: "cultural.clean.author",
            durationSeconds: 18,
            targetSounds: ["Ш"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Ша-ша-ша — наша каша хороша."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Шо-шо-шо — говорю тихошо."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Ши-ши-ши — тихо ты дыши.")
            ],
            symbolName: "waveform"
        ),
        .init(
            id: "clean.ra",
            category: .tongueTwister,
            titleKey: "cultural.clean.ra.title",
            authorKey: "cultural.clean.author",
            durationSeconds: 18,
            targetSounds: ["Р"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Ра-ра-ра — высокая гора."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Ро-ро-ро — новое перо."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Ру-ру-ру — начинаю я игру.")
            ],
            symbolName: "waveform"
        ),
        .init(
            id: "clean.la",
            category: .tongueTwister,
            titleKey: "cultural.clean.la.title",
            authorKey: "cultural.clean.author",
            durationSeconds: 18,
            targetSounds: ["Л"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Ла-ла-ла — Мила пол мела."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Ло-ло-ло — на дворе тепло."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Лу-лу-лу — стул стоит в углу.")
            ],
            symbolName: "waveform"
        ),
        .init(
            id: "clean.za",
            category: .tongueTwister,
            titleKey: "cultural.clean.za.title",
            authorKey: "cultural.clean.author",
            durationSeconds: 18,
            targetSounds: ["З"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "За-за-за — вот бежит коза."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Зо-зо-зо — вот катится зонт."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Зу-зу-зу — покормлю козу.")
            ],
            symbolName: "waveform"
        ),
        .init(
            id: "clean.zha",
            category: .tongueTwister,
            titleKey: "cultural.clean.zha.title",
            authorKey: "cultural.clean.author",
            durationSeconds: 18,
            targetSounds: ["Ж"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Жа-жа-жа — есть иголки у ежа."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Жо-жо-жо — осторожно, осторожно."),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Жу-жу-жу — молочко вожу.")
            ],
            symbolName: "waveform"
        ),
        .init(
            id: "clean.cha",
            category: .tongueTwister,
            titleKey: "cultural.clean.cha.title",
            authorKey: "cultural.clean.author",
            durationSeconds: 18,
            targetSounds: ["Ч"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 6,
                             text: "Ча-ча-ча — горит в комнате свеча."),
                CulturalLine(id: 1, startSeconds: 6,  endSeconds: 12,
                             text: "Чо-чо-чо — ах, как горячо!"),
                CulturalLine(id: 2, startSeconds: 12, endSeconds: 18,
                             text: "Чу-чу-чу — я на поезде качу.")
            ],
            symbolName: "waveform"
        ),
        .init(
            id: "clean.shcha",
            category: .tongueTwister,
            titleKey: "cultural.clean.shcha.title",
            authorKey: "cultural.clean.author",
            durationSeconds: 16,
            targetSounds: ["Щ"],
            lines: [
                CulturalLine(id: 0, startSeconds: 0,  endSeconds: 8,
                             text: "Щи да каша — пища наша."),
                CulturalLine(id: 1, startSeconds: 8,  endSeconds: 16,
                             text: "Наша Маша ест щи — хороша!")
            ],
            symbolName: "waveform"
        )
    ]

    // MARK: — Собранный каталог

    // Собирает все под-массивы в единый каталог для Interactor.
    //
    // Базовый статический набор (сказки/песни/стихи/скороговорки) дополняется
    // элементами из бандл-пака `pack_cultural.json` (фольклор и чистоговорки
    // от методиста, gap #7) через `CulturalContentPackLoader`. Идентификаторы
    // пака изолированы префиксом `cult.` и не пересекаются со статическими.
    static let catalog: [CulturalItem] = {
        let base = fairyTales + songs + poems + tongueTwisters
        let existingIDs = Set(base.map(\.id))
        let packItems = CulturalContentPackLoader.shared.items
            .filter { !existingIDs.contains($0.id) }
        return base + packItems
    }()
}
