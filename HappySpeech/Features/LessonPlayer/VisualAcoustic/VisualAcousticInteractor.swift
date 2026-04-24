import Foundation
import AVFoundation
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
//   2. `playAudio` — запускает TTS (AVSpeechSynthesizer, ru-RU) с полным
//      текстом вопроса и вариантов. Когда речь заканчивается —
//      AVSpeechSynthesizerDelegate переводит фазу в .choosing.
//   3. `chooseWord` — проверяет правильность, шлёт Response,
//      планирует автопереход: 1.2 с на correct, 1.5 с на wrong.
//   4. `nextRound` — инкрементит roundIndex; если раунды закончились —
//      вызывает `complete`, иначе подгружает следующий.
//   5. `complete` — считает финальный score = correctCount / totalRounds.
//
// AVSpeechSynthesizer хранится как instance var, чтобы система не
// освободила его до завершения речи (типичная ловушка с локальной переменной).

@MainActor
final class VisualAcousticInteractor: NSObject, VisualAcousticBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any VisualAcousticPresentationLogic)?
    var router: (any VisualAcousticRoutingLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VisualAcousticInteractor")

    // MARK: - TTS

    private let synthesizer = AVSpeechSynthesizer()
    private static let voiceLocale = "ru-RU"
    private static let utteranceRate: Float = 0.45
    private static let utteranceVolume: Float = 1.0
    private static let pitchMultiplier: Float = 1.05
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

    // MARK: - Lifecycle

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    deinit {
        advanceTask?.cancel()
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

        // Если TTS уже играет — останавливаем и стартуем заново.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: round.ttsText)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLocale)
        utterance.rate = Self.utteranceRate
        utterance.volume = Self.utteranceVolume
        utterance.pitchMultiplier = Self.pitchMultiplier
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)

        presenter?.presentPlayAudio(VisualAcousticModels.PlayAudio.Response(isPlaying: true))
        logger.info("playAudio round=\(self.roundIndex, privacy: .public)")
    }

    // MARK: - chooseWord

    func chooseWord(_ request: VisualAcousticModels.ChoiceWord.Request) {
        guard !isGameOver else { return }
        guard rounds.indices.contains(roundIndex) else { return }
        let round = rounds[roundIndex]

        // Останавливаем TTS — ребёнок уже принял решение.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

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
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

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
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
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
                    imageEmoji: "🐍",
                    imageLabel: String(localized: "Змея"),
                    question: String(localized: "Как звучит змея?"),
                    questionWithSound: String(localized: "Найди слово со звуком «С»"),
                    choices: ["шипит", "рычит", "свистит", "мяукает"],
                    correctIndex: 2,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Как звучит змея? Найди слово со звуком С. Шипит. Рычит. Свистит. Мяукает.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🦟",
                    imageLabel: String(localized: "Комар"),
                    question: String(localized: "Как звучит комар?"),
                    questionWithSound: String(localized: "Найди слово со звуком «З»"),
                    choices: ["звенит", "лает", "рычит", "пищит"],
                    correctIndex: 0,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Как звучит комар? Найди слово со звуком З. Звенит. Лает. Рычит. Пищит.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🐤",
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
                    imageEmoji: "🌲",
                    imageLabel: String(localized: "Сосна"),
                    question: String(localized: "Какое это дерево?"),
                    questionWithSound: String(localized: "Найди слово со звуком «С»"),
                    choices: ["дуб", "берёза", "сосна", "клён"],
                    correctIndex: 2,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Какое это дерево? Найди слово со звуком С. Дуб. Берёза. Сосна. Клён.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🦓",
                    imageLabel: String(localized: "Зебра"),
                    question: String(localized: "Кто это в полоску?"),
                    questionWithSound: String(localized: "Найди слово со звуком «З»"),
                    choices: ["тигр", "зебра", "лошадь", "корова"],
                    correctIndex: 1,
                    soundGroup: "whistling",
                    ttsText: String(localized: "Кто это в полоску? Найди слово со звуком З. Тигр. Зебра. Лошадь. Корова.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🌻",
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
                    imageEmoji: "🐝",
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
                    imageEmoji: "🐭",
                    imageLabel: String(localized: "Мышка"),
                    question: String(localized: "Кто пищит в норке?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ш»"),
                    choices: ["птица", "мышка", "крот", "лиса"],
                    correctIndex: 1,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Кто пищит в норке? Найди слово со звуком Ш. Птица. Мышка. Крот. Лиса.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "⏰",
                    imageLabel: String(localized: "Часы"),
                    question: String(localized: "Что показывает время?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ч»"),
                    choices: ["зеркало", "часы", "лампа", "окно"],
                    correctIndex: 1,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Что показывает время? Найди слово со звуком Ч. Зеркало. Часы. Лампа. Окно.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🪥",
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
                    imageEmoji: "🦒",
                    imageLabel: String(localized: "Жираф"),
                    question: String(localized: "Кто самый высокий?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ж»"),
                    choices: ["слон", "жираф", "зебра", "лев"],
                    correctIndex: 1,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Кто самый высокий? Найди слово со звуком Ж. Слон. Жираф. Зебра. Лев.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🧥",
                    imageLabel: String(localized: "Шуба"),
                    question: String(localized: "Что надевают зимой?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Ш»"),
                    choices: ["майка", "шуба", "панама", "кофта"],
                    correctIndex: 1,
                    soundGroup: "hissing",
                    ttsText: String(localized: "Что надевают зимой? Найди слово со звуком Ш. Майка. Шуба. Панама. Кофта.")
                )
            ],

            // MARK: sonants (Р, Л)
            "sonants": [
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🐯",
                    imageLabel: String(localized: "Тигр"),
                    question: String(localized: "Как звучит тигр?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Р»"),
                    choices: ["рычит", "хрюкает", "мяукает", "свистит"],
                    correctIndex: 0,
                    soundGroup: "sonants",
                    ttsText: String(localized: "Как звучит тигр? Найди слово со звуком Р. Рычит. Хрюкает. Мяукает. Свистит.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🚀",
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
                    imageEmoji: "🍋",
                    imageLabel: String(localized: "Лимон"),
                    question: String(localized: "Какой жёлтый и кислый?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Л»"),
                    choices: ["банан", "лимон", "груша", "киви"],
                    correctIndex: 1,
                    soundGroup: "sonants",
                    ttsText: String(localized: "Какой жёлтый и кислый? Найди слово со звуком Л. Банан. Лимон. Груша. Киви.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🐟",
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
                    imageEmoji: "🌕",
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
                    imageEmoji: "🌈",
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
                    imageEmoji: "🐸",
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
                    imageEmoji: "🦆",
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
                    imageEmoji: "🍞",
                    imageLabel: String(localized: "Хлеб"),
                    question: String(localized: "Что пекут в печке?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Х»"),
                    choices: ["суп", "хлеб", "каша", "пирог"],
                    correctIndex: 1,
                    soundGroup: "velar",
                    ttsText: String(localized: "Что пекут в печке? Найди слово со звуком Х. Суп. Хлеб. Каша. Пирог.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🐱",
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
                    imageEmoji: "🍇",
                    imageLabel: String(localized: "Виноград"),
                    question: String(localized: "Какая ягода гроздью?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Г»"),
                    choices: ["вишня", "виноград", "малина", "слива"],
                    correctIndex: 1,
                    soundGroup: "velar",
                    ttsText: String(localized: "Какая ягода гроздью? Найди слово со звуком Г. Вишня. Виноград. Малина. Слива.")
                ),
                VisualAcousticRound(
                    id: UUID(),
                    imageEmoji: "🐹",
                    imageLabel: String(localized: "Хомяк"),
                    question: String(localized: "Кто грызёт зёрна в клетке?"),
                    questionWithSound: String(localized: "Найди слово со звуком «Х»"),
                    choices: ["мышь", "хомяк", "заяц", "ёжик"],
                    correctIndex: 1,
                    soundGroup: "velar",
                    ttsText: String(localized: "Кто грызёт зёрна в клетке? Найди слово со звуком Х. Мышь. Хомяк. Заяц. Ёжик.")
                )
            ]
        ]
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VisualAcousticInteractor: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self, !self.isGameOver else { return }
            self.presenter?.presentPlayAudio(
                VisualAcousticModels.PlayAudio.Response(isPlaying: false)
            )
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.presenter?.presentPlayAudio(
                VisualAcousticModels.PlayAudio.Response(isPlaying: false)
            )
        }
    }
}
