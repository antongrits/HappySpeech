import FirebaseCore
import FirebaseFirestore
import Foundation

// MARK: - FirebaseTestSupport
//
// Конфигурирует минимальный Firebase-app для unit-тестов, которым нужен
// инициализированный `FirebaseApp` (например, тесты Live-сервисов, дёргающих
// `Auth.auth()`). Без этого `Auth.auth()` / `Database.database()` крашат
// тестовый хост, потому что `FirebaseApp.configure()` в тестах не вызывается.
//
// Это НЕ сетевой Firebase: используются фиктивные options, реальные сетевые
// вызовы по-прежнему не выполняются (и не покрываются — см. *ContractTests).
// Цель — лишь дать SDK валидный default-app, чтобы singleton-аксессоры
// не вызывали `fatalError`.
//
// ВАЖНО про `apiKey`: FirebaseInstallations при конфигурации валидирует ФОРМАТ
// API-ключа (`+[FIRInstallations validateAPIKey:]`) — он обязан начинаться с
// `AIza` и иметь длину 39 символов. Ключ неправильного формата приводит к
// `abort()` (`signal abrt`), который роняет весь тестовый процесс и каскадно
// «заваливает» все последующие тесты. Поэтому здесь используется СИНТАКСИЧЕСКИ
// валидный, но заведомо нерабочий фиктивный ключ — он проходит формат-валидацию,
// но не аутентифицирует ни один реальный сетевой запрос.
//
// ВАЖНО про сеть Firestore: с валидным форматом ключа Firestore-SDK начинает
// тянуться в реальную сеть. Запросы получают `Permission denied`, и `WriteStream`
// уходит в бесконечный retry — `batch.commit()` НИКОГДА не возвращает управление,
// что вешает тест-процесс. Поэтому сразу после `configure()` мы отключаем сеть
// Firestore (`disableNetwork`): write-операции и `commit()` тогда завершаются
// детерминированно против локального offline-кэша, без сети и без зависаний.

enum FirebaseTestSupport {

    /// Синтаксически валидный, но фиктивный Firebase API-ключ.
    /// Формат: `AIza` + 35 символов из набора `[0-9A-Za-z_-]` = ровно 39 символов.
    /// Проходит `+[FIRInstallations validateAPIKey:]`, но не работает по сети.
    private static let dummyAPIKey = "AIzaSyTEST0000000000000000000000000000A"

    /// Хост Firestore-эмулятора (стандартный порт из `firebase.json`).
    private static let emulatorHost = "127.0.0.1"
    private static let emulatorPort = 8080

    /// `true`, если default Firestore сконфигурирован против локального
    /// эмулятора. Тесты УСПЕШНОГО drain/upload могут реально выполняться,
    /// когда это значение `true` — иначе их `XCTSkipUnless` пропускает.
    ///
    /// `nonisolated(unsafe)`: записывается ровно один раз внутри
    /// сериализованного ленивого инициализатора `configureOnce` (Swift
    /// гарантирует однократное потокобезопасное исполнение `let`-инициализатора),
    /// после чего значение только читается — гонок нет.
    nonisolated(unsafe) private(set) static var isUsingEmulator = false

    /// Гарантирует, что default `FirebaseApp` сконфигурирован ровно один раз
    /// за процесс тестов. Идемпотентно и потокобезопасно.
    static func ensureConfigured() {
        configureOnce
    }

    /// Синхронная проверка доступности Firestore-эмулятора.
    /// Вызывается ДО первого обращения к `Firestore.firestore()`, поэтому
    /// решение «эмулятор / offline» принимается единожды и консистентно.
    private static func emulatorReachable() -> Bool {
        guard let url = URL(string: "http://\(emulatorHost):\(emulatorPort)/") else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let code = (response as? HTTPURLResponse)?.statusCode, code < 500 {
                reachable = true
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 3.0)
        return reachable
    }

    private static let configureOnce: Void = {
        guard FirebaseApp.app() == nil else { return }
        let options = FirebaseOptions(
            googleAppID: "1:000000000000:ios:0000000000000000",
            gcmSenderID: "000000000000"
        )
        options.projectID = "happyspeech-tests"
        options.apiKey = dummyAPIKey
        options.bundleID = Bundle.main.bundleIdentifier ?? "com.mmf.bsu.HappySpeech"
        options.databaseURL = "https://happyspeech-tests.firebaseio.com"
        options.storageBucket = "happyspeech-tests.appspot.com"
        FirebaseApp.configure(options: options)

        // Если локальный Firestore-эмулятор доступен — направляем default
        // Firestore на него. Тогда `setData`/`batch.commit()` завершают `await`
        // быстро (ack локального эмулятора), без сети и без зависаний — тесты
        // успешного drain/upload могут реально выполняться.
        //
        // Настройки Firestore обязаны быть установлены ДО первого обращения к
        // экземпляру; `configureOnce` вызывается из `setUp()` раньше создания
        // любого SUT (`firestore` в `LiveSyncService` — `lazy var`).
        if emulatorReachable() {
            let firestore = Firestore.firestore()
            let settings = firestore.settings
            settings.host = "\(emulatorHost):\(emulatorPort)"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            firestore.settings = settings
            isUsingEmulator = true
            return
        }

        // Эмулятор недоступен: отключаем сеть Firestore — все write/commit
        // завершаются против локального offline-кэша мгновенно и детерминированно,
        // без зависаний на бесконечном retry `WriteStream` при `Permission denied`.
        let semaphore = DispatchSemaphore(value: 0)
        Firestore.firestore().disableNetwork { _ in
            semaphore.signal()
        }
        // Ждём подтверждения отключения сети, но не дольше 5 секунд:
        // если SDK по какой-то причине не ответит, тесты не зависнут навсегда.
        _ = semaphore.wait(timeout: .now() + 5.0)
    }()
}
