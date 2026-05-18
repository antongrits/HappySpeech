import Foundation
import OSLog

// MARK: - VisualAcousticBusinessLogic

@MainActor
protocol VisualAcousticBusinessLogic: AnyObject {
    func loadRound(_ request: VisualAcousticModels.LoadRound.Request)
    func playAudio(_ request: VisualAcousticModels.PlayAudio.Request)
    func chooseWord(_ request: VisualAcousticModels.ChoiceWord.Request)
    func nextRound()
    func complete()
    func cancel()
}

// MARK: - VisualAcousticInteractor
//
// Бизнес-логика «Визуально-акустическая связь».
//   1. `loadRound` — при первом входе фиксирует активити и выбирает 6 раундов
//      из каталога для группы звуков ребёнка; шлёт Response в Presenter.
//   2. `playAudio` — озвучивает вопрос и варианты записанным голосом Ляли
//      через `LessonVoiceWorker` (m4a из bundle, Siri-TTS не используется).
//      Когда воспроизведение завершается — фаза переходит в .choosing.
//   3. `chooseWord` — проверяет правильность, шлёт Response,
//      планирует автопереход: 1.2 с на correct, 1.5 с на wrong.
//   4. `nextRound` — инкрементит roundIndex; если раунды закончились —
//      вызывает `complete`, иначе подгружает следующий.
//   5. `complete` — считает финальный score = correctCount / totalRounds.
//
// Озвучка идёт через `speakTask` — отменяемый Task, чтобы при dismiss
// экрана не было «призрачного» воспроизведения.

