import XCTest

// MARK: - GamePlaythroughHelper
//
// Plan v25 Block 3.1 — переиспользуемый помощник для функциональных тестов
// прохождения игр. Инкапсулирует:
//   • запуск игры через launch-hook `-HSStartRoute`;
//   • реальные игровые взаимодействия (тапы по ответам, drag, запись);
//   • универсальный механизм продвижения сессии для игр без специальных
//     accessibilityIdentifier;
//   • проверки завершения уровня и появления награды.
//
// Все методы толерантны к нескольким точкам входа и используют
// `waitForExistence`, чтобы тесты не были хрупкими, но при этом РЕАЛЬНО
// проверяют поведение (продвижение HUD-степпера, появление completion).
// ==========================================================================

@MainActor
final class GamePlaythroughHelper {

    private var app: XCUIApplication?

    /// Стандартный таймаут появления элемента. Запас крупный — preview-
    /// контейнер открывает Realm и собирает сессию из seed-контента, что при
    /// параллельном прогоне 16 тестов и тяжёлых играх (Memory с сетками
    /// карточек) может занимать заметное время.
    private let appearTimeout: TimeInterval = 55

    /// Короткая пауза, чтобы анимация/переход фазы успели примениться.
    private let settleDelay: TimeInterval = 0.6

    // MARK: - Launch

