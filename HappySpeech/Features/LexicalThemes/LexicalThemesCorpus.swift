import Foundation

// MARK: - LexicalThemesCorpus
//
// v29 Фаза 8, Функция 7 «Мир слов».
//
// Стартовый корпус лексических тем — 12 тем по ~10 слов (≈120 единиц).
// Каждое слово размечено существительным, типичным действием («что делает?»)
// и признаком («какой?») — предметный, глагольный и признаковый словарь
// (Филичёва, Чиркина: коррекция ОНР по лексическим темам).
//
// Корпус — представительный стартовый набор; может быть расширен до ~700
// единиц / 15–18 тем командой speech-content-curator. Полностью offline.

enum LexicalThemesCorpus {

    /// Сколько раундов в одной сессии темы (8–12 мин, антифатиговое правило).
    static let roundsPerSession = 8

    // MARK: - Themes

    static let themes: [LexicalTheme] = [
        vegetables, fruits, wildAnimals, petAnimals, transport,
        family, seasons, clothes, furniture, professions,
        birds, toys
    ]

    // MARK: Овощи

    static let vegetables = LexicalTheme(
        id: "vegetables", title: "Овощи", generalization: "овощи",
        symbolName: "carrot.fill",
        words: [
            .init(id: "veg-1", text: "морковь", action: "растёт", attribute: "оранжевая"),
            .init(id: "veg-2", text: "капуста", action: "хрустит", attribute: "хрустящая"),
            .init(id: "veg-3", text: "помидор", action: "краснеет", attribute: "красный"),
            .init(id: "veg-4", text: "огурец", action: "зеленеет", attribute: "зелёный"),
            .init(id: "veg-5", text: "картофель", action: "варится", attribute: "рассыпчатый"),
            .init(id: "veg-6", text: "лук", action: "горчит", attribute: "горький"),
            .init(id: "veg-7", text: "свёкла", action: "красится", attribute: "бордовая"),
            .init(id: "veg-8", text: "тыква", action: "зреет", attribute: "большая"),
            .init(id: "veg-9", text: "горох", action: "сыплется", attribute: "круглый"),
            .init(id: "veg-10", text: "перец", action: "блестит", attribute: "сладкий")
        ]
    )

    // MARK: Фрукты

    static let fruits = LexicalTheme(
        id: "fruits", title: "Фрукты", generalization: "фрукты",
        symbolName: "applelogo",
        words: [
            .init(id: "fru-1", text: "яблоко", action: "падает", attribute: "сочное"),
            .init(id: "fru-2", text: "груша", action: "висит", attribute: "сладкая"),
            .init(id: "fru-3", text: "банан", action: "желтеет", attribute: "жёлтый"),
            .init(id: "fru-4", text: "апельсин", action: "пахнет", attribute: "ароматный"),
            .init(id: "fru-5", text: "слива", action: "зреет", attribute: "синяя"),
            .init(id: "fru-6", text: "лимон", action: "кислит", attribute: "кислый"),
            .init(id: "fru-7", text: "виноград", action: "наливается", attribute: "сладкий"),
            .init(id: "fru-8", text: "персик", action: "румянится", attribute: "мягкий"),
            .init(id: "fru-9", text: "вишня", action: "краснеет", attribute: "красная"),
            .init(id: "fru-10", text: "абрикос", action: "сохнет", attribute: "оранжевый")
        ]
    )

    // MARK: Дикие животные