@MainActor
final class VisualAcousticInteractor: VisualAcousticBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any VisualAcousticPresentationLogic)?
    var router: (any VisualAcousticRoutingLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VisualAcousticInteractor")

    // MARK: - Timing

    /// Задержка перед автопереходом после правильного ответа.
    private static let advanceDelayCorrect: Duration = .milliseconds(1200)
    /// Задержка перед автопереходом после ошибки
    /// (ребёнок успевает увидеть подсвеченный правильный вариант).
    private static let advanceDelayWrong: Duration = .milliseconds(1500)

    // MARK: - Game state

    private let totalRounds: Int = 6
    private var activity: SessionActivity?
    private var soundGroup: String = "whistling"
    private var rounds: [VisualAcousticRound] = []
    private var roundIndex: Int = 0
    private var correctCount: Int = 0
    private var isGameOver: Bool = false

    private var advanceTask: Task<Void, Never>?
    private var speakTask: Task<Void, Never>?

    // MARK: - Init

    init() {}

    deinit {
        advanceTask?.cancel()
        speakTask?.cancel()
    }

    // MARK: - loadRound

    func loadRound(_ request: VisualAcousticModels.LoadRound.Request) {
        guard !isGameOver else { return }

        // Первый вход: фиксируем активити и строим набор раундов.
        if rounds.isEmpty {
            self.activity = request.activity
            self.soundGroup = Self.resolveSoundGroup(for: request.activity.soundTarget)
            self.rounds = Self.buildRounds(for: soundGroup, total: totalRounds)
            self.roundIndex = 0
            self.correctCount = 0
            logger.info(
                "loadRound bootstrap group=\(self.soundGroup, privacy: .public) rounds=\(self.rounds.count, privacy: .public)"
            )
        }

        let idx = max(0, min(request.roundIndex, rounds.count - 1))
        roundIndex = idx
        let round = rounds[idx]

        logger.info(
            "loadRound \(idx, privacy: .public)/\(self.totalRounds, privacy: .public) correct=\(round.choices[round.correctIndex], privacy: .private)"
        )

        presenter?.presentLoadRound(VisualAcousticModels.LoadRound.Response(
            round: round,
            roundIndex: idx,
            totalRounds: totalRounds
        ))
    }

    // MARK: - playAudio

    func playAudio(_ request: VisualAcousticModels.PlayAudio.Request) {
        guard !isGameOver else { return }
        guard rounds.indices.contains(roundIndex) else { return }
        let round = rounds[roundIndex]

        // Если уже играет — останавливаем и стартуем заново.
        LessonVoiceWorker.shared.stop()

        presenter?.presentPlayAudio(VisualAcousticModels.PlayAudio.Response(isPlaying: true))
        logger.info("playAudio round=\(self.roundIndex, privacy: .public)")

        speakTask?.cancel()
        speakTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await LessonVoiceWorker.shared.speak(
                round.ttsText,
                lessonType: "visual_acoustic"
            )
            guard !self.isGameOver, !Task.isCancelled else { return }
            self.presenter?.presentPlayAudio(
                VisualAcousticModels.PlayAudio.Response(isPlaying: false)
            )
            self.speakTask = nil
        }
    }

    // MARK: - chooseWord

    func chooseWord(_ request: VisualAcousticModels.ChoiceWord.Request) {
        guard !isGameOver else { return }
        guard rounds.indices.contains(roundIndex) else { return }
        let round = rounds[roundIndex]

        // Останавливаем воспроизведение — ребёнок уже принял решение.
        LessonVoiceWorker.shared.stop()

        let isCorrect = request.choiceIndex == round.correctIndex
        if isCorrect { correctCount += 1 }

        let correctWord = round.choices.indices.contains(round.correctIndex)
            ? round.choices[round.correctIndex]
            : ""

        logger.info(
            "chooseWord idx=\(request.choiceIndex, privacy: .public) correct=\(isCorrect, privacy: .public)"
        )

        presenter?.presentChoiceWord(VisualAcousticModels.ChoiceWord.Response(
            choiceIndex: request.choiceIndex,
            correctIndex: round.correctIndex,
            isCorrect: isCorrect,
            correctWord: correctWord
        ))

        scheduleAdvance(after: isCorrect ? Self.advanceDelayCorrect : Self.advanceDelayWrong)
    }

    // MARK: - nextRound

    func nextRound() {
        guard !isGameOver else { return }
        let next = roundIndex + 1
        if next >= totalRounds {
            logger.info("nextRound: all rounds played — completing")
            presenter?.presentNextRound(VisualAcousticModels.NextRound.Response(
                hasNextRound: false,
                nextRoundIndex: roundIndex
            ))
            complete()
            return
        }
        logger.info("nextRound -> \(next, privacy: .public)")
        presenter?.presentNextRound(VisualAcousticModels.NextRound.Response(
            hasNextRound: true,
            nextRoundIndex: next
        ))
        guard let activity else { return }
        loadRound(VisualAcousticModels.LoadRound.Request(
            activity: activity,
            roundIndex: next
        ))
    }

    // MARK: - complete

    func complete() {
        guard !isGameOver else { return }
        isGameOver = true
        cancelAdvance()
        LessonVoiceWorker.shared.stop()

        let total = max(totalRounds, 1)
        let rawScore = Float(correctCount) / Float(total)
        let score = min(max(rawScore, 0), 1)

        logger.info(
            "complete correct=\(self.correctCount, privacy: .public)/\(self.totalRounds, privacy: .public) score=\(score, privacy: .public)"
        )

        presenter?.presentComplete(VisualAcousticModels.Complete.Response(
            correctCount: correctCount,
            totalRounds: totalRounds,
            score: score
        ))
    }

    // MARK: - cancel

    func cancel() {
        isGameOver = true
        cancelAdvance()
        speakTask?.cancel()
        speakTask = nil
        LessonVoiceWorker.shared.stop()
        logger.info("VisualAcoustic cancelled")
    }

    // MARK: - Auto-advance

    private func scheduleAdvance(after delay: Duration) {
        cancelAdvance()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, !self.isGameOver else { return }
            self.nextRound()
        }
    }

    private func cancelAdvance() {
        advanceTask?.cancel()
        advanceTask = nil
    }

    // MARK: - Sound group resolution

    /// Согласовано с `BingoInteractor.resolveSoundGroup(for:)`.
    static func resolveSoundGroup(for targetSound: String) -> String {
        let firstLetter = targetSound.uppercased().prefix(1)
        switch firstLetter {
        case "С", "З", "Ц":      return "whistling"
        case "Ш", "Ж", "Ч", "Щ": return "hissing"
        case "Р", "Л":           return "sonants"
        case "К", "Г", "Х":      return "velar"
        default:                  return "whistling"
        }
    }

    // MARK: - Round catalog
    //
    // 4 звуковые группы × 6 раундов. В каждом раунде:
    //   - imageEmoji — крупная иллюстрация животного/предмета
    //   - question — «Как звучит X?»
    //   - questionWithSound — «Найди слово со звуком «Z»»
    //   - 4 варианта, один из которых содержит целевой звук группы.

    /// Выбирает раунды для группы. Если в каталоге меньше `total` раундов —
    /// берёт все имеющиеся; если больше — берёт первые `total`.
    static func buildRounds(for group: String, total: Int) -> [VisualAcousticRound] {
        let catalog = allRounds()
        let pool = catalog[group] ?? catalog["whistling"] ?? []
        return Array(pool.prefix(total))
    }

    /// Полный каталог раундов по группам.
    /// swiftlint:disable:next function_body_length
    static func allRounds() -> [String: [VisualAcousticRound]] {
        [
            // MARK: whistling (С, З, Ц)
            "whistling": [
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_fish",
                    imageLabel: String(localized: "Рыба"),
                    question: String(localized: "Кто плавает в реке?"),
                    questionWithSound: String(localized: "Найди слово со звуком «С»"),
                    choices: ["лещ", "сом", "карп", "ёрш"],
                    correctIndex: 1,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Кто плавает в реке? Найди слово со звуком С. Лещ. Сом. Карп. Ёрш.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_butterfly_insect",
                    imageLabel: String(localized: "Бабочка"),
                    question: String(localized: "Как зовут это насекомое?"),
                    questionWithSound: String(localized: "Найди слово со звуком «З»"),
                    choices: ["бабочка", "стрекоза", "пчела", "жук"],
                    correctIndex: 1,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Как зовут это насекомое? Найди слово со звуком З. Бабочка. Стрекоза. Пчела. Жук.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_hen",
                    imageLabel: String(localized: "Цыплёнок"),
                    question: String(localized: "Кто вылупился из яйца?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ц»"),
                    choices: ["утёнок", "цыплёнок", "котёнок", "щенок"],
                    correctIndex: 1,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Кто вылупился из яйца? Найди слово со звуком Ц. Утёнок. Цыплёнок. Котёнок. Щенок.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_forest",
                    imageLabel: String(localized: "Лес"),
                    question: String(localized: "Где растут деревья?"),
                    questionWithSound: String(localized: "Найди слово со звуком «С»"),
                    choices: ["поле", "лес", "море", "степь"],
                    correctIndex: 1,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Где растут деревья? Найди слово со звуком С. Поле. Лес. Море. Степь.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_hare",
                    imageLabel: String(localized: "Заяц"),
                    question: String(localized: "Кто прыгает по лесу?"),
                    questionWithSound: String(localized: "Найди слово со звуком «З»"),
                    choices: ["кот", "заяц", "лиса", "волк"],
                    correctIndex: 1,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Кто прыгает по лесу? Найди слово со звуком З. Кот. Заяц. Лиса. Волк.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_flower",
                    imageLabel: String(localized: "Цветок"),
                    question: String(localized: "Что растёт в поле?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ц»"),
                    choices: ["трава", "цветок", "дерево", "камень"],
                    correctIndex: 1,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Что растёт в поле? Найди слово со звуком Ц. Трава. Цветок. Дерево. Камень.")
                )
            ],

            // MARK: hissing (Ш, Ж, Ч, Щ)
            "hissing": [
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_butterfly_insect",
                    imageLabel: String(localized: "Пчела"),
                    question: String(localized: "Как звучит пчела?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ж»"),
                    choices: ["жужжит", "пищит", "рычит", "поёт"],
                    correctIndex: 0,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Как звучит пчела? Найди слово со звуком Ж. Жужжит. Пищит. Рычит. Поёт.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_cat",
                    imageLabel: String(localized: "Кошка"),
                    question: String(localized: "Кто мяукает?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ш»"),
                    choices: ["птица", "кошка", "крот", "лиса"],
                    correctIndex: 1,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Кто мяукает? Найди слово со звуком Ш. Птица. Кошка. Крот. Лиса.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_lamp",
                    imageLabel: String(localized: "Лампа"),
                    question: String(localized: "Что светит в комнате?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ч»"),
                    choices: ["свеча", "лампа", "фонарь", "факел"],
                    correctIndex: 0,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Что светит в комнате? Найди слово со звуком Ч. Свеча. Лампа. Фонарь. Факел.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "scribble",
                    imageLabel: String(localized: "Щётка"),
                    question: String(localized: "Чем чистят зубы?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Щ»"),
                    choices: ["мыло", "щётка", "полотенце", "крем"],
                    correctIndex: 1,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Чем чистят зубы? Найди слово со звуком Щ. Мыло. Щётка. Полотенце. Крем.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_elephant",
                    imageLabel: String(localized: "Слон"),
                    question: String(localized: "У кого длинный хобот?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ж»"),
                    choices: ["слон", "жираф", "зебра", "лев"],
                    correctIndex: 0,
                    soundGroup: "hissing",
                    ttsText: String(localized: "У кого длинный хобот? Найди слово со звуком Ж. Слон. Жираф. Зебра. Лев.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_bag",
                    imageLabel: String(localized: "Сумка"),
                    question: String(localized: "Что берут в школу?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ш»"),
                    choices: ["сумка", "шапка", "панама", "кофта"],
                    correctIndex: 1,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Что берут в школу? Найди слово со звуком Ш. Сумка. Шапка. Панама. Кофта.")
                )
            ],

            // MARK: sonants (Р, Л)
            "sonants": [
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_cat",
                    imageLabel: String(localized: "Кошка"),
                    question: String(localized: "Как говорит кошка?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Р»"),
                    choices: ["рычит", "хрюкает", "мяукает", "свистит"],
                    correctIndex: 2,
                    soundGroup: "sonants",
                    ttsText: String(localized: "Как говорит кошка? Найди слово со звуком Р. Рычит. Хрюкает. Мяукает. Свистит.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "airplane.departure",
                    imageLabel: String(localized: "Ракета"),
                    question: String(localized: "На чём летят в космос?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Р»"),
                    choices: ["самолёт", "ракета", "поезд", "автобус"],
                    correctIndex: 1,
                    soundGroup: "sonants",
                    ttsText: String(localized: "На чём летят в космос? Найди слово со звуком Р. Самолёт. Ракета. Поезд. Автобус.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_apple",
                    imageLabel: String(localized: "Яблоко"),
                    question: String(localized: "Какой красный и сладкий фрукт?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Л»"),
                    choices: ["груша", "яблоко", "слива", "апельсин"],
                    correctIndex: 1,
                    soundGroup: "sonants",
                    ttsText: String(localized: "Какой красный и сладкий фрукт? Найди слово со звуком Л. Груша. Яблоко. Слива. Апельсин.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_fish",
                    imageLabel: String(localized: "Рыба"),
                    question: String(localized: "Кто плавает в воде?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Р»"),
                    choices: ["птица", "рыба", "кот", "мышь"],
                    correctIndex: 1,
                    soundGroup: "sonants",
                    ttsText: String(localized: "Кто плавает в воде? Найди слово со звуком Р. Птица. Рыба. Кот. Мышь.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_moon",
                    imageLabel: String(localized: "Луна"),
                    question: String(localized: "Что светит ночью на небе?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Л»"),
                    choices: ["солнце", "луна", "звезда", "туча"],
                    correctIndex: 1,
                    soundGroup: "sonants",
                    ttsText: String(localized: "Что светит ночью на небе? Найди слово со звуком Л. Солнце. Луна. Звезда. Туча.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "reward_rainbow",
                    imageLabel: String(localized: "Радуга"),
                    question: String(localized: "Что появляется после дождя?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Р»"),
                    choices: ["радуга", "снег", "туман", "иней"],
                    correctIndex: 0,
                    soundGroup: "sonants",
                    ttsText: String(localized: "Что появляется после дождя? Найди слово со звуком Р. Радуга. Снег. Туман. Иней.")
                )
            ],

            // MARK: velar (К, Г, Х)
            "velar": [
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_frog",
                    imageLabel: String(localized: "Лягушка"),
                    question: String(localized: "Как звучит лягушка?"),
                    questionWithSound: String(localized: "Найди слово со звуком «К»"),
                    choices: ["квакает", "мяукает", "лает", "мычит"],
                    correctIndex: 0,
                    soundGroup: "velar",
                    ttsText: String(localized: "Как звучит лягушка? Найди слово со звуком К. Квакает. Мяукает. Лает. Мычит.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_bird",
                    imageLabel: String(localized: "Гусь"),
                    question: String(localized: "Кто кричит «га-га»?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Г»"),
                    choices: ["петух", "гусь", "утка", "курица"],
                    correctIndex: 1,
                    soundGroup: "velar",
                    ttsText: String(localized: "Кто кричит га-га? Найди слово со звуком Г. Петух. Гусь. Утка. Курица.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_cake",
                    imageLabel: String(localized: "Торт"),
                    question: String(localized: "Что едят на день рождения?"),
                    questionWithSound: String(localized: "Найди слово со звуком «К»"),
                    choices: ["торт", "суп", "каша", "кисель"],
                    correctIndex: 0,
                    soundGroup: "velar",
                    ttsText: String(localized: "Что едят на день рождения? Найди слово со звуком К. Торт. Суп. Каша. Кисель.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_cat",
                    imageLabel: String(localized: "Кот"),
                    question: String(localized: "Кто мяукает?"),
                    questionWithSound: String(localized: "Найди слово со звуком «К»"),
                    choices: ["пёс", "кот", "мышь", "птица"],
                    correctIndex: 1,
                    soundGroup: "velar",
                    ttsText: String(localized: "Кто мяукает? Найди слово со звуком К. Пёс. Кот. Мышь. Птица.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_apple",
                    imageLabel: String(localized: "Яблоко"),
                    question: String(localized: "Какой фрукт красный и круглый?"),
                    questionWithSound: String(localized: "Найди слово со звуком «К»"),
                    choices: ["груша", "слива", "яблоко", "кокос"],
                    correctIndex: 3,
                    soundGroup: "velar",
                    ttsText: String(localized: "Какой фрукт красный и круглый? Найди слово со звуком К. Груша. Слива. Яблоко. Кокос.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "word_hare",
                    imageLabel: String(localized: "Заяц"),
                    question: String(localized: "Кто прячется в кустах?"),
                    questionWithSound: String(localized: "Найди слово со звуком «К»"),
                    choices: ["волк", "заяц", "козёл", "лиса"],
                    correctIndex: 2,
                    soundGroup: "velar",
                    ttsText: String(localized: "Кто прячется в кустах? Найди слово со звуком К. Волк. Заяц. Козёл. Лиса.")
                )
            ]
        ]
    }
}
