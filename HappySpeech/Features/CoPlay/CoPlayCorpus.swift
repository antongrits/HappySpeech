import Foundation

// MARK: - CoPlayCorpus
//
// v29 Фаза 8, Функция 8 «Занятие вместе».
//
// Стартовый корпус сценариев совместной игры со взрослым. Каждый сценарий —
// чередование ходов: взрослый даёт образец речи, ребёнок повторяет/отвечает.
// Игры диалогового типа («вопрос-ответ», «доскажи за мамой», «угадай по
// описанию»). Лексика частотная, возрастная. Полностью offline / on-device.

enum CoPlayCorpus {

    /// Полный корпус сценариев.
    static let activities: [CoPlayActivity] = [
        echoAnimals, finishPhrase, guessByDescription, questionAnswer
    ]

    // MARK: - Эхо: животные и их голоса

    static let echoAnimals = CoPlayActivity(
        id: "echo-animals", title: "Эхо: кто как говорит",
        symbolName: "cat.fill",
        turns: [
            .init(id: "ea-1", role: .adult, line: "Кошка говорит: мяу-мяу.",
                  instruction: "Скажите фразу как образец."),
            .init(id: "ea-2", role: .child, line: "Кошка говорит: мяу-мяу.",
                  instruction: "Повтори за взрослым."),
            .init(id: "ea-3", role: .adult, line: "Собака говорит: гав-гав.",
                  instruction: "Скажите фразу как образец."),
            .init(id: "ea-4", role: .child, line: "Собака говорит: гав-гав.",
                  instruction: "Повтори за взрослым."),
            .init(id: "ea-5", role: .adult, line: "Корова говорит: му-у-у.",
                  instruction: "Скажите фразу как образец."),
            .init(id: "ea-6", role: .child, line: "Корова говорит: му-у-у.",
                  instruction: "Повтори за взрослым.")
        ],
        adultBriefing: "Произносите реплику чётко и с интонацией. Дайте малышу повторить за вами, хвалите за попытку."
    )

    // MARK: - Доскажи за мамой

    static let finishPhrase = CoPlayActivity(
        id: "finish-phrase", title: "Доскажи словечко",
        symbolName: "text.bubble.fill",
        turns: [
            .init(id: "fp-1", role: .adult, line: "Зимой на улице холодно и идёт...",
                  instruction: "Начните фразу, сделайте паузу."),
            .init(id: "fp-2", role: .child, line: "...снег.",
                  instruction: "Договори последнее слово."),
            .init(id: "fp-3", role: .adult, line: "Яблоко круглое, красное и очень...",
                  instruction: "Начните фразу, сделайте паузу."),
            .init(id: "fp-4", role: .child, line: "...вкусное.",
                  instruction: "Договори последнее слово."),
            .init(id: "fp-5", role: .adult, line: "Птицы умеют высоко в небе...",
                  instruction: "Начните фразу, сделайте паузу."),
            .init(id: "fp-6", role: .child, line: "...летать.",
                  instruction: "Договори последнее слово.")
        ],
        adultBriefing: "Начните фразу и сделайте паузу. Дайте ребёнку договорить последнее слово."
    )

    // MARK: - Угадай по описанию

    static let guessByDescription = CoPlayActivity(
        id: "guess-description", title: "Угадай по описанию",
        symbolName: "questionmark.bubble.fill",
        turns: [
            .init(id: "gd-1", role: .adult, line: "Это рыжая, хитрая, живёт в лесу. Кто это?",
                  instruction: "Опишите предмет, не называя."),
            .init(id: "gd-2", role: .child, line: "Это лиса!",
                  instruction: "Назови отгадку вслух."),
            .init(id: "gd-3", role: .child, line: "Жёлтый, кислый, кладут в чай. Что это?",
                  instruction: "Опиши свой предмет."),
            .init(id: "gd-4", role: .adult, line: "Это лимон!",
                  instruction: "Назовите отгадку вслух."),
            .init(id: "gd-5", role: .adult, line: "Зелёный, прыгает, квакает у пруда. Кто это?",
                  instruction: "Опишите предмет, не называя."),
            .init(id: "gd-6", role: .child, line: "Это лягушка!",
                  instruction: "Назови отгадку вслух.")
        ],
        adultBriefing: "Описывайте предмет словами, не называя его. Похвалите малыша за догадку, потом поменяйтесь ролями."
    )

    // MARK: - Вопрос-ответ

    static let questionAnswer = CoPlayActivity(
        id: "question-answer", title: "Вопрос и ответ",
        symbolName: "bubble.left.and.bubble.right.fill",
        turns: [
            .init(id: "qa-1", role: .adult, line: "Какое сейчас время года?",
                  instruction: "Задайте вопрос ребёнку."),
            .init(id: "qa-2", role: .child, line: "Сейчас время года — ...",
                  instruction: "Ответь полным предложением."),
            .init(id: "qa-3", role: .adult, line: "Что ты любишь делать на прогулке?",
                  instruction: "Задайте вопрос ребёнку."),
            .init(id: "qa-4", role: .child, line: "На прогулке я люблю...",
                  instruction: "Ответь полным предложением."),
            .init(id: "qa-5", role: .child, line: "А что любишь ты?",
                  instruction: "Задай вопрос взрослому."),
            .init(id: "qa-6", role: .adult, line: "Я люблю...",
                  instruction: "Ответьте ребёнку.")
        ],
        adultBriefing: "Задавайте вопрос с вопросительной интонацией. Дайте ребёнку ответить полным предложением."
    )

    // MARK: - Queries

    /// Сценарий по идентификатору.
    static func activity(id: String) -> CoPlayActivity? {
        activities.first { $0.id == id }
    }

    /// Случайный сценарий для сессии.
    static func randomActivity() -> CoPlayActivity {
        activities.randomElement() ?? echoAnimals
    }
}
