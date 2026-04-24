import Foundation
import AVFoundation
import OSLog

// MARK: - StoryCompletionBusinessLogic

@MainActor
protocol StoryCompletionBusinessLogic: AnyObject {
    func loadStory(_ request: StoryCompletionModels.LoadStory.Request)
    func chooseWord(_ request: StoryCompletionModels.ChooseWord.Request)
    func nextScene()
    func complete()
    func cancel()
}

// MARK: - StoryCompletionInteractor
//
// Бизнес-логика «Заверши историю».
//   1. `loadStory` — достаёт сцену из каталога по `soundGroup` + `sceneIndex`,
//      запускает TTS через AVSpeechSynthesizer (ru-RU), шлёт Response.
//   2. `chooseWord` — проверяет правильность, подсвечивает варианты,
//      автоматически планирует переход к следующей сцене: 1.2 с на correct,
//      1.8 с на wrong (ребёнок успевает увидеть правильный вариант).
//   3. `nextScene` — инкрементит sceneIndex; если сцены закончились — вызывает
//      `complete`, иначе подгружает следующую.
//   4. `complete` — считает финальный score = correctCount / totalScenes.
//
// AVSpeechSynthesizer хранится как instance var, чтобы система не освободила
// его до завершения речи.

@MainActor
final class StoryCompletionInteractor: NSObject, StoryCompletionBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any StoryCompletionPresentationLogic)?
    var router: (any StoryCompletionRoutingLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryCompletionInteractor")

    // MARK: - TTS

    private let synthesizer = AVSpeechSynthesizer()
    private static let voiceLocale = "ru-RU"
    private static let utteranceRate: Float = 0.45
    private static let utteranceVolume: Float = 1.0
    private static let pitchMultiplier: Float = 1.05
    /// Задержка перед автопереходом после правильного ответа.
    private static let advanceDelayCorrect: Duration = .milliseconds(1200)
    /// Задержка перед автопереходом после неправильного ответа
    /// (ребёнок успевает увидеть подсвеченный правильный вариант).
    private static let advanceDelayWrong: Duration = .milliseconds(1800)
    /// Пауза между загрузкой сцены и стартом TTS.
    private static let speakStartDelay: Duration = .milliseconds(350)

    // MARK: - Game state

    private let totalScenes: Int = 5
    private var activity: SessionActivity?
    private var soundGroup: String = "whistling"
    private var scenes: [StoryScene] = []
    private var sceneIndex: Int = 0
    private var correctCount: Int = 0
    private var isGameOver: Bool = false

    private var advanceTask: Task<Void, Never>?
    private var speakTask: Task<Void, Never>?

    // MARK: - Lifecycle

    deinit {
        advanceTask?.cancel()
        speakTask?.cancel()
    }

    // MARK: - loadStory

    func loadStory(_ request: StoryCompletionModels.LoadStory.Request) {
        guard !isGameOver else { return }

        // Первый вход: фиксируем активити и строим набор сцен.
        if scenes.isEmpty {
            self.activity = request.activity
            self.soundGroup = Self.resolveSoundGroup(for: request.activity.soundTarget)
            self.scenes = Self.buildScenes(for: soundGroup, total: totalScenes)
            self.sceneIndex = 0
            self.correctCount = 0
            logger.info(
                "loadStory bootstrap group=\(self.soundGroup, privacy: .public) scenes=\(self.scenes.count, privacy: .public)"
            )
        }

        let idx = max(0, min(request.sceneIndex, scenes.count - 1))
        sceneIndex = idx
        let scene = scenes[idx]

        logger.info(
            "loadStory scene=\(idx, privacy: .public)/\(self.totalScenes, privacy: .public) correct=\(scene.choices[scene.correctIndex], privacy: .private)"
        )

        presenter?.presentLoadStory(StoryCompletionModels.LoadStory.Response(
            scene: scene,
            sceneIndex: idx,
            totalScenes: totalScenes
        ))

        scheduleSpeak(scene: scene)
    }

    // MARK: - chooseWord

    func chooseWord(_ request: StoryCompletionModels.ChooseWord.Request) {
        guard !isGameOver else { return }
        guard scenes.indices.contains(sceneIndex) else { return }
        let scene = scenes[sceneIndex]

        // Останавливаем TTS — ребёнок уже принял решение.
        cancelSpeak()
        synthesizer.stopSpeaking(at: .immediate)

        let isCorrect = request.choiceIndex == scene.correctIndex
        if isCorrect { correctCount += 1 }

        let correctWord = scene.choices[scene.correctIndex]
        let chosenWord = (scene.choices.indices.contains(request.choiceIndex))
            ? scene.choices[request.choiceIndex]
            : ""
        let filledText = scene.storyText.replacingOccurrences(
            of: StoryPlaceholder.marker,
            with: correctWord
        )

        logger.info(
            "chooseWord idx=\(request.choiceIndex, privacy: .public) correct=\(isCorrect, privacy: .public)"
        )

        presenter?.presentChooseWord(StoryCompletionModels.ChooseWord.Response(
            choiceIndex: request.choiceIndex,
            correctIndex: scene.correctIndex,
            isCorrect: isCorrect,
            chosenWord: chosenWord,
            correctWord: correctWord,
            filledStoryText: filledText
        ))

        scheduleAdvance(after: isCorrect ? Self.advanceDelayCorrect : Self.advanceDelayWrong)
    }

    // MARK: - nextScene

    func nextScene() {
        guard !isGameOver else { return }
        let next = sceneIndex + 1
        if next >= totalScenes {
            logger.info("nextScene: all scenes played — completing")
            presenter?.presentNextScene(StoryCompletionModels.NextScene.Response(
                hasNextScene: false,
                nextSceneIndex: sceneIndex
            ))
            complete()
            return
        }
        logger.info("nextScene -> \(next, privacy: .public)")
        presenter?.presentNextScene(StoryCompletionModels.NextScene.Response(
            hasNextScene: true,
            nextSceneIndex: next
        ))
        guard let activity else { return }
        loadStory(StoryCompletionModels.LoadStory.Request(
            activity: activity,
            sceneIndex: next
        ))
    }

    // MARK: - complete

    func complete() {
        guard !isGameOver else { return }
        isGameOver = true
        cancelAdvance()
        cancelSpeak()
        synthesizer.stopSpeaking(at: .immediate)

        let total = max(totalScenes, 1)
        let score = Float(correctCount) / Float(total)
        let clamped = min(max(score, 0), 1)

        logger.info(
            "complete correct=\(self.correctCount, privacy: .public)/\(self.totalScenes, privacy: .public) score=\(clamped, privacy: .public)"
        )

        presenter?.presentComplete(StoryCompletionModels.Complete.Response(
            correctCount: correctCount,
            totalScenes: totalScenes,
            score: clamped
        ))
    }

    // MARK: - cancel

    func cancel() {
        isGameOver = true
        cancelAdvance()
        cancelSpeak()
        synthesizer.stopSpeaking(at: .immediate)
        logger.info("StoryCompletion cancelled")
    }

    // MARK: - TTS

    private func scheduleSpeak(scene: StoryScene) {
        cancelSpeak()
        speakTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.speakStartDelay)
            guard let self, !Task.isCancelled, !self.isGameOver else { return }
            self.speak(scene: scene)
        }
    }

    private func cancelSpeak() {
        speakTask?.cancel()
        speakTask = nil
    }

    private func speak(scene: StoryScene) {
        // Вместо "___" в озвучке говорим «пропуск», чтобы TTS не пытался
        // произнести подчёркивания по символу.
        let spoken = scene.storyText.replacingOccurrences(
            of: StoryPlaceholder.marker,
            with: String(localized: "пропуск")
        )
        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLocale)
        utterance.rate = Self.utteranceRate
        utterance.volume = Self.utteranceVolume
        utterance.pitchMultiplier = Self.pitchMultiplier
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.1

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
    }

    // MARK: - Auto-advance

    private func scheduleAdvance(after delay: Duration) {
        cancelAdvance()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, !self.isGameOver else { return }
            self.nextScene()
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

    // MARK: - Story catalog
    //
    // 4 звуковые группы × 5 сцен. Каждый «правильный» вариант содержит
    // целевой звук группы; два «неправильных» — нейтральные или с другим
    // звуком, чтобы контраст был очевиден.

    static func buildScenes(for group: String, total: Int) -> [StoryScene] {
        let pool = catalog[group] ?? catalog["whistling"] ?? []
        if pool.count >= total {
            return Array(pool.prefix(total))
        }
        // Страховка: если добавят группу с <5 сценами — добьём из whistling.
        var combined = pool
        let fallback = catalog["whistling"] ?? []
        for scene in fallback where combined.count < total {
            combined.append(scene)
        }
        return Array(combined.prefix(total))
    }

    /// Каталог сцен по группам. Правильный вариант помечен `correctIndex`.
    /// Все `choices` содержат ровно 3 слова; правильное — с целевым звуком.
    private static let catalog: [String: [StoryScene]] = [
        // MARK: whistling — С / З / Ц
        "whistling": [
            StoryScene(
                id: UUID(),
                storyText: "Маша пошла в лес и нашла большую ___.",
                choices: ["сосну", "берёзу", "рябину"],
                correctIndex: 0,
                soundGroup: "whistling",
                emoji: "🌲"
            ),
            StoryScene(
                id: UUID(),
                storyText: "На поляне сидит зелёная ___ и смотрит на нас.",
                choices: ["белка", "лягушка", "стрекоза"],
                correctIndex: 2,
                soundGroup: "whistling",
                emoji: "🪰"
            ),
            StoryScene(
                id: UUID(),
                storyText: "Утром по небу летит жёлтое ___.",
                choices: ["облако", "солнце", "пёрышко"],
                correctIndex: 1,
                soundGroup: "whistling",
                emoji: "☀️"
            ),
            StoryScene(
                id: UUID(),
                storyText: "На лугу мирно пасётся белая ___.",
                choices: ["корова", "лошадка", "коза"],
                correctIndex: 2,
                soundGroup: "whistling",
                emoji: "🐐"
            ),
            StoryScene(
                id: UUID(),
                storyText: "В траве прячется пугливый ___.",
                choices: ["ёжик", "крот", "заяц"],
                correctIndex: 2,
                soundGroup: "whistling",
                emoji: "🐇"
            ),
        ],

        // MARK: hissing — Ш / Ж / Ч / Щ
        "hissing": [
            StoryScene(
                id: UUID(),
                storyText: "По дорожке бежит пушистая ___.",
                choices: ["кошка", "мышка", "утка"],
                correctIndex: 0,
                soundGroup: "hissing",
                emoji: "🐱"
            ),
            StoryScene(
                id: UUID(),
                storyText: "На окошке стоит красивая ___.",
                choices: ["ваза", "чашка", "миска"],
                correctIndex: 1,
                soundGroup: "hissing",
                emoji: "🍵"
            ),
            StoryScene(
                id: UUID(),
                storyText: "В пруду плавает большая ___.",
                choices: ["уточка", "рыбка", "щука"],
                correctIndex: 2,
                soundGroup: "hissing",
                emoji: "🐟"
            ),
            StoryScene(
                id: UUID(),
                storyText: "В лесу под кустом живёт колючий ___.",
                choices: ["ёж", "волк", "лис"],
                correctIndex: 0,
                soundGroup: "hissing",
                emoji: "🦔"
            ),
            StoryScene(
                id: UUID(),
                storyText: "Папа надел тёплую ___ и пошёл гулять.",
                choices: ["куртку", "пальто", "шапку"],
                correctIndex: 2,
                soundGroup: "hissing",
                emoji: "🧢"
            ),
        ],

        // MARK: sonants — Р / Л
        "sonants": [
            StoryScene(
                id: UUID(),
                storyText: "В речке плавает быстрая ___.",
                choices: ["рыбка", "уточка", "бабочка"],
                correctIndex: 0,
                soundGroup: "sonants",
                emoji: "🐠"
            ),
            StoryScene(
                id: UUID(),
                storyText: "На столе горит яркая ___.",
                choices: ["свеча", "лампа", "печка"],
                correctIndex: 1,
                soundGroup: "sonants",
                emoji: "💡"
            ),
            StoryScene(
                id: UUID(),
                storyText: "У берега качается маленькая ___.",
                choices: ["машина", "тележка", "лодка"],
                correctIndex: 2,
                soundGroup: "sonants",
                emoji: "🛶"
            ),
            StoryScene(
                id: UUID(),
                storyText: "Высоко в небе парит большой ___.",
                choices: ["орёл", "воробей", "голубь"],
                correctIndex: 0,
                soundGroup: "sonants",
                emoji: "🦅"
            ),
            StoryScene(
                id: UUID(),
                storyText: "На грядке вырос красный спелый ___.",
                choices: ["огурец", "кабачок", "помидор"],
                correctIndex: 2,
                soundGroup: "sonants",
                emoji: "🍅"
            ),
        ],

        // MARK: velar — К / Г / Х
        "velar": [
            StoryScene(
                id: UUID(),
                storyText: "На крыльце сидит полосатый ___.",
                choices: ["пёс", "котик", "хомяк"],
                correctIndex: 1,
                soundGroup: "velar",
                emoji: "🐈"
            ),
            StoryScene(
                id: UUID(),
                storyText: "Вдоль реки важно ходит белый ___.",
                choices: ["гусь", "лебедь", "аист"],
                correctIndex: 0,
                soundGroup: "velar",
                emoji: "🪿"
            ),
            StoryScene(
                id: UUID(),
                storyText: "На столе лежит свежий душистый ___.",
                choices: ["хлеб", "пирог", "сыр"],
                correctIndex: 0,
                soundGroup: "velar",
                emoji: "🍞"
            ),
            StoryScene(
                id: UUID(),
                storyText: "Мальчик катится зимой с высокой ___.",
                choices: ["крыши", "лесенки", "горки"],
                correctIndex: 2,
                soundGroup: "velar",
                emoji: "🛷"
            ),
            StoryScene(
                id: UUID(),
                storyText: "На кухне вкусно пахнет горячая ___.",
                choices: ["булка", "каша", "рыба"],
                correctIndex: 0,
                soundGroup: "velar",
                emoji: "🥖"
            ),
        ],
    ]
}
