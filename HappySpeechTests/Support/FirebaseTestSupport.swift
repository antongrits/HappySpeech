import FirebaseCore
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

enum FirebaseTestSupport {

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
        options.apiKey = "test-api-key"
        options.bundleID = Bundle.main.bundleIdentifier ?? "com.mmf.bsu.HappySpeech"
        options.databaseURL = "https://happyspeech-tests.firebaseio.com"
        options.storageBucket = "happyspeech-tests.appspot.com"
        FirebaseApp.configure(options: options)
    }()
}