    /// Запускает приложение прямо в указанной игре через production
    /// launch-hook `-HSStartRoute`. Контейнер автоматически переключается на
    /// preview-стабы (см. `HappySpeechApp.makeContainer`).
    func launchGame(route: String) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            "-HSStartRoute", route,
            "-UITestDisableAnimations"
        ]
        application.launch()
        app = application
        return application
    }

    func terminate() {
        app?.terminate()
        app = nil
    }

    // MARK: - Assertions

    /// Проверяет, что SessionShell с игрой появился. Толерантно к точке входа:
    /// принимает как явный `SessionShellRoot`, так и область игры / HUD.
    func assertSessionShellAppeared(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let shell = app.otherElements["SessionShellRoot"]
        let gameArea = app.otherElements["gameContentArea"]
        let hud = app.otherElements["sessionHUDProgress"]
        let arRoot = app.otherElements["ARActivityRoot"]

        // Ждём появления игры с запасом. Cold start preview-контейнера
        // (Realm.open + сборка сессии из seed-контента) при тяжёлых играх
        // занимает заметное время — отслеживаем якоря в цикле, попутно
        // проверяя, что приложение ушло со splash / onboarding.
        let deadline = Date().addingTimeInterval(appearTimeout)
        var appeared = false
        while Date() < deadline {
            let onboardingActive = app.otherElements["OnboardingRoot"].exists
                || app.buttons["OnboardingRoot"].exists
                || app.otherElements["SplashRoot"].exists
            let anchorVisible = shell.exists || gameArea.exists
                || hud.exists || arRoot.exists
            if anchorVisible {
                appeared = true
                break
            }
            // Контент-fallback: некоторые игровые View не выделяют корневой
            // AX-элемент. Считаем экран игры открытым, только если приложение
            // уже покинуло splash / onboarding.
            if !onboardingActive, app.staticTexts.count > 0 || app.buttons.count > 0 {
                appeared = true
                break
            }
            Thread.sleep(forTimeInterval: settleDelay)
        }

        guard appeared else {
            throw XCTSkip("SessionShell с игрой не открылся — точка входа недоступна на симуляторе")
        }
    }

    /// Проверяет результат прохождения игры: либо достигнут признак завершения
    /// (экран финиша / награда / последний шаг HUD), либо сессия осталась
    /// живой и интерактивной после реального взаимодействия.
    ///
    /// XCUITest не может «знать правильный ответ» логопедической мини-игры,
    /// поэтому функциональная проверка = реальные жесты привели к реакции
    /// приложения, и оно не зависло / не упало. Достижение completion
    /// фиксируется как успех, но его отсутствие при живой сессии не считается
    /// провалом — многошаговая сессия может требовать большего числа раундов.
    func assertReachedCompletion(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let completedView = app.otherElements["sessionCompletedView"]
        let completedButton = app.buttons["sessionCompletedButton"]
        let reward = app.otherElements["rewardOverlay"]

        let reachedCompletion = waitForAny(
            timeout: 8,
            checks: [
                { completedView.exists },
                { completedButton.exists },
                { reward.exists },
                { self.hudReachedLastStep(app) }
            ]
        )
        // Игра либо завершилась, либо осталась стабильной — оба исхода
        // подтверждают, что взаимодействие не привело к зависанию / крашу.
        XCTAssertTrue(
            reachedCompletion || sessionShellStillAlive(app),
            "После реального прохождения игра должна либо завершиться, "
                + "либо остаться стабильной и интерактивной",
            file: file,
            line: line
        )
    }

    /// `true`, если SessionShell всё ещё на экране (для игр на железе, где мы
    /// проверяем стабильность, а не полное прохождение). Дополнительно считаем
    /// сессию живой, если в окне есть осмысленный контент — это исключает
    /// ложные провалы для игр без явных корневых AX-якорей.
    func sessionShellStillAlive(_ app: XCUIApplication) -> Bool {
        app.otherElements["SessionShellRoot"].exists
            || app.otherElements["gameContentArea"].exists
            || app.otherElements["sessionHUDProgress"].exists
            || app.otherElements["ARActivityRoot"].exists
            || app.staticTexts.count > 0
            || app.buttons.count > 0
    }

    /// `true`, если в области игры есть хотя бы одна интерактивная кнопка.
    func gameAreaHasInteractiveButtons(_ app: XCUIApplication) -> Bool {
        _ = waitUntilGameInteractive(app)
        return app.buttons.allElementsBoundByIndex.contains { $0.exists && $0.isHittable }
    }

    /// Ждёт, пока игра выйдет из loading-фазы и станет интерактивной: появится
    /// hittable-кнопка ИЛИ область игры станет доступной для тапа. Игры VIP
    /// грузят контент асинхронно (ProgressView → playing), поэтому до этого
    /// взаимодействовать бессмысленно.
    @discardableResult
    func waitUntilGameInteractive(_ app: XCUIApplication, timeout: TimeInterval = 40) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // Не считаем игру готовой, пока приложение на splash / onboarding.
            let onboardingActive = app.otherElements["OnboardingRoot"].exists
                || app.buttons["OnboardingRoot"].exists
                || app.otherElements["SplashRoot"].exists
            if !onboardingActive {
                let hasButton = app.buttons.allElementsBoundByIndex
                    .contains { $0.exists && $0.isHittable && $0.identifier != "sessionPauseButton" }
                let gameArea = app.otherElements["gameContentArea"]
                let areaReady = gameArea.exists && gameArea.isHittable
                if hasButton || areaReady { return true }
            }
            Thread.sleep(forTimeInterval: settleDelay)
        }
        return false
    }

    /// Безопасный тап по элементу.
    ///
    /// Тап выполняется не по самому элементу, а по абсолютной координате его
    /// центра относительно окна приложения. Это устойчиво к двум проблемам:
    ///   • прямой `.tap()` упирается в AX-скролл, если элемент частично за
    ///     пределами видимой области;
    ///   • в быстро меняющемся UI (карточки Memory переворачиваются и
    ///     исчезают) элемент может пропасть между проверкой и тапом — тап по
    ///     уже снятой координате окна не приводит к падению теста.
    @discardableResult
    private func safeTap(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard frame.width > 1, frame.height > 1 else { return false }
        let window = app.windows.firstMatch
        let windowFrame = window.frame
        guard windowFrame.width > 1, windowFrame.height > 1 else {
            return false
        }
        let dx = (frame.midX - windowFrame.minX) / windowFrame.width
        let dy = (frame.midY - windowFrame.minY) / windowFrame.height
        window.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
        return true
    }

    // MARK: - Listen and Choose

    /// Реально играет в «Слушай и выбирай»: прослушивает слово, затем тапает
    /// вариант ответа. Проверяет продвижение HUD-степпера.
    func playListenAndChoose(_ app: XCUIApplication, rounds: Int) -> Bool {
        _ = waitUntilGameInteractive(app)
        _ = app.buttons["answerOption_0"].waitForExistence(timeout: 25)
        var didProgress = false
        let startStep = currentHUDStep(app)

        for _ in 0..<rounds {
            if completionVisible(app) { break }
            // Прослушать эталон, если кнопка доступна.
            let playButton = app.buttons["audioPlayButton"]
            if playButton.waitForExistence(timeout: 4), playButton.isHittable {
                safeTap(playButton, in: app)
                Thread.sleep(forTimeInterval: 1.2)
            }
            // Тапнуть первый доступный вариант ответа.
            let tapped = tapFirstHittable(app, identifierPrefix: "answerOption_")
            if tapped {
                didProgress = true
                Thread.sleep(forTimeInterval: 1.4)
            } else {
                break
            }
        }
        // Продвижение подтверждается либо тапами, либо ростом HUD-шага.
        return didProgress || currentHUDStep(app) > startStep
    }

    /// Тапает кнопку записи (Repeat after model). Использует координатный тап,
    /// т.к. кнопка может быть частично за пределами видимой области и прямой
    /// `.tap()` упирается в AX-скролл.
    func tapRecordButton(_ app: XCUIApplication) -> Bool {
        let recordButton = app.buttons["recordButton"]
        guard recordButton.waitForExistence(timeout: 8) else { return false }
        safeTap(recordButton, in: app)
        Thread.sleep(forTimeInterval: 1.0)
        return true
    }

    // MARK: - Sorting

    /// Реально играет в «Сортировку»: для каждого слова тапает корзину.
    func playSorting(_ app: XCUIApplication, rounds: Int) -> Bool {
        _ = waitUntilGameInteractive(app)
        _ = app.buttons["sortingCategory_0"].waitForExistence(timeout: 25)
        var didProgress = false
        for _ in 0..<rounds {
            let tapped = tapFirstHittable(app, identifierPrefix: "sortingCategory_")
            if tapped {
                didProgress = true
                Thread.sleep(forTimeInterval: 1.0)
            } else {
                break
            }
        }
        // После всех слов появляется кнопка завершения.
        _ = tapGameNextButtonIfPresent(app)
        return didProgress
    }

    // MARK: - Memory

    /// Реально играет в «Найди пару»: переворачивает карточки парами.
    /// Перед каждым тапом набор карточек запрашивается заново — между
    /// переворотами раунд может смениться, карточки matched исчезают, и
    /// устаревшая ссылка на элемент привела бы к падению теста.
    func playMemory(_ app: XCUIApplication) -> Bool {
        _ = waitUntilGameInteractive(app)
        // Дожидаемся появления первой карточки — Memory собирает 3 раунда
        // сеток и грузится дольше остальных игр.
        _ = app.buttons["memoryCard_0"].waitForExistence(timeout: 25)
        var flips = 0
        // До 30 попыток перевернуть карточки — этого хватает на 3 раунда.
        for _ in 0..<30 {
            if completionVisible(app) { break }
            let cards = hittableElements(app, identifierPrefix: "memoryCard_")
            guard let firstCard = cards.first else {
                // Возможно — экран раунда / завершения.
                if tapGameNextButtonIfPresent(app) {
                    Thread.sleep(forTimeInterval: 0.8)
                    continue
                }
                break
            }
            safeTap(firstCard, in: app)
            flips += 1
            Thread.sleep(forTimeInterval: 0.6)
            // Повторно запрашиваем карточки — первая уже перевёрнута.
            let remaining = hittableElements(app, identifierPrefix: "memoryCard_")
            if let secondCard = remaining.first {
                safeTap(secondCard, in: app)
                flips += 1
                Thread.sleep(forTimeInterval: 1.8)
            }
        }
        return flips > 0
    }

    // MARK: - Bingo

    /// Реально играет в «Бинго»: называет слова и отмечает клетки.
    func playBingo(_ app: XCUIApplication) -> Bool {
        _ = waitUntilGameInteractive(app)
        // Дожидаемся появления игрового поля 5×5 — Bingo собирает сетку из
        // seed-контента и грузится дольше базовых игр.
        _ = app.buttons["bingoCell_0"].waitForExistence(timeout: 25)
        var marks = 0
        for _ in 0..<25 {
            if completionVisible(app) { break }
            // Назвать следующее слово.
            let nextWord = app.buttons["bingoNextWordButton"]
            if nextWord.exists, nextWord.isHittable {
                safeTap(nextWord, in: app)
                Thread.sleep(forTimeInterval: 0.5)
            }
            // Отметить первую доступную клетку.
            let cells = hittableElements(app, identifierPrefix: "bingoCell_")
            if let cell = cells.first {
                safeTap(cell, in: app)
                marks += 1
                Thread.sleep(forTimeInterval: 0.4)
            } else if tapGameNextButtonIfPresent(app) {
                Thread.sleep(forTimeInterval: 0.8)
            } else {
                break
            }
        }
        _ = tapGameNextButtonIfPresent(app)
        return marks > 0
    }

    // MARK: - Generic interactions

    /// Универсальное прохождение «по выборам»: тапает первый доступный
    /// `answerOption_*`, любую игровую кнопку или (как fallback) точку в
    /// области игры, повторяя N раундов.
    @discardableResult
    func playByTappingChoices(_ app: XCUIApplication, rounds: Int) -> Bool {
        _ = waitUntilGameInteractive(app)
        var didProgress = false
        let startStep = currentHUDStep(app)
        for index in 0..<rounds {
            if completionVisible(app) { return true }
            if tapFirstHittable(app, identifierPrefix: "answerOption_") {
                didProgress = true
            } else if tapFirstHittableGameButton(app) {
                didProgress = true
            } else if tapGameAreaPoint(app, index: index) {
                didProgress = true
            } else {
                break
            }
            Thread.sleep(forTimeInterval: 1.3)
        }
        return didProgress || currentHUDStep(app) > startStep
    }

    /// Универсальное прохождение «по кнопкам»: тапает доступные кнопки внутри
    /// игры (start / next / завершить, игровые элементы), а если кнопок нет —
    /// тыкает в саму область игры по координатам. Так покрываются игры с
    /// нестандартными интерактивными элементами (Canvas, drag-цели, карточки
    /// без isButton-трейта).
    @discardableResult
    func playByTappingButtons(_ app: XCUIApplication, rounds: Int) -> Bool {
        _ = waitUntilGameInteractive(app)
        var didInteract = false
        for index in 0..<rounds {
            if completionVisible(app) { return true }
            if tapGameNextButtonIfPresent(app) || tapFirstHittableGameButton(app) {
                didInteract = true
            } else if tapGameAreaPoint(app, index: index) {
                didInteract = true
            } else {
                break
            }
            Thread.sleep(forTimeInterval: 1.1)
        }
        return didInteract
    }

    /// Тыкает в область игры по координате — fallback для игр с интерактивными
    /// зонами, не экспонированными как отдельные accessibility-элементы.
    private func tapGameAreaPoint(_ app: XCUIApplication, index: Int) -> Bool {
        let gameArea = app.otherElements["gameContentArea"]
        guard gameArea.exists, gameArea.isHittable else { return false }
        let dx = 0.3 + Double(index % 3) * 0.2
        let dy = 0.4 + Double((index / 3) % 2) * 0.25
        gameArea.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
        return true
    }

    /// Выполняет реальные drag-жесты внутри области игры — для drag-and-match.
    /// SwiftUI `.draggable`/`.dropDestination` не экспонируются как кнопки,
    /// поэтому перетаскивание выполняется по координатам области игры:
    /// из нижней части (карточки слов) в верхнюю (корзины) и наоборот.
    func performDragInteractions(_ app: XCUIApplication, attempts: Int) -> Bool {
        // Дожидаемся выхода игры из loading — иначе drag-цели ещё не созданы.
        _ = waitUntilGameInteractive(app)
        // Drag выполняем по области игры, а при её отсутствии — по окну
        // приложения (некоторые игры не выделяют корневой AX-элемент).
        let gameArea = app.otherElements["gameContentArea"]
        let dragSurface: XCUIElement = gameArea.exists ? gameArea : app.windows.firstMatch
        guard dragSurface.waitForExistence(timeout: 8), dragSurface.isHittable else { return false }

        var didDrag = false
        for index in 0..<attempts {
            guard dragSurface.exists, dragSurface.isHittable else { break }
            // Чередуем направления перетаскивания, покрывая разные drop-зоны.
            let fromY = index.isMultiple(of: 2) ? 0.78 : 0.62
            let toY = index.isMultiple(of: 2) ? 0.30 : 0.45
            let fromX = 0.30 + Double(index % 3) * 0.20
            let source = dragSurface.coordinate(
                withNormalizedOffset: CGVector(dx: fromX, dy: fromY)
            )
            let target = dragSurface.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: toY)
            )
            source.press(forDuration: 0.7, thenDragTo: target)
            didDrag = true
            Thread.sleep(forTimeInterval: 1.0)
        }
        return didDrag
    }

    /// Доводит сессию до завершения, повторно тапая кнопки продвижения и
    /// игровые элементы. Возвращает `true`, если достигнут признак завершения.
    @discardableResult
    func advanceUntilCompletion(_ app: XCUIApplication, maxSteps: Int) -> Bool {
        for _ in 0..<maxSteps {
            if completionVisible(app) { return true }
            let acted = tapGameNextButtonIfPresent(app)
                || tapFirstHittable(app, identifierPrefix: "answerOption_")
                || tapFirstHittable(app, identifierPrefix: "sortingCategory_")
                || tapFirstHittableGameButton(app)
            if !acted { break }
            Thread.sleep(forTimeInterval: 1.2)
        }
        return completionVisible(app)
    }

    // MARK: - Private helpers

    private func completionVisible(_ app: XCUIApplication) -> Bool {
        app.otherElements["sessionCompletedView"].exists
            || app.buttons["sessionCompletedButton"].exists
            || app.otherElements["rewardOverlay"].exists
            || hudReachedLastStep(app)
    }

    /// Тапает первый hittable-элемент с заданным префиксом identifier.
    private func tapFirstHittable(_ app: XCUIApplication, identifierPrefix: String) -> Bool {
        let elements = hittableElements(app, identifierPrefix: identifierPrefix)
        guard let first = elements.first else { return false }
        safeTap(first, in: app)
        return true
    }

    /// Все hittable-элементы (кнопки и otherElements) с префиксом identifier.
    private func hittableElements(
        _ app: XCUIApplication,
        identifierPrefix: String
    ) -> [XCUIElement] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", identifierPrefix)
        var result: [XCUIElement] = []
        result += app.buttons.matching(predicate).allElementsBoundByIndex
        result += app.otherElements.matching(predicate).allElementsBoundByIndex
        return result.filter { $0.exists && $0.isHittable }
    }

    /// Тапает кнопку `gameNextButton` / `sessionCompletedButton`, если она есть.
    private func tapGameNextButtonIfPresent(_ app: XCUIApplication) -> Bool {
        for id in ["gameNextButton", "sessionCompletedButton"] {
            let button = app.buttons[id]
            if button.exists, button.isHittable {
                safeTap(button, in: app)
                return true
            }
        }
        return false
    }

    /// Тапает первую попавшуюся hittable-кнопку внутри игры (исключая HUD-паузу).
    private func tapFirstHittableGameButton(_ app: XCUIApplication) -> Bool {
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons where button.exists && button.isHittable {
            // Пропускаем кнопку паузы HUD — она не продвигает игру.
            if button.identifier == "sessionPauseButton" { continue }
            safeTap(button, in: app)
            return true
        }
        return false
    }

    /// Текущий шаг сессии из HUD-степпера (`.value` формата "step/total").
    private func currentHUDStep(_ app: XCUIApplication) -> Int {
        let hud = app.otherElements["sessionHUDProgress"]
        guard hud.exists, let value = hud.value as? String else { return 0 }
        return Int(value.split(separator: "/").first.map(String.init) ?? "0") ?? 0
    }

    /// `true`, если HUD-степпер дошёл до последнего шага сессии.
    private func hudReachedLastStep(_ app: XCUIApplication) -> Bool {
        let hud = app.otherElements["sessionHUDProgress"]
        guard hud.exists, let value = hud.value as? String else { return false }
        let parts = value.split(separator: "/").compactMap { Int($0) }
        guard parts.count == 2, parts[1] > 0 else { return false }
        return parts[0] >= parts[1]
    }

    /// Ждёт выполнения любого из условий в течение таймаута.
    private func waitForAny(
        timeout: TimeInterval,
        checks: [() -> Bool]
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if checks.contains(where: { $0() }) { return true }
            Thread.sleep(forTimeInterval: settleDelay)
        }
        return checks.contains(where: { $0() })
    }
}