    static let wildAnimals = LexicalTheme(
        id: "wild-animals", title: "Дикие животные", generalization: "дикие животные",
        symbolName: "pawprint.fill",
        words: [
            .init(id: "wld-1", text: "медведь", action: "ревёт", attribute: "косолапый"),
            .init(id: "wld-2", text: "лиса", action: "крадётся", attribute: "хитрая"),
            .init(id: "wld-3", text: "волк", action: "воет", attribute: "серый"),
            .init(id: "wld-4", text: "заяц", action: "прыгает", attribute: "трусливый"),
            .init(id: "wld-5", text: "ёж", action: "фыркает", attribute: "колючий"),
            .init(id: "wld-6", text: "белка", action: "скачет", attribute: "рыжая"),
            .init(id: "wld-7", text: "лось", action: "пасётся", attribute: "рогатый"),
            .init(id: "wld-8", text: "кабан", action: "роет", attribute: "клыкастый"),
            .init(id: "wld-9", text: "барсук", action: "копает", attribute: "полосатый"),
            .init(id: "wld-10", text: "олень", action: "бежит", attribute: "быстрый")
        ]
    )

    // MARK: Домашние животные

    static let petAnimals = LexicalTheme(
        id: "pet-animals", title: "Домашние животные", generalization: "домашние животные",
        symbolName: "cat.fill",
        words: [
            .init(id: "pet-1", text: "кошка", action: "мурлычет", attribute: "пушистая"),
            .init(id: "pet-2", text: "собака", action: "лает", attribute: "верная"),
            .init(id: "pet-3", text: "корова", action: "мычит", attribute: "рогатая"),
            .init(id: "pet-4", text: "лошадь", action: "скачет", attribute: "быстрая"),
            .init(id: "pet-5", text: "коза", action: "блеет", attribute: "бородатая"),
            .init(id: "pet-6", text: "овца", action: "пасётся", attribute: "кудрявая"),
            .init(id: "pet-7", text: "свинья", action: "хрюкает", attribute: "розовая"),
            .init(id: "pet-8", text: "кролик", action: "грызёт", attribute: "ушастый"),
            .init(id: "pet-9", text: "баран", action: "бодается", attribute: "упрямый"),
            .init(id: "pet-10", text: "телёнок", action: "сосёт", attribute: "маленький")
        ]
    )

    // MARK: Транспорт

    static let transport = LexicalTheme(
        id: "transport", title: "Транспорт", generalization: "транспорт",
        symbolName: "car.fill",
        words: [
            .init(id: "trn-1", text: "машина", action: "едет", attribute: "быстрая"),
            .init(id: "trn-2", text: "автобус", action: "везёт", attribute: "большой"),
            .init(id: "trn-3", text: "поезд", action: "мчится", attribute: "длинный"),
            .init(id: "trn-4", text: "самолёт", action: "летит", attribute: "крылатый"),
            .init(id: "trn-5", text: "корабль", action: "плывёт", attribute: "огромный"),
            .init(id: "trn-6", text: "велосипед", action: "катится", attribute: "лёгкий"),
            .init(id: "trn-7", text: "трамвай", action: "звенит", attribute: "рельсовый"),
            .init(id: "trn-8", text: "лодка", action: "качается", attribute: "деревянная"),
            .init(id: "trn-9", text: "вертолёт", action: "зависает", attribute: "винтовой"),
            .init(id: "trn-10", text: "грузовик", action: "гудит", attribute: "тяжёлый")
        ]
    )

    // MARK: Семья

    static let family = LexicalTheme(
        id: "family", title: "Семья", generalization: "семья",
        symbolName: "figure.2.and.child.holdinghands",
        words: [
            .init(id: "fam-1", text: "мама", action: "заботится", attribute: "ласковая"),
            .init(id: "fam-2", text: "папа", action: "работает", attribute: "сильный"),
            .init(id: "fam-3", text: "бабушка", action: "вяжет", attribute: "добрая"),
            .init(id: "fam-4", text: "дедушка", action: "читает", attribute: "мудрый"),
            .init(id: "fam-5", text: "сестра", action: "помогает", attribute: "старшая"),
            .init(id: "fam-6", text: "брат", action: "играет", attribute: "младший"),
            .init(id: "fam-7", text: "дочка", action: "рисует", attribute: "весёлая"),
            .init(id: "fam-8", text: "сын", action: "строит", attribute: "ловкий"),
            .init(id: "fam-9", text: "внук", action: "бегает", attribute: "шустрый"),
            .init(id: "fam-10", text: "тётя", action: "печёт", attribute: "приветливая")
        ]
    )

