import Foundation

// MARK: - ProsodyCorpus
//
// v29 Фаза 8, Функция 1 «Голосовые краски».
//
// Корпус коротких фраз, размеченных по типу интонации (повествование /
// вопрос / восклицание) и привязанных к лексическим темам. Лексика —
// частотная, возрастная (6–8 лет), короткие фразы 2–4 слова (методически
// верно для работы над мелодикой: Лопатина). Полностью offline / on-device.

enum ProsodyCorpus {

    /// Сколько раундов в одной сессии (8–12 мин, антифатиговое правило).
    static let roundsPerSession = 9

    // MARK: - Phrases

    /// Полный размеченный корпус фраз.
    static let phrases: [ProsodyPhrase] = [
        // Повествование — спокойный нисходящий тон.
        .init(id: "dec-1", text: "Кошка спит на коврике.",
              intonation: .declarative, theme: "Домашние животные"),
        .init(id: "dec-2", text: "На улице идёт дождь.",
              intonation: .declarative, theme: "Времена года"),
        .init(id: "dec-3", text: "Мама готовит вкусный суп.",
              intonation: .declarative, theme: "Семья"),
        .init(id: "dec-4", text: "В лесу растут грибы.",
              intonation: .declarative, theme: "Лес"),
        .init(id: "dec-5", text: "Машина едет по дороге.",
              intonation: .declarative, theme: "Транспорт"),
        .init(id: "dec-6", text: "Птицы улетают на юг.",
              intonation: .declarative, theme: "Птицы"),
        .init(id: "dec-7", text: "Дети играют во дворе.",
              intonation: .declarative, theme: "Семья"),
        .init(id: "dec-8", text: "Снег покрыл всю землю.",
              intonation: .declarative, theme: "Времена года"),

        // Вопрос — восходящий тон к концу фразы.
        .init(id: "int-1", text: "Ты любишь мороженое?",
              intonation: .interrogative, theme: "Еда"),
        .init(id: "int-2", text: "Где живёт медведь?",
              intonation: .interrogative, theme: "Дикие животные"),
        .init(id: "int-3", text: "Куда поехал автобус?",
              intonation: .interrogative, theme: "Транспорт"),
        .init(id: "int-4", text: "Кто стучит в дверь?",
              intonation: .interrogative, theme: "Дом"),
        .init(id: "int-5", text: "Почему светит солнце?",
              intonation: .interrogative, theme: "Времена года"),
        .init(id: "int-6", text: "Ты пойдёшь гулять?",
              intonation: .interrogative, theme: "Семья"),
        .init(id: "int-7", text: "Какого цвета шарик?",
              intonation: .interrogative, theme: "Игрушки"),
        .init(id: "int-8", text: "Что растёт в саду?",
              intonation: .interrogative, theme: "Овощи"),

        // Восклицание — эмоциональный, с усилением.
        .init(id: "exc-1", text: "Какой красивый закат!",
              intonation: .exclamatory, theme: "Времена года"),
        .init(id: "exc-2", text: "Ура, наступило лето!",
              intonation: .exclamatory, theme: "Времена года"),
        .init(id: "exc-3", text: "Как здорово ты прыгаешь!",
              intonation: .exclamatory, theme: "Спорт"),
        .init(id: "exc-4", text: "Смотри, какая радуга!",
              intonation: .exclamatory, theme: "Времена года"),
        .init(id: "exc-5", text: "Ах, как вкусно пахнет!",
              intonation: .exclamatory, theme: "Еда"),
        .init(id: "exc-6", text: "Какой огромный слон!",
              intonation: .exclamatory, theme: "Дикие животные"),
        .init(id: "exc-7", text: "Ой, как высоко летит!",
              intonation: .exclamatory, theme: "Птицы"),
        .init(id: "exc-8", text: "Как весело кататься с горки!",
              intonation: .exclamatory, theme: "Игры")
    ]

    // MARK: - Queries

    /// Все фразы данного типа интонации.
    static func phrases(of type: IntonationType) -> [ProsodyPhrase] {
        phrases.filter { $0.intonation == type }
    }

    /// Собирает методически упорядоченную сессию: на каждом этапе берётся
    /// сбалансированный набор фраз всех трёх типов интонации.
    static func sessionPhrases() -> [ProsodyPhrase] {
        var pool: [ProsodyPhrase] = []
        for type in IntonationType.allCases {
            pool.append(contentsOf: phrases(of: type).shuffled().prefix(3))
        }
        return pool
    }
}
