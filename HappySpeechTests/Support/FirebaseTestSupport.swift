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

    /// Гарантирует, что default `FirebaseApp` сконфигурирован ровно один раз
    /// за процесс тестов. Идемпотентно и потокобезопасно.
    static func ensureConfigured() {
        configureOnce
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

        // Отключаем сеть Firestore — все write/commit завершаются против
        // локального offline-кэша мгновенно и детерминированно, без зависаний
        // на бесконечном retry `WriteStream` при `Permission denied`.
        let semaphore = DispatchSemaphore(value: 0)
        Firestore.firestore().disableNetwork { _ in
            semaphore.signal()
        }
        // Ждём подтверждения отключения сети, но не дольше 5 секунд:
        // если SDK по какой-то причине не ответит, тесты не зависнут навсегда.
        _ = semaphore.wait(timeout: .now() + 5.0)
    }()
}
