import AVFoundation
import Foundation
import OSLog

// MARK: - NarrativeQuestBusinessLogic

@MainActor
protocol NarrativeQuestBusinessLogic: AnyObject {
    func loadQuest(_ request: NarrativeQuestModels.LoadQuest.Request)
    func startStage(_ request: NarrativeQuestModels.StartStage.Request)
    func recordWord(_ request: NarrativeQuestModels.RecordWord.Request)
    func evaluateWord(_ request: NarrativeQuestModels.EvaluateWord.Request)
    func advanceStage(_ request: NarrativeQuestModels.AdvanceStage.Request)
    func completeQuest(_ request: NarrativeQuestModels.CompleteQuest.Request)
    func cancel()
}

// MARK: - NarrativeQuestInteractor
//
// Бизнес-логика «Квеста с Лялей». Держит текущий сценарий, индекс этапа,
// накопленные эмодзи и скоры. Управляет TTS (AVSpeechSynthesizer) для
// нарратива и делегирует scoring presenter'у через Response.
// Все операции — @MainActor; отложенные переходы между фазами делаются
// через отменяемые `Task` — чтобы при dismiss экрана не было «призрачных»
// переходов.

@MainActor
final class NarrativeQuestInteractor: NarrativeQuestBusinessLogic {

    // MARK: - Collaborators

    var presenter: (any NarrativeQuestPresentationLogic)?

    // MARK: - TTS

    private let synthesizer = AVSpeechSynthesizer()
    private static let voiceLocale = "ru-RU"
    private static let utteranceRate: Float = 0.45
    private static let utterancePitch: Float = 1.0
    private static let utteranceVolume: Float = 1.0

    // MARK: - State

    private var script: NarrativeQuestScript?
    private var currentStageIndex: Int = 0
    private var stageScores: [Float] = []
    private var collectedEmojis: [String] = []
    private var isListening: Bool = false

