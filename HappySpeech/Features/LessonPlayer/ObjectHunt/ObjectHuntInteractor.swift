import Foundation
import OSLog

// MARK: - ObjectHuntBusinessLogic

@MainActor
protocol ObjectHuntBusinessLogic: AnyObject {
    func loadScene(_ request: ObjectHuntModels.LoadScene.Request)
    func tapObject(_ request: ObjectHuntModels.TapObject.Request)
    func useHint(_ request: ObjectHuntModels.UseHint.Request)
    func timerTick(_ request: ObjectHuntModels.TimerTick.Request)
    func advanceToNextScene()
    func finishEarly()
}

// MARK: - ObjectHuntInteractor

/// Бизнес-логика игры «Найди предметы на звук» (ObjectHunt).
///
/// ### Правила игры
/// - 5 сцен (раундов) в одной сессии
/// - В каждой сцене 9 предметов: 3–4 правильных + отвлекающие
/// - Таймер 60 секунд на сцену
/// - За каждый правильный предмет +5 очков
/// - Streak-бонус: 3 подряд правильных → +5 к следующему
/// - Подсказки: 2 на раунд (Hint 1 — shake-анимация, Hint 2 — glow-подсветка)
/// - Adaptive routing через AdaptivePlannerService: при streak > 5 — +1 к сложности
///
/// ### Сцены
/// Каталог из 6 сцен × 4 звуковые группы. Для каждой сессии выбираются
/// первые 5 сцен из группы, соответствующей targetSound.
///
/// ### Persistence
/// По завершению игры результаты записываются через AdaptivePlannerService.recordSessionResult.
@MainActor
final class ObjectHuntInteractor: ObjectHuntBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any ObjectHuntPresentationLogic)?
    var router: (any ObjectHuntRoutingLogic)?

    private let hapticService: (any HapticService)?
    private let soundService: (any SoundServiceProtocol)?
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ObjectHunt")

    // MARK: - Session state

    private let targetSound: String
    private let soundGroup: String
    private let childId: String
    private let timeLimitSec: Int = 60
    private let totalScenes: Int = 5

    private var sceneIndex: Int = 0
    private var allScenes: [[SceneItem]] = []
    private var currentItems: [SceneItem] = []
    private var targetCount: Int = 0
    private var correctCount: Int = 0

    // Score & streak
    private var totalScore: Int = 0
    private var totalFound: Int = 0
    private var totalTargets: Int = 0
    private var streakCount: Int = 0
    private var maxStreakReached: Int = 0

    // Timer
    private var secondsRemaining: Int = 60
    private var sceneStartTime: Date = Date()

    // Hints
    private var hintsUsed: Int = 0
    private let maxHints: Int = 2

    // Adaptive difficulty
    private var difficultyBonus: Int = 0    // увеличивается при высоком streak

    // Task handles
    private var shakeResetTask: Task<Void, Never>?
    private var hintGlowTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?

    // MARK: - Init

    init(
        targetSound: String,
        childId: String = "default",
        hapticService: (any HapticService)? = nil,
        soundService: (any SoundServiceProtocol)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.targetSound = targetSound
        self.soundGroup = Self.resolveSoundGroup(for: targetSound)
        self.childId = childId
        self.hapticService = hapticService
        self.soundService = soundService
        self.adaptivePlanner = adaptivePlanner
    }

    deinit {
        shakeResetTask?.cancel()
        hintGlowTask?.cancel()
        advanceTask?.cancel()
    }

    // MARK: - loadScene

    func loadScene(_ request: ObjectHuntModels.LoadScene.Request) {
        advanceTask?.cancel()
        shakeResetTask?.cancel()
        hintGlowTask?.cancel()

        sceneIndex = max(0, min(request.sceneIndex, totalScenes - 1))

        // Строим все сцены один раз и запоминаем
        if allScenes.isEmpty {
            allScenes = Self.buildAllScenes(
                group: soundGroup,
                targetSound: request.targetSound,
                totalScenes: totalScenes
            )
            totalTargets = allScenes.flatMap { $0 }.filter(\.hasTargetSound).count
        }

        currentItems = allScenes[sceneIndex]
        targetCount = currentItems.filter(\.hasTargetSound).count
        correctCount = 0
        hintsUsed = 0
        secondsRemaining = timeLimitSec
        sceneStartTime = Date()

        let descriptor = Self.sceneDescriptors[sceneIndex % Self.sceneDescriptors.count]

        let response = ObjectHuntModels.LoadScene.Response(
            items: currentItems,
            targetSound: request.targetSound,
            scene: descriptor,
            sceneIndex: sceneIndex,
            totalScenes: totalScenes,
            targetCount: targetCount,
            timeLimitSec: timeLimitSec
        )
        logger.info(
            "LoadScene index=\(self.sceneIndex, privacy: .public) sound=\(request.targetSound, privacy: .public) targets=\(self.targetCount, privacy: .public)"
        )
        presenter?.presentLoadScene(response)
    }

    // MARK: - tapObject

    func tapObject(_ request: ObjectHuntModels.TapObject.Request) {
        guard let index = currentItems.firstIndex(where: { $0.id == request.itemId }) else { return }
        let item = currentItems[index]

        // Повторный тап по уже обработанному предмету игнорируем
        guard item.tapState == .idle || item.tapState == .hinted else { return }

        let isCorrect = item.hasTargetSound
        let newState: SceneItemTapState

        if isCorrect {
            newState = .correct
            correctCount += 1
            totalFound += 1

            // Streak
            streakCount += 1
            if streakCount > maxStreakReached {
                maxStreakReached = streakCount
            }

            // Adaptive: при streak > 5 повышаем сложность следующей сцены
            if streakCount > 5 && difficultyBonus < 2 {
                difficultyBonus += 1
                logger.info("ObjectHunt: difficulty bonus → \(self.difficultyBonus, privacy: .public)")
            }

            let pointsBase = 5
            let streakBonus = streakCount >= 3 ? 5 : 0
            let pointsTotal = pointsBase + streakBonus + difficultyBonus
            totalScore += pointsTotal

            hapticService?.selection()
            soundService?.playUISound(.correct)

            if streakCount == 3 {
                soundService?.playUISound(.streak)
                Task { [weak self] in
                    await self?.hapticService?.play(pattern: .celebration)
                }
            }

            logger.info(
                "TapCorrect id=\(request.itemId.uuidString, privacy: .public) word=\(item.word, privacy: .public) streak=\(self.streakCount, privacy: .public) pts=\(pointsTotal, privacy: .public)"
            )
        } else {
            newState = .wrong
            streakCount = 0

            hapticService?.notification(.warning)
            soundService?.playUISound(.incorrect)

            scheduleShakeReset(for: request.itemId)
            logger.info(
                "TapWrong id=\(request.itemId.uuidString, privacy: .public) word=\(item.word, privacy: .public)"
            )
        }

        currentItems[index].tapState = newState
        currentItems[index].isHintActive = false

        let isSceneComplete = correctCount >= targetCount

        let response = ObjectHuntModels.TapObject.Response(
            itemId: request.itemId,
            newState: newState,
            isCorrect: isCorrect,
            word: item.word,
            correctCount: correctCount,
            targetCount: targetCount,
            streakCount: streakCount,
            score: totalScore,
            isSceneComplete: isSceneComplete
        )
        presenter?.presentTapObject(response)

        if isSceneComplete {
            scheduleSceneComplete()
        }
    }

    // MARK: - useHint

    func useHint(_ request: ObjectHuntModels.UseHint.Request) {
        guard hintsUsed < maxHints else {
            let response = ObjectHuntModels.UseHint.Response(
                hintedItemId: nil,
                hintsRemaining: 0,
                hintLevel: 0
            )
            presenter?.presentUseHint(response)
            return
        }

        hintsUsed += 1
        let hintLevel = hintsUsed  // 1 или 2

        // Находим первый нетронутый правильный предмет для подсказки
        guard let hintIndex = currentItems.firstIndex(where: {
            $0.hasTargetSound && ($0.tapState == .idle || $0.tapState == .hinted)
        }) else {
            let response = ObjectHuntModels.UseHint.Response(
                hintedItemId: nil,
                hintsRemaining: maxHints - hintsUsed,
                hintLevel: hintLevel
            )
            presenter?.presentUseHint(response)
            return
        }

        let hintItemId = currentItems[hintIndex].id
        currentItems[hintIndex].tapState = .hinted
        currentItems[hintIndex].isHintActive = true

        // Через 2 секунды сбрасываем glow-состояние (но не tapState)
        scheduleHintGlowReset(for: hintItemId)

        soundService?.playUISound(.tap)
        hapticService?.notification(.warning)

        let response = ObjectHuntModels.UseHint.Response(
            hintedItemId: hintItemId,
            hintsRemaining: maxHints - hintsUsed,
            hintLevel: hintLevel
        )
        logger.info(
            "UseHint level=\(hintLevel, privacy: .public) item=\(self.currentItems[hintIndex].word, privacy: .public) remaining=\(self.maxHints - self.hintsUsed, privacy: .public)"
        )
        presenter?.presentUseHint(response)
    }

    // MARK: - timerTick

    func timerTick(_ request: ObjectHuntModels.TimerTick.Request) {
        guard secondsRemaining > 0 else { return }
        secondsRemaining -= 1

        let isExpired = secondsRemaining <= 0
        let response = ObjectHuntModels.TimerTick.Response(
            secondsRemaining: secondsRemaining,
            isExpired: isExpired
        )
        presenter?.presentTimerTick(response)

        if isExpired {
            logger.info("ObjectHunt: timer expired scene=\(self.sceneIndex, privacy: .public)")
            completeCurrentScene(timedOut: true)
        }
    }

    // MARK: - advanceToNextScene

    func advanceToNextScene() {
        advanceTask?.cancel()
        let nextIndex = sceneIndex + 1
        if nextIndex >= totalScenes {
            completeGame()
        } else {
            loadScene(.init(
                soundGroup: soundGroup,
                targetSound: targetSound,
                sceneIndex: nextIndex
            ))
        }
    }

    // MARK: - finishEarly

    /// Завершает игру досрочно (кнопка «Выйти» или навигационный back).
    func finishEarly() {
        advanceTask?.cancel()
        shakeResetTask?.cancel()
        hintGlowTask?.cancel()
        completeGame()
    }

    // MARK: - Private: scene complete

    private func scheduleSceneComplete() {
        advanceTask?.cancel()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self, !Task.isCancelled else { return }
            self.completeCurrentScene(timedOut: false)
        }
    }

    private func completeCurrentScene(timedOut: Bool) {
        advanceTask?.cancel()
        shakeResetTask?.cancel()
        hintGlowTask?.cancel()

        let timeUsed = Int(Date().timeIntervalSince(sceneStartTime))
        let streakBonus: Int = maxStreakReached >= 3 ? (maxStreakReached - 2) * 5 : 0
        let sceneScore = correctCount * 5 + streakBonus
        let isLastScene = sceneIndex >= totalScenes - 1

        if timedOut {
            hapticService?.notification(.warning)
        } else {
            Task { [weak self] in
                await self?.hapticService?.play(pattern: .perfectRound)
            }
            soundService?.playUISound(.reward)
        }

        let response = ObjectHuntModels.CompleteScene.Response(
            sceneIndex: sceneIndex,
            foundCount: correctCount,
            targetCount: targetCount,
            timeUsedSec: min(timeUsed, timeLimitSec),
            streakBonus: streakBonus,
            sceneScore: sceneScore,
            isLastScene: isLastScene
        )
        logger.info(
            "CompleteScene index=\(self.sceneIndex, privacy: .public) found=\(self.correctCount, privacy: .public)/\(self.targetCount, privacy: .public) timedOut=\(timedOut, privacy: .public)"
        )
        presenter?.presentCompleteScene(response)

        if isLastScene {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard let self, !Task.isCancelled else { return }
                self.completeGame()
            }
        }
    }

    // MARK: - Private: game complete

    private func completeGame() {
        let accuracy: Float = totalTargets > 0
            ? Float(totalFound) / Float(totalTargets)
            : 0.0
        let clamped = max(0, min(1, accuracy))
        let stars = starsFor(accuracy: clamped)

        Task { @MainActor [weak self] in
            await self?.hapticService?.play(pattern: stars >= 2 ? .achievementUnlock : .celebration)
            await self?.persistResult(accuracy: clamped)
        }

        soundService?.playUISound(.complete)

        let response = ObjectHuntModels.CompleteGame.Response(
            totalScore: totalScore,
            maxScore: totalTargets * 5,
            starsEarned: stars,
            totalFound: totalFound,
            totalTargets: totalTargets,
            accuracy: clamped
        )
        logger.info(
            "CompleteGame score=\(self.totalScore, privacy: .public) accuracy=\(clamped, privacy: .public) stars=\(stars, privacy: .public)"
        )
        presenter?.presentCompleteGame(response)
    }

    // MARK: - Private: async helpers

    private func persistResult(accuracy: Float) async {
        guard let planner = adaptivePlanner else { return }
        let quality: SM2Quality = SM2Quality.from(accuracy: accuracy)
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: targetSound,
                qualityScore: quality
            )
        } catch {
            logger.error("ObjectHunt: persistResult failed — \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleShakeReset(for itemId: UUID) {
        shakeResetTask?.cancel()
        shakeResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            guard let index = self.currentItems.firstIndex(where: { $0.id == itemId }) else { return }
            guard self.currentItems[index].tapState == .wrong else { return }
            self.currentItems[index].tapState = .idle

            let response = ObjectHuntModels.TapObject.Response(
                itemId: itemId,
                newState: .idle,
                isCorrect: false,
                word: self.currentItems[index].word,
                correctCount: self.correctCount,
                targetCount: self.targetCount,
                streakCount: self.streakCount,
                score: self.totalScore,
                isSceneComplete: false
            )
            self.presenter?.presentTapObject(response)
        }
    }

    private func scheduleHintGlowReset(for itemId: UUID) {
        hintGlowTask?.cancel()
        hintGlowTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, !Task.isCancelled else { return }
            guard let index = self.currentItems.firstIndex(where: { $0.id == itemId }) else { return }
            self.currentItems[index].isHintActive = false
            // tapState оставляем .hinted, чтобы View знал что предмет был подсказан
        }
    }

    // MARK: - Private: stars

    private func starsFor(accuracy: Float) -> Int {
        if accuracy >= 0.9 { return 3 }
        if accuracy >= 0.65 { return 2 }
        if accuracy >= 0.35 { return 1 }
        return 1
    }

    // MARK: - Static: sound group resolver

    static func resolveSoundGroup(for sound: String) -> String {
        let first = sound.uppercased().prefix(1)
        switch first {
        case "С", "З", "Ц":        return "whistling"
        case "Ш", "Ж", "Ч", "Щ":  return "hissing"
        case "Р", "Л":             return "sonants"
        case "К", "Г", "Х":       return "velar"
        default:                   return "whistling"
        }
    }

    // MARK: - Static: scene descriptors (6 сцен)

    static let sceneDescriptors: [SceneDescriptor] = [
        SceneDescriptor(name: String(localized: "scene.kitchen"),    systemBackground: "fork.knife"),
        SceneDescriptor(name: String(localized: "scene.forest"),     systemBackground: "tree.fill"),
        SceneDescriptor(name: String(localized: "scene.ocean"),      systemBackground: "water.waves"),
        SceneDescriptor(name: String(localized: "scene.school"),     systemBackground: "building.columns.fill"),
        SceneDescriptor(name: String(localized: "scene.playground"), systemBackground: "figure.play"),
        SceneDescriptor(name: String(localized: "scene.beach"),      systemBackground: "sun.horizon.fill")
    ]

    // MARK: - Static: build all scenes

    static func buildAllScenes(
        group: String,
        targetSound: String,
        totalScenes: Int
    ) -> [[SceneItem]] {
        let catalog: [[SceneItem]]
        switch group {
        case "whistling": catalog = whistlingCatalog(for: targetSound)
        case "hissing":   catalog = hissingCatalog(for: targetSound)
        case "sonants":   catalog = sonantCatalog(for: targetSound)
        case "velar":     catalog = velarCatalog(for: targetSound)
        default:          catalog = whistlingCatalog(for: targetSound)
        }

        // Берём первые totalScenes сцен (каталог содержит 6)
        return Array(catalog.prefix(totalScenes))
    }

    // MARK: - Catalogs: Whistling (С, З, Ц)

    private static func whistlingCatalog(for sound: String) -> [[SceneItem]] {
        [
            // Сцена 1 — кухня
            [
                SceneItem(word: "сахар",    icon: "cube.fill",             hasTargetSound: true),
                SceneItem(word: "сок",      icon: "drop.fill",             hasTargetSound: true),
                SceneItem(word: "сковорода",icon: "circle.fill",           hasTargetSound: true),
                SceneItem(word: "зонт",     icon: "umbrella.fill",         hasTargetSound: sound == "З"),
                SceneItem(word: "цыплёнок", icon: "bird.fill",             hasTargetSound: sound == "Ц"),
                SceneItem(word: "кастрюля", icon: "cylinder.fill",         hasTargetSound: false),
                SceneItem(word: "дом",      icon: "house.fill",            hasTargetSound: false),
                SceneItem(word: "рыба",     icon: "fish.fill",             hasTargetSound: false),
                SceneItem(word: "ложка",    icon: "fork.knife",            hasTargetSound: false)
            ],
            // Сцена 2 — лес
            [
                SceneItem(word: "сосна",    icon: "tree.fill",             hasTargetSound: true),
                SceneItem(word: "слон",     icon: "hare.fill",             hasTargetSound: true),
                SceneItem(word: "заяц",     icon: "hare.fill",             hasTargetSound: sound == "З"),
                SceneItem(word: "звезда",   icon: "star.fill",             hasTargetSound: sound == "З"),
                SceneItem(word: "цветок",   icon: "leaf.fill",             hasTargetSound: sound == "Ц"),
                SceneItem(word: "медведь",  icon: "pawprint.fill",         hasTargetSound: false),
                SceneItem(word: "ягода",    icon: "circle.fill",           hasTargetSound: false),
                SceneItem(word: "лиса",     icon: "cat.fill",              hasTargetSound: false),
                SceneItem(word: "птица",    icon: "bird.fill",             hasTargetSound: false)
            ],
            // Сцена 3 — океан
            [
                SceneItem(word: "сом",      icon: "fish.fill",             hasTargetSound: true),
                SceneItem(word: "скала",    icon: "mountain.2.fill",       hasTargetSound: true),
                SceneItem(word: "зонтик",   icon: "umbrella.fill",         hasTargetSound: sound == "З"),
                SceneItem(word: "цепь",     icon: "link",                  hasTargetSound: sound == "Ц"),
                SceneItem(word: "краб",     icon: "ant.fill",              hasTargetSound: false),
                SceneItem(word: "волна",    icon: "water.waves",           hasTargetSound: false),
                SceneItem(word: "лодка",    icon: "sailboat.fill",         hasTargetSound: false),
                SceneItem(word: "дельфин",  icon: "fish.fill",             hasTargetSound: false),
                SceneItem(word: "ракушка",  icon: "sparkle",               hasTargetSound: false)
            ],
            // Сцена 4 — школа
            [
                SceneItem(word: "стул",     icon: "chair.lounge.fill",     hasTargetSound: true),
                SceneItem(word: "стол",     icon: "table.furniture",       hasTargetSound: true),
                SceneItem(word: "сумка",    icon: "bag.fill",              hasTargetSound: true),
                SceneItem(word: "зубры",    icon: "pawprint",              hasTargetSound: sound == "З"),
                SceneItem(word: "цифра",    icon: "number",                hasTargetSound: sound == "Ц"),
                SceneItem(word: "книга",    icon: "book.fill",             hasTargetSound: false),
                SceneItem(word: "линейка",  icon: "ruler.fill",            hasTargetSound: false),
                SceneItem(word: "ножницы",  icon: "scissors",              hasTargetSound: false),
                SceneItem(word: "карандаш", icon: "pencil",                hasTargetSound: false)
            ],
            // Сцена 5 — площадка
            [
                SceneItem(word: "самокат",  icon: "figure.roll",           hasTargetSound: true),
                SceneItem(word: "собака",   icon: "pawprint.fill",         hasTargetSound: true),
                SceneItem(word: "зуб",      icon: "staroflife.fill",       hasTargetSound: sound == "З"),
                SceneItem(word: "цирк",     icon: "tent.fill",             hasTargetSound: sound == "Ц"),
                SceneItem(word: "горка",    icon: "mountain.2.fill",       hasTargetSound: false),
                SceneItem(word: "мяч",      icon: "soccerball",            hasTargetSound: false),
                SceneItem(word: "качели",   icon: "figure.play",           hasTargetSound: false),
                SceneItem(word: "голубь",   icon: "bird.fill",             hasTargetSound: false),
                SceneItem(word: "велосипед",icon: "bicycle",               hasTargetSound: false)
            ],
            // Сцена 6 — пляж
            [
                SceneItem(word: "сапог",    icon: "shoe.fill",             hasTargetSound: true),
                SceneItem(word: "солнце",   icon: "sun.max.fill",          hasTargetSound: true),
                SceneItem(word: "зеркало",  icon: "rectangle.portrait.fill", hasTargetSound: sound == "З"),
                SceneItem(word: "цапля",    icon: "bird",                  hasTargetSound: sound == "Ц"),
                SceneItem(word: "пальма",   icon: "tree",                  hasTargetSound: false),
                SceneItem(word: "ведро",    icon: "cylinder",              hasTargetSound: false),
                SceneItem(word: "мяч",      icon: "sportscourt",           hasTargetSound: false),
                SceneItem(word: "парус",    icon: "sailboat.fill",         hasTargetSound: false),
                SceneItem(word: "якорь",    icon: "anchor.fill",           hasTargetSound: false)
            ]
        ]
    }

    // MARK: - Catalogs: Hissing (Ш, Ж, Ч, Щ)

    private static func hissingCatalog(for sound: String) -> [[SceneItem]] {
        [
            // Сцена 1 — кухня
            [
                SceneItem(word: "шапка",    icon: "hat.cap",               hasTargetSound: sound != "Ж" && sound != "Ч" && sound != "Щ"),
                SceneItem(word: "кошка",    icon: "cat.fill",              hasTargetSound: true),
                SceneItem(word: "жук",      icon: "ant.fill",              hasTargetSound: sound == "Ж"),
                SceneItem(word: "чашка",    icon: "cup.and.saucer.fill",   hasTargetSound: sound == "Ч" || sound == "Ш"),
                SceneItem(word: "щётка",    icon: "paintbrush.fill",       hasTargetSound: sound == "Щ"),
                SceneItem(word: "вилка",    icon: "fork.knife",            hasTargetSound: false),
                SceneItem(word: "дом",      icon: "house.fill",            hasTargetSound: false),
                SceneItem(word: "рыба",     icon: "fish.fill",             hasTargetSound: false),
                SceneItem(word: "луна",     icon: "moon.fill",             hasTargetSound: false)
            ],
            // Сцена 2 — лес
            [
                SceneItem(word: "шишка",    icon: "leaf.fill",             hasTargetSound: sound == "Ш"),
                SceneItem(word: "ёж",       icon: "tortoise.fill",         hasTargetSound: sound == "Ж"),
                SceneItem(word: "черепаха", icon: "tortoise.fill",         hasTargetSound: sound == "Ч"),
                SceneItem(word: "щука",     icon: "fish.fill",             hasTargetSound: sound == "Щ"),
                SceneItem(word: "машина",   icon: "car.fill",              hasTargetSound: sound == "Ш"),
                SceneItem(word: "кот",      icon: "cat.fill",              hasTargetSound: false),
                SceneItem(word: "дерево",   icon: "tree.fill",             hasTargetSound: false),
                SceneItem(word: "облако",   icon: "cloud.fill",            hasTargetSound: false),
                SceneItem(word: "гриб",     icon: "leaf",                  hasTargetSound: false)
            ],
            // Сцена 3 — океан
            [
                SceneItem(word: "шар",      icon: "balloon.fill",          hasTargetSound: sound == "Ш"),
                SceneItem(word: "жираф",    icon: "pawprint.fill",         hasTargetSound: sound == "Ж"),
                SceneItem(word: "ключ",     icon: "key.fill",              hasTargetSound: sound == "Ч"),
                SceneItem(word: "плащ",     icon: "coat",                  hasTargetSound: sound == "Щ" || sound == "Ш"),
                SceneItem(word: "краб",     icon: "ant.fill",              hasTargetSound: false),
                SceneItem(word: "волна",    icon: "water.waves",           hasTargetSound: false),
                SceneItem(word: "лодка",    icon: "sailboat.fill",         hasTargetSound: false),
                SceneItem(word: "камень",   icon: "mountain.2.fill",       hasTargetSound: false),
                SceneItem(word: "звезда",   icon: "star.fill",             hasTargetSound: false)
            ],
            // Сцена 4 — школа
            [
                SceneItem(word: "карандаш", icon: "pencil",                hasTargetSound: sound == "Ш"),
                SceneItem(word: "ножик",    icon: "scissors",              hasTargetSound: sound == "Ж"),
                SceneItem(word: "мяч",      icon: "soccerball",            hasTargetSound: sound == "Ч"),
                SceneItem(word: "ящик",     icon: "shippingbox.fill",      hasTargetSound: sound == "Щ" || sound == "Ш"),
                SceneItem(word: "книга",    icon: "book.fill",             hasTargetSound: false),
                SceneItem(word: "стол",     icon: "table.furniture",       hasTargetSound: false),
                SceneItem(word: "окно",     icon: "window.casement",       hasTargetSound: false),
                SceneItem(word: "рюкзак",   icon: "bag.fill",              hasTargetSound: false),
                SceneItem(word: "доска",    icon: "rectangle.fill",        hasTargetSound: false)
            ],
            // Сцена 5 — площадка
            [
                SceneItem(word: "мышка",    icon: "hare.fill",             hasTargetSound: sound == "Ш"),
                SceneItem(word: "лужа",     icon: "water.waves",           hasTargetSound: sound == "Ж"),
                SceneItem(word: "мяч",      icon: "sportscourt",           hasTargetSound: sound == "Ч"),
                SceneItem(word: "пещера",   icon: "mountain.2.fill",       hasTargetSound: sound == "Щ"),
                SceneItem(word: "горка",    icon: "figure.play",           hasTargetSound: false),
                SceneItem(word: "гриб",     icon: "leaf",                  hasTargetSound: false),
                SceneItem(word: "велосипед",icon: "bicycle",               hasTargetSound: false),
                SceneItem(word: "скамья",   icon: "chair.lounge.fill",     hasTargetSound: false),
                SceneItem(word: "голубь",   icon: "bird.fill",             hasTargetSound: false)
            ],
            // Сцена 6 — пляж
            [
                SceneItem(word: "шляпа",    icon: "hat.widebrim.fill",     hasTargetSound: sound == "Ш"),
                SceneItem(word: "пляж",     icon: "sun.horizon.fill",      hasTargetSound: sound == "Ж"),
                SceneItem(word: "бочка",    icon: "cylinder.fill",         hasTargetSound: sound == "Ч"),
                SceneItem(word: "щит",      icon: "shield.fill",           hasTargetSound: sound == "Щ"),
                SceneItem(word: "якорь",    icon: "anchor.fill",           hasTargetSound: false),
                SceneItem(word: "пальма",   icon: "tree",                  hasTargetSound: false),
                SceneItem(word: "парус",    icon: "sailboat.fill",         hasTargetSound: false),
                SceneItem(word: "ведро",    icon: "cylinder",              hasTargetSound: false),
                SceneItem(word: "скала",    icon: "mountain.2.fill",       hasTargetSound: false)
            ]
        ]
    }

    // MARK: - Catalogs: Sonants (Р, Л)

    private static func sonantCatalog(for sound: String) -> [[SceneItem]] {
        [
            // Сцена 1 — кухня
            [
                SceneItem(word: "рыба",     icon: "fish.fill",             hasTargetSound: sound == "Р"),
                SceneItem(word: "лимон",    icon: "leaf.fill",             hasTargetSound: sound == "Л"),
                SceneItem(word: "ракета",   icon: "airplane.departure",    hasTargetSound: sound == "Р"),
                SceneItem(word: "лампа",    icon: "lamp.desk.fill",        hasTargetSound: sound == "Л"),
                SceneItem(word: "корова",   icon: "hare.fill",             hasTargetSound: sound == "Р"),
                SceneItem(word: "дом",      icon: "house.fill",            hasTargetSound: false),
                SceneItem(word: "кот",      icon: "cat.fill",              hasTargetSound: false),
                SceneItem(word: "окно",     icon: "window.casement",       hasTargetSound: false),
                SceneItem(word: "стакан",   icon: "cup.and.saucer",        hasTargetSound: false)
            ],
            // Сцена 2 — лес
            [
                SceneItem(word: "рак",      icon: "ant.fill",              hasTargetSound: sound == "Р"),
                SceneItem(word: "лиса",     icon: "cat.fill",              hasTargetSound: sound == "Л"),
                SceneItem(word: "роза",     icon: "leaf.fill",             hasTargetSound: sound == "Р"),
                SceneItem(word: "лось",     icon: "pawprint.fill",         hasTargetSound: sound == "Л"),
                SceneItem(word: "берёза",   icon: "tree.fill",             hasTargetSound: sound == "Р"),
                SceneItem(word: "гриб",     icon: "leaf",                  hasTargetSound: false),
                SceneItem(word: "ягода",    icon: "circle.fill",           hasTargetSound: false),
                SceneItem(word: "птица",    icon: "bird.fill",             hasTargetSound: false),
                SceneItem(word: "пень",     icon: "cylinder",              hasTargetSound: false)
            ],
            // Сцена 3 — океан
            [
                SceneItem(word: "рак",      icon: "ant.fill",              hasTargetSound: sound == "Р"),
                SceneItem(word: "лодка",    icon: "sailboat.fill",         hasTargetSound: sound == "Л"),
                SceneItem(word: "краб",     icon: "ant",                   hasTargetSound: sound == "Р"),
                SceneItem(word: "луч",      icon: "sun.max.fill",          hasTargetSound: sound == "Л"),
                SceneItem(word: "морж",     icon: "tortoise.fill",         hasTargetSound: sound == "Р"),
                SceneItem(word: "волна",    icon: "water.waves",           hasTargetSound: false),
                SceneItem(word: "ракушка",  icon: "sparkle",               hasTargetSound: false),
                SceneItem(word: "якорь",    icon: "anchor.fill",           hasTargetSound: false),
                SceneItem(word: "парус",    icon: "sailboat",              hasTargetSound: false)
            ],
            // Сцена 4 — школа
            [
                SceneItem(word: "ручка",    icon: "pencil",                hasTargetSound: sound == "Р"),
                SceneItem(word: "линейка",  icon: "ruler.fill",            hasTargetSound: sound == "Л"),
                SceneItem(word: "рюкзак",   icon: "bag.fill",              hasTargetSound: sound == "Р"),
                SceneItem(word: "лента",    icon: "ribbon.fill",           hasTargetSound: sound == "Л"),
                SceneItem(word: "тетрадь",  icon: "book.fill",             hasTargetSound: sound == "Р"),
                SceneItem(word: "стол",     icon: "table.furniture",       hasTargetSound: false),
                SceneItem(word: "доска",    icon: "rectangle.fill",        hasTargetSound: false),
                SceneItem(word: "краска",   icon: "paintbrush.fill",       hasTargetSound: false),
                SceneItem(word: "цифра",    icon: "number",                hasTargetSound: false)
            ],
            // Сцена 5 — площадка
            [
                SceneItem(word: "горка",    icon: "mountain.2.fill",       hasTargetSound: sound == "Р"),
                SceneItem(word: "лопата",   icon: "shovel.fill",           hasTargetSound: sound == "Л"),
                SceneItem(word: "ракета",   icon: "airplane.departure",    hasTargetSound: sound == "Р"),
                SceneItem(word: "лужа",     icon: "water.waves",           hasTargetSound: sound == "Л"),
                SceneItem(word: "рукавица", icon: "hand.raised.fill",      hasTargetSound: sound == "Р"),
                SceneItem(word: "мяч",      icon: "soccerball",            hasTargetSound: false),
                SceneItem(word: "велосипед",icon: "bicycle",               hasTargetSound: false),
                SceneItem(word: "голубь",   icon: "bird.fill",             hasTargetSound: false),
                SceneItem(word: "скамья",   icon: "chair.lounge.fill",     hasTargetSound: false)
            ],
            // Сцена 6 — пляж
            [
                SceneItem(word: "рак",      icon: "ant.fill",              hasTargetSound: sound == "Р"),
                SceneItem(word: "лето",     icon: "sun.max.fill",          hasTargetSound: sound == "Л"),
                SceneItem(word: "риф",      icon: "mountain.2.fill",       hasTargetSound: sound == "Р"),
                SceneItem(word: "лёд",      icon: "snowflake",             hasTargetSound: sound == "Л"),
                SceneItem(word: "волна",    icon: "water.waves",           hasTargetSound: false),
                SceneItem(word: "пальма",   icon: "tree",                  hasTargetSound: false),
                SceneItem(word: "парус",    icon: "sailboat.fill",         hasTargetSound: false),
                SceneItem(word: "якорь",    icon: "anchor.fill",           hasTargetSound: false),
                SceneItem(word: "ведро",    icon: "cylinder",              hasTargetSound: false)
            ]
        ]
    }

    // MARK: - Catalogs: Velar (К, Г, Х)

    private static func velarCatalog(for sound: String) -> [[SceneItem]] {
        [
            // Сцена 1 — кухня
            [
                SceneItem(word: "кот",      icon: "cat.fill",              hasTargetSound: sound == "К"),
                SceneItem(word: "гриб",     icon: "leaf.fill",             hasTargetSound: sound == "Г"),
                SceneItem(word: "хлеб",     icon: "birthday.cake.fill",    hasTargetSound: sound == "Х"),
                SceneItem(word: "кубик",    icon: "cube.fill",             hasTargetSound: sound == "К"),
                SceneItem(word: "горка",    icon: "mountain.2.fill",       hasTargetSound: sound == "Г"),
                SceneItem(word: "дом",      icon: "house.fill",            hasTargetSound: false),
                SceneItem(word: "рыба",     icon: "fish.fill",             hasTargetSound: false),
                SceneItem(word: "ложка",    icon: "fork.knife",            hasTargetSound: false),
                SceneItem(word: "луна",     icon: "moon.fill",             hasTargetSound: false)
            ],
            // Сцена 2 — лес
            [
                SceneItem(word: "ключ",     icon: "key.fill",              hasTargetSound: sound == "К"),
                SceneItem(word: "гусь",     icon: "bird",                  hasTargetSound: sound == "Г"),
                SceneItem(word: "муха",     icon: "allergens",             hasTargetSound: sound == "Х"),
                SceneItem(word: "кошка",    icon: "pawprint.fill",         hasTargetSound: sound == "К"),
                SceneItem(word: "нога",     icon: "figure.walk",           hasTargetSound: sound == "Г"),
                SceneItem(word: "ягода",    icon: "circle.fill",           hasTargetSound: false),
                SceneItem(word: "птица",    icon: "bird.fill",             hasTargetSound: false),
                SceneItem(word: "пень",     icon: "cylinder",              hasTargetSound: false),
                SceneItem(word: "дерево",   icon: "tree.fill",             hasTargetSound: false)
            ],
            // Сцена 3 — океан
            [
                SceneItem(word: "краб",     icon: "ant.fill",              hasTargetSound: sound == "К"),
                SceneItem(word: "горизонт", icon: "sun.horizon.fill",      hasTargetSound: sound == "Г"),
                SceneItem(word: "ухо",      icon: "ear.fill",              hasTargetSound: sound == "Х"),
                SceneItem(word: "корабль",  icon: "sailboat.fill",         hasTargetSound: sound == "К"),
                SceneItem(word: "глубина",  icon: "water.waves",           hasTargetSound: sound == "Г"),
                SceneItem(word: "волна",    icon: "water.waves",           hasTargetSound: false),
                SceneItem(word: "звезда",   icon: "star.fill",             hasTargetSound: false),
                SceneItem(word: "якорь",    icon: "anchor.fill",           hasTargetSound: false),
                SceneItem(word: "парус",    icon: "sailboat",              hasTargetSound: false)
            ],
            // Сцена 4 — школа
            [
                SceneItem(word: "карандаш", icon: "pencil",                hasTargetSound: sound == "К"),
                SceneItem(word: "глобус",   icon: "globe",                 hasTargetSound: sound == "Г"),
                SceneItem(word: "пух",      icon: "cloud.fill",            hasTargetSound: sound == "Х"),
                SceneItem(word: "класс",    icon: "building.fill",         hasTargetSound: sound == "К"),
                SceneItem(word: "гаечный",  icon: "wrench.fill",           hasTargetSound: sound == "Г"),
                SceneItem(word: "книга",    icon: "book.fill",             hasTargetSound: false),
                SceneItem(word: "стол",     icon: "table.furniture",       hasTargetSound: false),
                SceneItem(word: "доска",    icon: "rectangle.fill",        hasTargetSound: false),
                SceneItem(word: "линейка",  icon: "ruler.fill",            hasTargetSound: false)
            ],
            // Сцена 5 — площадка
            [
                SceneItem(word: "качели",   icon: "figure.play",           hasTargetSound: sound == "К"),
                SceneItem(word: "голубь",   icon: "bird.fill",             hasTargetSound: sound == "Г"),
                SceneItem(word: "петух",    icon: "bird",                  hasTargetSound: sound == "Х"),
                SceneItem(word: "кот",      icon: "cat.fill",              hasTargetSound: sound == "К"),
                SceneItem(word: "горка",    icon: "mountain.2.fill",       hasTargetSound: sound == "Г"),
                SceneItem(word: "мяч",      icon: "soccerball",            hasTargetSound: false),
                SceneItem(word: "велосипед",icon: "bicycle",               hasTargetSound: false),
                SceneItem(word: "скамья",   icon: "chair.lounge.fill",     hasTargetSound: false),
                SceneItem(word: "лужа",     icon: "water.waves",           hasTargetSound: false)
            ],
            // Сцена 6 — пляж
            [
                SceneItem(word: "крабик",   icon: "ant.fill",              hasTargetSound: sound == "К"),
                SceneItem(word: "галька",   icon: "circle.fill",           hasTargetSound: sound == "Г"),
                SceneItem(word: "хвост",    icon: "chevron.right",         hasTargetSound: sound == "Х"),
                SceneItem(word: "ковш",     icon: "cylinder",              hasTargetSound: sound == "К"),
                SceneItem(word: "горизонт", icon: "sun.horizon.fill",      hasTargetSound: sound == "Г"),
                SceneItem(word: "пальма",   icon: "tree",                  hasTargetSound: false),
                SceneItem(word: "парус",    icon: "sailboat.fill",         hasTargetSound: false),
                SceneItem(word: "якорь",    icon: "anchor.fill",           hasTargetSound: false),
                SceneItem(word: "волна",    icon: "water.waves",           hasTargetSound: false)
            ]
        ]
    }
}

// MARK: - SM2Quality extension

private extension SM2Quality {
    /// Конвертирует accuracy (0–1) в SM-2 качество (0–5).
    static func from(accuracy: Float) -> SM2Quality {
        switch accuracy {
        case 0.9...:      return .perfect
        case 0.75..<0.9:  return .correct
        case 0.6..<0.75:  return .hardCorrect
        case 0.4..<0.6:   return .hardWrong
        case 0.2..<0.4:   return .wrong
        default:          return .blackout
        }
    }
}