    // MARK: Времена года

    static let seasons = LexicalTheme(
        id: "seasons", title: "Времена года", generalization: "времена года",
        symbolName: "sun.max.fill",
        words: [
            .init(id: "sea-1", text: "зима", action: "морозит", attribute: "снежная"),
            .init(id: "sea-2", text: "весна", action: "тает", attribute: "тёплая"),
            .init(id: "sea-3", text: "лето", action: "греет", attribute: "жаркое"),
            .init(id: "sea-4", text: "осень", action: "желтеет", attribute: "дождливая"),
            .init(id: "sea-5", text: "снег", action: "падает", attribute: "белый"),
            .init(id: "sea-6", text: "дождь", action: "капает", attribute: "холодный"),
            .init(id: "sea-7", text: "солнце", action: "светит", attribute: "яркое"),
            .init(id: "sea-8", text: "лёд", action: "блестит", attribute: "скользкий"),
            .init(id: "sea-9", text: "ветер", action: "дует", attribute: "сильный"),
            .init(id: "sea-10", text: "листопад", action: "кружит", attribute: "золотой")
        ]
    )

    // MARK: Одежда

    static let clothes = LexicalTheme(
        id: "clothes", title: "Одежда", generalization: "одежда",
        symbolName: "tshirt.fill",
        words: [
            .init(id: "clo-1", text: "куртка", action: "греет", attribute: "тёплая"),
            .init(id: "clo-2", text: "шапка", action: "сидит", attribute: "вязаная"),
            .init(id: "clo-3", text: "шарф", action: "обнимает", attribute: "длинный"),
            .init(id: "clo-4", text: "платье", action: "развевается", attribute: "нарядное"),
            .init(id: "clo-5", text: "рубашка", action: "висит", attribute: "белая"),
            .init(id: "clo-6", text: "брюки", action: "мнутся", attribute: "удобные"),
            .init(id: "clo-7", text: "варежки", action: "согревают", attribute: "пушистые"),
            .init(id: "clo-8", text: "носки", action: "стираются", attribute: "мягкие"),
            .init(id: "clo-9", text: "пальто", action: "застёгивается", attribute: "длинное"),
            .init(id: "clo-10", text: "свитер", action: "колется", attribute: "шерстяной")
        ]
    )

    // MARK: Мебель

    static let furniture = LexicalTheme(
        id: "furniture", title: "Мебель", generalization: "мебель",
        symbolName: "bed.double.fill",
        words: [
            .init(id: "fur-1", text: "стол", action: "стоит", attribute: "деревянный"),
            .init(id: "fur-2", text: "стул", action: "скрипит", attribute: "крепкий"),
            .init(id: "fur-3", text: "кровать", action: "ждёт", attribute: "мягкая"),
            .init(id: "fur-4", text: "шкаф", action: "вмещает", attribute: "большой"),
            .init(id: "fur-5", text: "диван", action: "пружинит", attribute: "уютный"),
            .init(id: "fur-6", text: "полка", action: "держит", attribute: "узкая"),
            .init(id: "fur-7", text: "кресло", action: "качается", attribute: "удобное"),
            .init(id: "fur-8", text: "тумбочка", action: "хранит", attribute: "маленькая"),
            .init(id: "fur-9", text: "комод", action: "выдвигается", attribute: "тяжёлый"),
            .init(id: "fur-10", text: "табурет", action: "переносится", attribute: "лёгкий")
        ]
    )

    // MARK: Профессии

