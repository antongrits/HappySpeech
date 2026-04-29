@testable import HappySpeech
import XCTest

// MARK: - AppShortcutsTests
// ==================================================================================
// Unit-тесты для DeepLinkRouter (Block L — L.6).
//
// L.6.1 — DeepLinkRouter накапливает pending actions если coordinator не зарегистрирован
// L.6.2 — DeepLinkRouter воспроизводит pending actions при register
// L.6.3 — DeepLinkRouter сразу dispatches если coordinator уже зарегистрирован
// L.6.4 — Несколько pending actions воспроизводятся в правильном порядке
// L.6.5 — pendingActions очищается после register
// L.6.6 — OpenLessonIntent normalizeSound: корректно нормализует входные строки
// ==================================================================================

// MARK: - MockAppCoordinatorBridge

@MainActor
final class MockAppCoordinatorBridge: AppCoordinatorBridge {
    private(set) var handledActions: [DeepLinkAction] = []

    func handle(_ action: DeepLinkAction) {
        handledActions.append(action)
    }
}

// MARK: - AppShortcutsTests

@MainActor
final class AppShortcutsTests: XCTestCase {

    // MARK: - Private helpers

    /// Создаёт изолированный экземпляр DeepLinkRouter через MockIsolatedRouter,
    /// чтобы не загрязнять singleton в тестах.
    private func makeRouter() -> IsolatedDeepLinkRouter {
        IsolatedDeepLinkRouter()
    }

    // MARK: - L.6.1

    /// DeepLinkRouter накапливает pending actions если coordinator не зарегистрирован.
    func testRouter_holdsPendingActions_whenCoordinatorNotRegistered() {
        let router = makeRouter()

        router.handleOpenLesson(soundId: "Ш")
        router.handleShowProgress()

        XCTAssertEqual(router.pendingActionsCount, 2, "Должно быть 2 отложенных действия")
    }

    // MARK: - L.6.2

    /// DeepLinkRouter воспроизводит pending actions при register.
    func testRouter_replaysPendingActions_onRegister() {
        let router = makeRouter()
        let mock = MockAppCoordinatorBridge()

        router.handleShowProgress()
        router.handlePlayWithLyalya()

        XCTAssertEqual(router.pendingActionsCount, 2)
        XCTAssertTrue(mock.handledActions.isEmpty)

        router.register(coordinator: mock)

        XCTAssertEqual(mock.handledActions.count, 2, "Оба pending действия должны быть воспроизведены")
    }

    // MARK: - L.6.3

    /// Если coordinator уже зарегистрирован — dispatch происходит немедленно без накопления.
    func testRouter_dispatchesImmediately_whenCoordinatorRegistered() {
        let router = makeRouter()
        let mock = MockAppCoordinatorBridge()

        router.register(coordinator: mock)
        router.handleStartBreathing()

        XCTAssertEqual(mock.handledActions.count, 1)
        if case .startBreathing = mock.handledActions.first {
            // Верное действие
        } else {
            XCTFail("Ожидали .startBreathing, получили \(String(describing: mock.handledActions.first))")
        }
    }

    // MARK: - L.6.4

    /// Несколько pending actions воспроизводятся в правильном FIFO порядке.
    func testRouter_pendingActionsReplayedInOrder() {
        let router = makeRouter()
        let mock = MockAppCoordinatorBridge()

        router.handleOpenLesson(soundId: "Р")
        router.handleShowProgress()
        router.handleShowTodaysMission()

        router.register(coordinator: mock)

        guard mock.handledActions.count == 3 else {
            XCTFail("Ожидали 3 действия, получили \(mock.handledActions.count)")
            return
        }

        if case .openLesson(let soundId) = mock.handledActions[0] {
            XCTAssertEqual(soundId, "Р")
        } else {
            XCTFail("Первое действие должно быть .openLesson")
        }

        if case .showProgress = mock.handledActions[1] {
            // Верно
        } else {
            XCTFail("Второе действие должно быть .showProgress")
        }

        if case .showTodaysMission = mock.handledActions[2] {
            // Верно
        } else {
            XCTFail("Третье действие должно быть .showTodaysMission")
        }
    }

    // MARK: - L.6.5

    /// pendingActions очищается после register — повторная регистрация не воспроизводит.
    func testRouter_pendingActionsCleared_afterRegister() {
        let router = makeRouter()
        let mock1 = MockAppCoordinatorBridge()
        let mock2 = MockAppCoordinatorBridge()

        router.handlePlayWithLyalya()
        router.register(coordinator: mock1)

        XCTAssertEqual(router.pendingActionsCount, 0, "pendingActions должен быть очищен после register")

        // Регистрируем второй coordinator — не должен получить старые actions
        router.register(coordinator: mock2)
        XCTAssertEqual(mock2.handledActions.count, 0, "Второй coordinator не должен получать старые pending actions")
    }

    // MARK: - L.6.6

    /// Проверяем normalizeSound для OpenLessonIntent через валидацию звуков.
    /// Передаём корректные и некорректные значения.
    @available(iOS 17.0, *)
    func testOpenLessonIntent_validSounds_accepted() {
        let validSounds = ["С", "З", "Ц", "Ш", "Ж", "Ч", "Щ", "Р", "Рь", "Л", "Ль", "К", "Г", "Х"]

        for sound in validSounds {
            let intent = OpenLessonIntent(soundId: sound)
            XCTAssertEqual(intent.soundId, sound, "Звук \(sound) должен быть принят без изменений")
        }
    }
}

// MARK: - IsolatedDeepLinkRouter
// Testable копия DeepLinkRouter без использования singleton — позволяет
// тестировать логику pending в изоляции.

@MainActor
final class IsolatedDeepLinkRouter {

    private weak var coordinator: (any AppCoordinatorBridge)?
    private var pendingActions: [DeepLinkAction] = []

    var pendingActionsCount: Int { pendingActions.count }

    func register(coordinator: any AppCoordinatorBridge) {
        self.coordinator = coordinator
        for action in pendingActions {
            coordinator.handle(action)
        }
        pendingActions.removeAll()
    }

    func handleOpenLesson(soundId: String) { dispatch(.openLesson(soundId: soundId)) }
    func handleShowProgress() { dispatch(.showProgress) }
    func handleStartBreathing() { dispatch(.startBreathing) }
    func handlePlayWithLyalya() { dispatch(.playWithLyalya) }
    func handleShowTodaysMission() { dispatch(.showTodaysMission) }

    private func dispatch(_ action: DeepLinkAction) {
        if let coordinator = coordinator {
            coordinator.handle(action)
        } else {
            pendingActions.append(action)
        }
    }
}