    // Отложенные задачи между фазами (auto-advance, feedback delay).
    private var pendingTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "NarrativeQuest")

    // Constants
    private let passThreshold: Float = 0.6
    private let feedbackDelay: Duration = .milliseconds(1500)
    private let stageIntroDelay: Duration = .milliseconds(600)

    // MARK: - Init

    init(presenter: (any NarrativeQuestPresentationLogic)? = nil) {
        self.presenter = presenter
    }

    deinit {
        // Нельзя безопасно останавливать синтезатор из deinit (он не Sendable),
        // поэтому полагаемся на `cancel()` из View.onDisappear.
    }

    // MARK: - LoadQuest

    func loadQuest(_ request: NarrativeQuestModels.LoadQuest.Request) {
        let group = Self.resolveSoundGroup(request.soundTarget)
        let script = Self.questCatalog[group] ?? Self.questCatalog["whistling"]!
        self.script = script
        self.currentStageIndex = 0
        self.stageScores = []
        self.collectedEmojis = []

        logger.info("NarrativeQuest loaded id=\(script.id, privacy: .public) stages=\(script.stages.count)")
        presenter?.presentLoadQuest(.init(script: script))

        // Озвучиваем вступление квеста.
        speak(script.introNarration)
    }

    // MARK: - StartStage

    func startStage(_ request: NarrativeQuestModels.StartStage.Request) {
        guard let script else { return }
        let index = request.stageIndex
        guard script.stages.indices.contains(index) else {
            logger.error("startStage out of bounds index=\(index)")
            return
        }

        currentStageIndex = index
        let stage = script.stages[index]
        let total = script.stages.count
        let progress = Double(index) / Double(total)

        let response = NarrativeQuestModels.StartStage.Response(
            stage: stage,
            stageNumber: stage.stageNumber,
            totalStages: total,
            progressFraction: progress
        )
        presenter?.presentStartStage(response)

        // Озвучиваем этап: сначала narration, затем task.
        let combined = stage.narration + " " + stage.task
        speak(combined)
    }

    // MARK: - RecordWord

    func recordWord(_ request: NarrativeQuestModels.RecordWord.Request) {
        guard !isListening else { return }
        isListening = true
        stopSpeaking()
        presenter?.presentRecordWord(.init(isListening: true))
        logger.debug("NarrativeQuest start recording stage=\(self.currentStageIndex)")
    }

    // MARK: - EvaluateWord

    func evaluateWord(_ request: NarrativeQuestModels.EvaluateWord.Request) {
        guard let script else { return }
        guard script.stages.indices.contains(currentStageIndex) else { return }
        let stage = script.stages[currentStageIndex]
        isListening = false
        presenter?.presentRecordWord(.init(isListening: false))

        let (score, passed) = Self.scoreAttempt(
            transcript: request.transcript,
            target: stage.targetWord,
            confidence: request.confidence
        )

        stageScores.append(score)
        if passed {
            collectedEmojis.append(stage.rewardEmoji)
        }

        logger.info(
            "NarrativeQuest stage=\(stage.stageNumber) target=\(stage.targetWord, privacy: .public) score=\(score, privacy: .public) passed=\(passed)"
        )

        let response = NarrativeQuestModels.EvaluateWord.Response(
            score: score,
            passed: passed,
            rewardEmoji: stage.rewardEmoji,
            successNarration: stage.successNarration
        )
        presenter?.presentEvaluateWord(response)

        // Озвучиваем успех-нарратив этапа.
        if passed {
            speak(stage.successNarration)
        }

        // Через feedbackDelay — либо следующий этап, либо завершение.
        scheduleAdvance()
    }

    // MARK: - AdvanceStage

    func advanceStage(_ request: NarrativeQuestModels.AdvanceStage.Request) {
        guard let script else { return }
        let next = currentStageIndex + 1
        if next >= script.stages.count {
            // Квест закончен — финал.
            let response = NarrativeQuestModels.AdvanceStage.Response(
                nextStageIndex: nil,
                collectedEmojis: collectedEmojis,
                progressFraction: 1.0,
                stageNumber: script.stages.count
            )
            presenter?.presentAdvanceStage(response)
            completeQuest(.init())
            return
        }

        let total = script.stages.count
        let response = NarrativeQuestModels.AdvanceStage.Response(
            nextStageIndex: next,
            collectedEmojis: collectedEmojis,
            progressFraction: Double(next) / Double(total),
            stageNumber: next + 1
        )
        presenter?.presentAdvanceStage(response)

        // Небольшая пауза перед запуском следующего этапа.
        pendingTask?.cancel()
        pendingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.stageIntroDelay ?? .milliseconds(600))
            guard let self, !Task.isCancelled else { return }
            self.startStage(.init(stageIndex: next))
        }
    }

    // MARK: - CompleteQuest

    func completeQuest(_ request: NarrativeQuestModels.CompleteQuest.Request) {
        guard let script else { return }
        let avg = stageScores.isEmpty
            ? 0
            : stageScores.reduce(0, +) / Float(stageScores.count)
        let stars = NarrativeQuestPresenter.stars(for: avg)

        logger.info(
            "NarrativeQuest completed avg=\(avg, privacy: .public) stars=\(stars) collected=\(self.collectedEmojis.count)"
        )

        let response = NarrativeQuestModels.CompleteQuest.Response(
            averageScore: avg,
            starsEarned: stars,
            collectedEmojis: collectedEmojis,
            finalRewardEmoji: script.finalRewardEmoji,
            finalMessage: script.finalMessage
        )
        presenter?.presentCompleteQuest(response)

        // Финальный голос Ляли.
        speak(script.finalMessage)
    }

    // MARK: - Cancel

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        isListening = false
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Private helpers

    private func scheduleAdvance() {
        pendingTask?.cancel()
        pendingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.feedbackDelay ?? .milliseconds(1500))
            guard let self, !Task.isCancelled else { return }
            self.advanceStage(.init())
        }
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLocale)
        utterance.rate = Self.utteranceRate
        utterance.pitchMultiplier = Self.utterancePitch
        utterance.volume = Self.utteranceVolume
        utterance.postUtteranceDelay = 0.1

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
    }

    private func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Sound group resolution

    static func resolveSoundGroup(_ soundTarget: String) -> String {
        let trimmed = soundTarget.trimmingCharacters(in: .whitespaces).uppercased()
        let whistling: Set<String> = ["С", "С'", "З", "З'", "Ц"]
        let hissing: Set<String> = ["Ш", "Ж", "Ч", "Щ"]
        let sonants: Set<String> = ["Р", "Р'", "РЬ", "Л", "Л'", "ЛЬ"]
        let velar: Set<String> = ["К", "Г", "Х"]
        if whistling.contains(trimmed) { return "whistling" }
        if hissing.contains(trimmed) { return "hissing" }
        if sonants.contains(trimmed) { return "sonants" }
        if velar.contains(trimmed) { return "velar" }
        // Fallback по lower-cased family id (если пришёл уже id группы).
        let lower = soundTarget.lowercased()
        if ["whistling", "hissing", "sonants", "sonorant", "velar"].contains(lower) {
            return lower == "sonorant" ? "sonants" : lower
        }
        return "whistling"
    }

    // MARK: - Scoring

    /// Простой scoring для нарративного квеста.
    /// Основан на сопоставлении transcript → targetWord + confidence.
    static func scoreAttempt(
        transcript: String,
        target: String,
        confidence: Float
    ) -> (score: Float, passed: Bool) {
        let cleanTranscript = transcript
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTarget = target
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTarget.isEmpty else { return (0, false) }

        // 1. Точное совпадение / содержание.
        if !cleanTranscript.isEmpty && cleanTranscript.contains(cleanTarget) {
            return (1.0, true)
        }

        // 2. Совпадение первых двух символов — хороший знак для детской речи.
        let prefix = sharedPrefixLength(cleanTranscript, cleanTarget)
        if prefix >= 2 && confidence >= 0.6 {
            return (0.85, true)
        }
        if prefix >= 2 {
            return (0.7, true)
        }

        // 3. Нет ASR-результата — используем confidence-fallback.
        if cleanTranscript.isEmpty {
            let score: Float = 0.75
            return (score, score >= 0.6)
        }

        // 4. По умолчанию — мягкая «попробуй ещё» оценка.
        return (0.5, false)
    }

    private static func sharedPrefixLength(_ a: String, _ b: String) -> Int {
        var count = 0
        for (c1, c2) in zip(a, b) where c1 == c2 {
            count += 1
        }
        return count
    }

    // MARK: - Quest catalog
    //
    // По одному квесту на каждую звуковую группу. Темы специально
    // «сказочные» и универсальные — джунгли, море, космос, горы.
    // Каждый квест — 4 этапа, в каждом этапе целевое слово с нужным звуком.

    static let questCatalog: [String: NarrativeQuestScript] = [
        "whistling": NarrativeQuestScript(
            id: "jungle-quest",
            title: String(localized: "В джунглях"),
            introNarration: String(localized: "Ляля отправляется в джунгли! Помоги ей, и она соберёт все сокровища."),
            stages: [
                NarrativeQuestStage(
                    stageNumber: 1,
                    narration: String(localized: "Ляля вышла на тропинку и увидела большую змею!"),
                    task: String(localized: "Произнеси слово «сова», чтобы позвать умного помощника."),
                    targetWord: String(localized: "сова"),
                    targetSoundGroup: "whistling",
                    successNarration: String(localized: "Прилетела мудрая сова и прогнала змею!"),
                    rewardEmoji: "🦉",
                    hint: String(localized: "Звук «С» — как свисток чайника.")
                ),
                NarrativeQuestStage(
                    stageNumber: 2,
                    narration: String(localized: "На поляне Ляля нашла заколдованный цветок."),
                    task: String(localized: "Скажи волшебное слово «звезда», и цветок расцветёт."),
                    targetWord: String(localized: "звезда"),
                    targetSoundGroup: "whistling",
                    successNarration: String(localized: "Цветок расцвёл разноцветными огоньками!"),
                    rewardEmoji: "⭐",
                    hint: String(localized: "Звук «З» — это звонкий свисток.")
                ),
                NarrativeQuestStage(
                    stageNumber: 3,
                    narration: String(localized: "К Ляле подбежала испуганная цапля: её птенцов кто-то спрятал."),
                    task: String(localized: "Произнеси «цыплёнок», чтобы найти птенцов."),
                    targetWord: String(localized: "цыплёнок"),
                    targetSoundGroup: "whistling",
                    successNarration: String(localized: "Цыплята нашлись под листочком — цапля благодарит Лялю!"),
                    rewardEmoji: "🐣",
                    hint: String(localized: "«Ц» — это как «ТС», быстро.")
                ),
                NarrativeQuestStage(
                    stageNumber: 4,
                    narration: String(localized: "Впереди сундук с сокровищами, но он заперт."),
                    task: String(localized: "Скажи «сундук» — и замок откроется."),
                    targetWord: String(localized: "сундук"),
                    targetSoundGroup: "whistling",
                    successNarration: String(localized: "Сундук открылся! Внутри — золотые монетки."),
                    rewardEmoji: "💰",
                    hint: String(localized: "Начни со свистящего «С».")
                )
            ],
            finalRewardEmoji: "🏆",
            finalMessage: String(localized: "Ляля вернулась из джунглей настоящим героем! Ты ей очень помог.")
        ),

        "hissing": NarrativeQuestScript(
            id: "sea-quest",
            title: String(localized: "На море"),
            introNarration: String(localized: "Ляля отправляется к морю! Там её ждут морские приключения."),
            stages: [
                NarrativeQuestStage(
                    stageNumber: 1,
                    narration: String(localized: "На берегу Ляля нашла красивую раковину."),
                    task: String(localized: "Произнеси «шар», и из раковины появится волшебный пузырь."),
                    targetWord: String(localized: "шар"),
                    targetSoundGroup: "hissing",
                    successNarration: String(localized: "Из раковины вылетел переливающийся пузырь!"),
                    rewardEmoji: "🫧",
                    hint: String(localized: "«Ш» — это как ветер в листьях.")
                ),
                NarrativeQuestStage(
                    stageNumber: 2,
                    narration: String(localized: "Ляля встретила на песке крошечного жучка."),
                    task: String(localized: "Произнеси «жук», чтобы он поверил тебе и показал дорогу."),
                    targetWord: String(localized: "жук"),
                    targetSoundGroup: "hissing",
                    successNarration: String(localized: "Жук зажужжал и полетел впереди, показывая путь!"),
                    rewardEmoji: "🪲",
                    hint: String(localized: "«Ж» — как жужжание пчелы.")
                ),
                NarrativeQuestStage(
                    stageNumber: 3,
                    narration: String(localized: "У моря Ляля увидела домик с чайником на окошке."),
                    task: String(localized: "Скажи «чайник», и в нём закипит тёплое какао."),
                    targetWord: String(localized: "чайник"),
                    targetSoundGroup: "hissing",
                    successNarration: String(localized: "Чайник засвистел — значит, какао готово!"),
                    rewardEmoji: "☕",
                    hint: String(localized: "«Ч» — это как тихое чиханье.")
                ),
                NarrativeQuestStage(
                    stageNumber: 4,
                    narration: String(localized: "Из воды вынырнул большой щенок-тюлень и хочет играть."),
                    task: String(localized: "Произнеси «щенок» — и он прыгнет к тебе."),
                    targetWord: String(localized: "щенок"),
                    targetSoundGroup: "hissing",
                    successNarration: String(localized: "Щенок радостно плюхнулся рядом и подарил ракушку!"),
                    rewardEmoji: "🐶",
                    hint: String(localized: "«Щ» — длинный мягкий «Ш».")
                )
            ],
            finalRewardEmoji: "🏆",
            finalMessage: String(localized: "Море подарило Ляле целую коллекцию сокровищ! Спасибо тебе.")
        ),

        "sonants": NarrativeQuestScript(
            id: "space-quest",
            title: String(localized: "В космосе"),
            introNarration: String(localized: "Ляля стартует в космос на своей ракете! Помоги ей добраться до звёзд."),
            stages: [
                NarrativeQuestStage(
                    stageNumber: 1,
                    narration: String(localized: "Ляля сидит в ракете, но двигатель ещё не запустился."),
                    task: String(localized: "Произнеси «ракета», чтобы запустить двигатели."),
                    targetWord: String(localized: "ракета"),
                    targetSoundGroup: "sonants",
                    successNarration: String(localized: "Ракета взлетает с громким «ррр»! Ляля в космосе!"),
                    rewardEmoji: "🚀",
                    hint: String(localized: "Звук «Р» — рычит как моторчик.")
                ),
                NarrativeQuestStage(
                    stageNumber: 2,
                    narration: String(localized: "Вокруг ракеты плывут огромные космические рыбы!"),
                    task: String(localized: "Скажи «рыба», и одна из них станет проводником."),
                    targetWord: String(localized: "рыба"),
                    targetSoundGroup: "sonants",
                    successNarration: String(localized: "Космическая рыба поплыла впереди, освещая путь!"),
                    rewardEmoji: "🐟",
                    hint: String(localized: "Рычи мягко: «рр-рыба».")
                ),
                NarrativeQuestStage(
                    stageNumber: 3,
                    narration: String(localized: "Впереди планета, на которой живут добрые львы."),
                    task: String(localized: "Произнеси «лев», и он поделится историей."),
                    targetWord: String(localized: "лев"),
                    targetSoundGroup: "sonants",
                    successNarration: String(localized: "Лев рассказал Ляле сказку про звёзды!"),
                    rewardEmoji: "🦁",
                    hint: String(localized: "«Л» — язык к зубкам.")
                ),
                NarrativeQuestStage(
                    stageNumber: 4,
                    narration: String(localized: "На последней планете Ляля видит волшебную лампу."),
                    task: String(localized: "Скажи «луна», и лампа покажет дорогу домой."),
                    targetWord: String(localized: "луна"),
                    targetSoundGroup: "sonants",
                    successNarration: String(localized: "Лампа засветилась лунным светом — путь домой открыт!"),
                    rewardEmoji: "🌙",
                    hint: String(localized: "«Л» — тёплый и мягкий звук.")
                )
            ],
            finalRewardEmoji: "🏆",
            finalMessage: String(localized: "Ляля вернулась из космоса с целой горстью звёздочек!")
        ),

        "velar": NarrativeQuestScript(
            id: "mountain-quest",
            title: String(localized: "В горах"),
            introNarration: String(localized: "Ляля поднимается в горы! Там спрятано настоящее сокровище."),
            stages: [
                NarrativeQuestStage(
                    stageNumber: 1,
                    narration: String(localized: "У подножия горы Ляля встретила важного кота."),
                    task: String(localized: "Произнеси «кот», и он покажет тропинку наверх."),
                    targetWord: String(localized: "кот"),
                    targetSoundGroup: "velar",
                    successNarration: String(localized: "Кот вежливо мяукнул и повёл Лялю вверх по тропе!"),
                    rewardEmoji: "🐱",
                    hint: String(localized: "Звук «К» — как короткий щелчок.")
                ),
                NarrativeQuestStage(
                    stageNumber: 2,
                    narration: String(localized: "На полпути перед Лялей важно шагает большой гусь."),
                    task: String(localized: "Скажи «гусь», и он пропустит тебя."),
                    targetWord: String(localized: "гусь"),
                    targetSoundGroup: "velar",
                    successNarration: String(localized: "Гусь гоготнул и уступил дорогу!"),
                    rewardEmoji: "🪿",
                    hint: String(localized: "«Г» — это «К», только звонкий.")
                ),
                NarrativeQuestStage(
                    stageNumber: 3,
                    narration: String(localized: "На вершине горы холодно, у Ляли замерзают лапки."),
                    task: String(localized: "Произнеси «хлеб», и добрый пекарь пригласит тебя."),
                    targetWord: String(localized: "хлеб"),
                    targetSoundGroup: "velar",
                    successNarration: String(localized: "Пекарь угостил Лялю тёплым хлебом и чаем!"),
                    rewardEmoji: "🥖",
                    hint: String(localized: "«Х» — как тёплый выдох на ладошки.")
                ),
                NarrativeQuestStage(
                    stageNumber: 4,
                    narration: String(localized: "На самой верхушке Ляля увидела сундук со звёздной картой."),
                    task: String(localized: "Скажи «ключ», чтобы открыть сундук."),
                    targetWord: String(localized: "ключ"),
                    targetSoundGroup: "velar",
                    successNarration: String(localized: "Ключ провернулся — Ляля получила карту сокровищ!"),
                    rewardEmoji: "🗝️",
                    hint: String(localized: "Начни со звука «К».")
                )
            ],
            finalRewardEmoji: "🏆",
            finalMessage: String(localized: "Ляля спустилась с горы с картой сокровищ! Вы сделали это вместе.")
        )
    ]
}