    static let professions = LexicalTheme(
        id: "professions", title: "Профессии", generalization: "профессии",
        symbolName: "person.badge.shield.checkmark.fill",
        words: [
            .init(id: "pro-1", text: "врач", action: "лечит", attribute: "внимательный"),
            .init(id: "pro-2", text: "повар", action: "готовит", attribute: "умелый"),
            .init(id: "pro-3", text: "учитель", action: "учит", attribute: "терпеливый"),
            .init(id: "pro-4", text: "строитель", action: "строит", attribute: "сильный"),
            .init(id: "pro-5", text: "пожарный", action: "тушит", attribute: "смелый"),
            .init(id: "pro-6", text: "водитель", action: "везёт", attribute: "осторожный"),
            .init(id: "pro-7", text: "художник", action: "рисует", attribute: "творческий"),
            .init(id: "pro-8", text: "садовник", action: "поливает", attribute: "заботливый"),
            .init(id: "pro-9", text: "пекарь", action: "печёт", attribute: "ранний"),
            .init(id: "pro-10", text: "почтальон", action: "разносит", attribute: "быстрый")
        ]
    )

    // MARK: Птицы

    static let birds = LexicalTheme(
        id: "birds", title: "Птицы", generalization: "птицы",
        symbolName: "bird.fill",
        words: [
            .init(id: "brd-1", text: "воробей", action: "чирикает", attribute: "шустрый"),
            .init(id: "brd-2", text: "ворона", action: "каркает", attribute: "чёрная"),
            .init(id: "brd-3", text: "синица", action: "свистит", attribute: "жёлтая"),
            .init(id: "brd-4", text: "голубь", action: "воркует", attribute: "сизый"),
            .init(id: "brd-5", text: "ласточка", action: "вьётся", attribute: "быстрая"),
            .init(id: "brd-6", text: "сова", action: "ухает", attribute: "ночная"),
            .init(id: "brd-7", text: "дятел", action: "стучит", attribute: "пёстрый"),
            .init(id: "brd-8", text: "снегирь", action: "посвистывает", attribute: "красногрудый"),
            .init(id: "brd-9", text: "аист", action: "клекочет", attribute: "длинноногий"),
            .init(id: "brd-10", text: "утка", action: "крякает", attribute: "водоплавающая")
        ]
    )

    // MARK: Игрушки

    static let toys = LexicalTheme(
        id: "toys", title: "Игрушки", generalization: "игрушки",
        symbolName: "teddybear.fill",
        words: [
            .init(id: "toy-1", text: "мяч", action: "прыгает", attribute: "круглый"),
            .init(id: "toy-2", text: "кукла", action: "улыбается", attribute: "нарядная"),
            .init(id: "toy-3", text: "мишка", action: "сидит", attribute: "плюшевый"),
            .init(id: "toy-4", text: "машинка", action: "катается", attribute: "блестящая"),
            .init(id: "toy-5", text: "кубики", action: "падают", attribute: "цветные"),
            .init(id: "toy-6", text: "пирамидка", action: "собирается", attribute: "разноцветная"),
            .init(id: "toy-7", text: "юла", action: "крутится", attribute: "пёстрая"),
            .init(id: "toy-8", text: "скакалка", action: "вертится", attribute: "длинная"),
            .init(id: "toy-9", text: "конструктор", action: "соединяется", attribute: "сборный"),
            .init(id: "toy-10", text: "барабан", action: "гремит", attribute: "звонкий")
        ]
    )

    // MARK: - Queries

    /// Все слова всех тем — для построения дистракторов.
    static var allWords: [LexicalWord] {
        themes.flatMap(\.words)
    }

    /// Тема по идентификатору.
    static func theme(id: String) -> LexicalTheme? {
        themes.first { $0.id == id }
    }

    /// Слова других тем (дистракторы для «четвёртого лишнего» и обобщения).
    static func words(excludingTheme themeId: String) -> [LexicalWord] {
        themes.filter { $0.id != themeId }.flatMap(\.words)
    }

    /// Обобщающие понятия всех тем (дистракторы для игры «обобщение»).
    static var allGeneralizations: [String] {
        themes.map(\.generalization)
    }
}
