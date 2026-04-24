import Foundation
import OSLog

// MARK: - SoundHunterBusinessLogic

@MainActor
protocol SoundHunterBusinessLogic: AnyObject {
    func loadScene(_ request: SoundHunterModels.LoadScene.Request)
    func tapItem(_ request: SoundHunterModels.TapItem.Request)
    func loadNextScene()
    func completeGame()
}

// MARK: - SoundHunterInteractor
//
// Бизнес-логика «Охоты на звук». Внутри — каталог из 4 звуковых групп × 3 сцен ×
// 9 предметов. Для каждой сессии выбирается свой targetSound, группа выводится
// через `resolveSoundGroup(for:)`. После загрузки сцены пользователь нажимает
// на предметы: правильные подсвечиваются зелёным, неправильные трясутся и
// подсвечиваются красным. Когда все целевые найдены — автопереход к следующей
// сцене или к итоговому экрану.

@MainActor
final class SoundHunterInteractor: SoundHunterBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any SoundHunterPresentationLogic)?
    var router: (any SoundHunterRoutingLogic)?

    private let hapticService: (any HapticService)?
    private let soundService: (any SoundServiceProtocol)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundHunter")

    // MARK: - State

    private let targetSound: String
    private let soundGroup: String
    private let totalScenes: Int = 3
    private var sceneIndex: Int = 0
    private var scenes: [[HuntItem]] = []
    private var correctCount: Int = 0
    private var totalCorrectNeeded: Int = 0
    private var totalCorrectOverall: Int = 0
    private var totalPossibleOverall: Int = 0
    private var shakeResetTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?

    // MARK: - Init

    init(
        targetSound: String,
        hapticService: (any HapticService)? = nil,
        soundService: (any SoundServiceProtocol)? = nil
    ) {
        self.targetSound = targetSound
        self.soundGroup = Self.resolveSoundGroup(for: targetSound)
        self.hapticService = hapticService
        self.soundService = soundService
    }

    deinit {
        shakeResetTask?.cancel()
        advanceTask?.cancel()
    }

    // MARK: - loadScene

    func loadScene(_ request: SoundHunterModels.LoadScene.Request) {
        sceneIndex = max(0, min(request.sceneIndex, totalScenes - 1))
        // Подготавливаем все сцены для группы заранее — чтобы totalPossibleOverall
        // был известен ещё до завершения.
        scenes = Self.buildScenes(for: soundGroup)
        totalPossibleOverall = scenes.flatMap { $0 }.filter(\.hasTargetSound).count
        logger.info(
            "Load scene=\(self.sceneIndex, privacy: .public) group=\(self.soundGroup, privacy: .public) total=\(self.totalPossibleOverall, privacy: .public)"
        )

        let sceneItems = scenes[sceneIndex]
        totalCorrectNeeded = sceneItems.filter(\.hasTargetSound).count
        correctCount = 0

        let response = SoundHunterModels.LoadScene.Response(
            items: sceneItems,
            targetSound: targetSound,
            targetSoundGroup: soundGroup,
            sceneIndex: sceneIndex,
            totalScenes: totalScenes,
            totalCorrectNeeded: totalCorrectNeeded
        )
        presenter?.presentLoadScene(response)
    }

    // MARK: - tapItem

    func tapItem(_ request: SoundHunterModels.TapItem.Request) {
        guard sceneIndex < scenes.count else { return }
        var sceneItems = scenes[sceneIndex]
        guard let index = sceneItems.firstIndex(where: { $0.id == request.itemId }) else { return }

        let item = sceneItems[index]
        // Повторное нажатие по уже обработанному предмету игнорируем.
        guard item.tapState == .idle else { return }

        let newState: TapState
        if item.hasTargetSound {
            newState = .correct
            correctCount += 1
            totalCorrectOverall += 1
            hapticService?.selection()
            soundService?.playUISound(.correct)
            logger.info("Tap correct id=\(request.itemId.uuidString, privacy: .public) word=\(item.word, privacy: .public)")
        } else {
            newState = .wrong
            hapticService?.notification(.warning)
            soundService?.playUISound(.incorrect)
            logger.info("Tap wrong id=\(request.itemId.uuidString, privacy: .public) word=\(item.word, privacy: .public)")
            scheduleShakeReset(for: request.itemId)
        }

        sceneItems[index].tapState = newState
        scenes[sceneIndex] = sceneItems

        let isSceneComplete = correctCount >= totalCorrectNeeded
        let response = SoundHunterModels.TapItem.Response(
            itemId: request.itemId,
            newState: newState,
            correctCount: correctCount,
            totalCorrectNeeded: totalCorrectNeeded,
            isSceneComplete: isSceneComplete
        )
        presenter?.presentTapItem(response)

        if isSceneComplete {
            scheduleAdvance()
        }
    }

    // MARK: - loadNextScene

    func loadNextScene() {
        advanceTask?.cancel()
        let nextIndex = sceneIndex + 1
        if nextIndex >= totalScenes {
            completeGame()
            return
        }
        sceneIndex = nextIndex
        let sceneItems = scenes[sceneIndex]
        totalCorrectNeeded = sceneItems.filter(\.hasTargetSound).count
        correctCount = 0

        let response = SoundHunterModels.NextScene.Response(
            nextSceneIndex: sceneIndex,
            items: sceneItems,
            targetSound: targetSound,
            totalCorrectNeeded: totalCorrectNeeded
        )
        presenter?.presentNextScene(response)
        logger.info("Next scene=\(self.sceneIndex, privacy: .public) needed=\(self.totalCorrectNeeded, privacy: .public)")
    }

    // MARK: - completeGame

    func completeGame() {
        advanceTask?.cancel()
        shakeResetTask?.cancel()

        let totalScore: Float = totalPossibleOverall > 0
            ? Float(totalCorrectOverall) / Float(totalPossibleOverall)
            : 0
        let clamped = max(0, min(1, totalScore))
        let stars = starsFor(score: clamped)

        if stars >= 2 {
            hapticService?.notification(.success)
        } else if stars == 1 {
            hapticService?.notification(.warning)
        } else {
            hapticService?.impact(.light)
        }

        let response = SoundHunterModels.CompleteScene.Response(
            totalScore: clamped,
            starsEarned: stars,
            isFinalScene: true
        )
        presenter?.presentCompleteScene(response)
        logger.info("Complete game score=\(clamped, privacy: .public) stars=\(stars, privacy: .public)")
    }

    // MARK: - Private helpers

    private func scheduleShakeReset(for itemId: UUID) {
        shakeResetTask?.cancel()
        shakeResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            // Сбрасываем неправильно помеченный предмет обратно в idle, чтобы ребёнок
            // мог перейти к следующему — ошибка не блокирует дальнейшие попытки.
            guard self.sceneIndex < self.scenes.count else { return }
            var sceneItems = self.scenes[self.sceneIndex]
            guard let index = sceneItems.firstIndex(where: { $0.id == itemId }) else { return }
            guard sceneItems[index].tapState == .wrong else { return }
            sceneItems[index].tapState = .idle
            self.scenes[self.sceneIndex] = sceneItems

            let response = SoundHunterModels.TapItem.Response(
                itemId: itemId,
                newState: .idle,
                correctCount: self.correctCount,
                totalCorrectNeeded: self.totalCorrectNeeded,
                isSceneComplete: self.correctCount >= self.totalCorrectNeeded
            )
            self.presenter?.presentTapItem(response)
        }
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self, !Task.isCancelled else { return }
            self.loadNextScene()
        }
    }

    private func starsFor(score: Float) -> Int {
        let clamped = max(0, min(1, score))
        if clamped >= 0.9 { return 3 }
        if clamped >= 0.7 { return 2 }
        if clamped >= 0.5 { return 1 }
        return 0
    }

    // MARK: - Static helpers

    /// Определяет звуковую группу по целевому звуку.
    static func resolveSoundGroup(for targetSound: String) -> String {
        let upper = targetSound.uppercased()
        let firstLetter = upper.prefix(1)
        switch firstLetter {
        case "С", "З", "Ц":            return "whistling"
        case "Ш", "Ж", "Ч", "Щ":       return "hissing"
        case "Р", "Л":                 return "sonants"
        case "К", "Г", "Х":            return "velar"
        default:                       return "whistling"
        }
    }

    /// Каталог сцен для каждой группы звуков. По 3 сцены × 9 предметов.
    /// В каждой сцене ровно 3–4 предмета со «своим» звуком, остальные — отвлекающие.
    static func buildScenes(for group: String) -> [[HuntItem]] {
        switch group {
        case "whistling": return whistlingScenes()
        case "hissing":   return hissingScenes()
        case "sonants":   return sonantScenes()
        case "velar":     return velarScenes()
        default:          return whistlingScenes()
        }
    }

    // MARK: - Catalog: Whistling (С, З, Ц)

    private static func whistlingScenes() -> [[HuntItem]] {
        [
            [
                HuntItem(word: "самолёт", icon: "airplane", hasTargetSound: true),
                HuntItem(word: "собака", icon: "pawprint.fill", hasTargetSound: true),
                HuntItem(word: "стол", icon: "table.furniture", hasTargetSound: true),
                HuntItem(word: "кот", icon: "cat.fill", hasTargetSound: false),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false),
                HuntItem(word: "книга", icon: "book.fill", hasTargetSound: false),
                HuntItem(word: "цветок", icon: "leaf.fill", hasTargetSound: true),
                HuntItem(word: "птица", icon: "bird.fill", hasTargetSound: false)
            ],
            [
                HuntItem(word: "сумка", icon: "bag.fill", hasTargetSound: true),
                HuntItem(word: "зонт", icon: "umbrella.fill", hasTargetSound: true),
                HuntItem(word: "солнце", icon: "sun.max.fill", hasTargetSound: true),
                HuntItem(word: "луна", icon: "moon.fill", hasTargetSound: false),
                HuntItem(word: "лодка", icon: "sailboat.fill", hasTargetSound: false),
                HuntItem(word: "мяч", icon: "soccerball", hasTargetSound: false),
                HuntItem(word: "нога", icon: "figure.walk", hasTargetSound: false),
                HuntItem(word: "цепь", icon: "link", hasTargetSound: true),
                HuntItem(word: "окно", icon: "window.casement", hasTargetSound: false)
            ],
            [
                HuntItem(word: "сапог", icon: "shoe.fill", hasTargetSound: true),
                HuntItem(word: "заяц", icon: "hare.fill", hasTargetSound: true),
                HuntItem(word: "звезда", icon: "star.fill", hasTargetSound: true),
                HuntItem(word: "роза", icon: "flame.fill", hasTargetSound: true),
                HuntItem(word: "хлеб", icon: "birthday.cake.fill", hasTargetSound: false),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "ключ", icon: "key.fill", hasTargetSound: false),
                HuntItem(word: "муха", icon: "allergens", hasTargetSound: false),
                HuntItem(word: "лодка", icon: "sailboat.fill", hasTargetSound: false)
            ]
        ]
    }

    // MARK: - Catalog: Hissing (Ш, Ж, Ч, Щ)

    private static func hissingScenes() -> [[HuntItem]] {
        [
            [
                HuntItem(word: "шапка", icon: "hat.cap", hasTargetSound: true),
                HuntItem(word: "кошка", icon: "cat.fill", hasTargetSound: true),
                HuntItem(word: "машина", icon: "car.fill", hasTargetSound: true),
                HuntItem(word: "стол", icon: "table.furniture", hasTargetSound: false),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false),
                HuntItem(word: "книга", icon: "book.fill", hasTargetSound: false),
                HuntItem(word: "шарик", icon: "balloon.fill", hasTargetSound: true),
                HuntItem(word: "окно", icon: "window.casement", hasTargetSound: false)
            ],
            [
                HuntItem(word: "жук", icon: "ant.fill", hasTargetSound: true),
                HuntItem(word: "ёж", icon: "tortoise.fill", hasTargetSound: true),
                HuntItem(word: "ножик", icon: "scissors", hasTargetSound: true),
                HuntItem(word: "сумка", icon: "bag.fill", hasTargetSound: false),
                HuntItem(word: "лодка", icon: "sailboat.fill", hasTargetSound: false),
                HuntItem(word: "рыба", icon: "fish.fill", hasTargetSound: false),
                HuntItem(word: "жираф", icon: "pawprint.fill", hasTargetSound: true),
                HuntItem(word: "мяч", icon: "soccerball", hasTargetSound: false),
                HuntItem(word: "хлеб", icon: "birthday.cake.fill", hasTargetSound: false)
            ],
            [
                HuntItem(word: "чашка", icon: "cup.and.saucer.fill", hasTargetSound: true),
                HuntItem(word: "ключ", icon: "key.fill", hasTargetSound: true),
                HuntItem(word: "щука", icon: "fish.fill", hasTargetSound: true),
                HuntItem(word: "плащ", icon: "coat", hasTargetSound: true),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "стол", icon: "table.furniture", hasTargetSound: false),
                HuntItem(word: "луна", icon: "moon.fill", hasTargetSound: false),
                HuntItem(word: "сад", icon: "tree.fill", hasTargetSound: false),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false)
            ]
        ]
    }

    // MARK: - Catalog: Sonants (Р, Л)

    private static func sonantScenes() -> [[HuntItem]] {
        [
            [
                HuntItem(word: "рыба", icon: "fish.fill", hasTargetSound: true),
                HuntItem(word: "рак", icon: "ant.fill", hasTargetSound: true),
                HuntItem(word: "ракета", icon: "airplane.departure", hasTargetSound: true),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "кот", icon: "cat.fill", hasTargetSound: false),
                HuntItem(word: "сад", icon: "tree.fill", hasTargetSound: false),
                HuntItem(word: "корова", icon: "hare.fill", hasTargetSound: true),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false),
                HuntItem(word: "окно", icon: "window.casement", hasTargetSound: false)
            ],
            [
                HuntItem(word: "лампа", icon: "lamp.desk.fill", hasTargetSound: true),
                HuntItem(word: "лодка", icon: "sailboat.fill", hasTargetSound: true),
                HuntItem(word: "луна", icon: "moon.fill", hasTargetSound: true),
                HuntItem(word: "волк", icon: "pawprint", hasTargetSound: true),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "сад", icon: "tree.fill", hasTargetSound: false),
                HuntItem(word: "кот", icon: "cat.fill", hasTargetSound: false),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false),
                HuntItem(word: "окно", icon: "window.casement", hasTargetSound: false)
            ],
            [
                HuntItem(word: "горка", icon: "mountain.2.fill", hasTargetSound: true),
                HuntItem(word: "рука", icon: "hand.raised.fill", hasTargetSound: true),
                HuntItem(word: "роза", icon: "flame.fill", hasTargetSound: true),
                HuntItem(word: "белка", icon: "leaf.fill", hasTargetSound: true),
                HuntItem(word: "кот", icon: "cat.fill", hasTargetSound: false),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false),
                HuntItem(word: "сумка", icon: "bag.fill", hasTargetSound: false),
                HuntItem(word: "книга", icon: "book.fill", hasTargetSound: false)
            ]
        ]
    }

    // MARK: - Catalog: Velar (К, Г, Х)

    private static func velarScenes() -> [[HuntItem]] {
        [
            [
                HuntItem(word: "кот", icon: "cat.fill", hasTargetSound: true),
                HuntItem(word: "кубик", icon: "cube.fill", hasTargetSound: true),
                HuntItem(word: "ключ", icon: "key.fill", hasTargetSound: true),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "рыба", icon: "fish.fill", hasTargetSound: false),
                HuntItem(word: "сад", icon: "tree.fill", hasTargetSound: false),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false),
                HuntItem(word: "окно", icon: "window.casement", hasTargetSound: false),
                HuntItem(word: "кошка", icon: "pawprint.fill", hasTargetSound: true)
            ],
            [
                HuntItem(word: "гусь", icon: "bird", hasTargetSound: true),
                HuntItem(word: "нога", icon: "figure.walk", hasTargetSound: true),
                HuntItem(word: "горка", icon: "mountain.2.fill", hasTargetSound: true),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "рыба", icon: "fish.fill", hasTargetSound: false),
                HuntItem(word: "сад", icon: "tree.fill", hasTargetSound: false),
                HuntItem(word: "сумка", icon: "bag.fill", hasTargetSound: true),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false),
                HuntItem(word: "луна", icon: "moon.fill", hasTargetSound: false)
            ],
            [
                HuntItem(word: "хлеб", icon: "birthday.cake.fill", hasTargetSound: true),
                HuntItem(word: "муха", icon: "allergens", hasTargetSound: true),
                HuntItem(word: "петух", icon: "bird.fill", hasTargetSound: true),
                HuntItem(word: "ухо", icon: "ear.fill", hasTargetSound: true),
                HuntItem(word: "дом", icon: "house.fill", hasTargetSound: false),
                HuntItem(word: "сад", icon: "tree.fill", hasTargetSound: false),
                HuntItem(word: "мяч", icon: "sportscourt", hasTargetSound: false),
                HuntItem(word: "рыба", icon: "fish.fill", hasTargetSound: false),
                HuntItem(word: "окно", icon: "window.casement", hasTargetSound: false)
            ]
        ]
    }
}
